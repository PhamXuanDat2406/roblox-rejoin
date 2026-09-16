#!/data/data/com.termux/files/usr/bin/bash

TOOL_DIR="$HOME/roblox-rejoin"
CONFIG="$TOOL_DIR/config.cfg"

PLACE_ID="1730877806"
CLIENT_SUFFIXES=""
REJOIN_DELAY=3
BASE_PACKAGE="com.roblox.clien"

mkdir -p "$TOOL_DIR"

if [ -f "$CONFIG" ]; then
    source "$CONFIG"
fi

save_config() {
    cat > "$CONFIG" <<EOF
PLACE_ID="$PLACE_ID"
CLIENT_SUFFIXES="$CLIENT_SUFFIXES"
EOF
}

pause_menu() {
    echo
    read -r -p "Nhan Enter de tiep tuc..." < /dev/tty
}

build_clients() {
    local raw="$CLIENT_SUFFIXES"
    local token pkg

    [ -z "$raw" ] && return

    IFS=',' read -ra TOKENS <<< "$raw"

    for token in "${TOKENS[@]}"; do
        token="$(echo "$token" | xargs)"
        [ -z "$token" ] && continue

        if [ "$token" = "base" ] || [ "$token" = "goc" ]; then
            pkg="$BASE_PACKAGE"
        elif [[ "$token" == com.roblox.clien* ]]; then
            pkg="$token"
        else
            pkg="${BASE_PACKAGE}${token}"
        fi

        echo "$pkg"
    done
}

count_clients() {
    local clients
    clients="$(build_clients)"
    if [ -z "$clients" ]; then
        echo "0"
    else
        printf "%s\n" "$clients" | grep -c .
    fi
}

show_clients() {
    clear
    echo "========================================"
    echo "             SAVED CLIENS"
    echo "========================================"
    echo

    local clients
    clients="$(build_clients)"

    if [ -z "$clients" ]; then
        echo "[!] Chua nhap clien nao."
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

set_clients() {
    clear
    echo "========================================"
    echo "              SET CLIENS"
    echo "========================================"
    echo
    echo "Package goc:"
    echo "  $BASE_PACKAGE"
    echo
    echo "Chi can nhap phan cuoi, cach nhau bang dau phay."
    echo
    echo "Vi du:"
    echo "  a,b,c"
    echo
    echo "Se thanh:"
    echo "  com.roblox.cliena"
    echo "  com.roblox.clienb"
    echo "  com.roblox.clienc"
    echo
    echo "Neu muon them package goc com.roblox.clien:"
    echo "  base,a,b,c"
    echo
    echo "Cung co the nhap full package neu can."
    echo
    echo "Hien tai: ${CLIENT_SUFFIXES:-Chua co}"
    echo

    local input
    read -r -p "Nhap cliens: " input < /dev/tty

    if [ -n "$input" ]; then
        CLIENT_SUFFIXES="$input"
        save_config
        echo
        echo "[OK] Da luu danh sach clien."
    else
        echo
        echo "[!] Khong thay doi."
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
    clients="$(build_clients)"

    if [ -z "$clients" ]; then
        echo "[!] Chua co clien nao."
        echo "[+] Vao muc [3] SET CLIENS truoc."
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
    echo "========================================"
    echo "              SET PLACE ID"
    echo "========================================"
    echo
    echo "PlaceId hien tai: $PLACE_ID"
    echo

    local new_place
    read -r -p "Nhap PlaceId moi: " new_place < /dev/tty

    if [[ "$new_place" =~ ^[0-9]+$ ]]; then
        PLACE_ID="$new_place"
        save_config
        echo
        echo "[OK] Da luu PlaceId: $PLACE_ID"
    else
        echo
        echo "[!] PlaceId phai la so."
    fi

    pause_menu
}

internet_ok() {
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1
}

rejoin_all_silent() {
    local clients
    clients="$(build_clients)"
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

    if [ "$(count_clients)" = "0" ]; then
        echo "[!] Chua co clien nao."
        echo "[+] Vao muc [3] SET CLIENS truoc."
        pause_menu
        return
    fi

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

    echo "╔════════════════════════════════════════╗"
    echo "║       ROBLOX MULTI REJOIN - TERMUX     ║"
    echo "╠════════════════════════════════════════╣"
    printf "║ PlaceId : %-28s║\n" "$PLACE_ID"
    printf "║ Cliens  : %-28s║\n" "$(count_clients)"
    echo "╠════════════════════════════════════════╣"
    echo "║ [1] REJOIN ALL CLIENS                  ║"
    echo "║ [2] AUTO REJOIN ALL                    ║"
    echo "║ [3] SET CLIENS                         ║"
    echo "║ [4] SHOW SAVED CLIENS                  ║"
    echo "║ [5] SET PLACE ID                       ║"
    echo "║ [0] EXIT                               ║"
    echo "╚════════════════════════════════════════╝"
    echo

    read -r -p "Select > " choice < /dev/tty

    case "$choice" in
        1) rejoin_all ;;
        2) auto_rejoin ;;
        3) set_clients ;;
        4) show_clients ;;
        5) set_place_id ;;
        0) clear; exit 0 ;;
        *) echo; echo "Lua chon khong hop le."; sleep 1 ;;
    esac
done
