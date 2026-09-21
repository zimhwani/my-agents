#!/usr/bin/env bash
# One-time setup on a fresh Ubuntu 22.04/24.04 droplet. Run as root:
#   bash deploy/setup-droplet.sh
# Then put your .env in /opt/my-agents/trading-bot/.env and `systemctl start tradebot-dashboard`.
set -euo pipefail

REPO="${REPO:-https://github.com/zimhwani/my-agents.git}"
BRANCH="${BRANCH:-claude/magical-allen-jan8gi}"
APP_DIR=/opt/my-agents/trading-bot

apt-get update -y
apt-get install -y python3.12 python3.12-venv git || {
  add-apt-repository -y ppa:deadsnakes/ppa && apt-get update -y && apt-get install -y python3.12 python3.12-venv git; }

id -u tradebot &>/dev/null || useradd --system --create-home --shell /usr/sbin/nologin tradebot
if [ ! -d /opt/my-agents ]; then
  git clone --branch "$BRANCH" "$REPO" /opt/my-agents
fi
cd "$APP_DIR"
git pull --ff-only || true
python3.12 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
mkdir -p data
chown -R tradebot:tradebot /opt/my-agents

install -m 0644 deploy/tradebot.service /etc/systemd/system/tradebot.service
install -m 0644 deploy/tradebot.timer /etc/systemd/system/tradebot.timer
install -m 0644 deploy/tradebot-dashboard.service /etc/systemd/system/tradebot-dashboard.service
install -m 0644 deploy/tradebot-crypto.service /etc/systemd/system/tradebot-crypto.service
install -m 0644 deploy/tradebot-crypto-dashboard.service /etc/systemd/system/tradebot-crypto-dashboard.service
systemctl daemon-reload
systemctl enable --now tradebot.timer
systemctl enable tradebot-dashboard.service

echo
echo "Done. Next:"
echo "  1. Copy your .env to $APP_DIR/.env  (scp .env root@DROPLET:$APP_DIR/.env)"
echo "     then: chown tradebot:tradebot $APP_DIR/.env && chmod 600 $APP_DIR/.env"
echo "  2. sudo -u tradebot $APP_DIR/.venv/bin/python -m tradebot check   (from $APP_DIR)"
echo "  3. systemctl start tradebot-dashboard   # then ssh -L 8765:127.0.0.1:8765 root@DROPLET"
echo "  4. The bot starts automatically weekdays at 09:00 ET: systemctl list-timers tradebot.timer"
echo "     Start today's session by hand: systemctl start tradebot ; logs: journalctl -u tradebot -f"
echo "  5. 24/7 crypto bot (optional): copy .env.crypto, then"
echo "     systemctl enable --now tradebot-crypto tradebot-crypto-dashboard"
