#!/bin/bash

set -e

REPO_BASE="https://raw.githubusercontent.com/KiritoMiao/Routes-Generator/refs/heads/main/bird"
SCRIPT_PATH="/etc/bird/generate_bird_routes.py"
SERVICE_PATH="/etc/systemd/system/generate-bird-routes.service"
TIMER_PATH="/etc/systemd/system/generate-bird-routes.timer"

echo "📥 Downloading latest files from Routes-Generator repo ..."

sudo mkdir -p /etc/bird

curl -fsSL "$REPO_BASE/generate_bird_routes.py" -o "$SCRIPT_PATH"
curl -fsSL "$REPO_BASE/generate-bird-routes.service" -o "$SERVICE_PATH"
curl -fsSL "$REPO_BASE/generate-bird-routes.timer" -o "$TIMER_PATH"

sudo chmod 755 "$SCRIPT_PATH"

echo ""
echo "🛠️ Configuring Python script interactively..."

read -p "Enter output interface for BIRD (e.g., eth0, wg0): " OUT_INTERFACE
read -p "Reload BIRD after update? (yes/no): " RELOAD_BIRD_ANSWER
read -p "Generate reverse (non-China) routes? (yes/no): " REVERSE_ANSWER
read -p "Enable Telegram notifications? (yes/no): " TELEGRAM_ENABLE_ANSWER

RELOAD_BIRD="False"
[ "$RELOAD_BIRD_ANSWER" == "yes" ] && RELOAD_BIRD="True"

REVERSE="False"
[ "$REVERSE_ANSWER" == "yes" ] && REVERSE="True"

ENABLE_TELEGRAM="False"
if [ "$TELEGRAM_ENABLE_ANSWER" == "yes" ]; then
    ENABLE_TELEGRAM="True"
    read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
else
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
fi

# Inject config into the script
sudo sed -i "s|^OUT_INTERFACE = .*|OUT_INTERFACE = \"$OUT_INTERFACE\"|" "$SCRIPT_PATH"
sudo sed -i "s|^REVERSE = .*|REVERSE = $REVERSE|" "$SCRIPT_PATH"
sudo sed -i "s|^RELOAD_BIRD = .*|RELOAD_BIRD = $RELOAD_BIRD|" "$SCRIPT_PATH"
sudo sed -i "s|^ENABLE_TELEGRAM = .*|ENABLE_TELEGRAM = $ENABLE_TELEGRAM|" "$SCRIPT_PATH"
sudo sed -i "s|^TELEGRAM_BOT_TOKEN = .*|TELEGRAM_BOT_TOKEN = \"$TELEGRAM_BOT_TOKEN\"|" "$SCRIPT_PATH"
sudo sed -i "s|^TELEGRAM_CHAT_ID = .*|TELEGRAM_CHAT_ID = \"$TELEGRAM_CHAT_ID\"|" "$SCRIPT_PATH"

echo ""
echo "🔄 Reloading systemd ..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo ""
echo "✅ Setup complete!"
echo "👉 Run a test with:"
echo "   sudo systemctl start generate-bird-routes.service"
echo ""
echo "📅 Enable automatic daily updates with:"
echo "   sudo systemctl enable --now generate-bird-routes.timer"
