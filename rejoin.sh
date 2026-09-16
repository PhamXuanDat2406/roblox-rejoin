#!/data/data/com.termux/files/usr/bin/bash

TOOL_DIR="$HOME/roblox-rejoin"
CONFIG="$TOOL_DIR/config.cfg"

DEFAULT_PLACE_ID="1730877806"
PLACE_ID="$DEFAULT_PLACE_ID"
REJOIN_DELAY=3

[ -f "$CONFIG" ] && source "$CONFIG"

save_config() {
    echo "PLACE_ID=\"$PLACE_ID\"" > "$CONFIG"
}

pause_menu() {
    echo
    read -r -p "Nhan Enter de tiep tuc..." < /dev/tty
}

get_clients() {
    {
        pm list packages 2>/dev/null || cmd package list packages 2>/dev/null
    } | sed 's/^package://' \
      | grep -E '^com\.roblox\.clien' \
      | sort -u
}

count_clients() {
    local clients
    clients="$(get_clients)"
    if [ -z "$clients" ]; then
        echo "0"
    else
        printf "%s\n" "$clients" | grep -c .
    fi
}

show_clients() {
    clear
    echo "========================================"
    echo "         DETECTED ROBLOX CLIENS"
    echo "========================================"
    echo

    local clients
    clients="$(get_clients)"

    if [ -z "$clients" ]; then
        echo "[!] Khong tim thay clien nao."
        echo
        echo "Dang tim package dang:"
        echo "  com.roblox.clien"
        echo "  com.roblox.cliena"
        echo "  com.roblox.clienb"
        echo "  ..."
    else
        local n=1
        while IFS= read -r package; do
            [ -z "$package" ] && continue
            echo "[$n] $package"
            n=$((n + 1))
        done <<< "$clients"
    fi

    pause_menu
}

open_client() {
    local package="$1"
    echo "[+] Opening $package"

    local output
    output="$(
        am start \
          -a android.intent.action.VIEW \
          -d "roblox://placeId=${PLACE_ID}" \
          -p "$package" 2>&1
    )"

    if echo "$output" | grep -qiE "error|exception|unable"; then
        echo "[!] Deep link failed, thu mo app..."
        monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    else
        echo "[OK] Rejoin command sent."
    fi
}

rejoin_all() {
    clear
    echo "========================================"
    echo "            REJOIN ALL CLIENS"
    echo "========================================"
    echo

    local clients
    clients="$(get_clients)"

    if [ -z "$clients" ]; then
        echo "[!] Khong tim thay Roblox clien."
        pause_menu
        return
    fi

    local total current
    total="$(printf "%s\n" "$clients" | grep -c .)"
    current=0

    echo "PlaceId : $PLACE_ID"
    echo "Cliens  : $total"
    echo

    while IFS= read -r package; do
        [ -z "$package" ] && continue
        current=$((current + 1))
        echo "[$current/$total]"
        open_client "$package"
        echo
        [ "$current" -lt "$total" ] && sleep "$REJOIN_DELAY"
    done <<< "$clients"

    echo "[OK] Da gui lenh cho $total cliens."
    pause_menu
}

set_place_id() {
    clear
    echo "PlaceId hien tai: $PLACE_ID"
    echo

    local new_place
    read -r -p "Nhap PlaceId moi: " new_place < /dev/tty

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

    while IFS= read -r package; do
        [ -z "$package" ] && continue
        echo "[$(date +%H:%M:%S)] Rejoin $package"
        am start \
          -a android.intent.action.VIEW \
          -d "roblox://placeId=${PLACE_ID}" \
          -p "$package" >/dev/null 2>&1
        sleep "$REJOIN_DELAY"
    done <<< "$clients"
}

auto_rejoin() {
    clear
    echo "========================================"
    echo "          AUTO REJOIN ALL ACTIVE"
    echo "========================================"
    echo
    echo "PlaceId : $PLACE_ID"
    echo "Cliens  : $(count_clients)"
    echo
    echo "Mat mang -> cho mang."
    echo "Co mang lai -> rejoin ALL."
    echo
    echo "CTRL+C de dung."
    echo

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
    client_count="$(count_clients)"

    echo "╔════════════════════════════════════════╗"
    echo "║       ROBLOX MULTI REJOIN - TERMUX     ║"
    echo "╠════════════════════════════════════════╣"
    printf "║ PlaceId : %-28s║\n" "$PLACE_ID"
    printf "║ Cliens  : %-28s║\n" "$client_count"
    echo "╠════════════════════════════════════════╣"
    echo "║ [1] REJOIN ALL CLIENS                  ║"
    echo "║ [2] AUTO REJOIN ALL                    ║"
    echo "║ [3] SHOW DETECTED CLIENS               ║"
    echo "║ [4] SET PLACE ID                       ║"
    echo "║ [0] EXIT                               ║"
    echo "╚════════════════════════════════════════╝"
    echo

    read -r -p "Select > " choice < /dev/tty

    case "$choice" in
        1) rejoin_all ;;
        2) auto_rejoin ;;
        3) show_clients ;;
        4) set_place_id ;;
        0) clear; exit 0 ;;
        *) echo; echo "Lua chon khong hop le."; sleep 1 ;;
    esac
done
