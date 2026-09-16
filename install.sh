#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"
TOOL_DIR="$HOME/roblox-rejoin"

echo "======================================"
echo "   ROBLOX MULTI REJOIN INSTALLER"
echo "======================================"
echo

pkg update -y
pkg install bash coreutils grep sed inetutils curl -y

mkdir -p "$TOOL_DIR"

echo "[+] Dang tai rejoin.sh..."
curl -fsSL "$REPO_RAW_BASE/rejoin.sh" -o "$TOOL_DIR/rejoin.sh"

chmod +x "$TOOL_DIR/rejoin.sh"

grep -qxF 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' "$HOME/.bashrc" 2>/dev/null || \
echo 'alias rejoin="$HOME/roblox-rejoin/rejoin.sh"' >> "$HOME/.bashrc"

echo
echo "======================================"
echo "[OK] CAI DAT XONG"
echo "======================================"
echo
echo "QUAN TRONG:"
echo "Installer se KHONG tu mo menu de tranh loi nhay."
echo
echo "Sau khi installer ket thuc, chay:"
echo
echo "  source ~/.bashrc"
echo "  rejoin"
echo
