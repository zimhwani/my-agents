"""Command-line entry point for the GEO engine.

    python -m geo run    --client clients/example-medspa.json
    python -m geo scan   --client clients/example-medspa.json --out out
    python -m geo report --scan out/scan.json --out out

`run` = scan + analyze + report in one shot (the usual path). Split `scan`
and `report` when you want to persist a raw scan and regenerate the report
without re-querying the providers.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from .analyze import analyze
from .config import default_model, load_profile
from .providers import build_providers
from .report import render_html, render_markdown
from .scan import run_scan


def _write(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    print(f"  wrote {path}")


def _do_scan(args) -> dict:
    profile = load_profile(args.client)
    providers = build_providers(profile, args.providers.split(","), model=args.model)
    print(
        f"Scanning '{profile.business_name}' with providers "
        f"[{', '.join(p.name for p in providers)}]..."
    )
    scan = run_scan(profile, providers, max_prompts=args.max_prompts)
    print(f"  {len(scan['results'])} answers across {scan['prompt_count']} prompts")
    return scan


def _emit_report(scan: dict, out_dir: str) -> None:
    result = analyze(scan)
    result["generated_at"] = scan.get("generated_at", "")
    client = scan["client"]
    _write(os.path.join(out_dir, "report.html"), render_html(result, client))
    _write(os.path.join(out_dir, "report.md"), render_markdown(result, client))
    print(
        f"\nVisibility score for {result['client_name']}: "
        f"{result['visibility_score']}/100  "
        f"(named in {result['client']['presence_rate']:.0%} of answers)"
    )


def cmd_scan(args) -> int:
    scan = _do_scan(args)
    _write(os.path.join(args.out, "scan.json"), json.dumps(scan, indent=2))
    return 0


def cmd_report(args) -> int:
    with open(args.scan, "r", encoding="utf-8") as fh:
        scan = json.load(fh)
    _emit_report(scan, args.out)
    return 0


def cmd_run(args) -> int:
    scan = _do_scan(args)
    _write(os.path.join(args.out, "scan.json"), json.dumps(scan, indent=2))
    _emit_report(scan, args.out)
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="geo", description="AI-answer visibility engine")
    sub = parser.add_subparsers(dest="command", required=True)

    def add_common(p, need_client=True):
        if need_client:
            p.add_argument("--client", required=True, help="Path to a client profile JSON")
            p.add_argument("--providers", default="mock",
                           help="Comma-separated: 'mock' (default) or 'anthropic'")
            p.add_argument("--max-prompts", type=int, default=12, help="Cap on buyer prompts")
            p.add_argument("--model", default=default_model(),
                           help="Model for the anthropic provider")
        p.add_argument("--out", default="out", help="Output directory")

    p_run = sub.add_parser("run", help="Scan + analyze + report")
    add_common(p_run)
    p_run.set_defaults(func=cmd_run)

    p_scan = sub.add_parser("scan", help="Scan and save scan.json")
    add_common(p_scan)
    p_scan.set_defaults(func=cmd_scan)

    p_report = sub.add_parser("report", help="Build a report from an existing scan.json")
    p_report.add_argument("--scan", required=True, help="Path to scan.json")
    add_common(p_report, need_client=False)
    p_report.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (FileNotFoundError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
