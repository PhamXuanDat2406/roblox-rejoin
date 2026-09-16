#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"
TOOL_DIR="$HOME/roblox-rejoin"

pkg update -y
pkg install bash coreutils grep sed inetutils curl -y
mkdir -p "$TOOL_DIR"

curl -fsSL "$REPO_RAW_BASE/rejoin.sh" -o "$TOOL_DIR/rejoin.sh"
chmod +x "$TOOL_DIR/rejoin.sh"

grep -qxF 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' "$HOME/.bashrc" 2>/dev/null || \
  echo 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' >> "$HOME/.bashrc"

source "$HOME/.bashrc" 2>/dev/null || true

echo
echo "Install completed."
echo "Run: rejoin"
echo
"$TOOL_DIR/rejoin.sh"
