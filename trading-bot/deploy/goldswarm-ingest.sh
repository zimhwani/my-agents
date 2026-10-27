#!/bin/sh
# Forced command for the Gold Swarm feed key. Installed in root's authorized_keys as
#   restrict,command="/bin/sh /opt/my-agents/trading-bot/deploy/goldswarm-ingest.sh" ssh-ed25519 ... goldswarm-feed
# so that key can do exactly one thing: hand over one feed JSON on stdin (max 5 MB),
# which is then published to the dashboard's Gold tab as user tradebot. No shell, no
# other command (SSH_ORIGINAL_COMMAND is ignored), no forwarding. Display only.
set -eu
BOT=/opt/my-agents/trading-bot
DIR="$BOT/data-goldswarm"
install -d -o tradebot -g tradebot "$DIR"
TMP=$(mktemp "$DIR/.feed.XXXXXX")
head -c 5242880 > "$TMP"
chown tradebot:tradebot "$TMP"
chmod 644 "$TMP"
mv "$TMP" "$DIR/feed.json"
cd "$BOT"
exec runuser -u tradebot -- "$BOT/.venv/bin/python" -m tradebot --env .env.gold goldswarm-publish --feed "$DIR/feed.json"
