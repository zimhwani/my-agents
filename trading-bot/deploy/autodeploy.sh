#!/bin/sh
# Pull new commits on the bot's branch, run the tests, and restart the bots only if they pass.
# Installed as tradebot-autodeploy.timer (every 5 minutes). Logs: journalctl -u tradebot-autodeploy
set -u
REPO=/opt/my-agents
BRANCH="${TRADEBOT_BRANCH:-claude/magical-allen-jan8gi}"
BOT="$REPO/trading-bot"
PY="$BOT/.venv/bin/python"

cd "$REPO" || exit 1
git fetch -q origin "$BRANCH" || { echo "fetch failed"; exit 1; }
OLD=$(git rev-parse HEAD)
NEW=$(git rev-parse "origin/$BRANCH")
[ "$OLD" = "$NEW" ] && exit 0

if ! git merge --ff-only -q "origin/$BRANCH"; then
  echo "cannot fast-forward $OLD -> $NEW (local changes?); not deploying"
  exit 1
fi
SUBJECT=$(git log -1 --format=%s "$NEW")
cd "$BOT" || exit 1

if git diff --name-only "$OLD" "$NEW" | grep -q 'trading-bot/requirements.txt'; then
  "$BOT/.venv/bin/pip" install -q -r requirements.txt || echo "pip install failed (continuing to tests)"
fi

if ! timeout 600 "$PY" -m pytest -q -p no:cacheprovider > /tmp/tradebot-deploy-tests.log 2>&1; then
  echo "tests failed on $NEW; rolling back to $OLD"
  tail -20 /tmp/tradebot-deploy-tests.log
  cd "$REPO" && git reset -q --hard "$OLD"
  cd "$BOT" && "$PY" -m tradebot --env .env.crypto notify --text "⚠️ Deploy of ${NEW%${NEW#???????}} failed its tests; still running ${OLD%${OLD#???????}}. ($SUBJECT)" || true
  exit 1
fi

# deploy/gold.strategy (one line: a rules file path) picks the gold bot's strategy from git, so switching
# it is a commit rather than an edit on the server. Missing file = leave .env.gold alone.
if [ -f deploy/gold.strategy ] && [ -f .env.gold ]; then
  GOLD_RULES=$(head -n1 deploy/gold.strategy | tr -d '[:space:]')
  if [ -f "$GOLD_RULES" ] && ! grep -qx "STRATEGY_FILE=$GOLD_RULES" .env.gold; then
    if grep -q '^STRATEGY_FILE=' .env.gold; then
      sed -i "s|^STRATEGY_FILE=.*|STRATEGY_FILE=$GOLD_RULES|" .env.gold
    else
      echo "STRATEGY_FILE=$GOLD_RULES" >> .env.gold
    fi
    echo "gold strategy -> $GOLD_RULES"
  fi
fi

if systemctl is-enabled --quiet tradebot-crypto 2>/dev/null; then systemctl restart tradebot-crypto; fi
if systemctl is-active --quiet tradebot; then systemctl restart tradebot; fi
if systemctl is-enabled --quiet tradebot-gold 2>/dev/null; then systemctl restart tradebot-gold; fi
# deploy/job.json: a research job (allow-listed tradebot commands, see tradebot/jobs.py). A new id starts it once,
# detached, as the bot user, memory-capped so it can't starve the trading bots; its log is published to Blob.
if [ -f deploy/job.json ]; then
  JOB_ID=$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' deploy/job.json 2>/dev/null)
  JOB_LAST=$(cat /var/lib/tradebot/job.last 2>/dev/null)
  if [ -n "$JOB_ID" ] && [ "$JOB_ID" != "$JOB_LAST" ]; then
    mkdir -p /var/lib/tradebot && echo "$JOB_ID" > /var/lib/tradebot/job.last
    for d in "$BOT"/data "$BOT"/data-*; do [ -d "$d" ] && chown -R tradebot:tradebot "$d"; done  # files made by root ssh runs
    systemd-run --collect --unit="tradebot-job-$(date +%s)" --uid=tradebot --gid=tradebot \
      --working-directory="$BOT" -p MemoryMax=300M -p Nice=10 -p RuntimeMaxSec=21600 \
      -E PYTHONUNBUFFERED=1 "$PY" -m tradebot job deploy/job.json && echo "started job $JOB_ID"
  fi
fi

echo "deployed $OLD -> $NEW: $SUBJECT"
"$PY" -m tradebot --env .env.crypto notify --text "🚀 Deployed ${NEW%${NEW#???????}}: $SUBJECT" || true
