#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"
TOOL_DIR="$HOME/roblox-rejoin"

echo "=========================================="
echo " ROBLOX AUTO REJOIN V8 - INSTALLER"
echo "=========================================="
echo

pkg update -y
pkg install bash coreutils grep sed inetutils curl jq -y

mkdir -p "$TOOL_DIR"

echo "[+] Download rejoin.sh..."
curl -fsSL "$REPO_RAW_BASE/rejoin.sh" -o "$TOOL_DIR/rejoin.sh"

chmod +x "$TOOL_DIR/rejoin.sh"

grep -qxF 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' "$HOME/.bashrc" 2>/dev/null || \
echo 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' >> "$HOME/.bashrc"

echo
echo "=========================================="
echo "[OK] INSTALLED V8"
echo "=========================================="
echo
echo "Run:"
echo "  source ~/.bashrc"
echo "  rejoin"
