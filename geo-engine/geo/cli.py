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
from .batch import run_batch
from .config import ClientProfile, default_model, load_profile
from .digest import run_digest
from .fixes import generate_fixes
from .prospect import run_prospecting
from .providers import build_providers
from .sources import find_prospects, write_csv
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


def cmd_fix(args) -> int:
    if args.scan:
        with open(args.scan, "r", encoding="utf-8") as fh:
            scan = json.load(fh)
    elif args.client:
        scan = _do_scan(args)
    else:
        print("error: pass --scan <scan.json> or --client <profile.json>", file=sys.stderr)
        return 1
    profile = ClientProfile(**scan["client"])
    result = analyze(scan)
    out = os.path.join(args.out, "fixes")
    print(f"Drafting fix package for {profile.business_name}...")
    info = generate_fixes(profile, result, out, use_claude=not args.no_claude)
    print(f"  source: {', '.join(info['sources']) or 'template'}")
    for a in info["artifacts"]:
        print(f"  wrote {os.path.join(out, a)}")
    return 0


def cmd_batch(args) -> int:
    run_batch(
        args.clients,
        args.out,
        args.providers.split(","),
        max_prompts=args.max_prompts,
        model=args.model,
    )
    return 0


def cmd_digest(args) -> int:
    run_digest(
        args.clients,
        args.out,
        args.providers.split(","),
        email_to=args.email,
        max_prompts=args.max_prompts,
        model=args.model,
        dry_run=args.dry_run,
    )
    return 0


def cmd_find(args) -> int:
    rows = find_prospects(args.vertical, args.location, source=args.source, limit=args.limit)
    write_csv(rows, args.out)
    print(f"Found {len(rows)} prospects → {args.out}")
    for r in rows[:10]:
        print(f"  · {r['business_name']}")
    if rows:
        print(f"\nNext: python -m geo prospect --prospects {args.out}")
    return 0


def cmd_prospect(args) -> int:
    run_prospecting(
        args.prospects,
        args.out,
        args.providers.split(","),
        max_prompts=args.max_prompts,
        model=args.model,
        use_claude=not args.no_claude,
    )
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

    p_fix = sub.add_parser("fix", help="Draft the fix package (schema, FAQ, comparison)")
    p_fix.add_argument("--scan", help="Path to an existing scan.json")
    p_fix.add_argument("--client", help="Client profile JSON (scans first if no --scan)")
    p_fix.add_argument("--providers", default="mock", help="Providers if scanning")
    p_fix.add_argument("--max-prompts", type=int, default=12)
    p_fix.add_argument("--model", default=default_model())
    p_fix.add_argument("--no-claude", action="store_true",
                       help="Force editable templates instead of AI drafting")
    p_fix.add_argument("--out", default="out", help="Output directory")
    p_fix.set_defaults(func=cmd_fix)

    p_batch = sub.add_parser("batch", help="Scan a folder of clients + build a portfolio index")
    p_batch.add_argument("--clients", required=True, help="Directory of client profile JSONs")
    p_batch.add_argument("--providers", default="mock")
    p_batch.add_argument("--max-prompts", type=int, default=12)
    p_batch.add_argument("--model", default=default_model())
    p_batch.add_argument("--out", default="portfolio", help="Output directory")
    p_batch.set_defaults(func=cmd_batch)

    p_digest = sub.add_parser("digest", help="Weekly autopilot: scan portfolio + email a digest")
    p_digest.add_argument("--clients", required=True, help="Directory of client profile JSONs")
    p_digest.add_argument("--providers", default="mock")
    p_digest.add_argument("--max-prompts", type=int, default=12)
    p_digest.add_argument("--model", default=default_model())
    p_digest.add_argument("--out", default="portfolio")
    p_digest.add_argument("--email", help="Recipient for the digest (omit to just print)")
    p_digest.add_argument("--dry-run", action="store_true", help="Print the email instead of sending")
    p_digest.set_defaults(func=cmd_digest)

    p_find = sub.add_parser("find", help="Auto-pull target businesses for a vertical + city")
    p_find.add_argument("--vertical", required=True, help="Vertical slug (e.g. dental, med_spa)")
    p_find.add_argument("--location", required=True, help='City, e.g. "San Diego, CA"')
    p_find.add_argument("--source", default="overpass", help="overpass (OpenStreetMap) or mock")
    p_find.add_argument("--limit", type=int, default=20)
    p_find.add_argument("--out", default="prospects.csv", help="Output CSV")
    p_find.set_defaults(func=cmd_find)

    p_prospect = sub.add_parser("prospect", help="Scan a list of targets + draft outreach emails")
    p_prospect.add_argument("--prospects", required=True, help="CSV of target businesses")
    p_prospect.add_argument("--providers", default="mock")
    p_prospect.add_argument("--max-prompts", type=int, default=8)
    p_prospect.add_argument("--model", default=default_model())
    p_prospect.add_argument("--no-claude", action="store_true", help="Template emails instead of AI-drafted")
    p_prospect.add_argument("--out", default="outreach")
    p_prospect.set_defaults(func=cmd_prospect)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (FileNotFoundError, ValueError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
