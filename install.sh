#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO_RAW="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"
TOOL_DIR="$HOME/roblox-rejoin"

echo "=============================================="
echo " ROBLOX AUTO REJOIN V9 - CLEAN INSTALLER"
echo "=============================================="
echo
echo "V9 khong dung termux-tools."
echo "Android control dung android-tools / adb."
echo

pkg update -y
pkg install bash curl jq grep sed coreutils android-tools -y

mkdir -p "$TOOL_DIR"

echo
echo "[+] Downloading rejoin.sh..."
curl -fsSL "$REPO_RAW/rejoin.sh" -o "$TOOL_DIR/rejoin.sh"

echo "[+] Checking syntax..."
bash -n "$TOOL_DIR/rejoin.sh"

chmod +x "$TOOL_DIR/rejoin.sh"
touch "$TOOL_DIR/accounts.txt"

grep -qxF 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' \
  "$HOME/.bashrc" 2>/dev/null \
  || echo 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' >> "$HOME/.bashrc"

echo
echo "=============================================="
echo "[OK] INSTALL COMPLETE"
echo "=============================================="
echo
echo "Installer KHONG tu mo menu de tranh loi input."
echo
echo "Chay:"
echo
echo "  source ~/.bashrc"
echo "  rejoin"
echo
echo "Buoc dau tien: [6] ADB SETUP / RECONNECT"
