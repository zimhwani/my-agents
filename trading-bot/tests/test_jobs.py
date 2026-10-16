"""Research jobs from deploy/job.json: validation, step execution, publishing."""

import json
import subprocess
import sys

import pytest

from tradebot.jobs import JobError, load_job, run_job


def _write(tmp_path, job):
    p = tmp_path / "job.json"
    p.write_text(json.dumps(job))
    return p


def test_load_job_allows_research_commands_only(tmp_path):
    ok = load_job(_write(tmp_path, {"id": "gold-2y", "env": ".env.gold", "steps": [["research", "--fetch-days", "730"]]}))
    assert ok["publish"] == [] and ok["timeout_minutes"] == 180
    assert ok["steps"] == [{"env": ".env.gold", "args": ["research", "--fetch-days", "730"]}]
    mixed = load_job(_write(tmp_path, {"id": "m", "env": ".env.gold",
                                       "steps": [{"env": ".env", "args": ["backtest", "--data", "data/g"]}]}))
    assert mixed["steps"][0]["env"] == ".env"
    bad = [
        {"id": "x", "env": ".env.gold", "steps": [["flatten"]]},                    # trading command
        {"id": "x", "env": ".env.gold", "steps": [["run"]]},
        {"id": "x y", "env": ".env.gold", "steps": [["report"]]},                   # id with a space
        {"id": "x", "env": "../secrets", "steps": [["report"]]},                    # env outside the folder
        {"id": "x", "env": ".env.gold", "steps": [["report", "--env", ".env"]]},    # env override in a step
        {"id": "x", "env": ".env.gold", "steps": [["report"]], "publish": ["/etc/passwd"]},
        {"id": "x", "env": ".env.gold", "steps": [["report"]], "publish": ["../.env"]},
        {"id": "x", "env": ".env.gold", "steps": []},
        {"id": "x", "env": ".env.gold", "steps": [{"env": "/root/.env", "args": ["report"]}]},
        {"id": "x", "env": ".env.gold", "steps": [{"env": ".env", "args": ["flatten"]}]},
    ]
    for job in bad:
        with pytest.raises(JobError):
            load_job(_write(tmp_path, job))


def test_run_job_runs_steps_publishes_log_and_files(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    (tmp_path / "out.md").write_text("# report\n")
    calls, uploads = [], {}

    def fake_popen(cmd, stdout, stderr):
        calls.append(cmd)
        code = "print('ok')" if cmd[-1] != "boom" else "import sys; print('bad'); sys.exit(3)"
        return subprocess.Popen([sys.executable, "-c", code], stdout=stdout, stderr=stderr)

    job = {"id": "j1", "env": ".env.gold", "steps": [{"env": ".env.gold", "args": ["report"]},
                                                     {"env": ".env", "args": ["research", "boom"]},
                                                     {"env": ".env.gold", "args": ["report"]}],
           "publish": ["out.md", "missing.md"], "timeout_minutes": 5}
    status = run_job(job, tmp_path / "logs" / "j1.log", lambda n, b, c: uploads.__setitem__(n, b),
                     popen=fake_popen, poll_seconds=0.01)
    assert status == "failed at step 2 (exit 3)" and len(calls) == 2  # stops at the first failure
    assert calls[0][-4:] == ["tradebot", "--env", ".env.gold", "report"] and calls[1][-3] == ".env"
    log = uploads["jobs/j1.log"].decode()
    assert "failed at step 2" in log and "ok" in log and "bad" in log and "missing.md: not found" in log
    assert uploads["jobs/j1/out.md"] == b"# report\n"
