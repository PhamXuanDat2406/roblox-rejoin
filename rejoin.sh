#!/data/data/com.termux/files/usr/bin/bash

TOOL_DIR="$HOME/roblox-rejoin"
CONFIG="$TOOL_DIR/config.cfg"
DEFAULT_PLACE_ID="1730877806"
PLACE_ID="$DEFAULT_PLACE_ID"
REJOIN_DELAY=3

mkdir -p "$TOOL_DIR"
[ -f "$CONFIG" ] && source "$CONFIG"

save_config() {
  echo "PLACE_ID=\"$PLACE_ID\"" > "$CONFIG"
}

pause_menu() {
  echo
  read -p "Nhan Enter de tiep tuc..."
}

get_clients() {
  local out
  out="$(pm list packages 2>/dev/null | sed 's/^package://' | grep -E '^com\.roblox\.client' | sort -u)"
  if [ -z "$out" ]; then
    out="$(cmd package list packages 2>/dev/null | sed 's/^package://' | grep -E '^com\.roblox\.client' | sort -u)"
  fi
  echo "$out"
}

count_clients() {
  local clients
  clients="$(get_clients)"
  [ -z "$clients" ] && echo 0 || echo "$clients" | grep -c .
}

show_clients() {
  clear
  echo "========================================"
  echo "         DETECTED ROBLOX CLIENTS"
  echo "========================================"
  echo
  local clients num
  clients="$(get_clients)"
  if [ -z "$clients" ]; then
    echo "[!] Khong tim thay client nao."
    echo "Tool tim package dang com.roblox.client*"
  else
    num=1
    while IFS= read -r pkg; do
      [ -z "$pkg" ] && continue
      echo "[$num] $pkg"
      num=$((num+1))
    done <<< "$clients"
  fi
  pause_menu
}

open_client() {
  local pkg="$1"
  echo "[+] Opening $pkg"
  am start -a android.intent.action.VIEW -d "roblox://placeId=${PLACE_ID}" -p "$pkg" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "[OK] Rejoin command sent."
  else
    echo "[!] Deep link failed, opening app..."
    monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  fi
}

rejoin_all() {
  clear
  echo "========================================"
  echo "            REJOIN ALL CLIENTS"
  echo "========================================"
  echo
  local clients total current
  clients="$(get_clients)"
  if [ -z "$clients" ]; then
    echo "[!] Khong tim thay Roblox client."
    pause_menu
    return
  fi
  total="$(echo "$clients" | grep -c .)"
  echo "PlaceId : $PLACE_ID"
  echo "Clients : $total"
  echo
  current=0
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    current=$((current+1))
    echo "[$current/$total]"
    open_client "$pkg"
    echo
    [ "$current" -lt "$total" ] && sleep "$REJOIN_DELAY"
  done <<< "$clients"
  echo "[OK] Da gui lenh cho $total clients."
  pause_menu
}

set_place_id() {
  clear
  echo "PlaceId hien tai: $PLACE_ID"
  echo
  read -p "Nhap PlaceId moi: " new_place
  if [[ "$new_place" =~ ^[0-9]+$ ]]; then
    PLACE_ID="$new_place"
    save_config
    echo "[OK] Da luu PlaceId: $PLACE_ID"
  else
    echo "[!] PlaceId phai la so."
  fi
  pause_menu
}

internet_ok() {
  ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1
}

rejoin_all_silent() {
  local clients
  clients="$(get_clients)"
  [ -z "$clients" ] && return
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    echo "[$(date +%H:%M:%S)] Rejoin $pkg"
    am start -a android.intent.action.VIEW -d "roblox://placeId=${PLACE_ID}" -p "$pkg" >/dev/null 2>&1
    sleep "$REJOIN_DELAY"
  done <<< "$clients"
}

auto_rejoin() {
  clear
  echo "========================================"
  echo "          AUTO REJOIN ALL ACTIVE"
  echo "========================================"
  echo "PlaceId : $PLACE_ID"
  echo "Clients : $(count_clients)"
  echo "CTRL + C de dung."
  echo
  termux-wake-lock >/dev/null 2>&1
  local was_offline=0
  while true; do
    if internet_ok; then
      if [ "$was_offline" = "1" ]; then
        echo "[$(date +%H:%M:%S)] INTERNET RESTORED"
        rejoin_all_silent
        was_offline=0
      fi
    else
      if [ "$was_offline" = "0" ]; then
        echo "[$(date +%H:%M:%S)] INTERNET LOST"
      fi
      was_offline=1
    fi
    sleep 5
  done
}

while true; do
  clear
  echo "╔════════════════════════════════════════╗"
  echo "║      ROBLOX MULTI REJOIN - TERMUX      ║"
  echo "╠════════════════════════════════════════╣"
  printf "║ PlaceId : %-28s║\n" "$PLACE_ID"
  printf "║ Clients : %-28s║\n" "$(count_clients)"
  echo "╠════════════════════════════════════════╣"
  echo "║ [1] REJOIN ALL CLIENTS                 ║"
  echo "║ [2] AUTO REJOIN ALL                    ║"
  echo "║ [3] SHOW DETECTED CLIENTS              ║"
  echo "║ [4] SET PLACE ID                       ║"
  echo "║ [0] EXIT                               ║"
  echo "╚════════════════════════════════════════╝"
  echo
  read -p "Select > " choice
  case "$choice" in
    1) rejoin_all ;;
    2) auto_rejoin ;;
    3) show_clients ;;
    4) set_place_id ;;
    0) clear; exit ;;
    *) echo "Lua chon khong hop le."; sleep 1 ;;
  esac
done
