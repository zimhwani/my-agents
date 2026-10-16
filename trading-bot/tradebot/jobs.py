"""Research jobs requested from git: deploy/job.json -> run on the server -> log published to the dashboard store.

The auto-deploy starts a job (as the bot user, memory-capped) when deploy/job.json carries an id it hasn't run.
Each step is a tradebot sub-command from a fixed allow-list (research/backtest/fetch, never run/flatten/kill),
run with the job's env file. Output goes to DATA_DIR/jobs/<id>.log and is uploaded, with any files listed under
"publish", to <VERCEL_BLOB_PREFIX>/jobs/ so results can be read without a shell on the server.

    {"id": "2026-10-16-gold-2y", "env": ".env.gold",
     "steps": [["research", "--strategies", "strategies_cfd/gold_day_*.json", "--fetch-days", "730"],
               {"env": ".env", "args": ["backtest", "--data", "data/gappers90"]}],
     "publish": ["data-gold/research_day.md"]}
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time as _time
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

ALLOWED = frozenset({"research", "backtest", "fetch-gappers", "fetch-crypto", "fetch-data", "report", "sweep",
                     "analyze", "crypto-explain", "tjl-check", "news", "scan"})
ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,64}$")
ENV_RE = re.compile(r"^\.env(\.[a-z0-9]+)?$")
MAX_LOG = 400_000  # bytes of log kept in the published copy (the tail)


class JobError(ValueError):
    pass


def load_job(path: str | Path) -> dict:
    job = json.loads(Path(path).read_text())
    jid, env, steps = job.get("id", ""), job.get("env", ".env"), job.get("steps")
    if not isinstance(jid, str) or not ID_RE.match(jid):
        raise JobError(f"bad job id {jid!r}")
    if not isinstance(env, str) or not ENV_RE.match(env):
        raise JobError(f"bad env file {env!r} (expected .env or .env.<name>)")
    if not isinstance(steps, list) or not steps:
        raise JobError("steps must be a non-empty list")
    norm = []
    for st in steps:
        st_env = env
        if isinstance(st, dict):  # {"env": ".env", "args": [...]}: one step on another bot's settings
            st_env, st = st.get("env", env), st.get("args")
            if not isinstance(st_env, str) or not ENV_RE.match(st_env):
                raise JobError(f"bad env file {st_env!r} (expected .env or .env.<name>)")
        if not (isinstance(st, list) and st and all(isinstance(a, str) for a in st)):
            raise JobError(f"each step is a list of strings, got {st!r}")
        if st[0] not in ALLOWED:
            raise JobError(f"step {st[0]!r} is not allowed (allowed: {', '.join(sorted(ALLOWED))})")
        if any(a in ("--env",) for a in st):
            raise JobError("set the env file with the job's 'env', not --env in a step")
        norm.append({"env": st_env, "args": list(st)})
    job["steps"] = norm
    publish = job.get("publish", [])
    if not isinstance(publish, list):
        raise JobError("publish must be a list of paths")
    for p in publish:
        if not isinstance(p, str) or p.startswith("/") or ".." in Path(p).parts:
            raise JobError(f"publish path {p!r} must be relative, inside the bot folder")
    job.setdefault("publish", [])
    job["timeout_minutes"] = int(job.get("timeout_minutes", 180))
    return job


def run_job(job: dict, log_path: Path, upload: Callable[[str, bytes, str], object] | None = None,
            python: str = sys.executable, popen=subprocess.Popen, poll_seconds: float = 60.0) -> str:
    """Run every step (stopping at the first failure); returns 'done' or 'failed: ...'."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    jid = job["id"]

    def push(status: str) -> None:
        if upload is None:
            return
        body = log_path.read_bytes()[-MAX_LOG:] if log_path.exists() else b""
        head = f"job {jid} · {status} · {datetime.now(timezone.utc):%Y-%m-%d %H:%M:%S} UTC\n\n".encode()
        try:
            upload(f"jobs/{jid}.log", head + body, "text/plain; charset=utf-8")
        except Exception as exc:  # publishing is best effort; the log stays on disk
            with log_path.open("a") as f:
                f.write(f"[job] publish failed: {exc}\n")

    status = "done"
    with log_path.open("w") as f:
        f.write(f"[job] {jid}: {len(job['steps'])} step(s), env {job['env']}\n")
    for i, step in enumerate(job["steps"], 1):
        cmd = [python, "-m", "tradebot", "--env", step["env"], *step["args"]]
        with log_path.open("a") as f:
            f.write(f"\n[job] step {i}/{len(job['steps'])} ({step['env']}): {' '.join(step['args'])}\n")
            f.flush()
            started = _time.monotonic()
            proc = popen(cmd, stdout=f, stderr=subprocess.STDOUT)
            push(f"running step {i}/{len(job['steps'])}")
            while proc.poll() is None:
                if _time.monotonic() - started > job["timeout_minutes"] * 60:
                    proc.kill()
                    proc.wait()
                    break
                _time.sleep(poll_seconds)
                f.flush()
                push(f"running step {i}/{len(job['steps'])}")
            rc = proc.returncode
            f.write(f"[job] step {i} exit code {rc} after {(_time.monotonic() - started) / 60:.1f} min\n")
        if rc != 0:
            status = f"failed at step {i} (exit {rc})"
            break
    for p in job["publish"]:
        path = Path(p)
        if upload is not None and path.is_file():
            try:
                upload(f"jobs/{jid}/{path.name}", path.read_bytes()[-MAX_LOG:],
                       "application/json" if path.suffix == ".json" else "text/plain; charset=utf-8")
                with log_path.open("a") as f:
                    f.write(f"[job] published {p}\n")
            except Exception as exc:
                with log_path.open("a") as f:
                    f.write(f"[job] publish {p} failed: {exc}\n")
        elif upload is not None:
            with log_path.open("a") as f:
                f.write(f"[job] {p}: not found, not published\n")
    with log_path.open("a") as f:
        f.write(f"\n[job] {status}\n")
    push(status)
    return status
