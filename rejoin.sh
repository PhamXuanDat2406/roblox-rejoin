#!/data/data/com.termux/files/usr/bin/bash

VERSION="9.0"
REPO_RAW="https://raw.githubusercontent.com/PhamXuanDat2406/roblox-rejoin/main"

TOOL_DIR="$HOME/roblox-rejoin"
ACCOUNTS_FILE="$TOOL_DIR/accounts.txt"
PLACE_FILE="$TOOL_DIR/placeid.txt"
ADB_FILE="$TOOL_DIR/adb_serial.txt"

BASE_PACKAGE="com.free.noka"
DEFAULT_PLACE_ID="1730877806"
PRESENCE_URL="https://presence.roblox.com/v1/presence/users"

CHECK_DELAY=20
PRESENCE_CONFIRM=2
JOIN_GRACE=90
FAIL_RETRY=180
NEXT_CLIENT_DELAY=5
APP_BOOT_DELAY=2

mkdir -p "$TOOL_DIR"
touch "$ACCOUNTS_FILE"

if [ -s "$PLACE_FILE" ]; then
    PLACE_ID="$(head -n1 "$PLACE_FILE" | tr -cd '0-9')"
fi
[ -z "$PLACE_ID" ] && PLACE_ID="$DEFAULT_PLACE_ID"

if [ -s "$ADB_FILE" ]; then
    ADB_SERIAL="$(head -n1 "$ADB_FILE" | tr -d '\r\n')"
else
    ADB_SERIAL=""
fi

declare -A MISS_COUNT
declare -A LAST_JOIN
declare -A LAST_FAIL

pause_menu() {
    echo
    read -r -p "Nhan Enter de tiep tuc..." < /dev/tty
}

line() { printf '%s\n' "=============================================="; }
now_hms() { date +%H:%M:%S; }

account_count() {
    local n
    n="$(grep -cve '^[[:space:]]*$' "$ACCOUNTS_FILE" 2>/dev/null)"
    [ -z "$n" ] && n=0
    echo "$n"
}

first_connected_adb() {
    adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'
}

adb_is_ready() {
    local serial="$1"
    [ -z "$serial" ] && return 1
    [ "$(adb -s "$serial" get-state 2>/dev/null | tr -d '\r')" = "device" ]
}

save_adb_serial() {
    ADB_SERIAL="$1"
    printf '%s\n' "$ADB_SERIAL" > "$ADB_FILE"
}

try_adb_reconnect() {
    local serial

    if adb_is_ready "$ADB_SERIAL"; then
        return 0
    fi

    if [ -n "$ADB_SERIAL" ]; then
        adb connect "$ADB_SERIAL" >/dev/null 2>&1 || true
        sleep 1
        if adb_is_ready "$ADB_SERIAL"; then
            return 0
        fi
    fi

    serial="$(first_connected_adb)"
    if [ -n "$serial" ]; then
        save_adb_serial "$serial"
        return 0
    fi

    return 1
}

adb_setup() {
    clear
    line
    echo "              ADB SETUP / RECONNECT"
    line
    echo
    echo "1) Android > Developer options > Wireless debugging > ON"
    echo "2) Neu chua pair: chon Pair device with pairing code."
    echo "3) Nhap Pair IP:PORT + code vao tool."
    echo "4) Sau do nhap IP address & Port dung de CONNECT."
    echo

    adb start-server >/dev/null 2>&1 || true

    echo "ADB devices hien tai:"
    adb devices 2>/dev/null
    echo

    local pair_addr pair_code connect_addr serial

    read -r -p "Pair address (Enter neu da pair): " pair_addr < /dev/tty

    if [ -n "$pair_addr" ]; then
        read -r -p "Pairing code: " pair_code < /dev/tty
        echo
        echo "[*] Pairing..."
        if ! adb pair "$pair_addr" "$pair_code"; then
            echo "[FAIL] Pair khong thanh cong."
            pause_menu
            return
        fi
    fi

    echo
    read -r -p "Connect IP:PORT: " connect_addr < /dev/tty

    if [ -n "$connect_addr" ]; then
        echo
        echo "[*] Connecting $connect_addr ..."
        adb connect "$connect_addr"
        sleep 1

        if adb_is_ready "$connect_addr"; then
            save_adb_serial "$connect_addr"
            echo "[OK] ADB connected: $ADB_SERIAL"
            pause_menu
            return
        fi
    fi

    serial="$(first_connected_adb)"
    if [ -n "$serial" ]; then
        save_adb_serial "$serial"
        echo "[OK] Found connected ADB: $ADB_SERIAL"
    else
        echo "[FAIL] Chua co ADB device o trang thai device."
    fi

    pause_menu
}

require_adb() {
    if try_adb_reconnect; then
        return 0
    fi
    echo
    echo "[ADB] Chua ket noi Wireless ADB."
    echo "[ADB] Chon menu [6] ADB SETUP / RECONNECT."
    return 1
}

adbs() {
    adb -s "$ADB_SERIAL" shell "$@"
}

normalize_package() {
    local token="$1"
    token="$(printf '%s' "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$token" ] && return 1

    case "$token" in
        base|BASE|goc|GOC) printf '%s\n' "$BASE_PACKAGE" ;;
        com.free.noka*) printf '%s\n' "$token" ;;
        *) printf '%s%s\n' "$BASE_PACKAGE" "$token" ;;
    esac
}

upsert_account() {
    local package="$1"
    local userid="$2"
    local temp="$TOOL_DIR/.accounts.tmp"

    awk -F'|' -v p="$package" '$1 != p' "$ACCOUNTS_FILE" > "$temp" 2>/dev/null || true
    printf '%s|%s\n' "$package" "$userid" >> "$temp"
    sort -t'|' -k1,1 -u "$temp" > "$ACCOUNTS_FILE"
    rm -f "$temp"
}

add_accounts() {
    clear
    line
    echo "             ADD / UPDATE ACCOUNTS"
    line
    echo
    echo "Nhap nhieu clone cung luc:"
    echo "  A:USERID,B:USERID,C:USERID"
    echo
    echo "Vi du:"
    echo "  A:123456789,B:987654321"
    echo
    echo "Package goc:"
    echo "  base:USERID"
    echo

    local input pair suffix userid package added=0
    read -r -p "Add > " input < /dev/tty

    [ -z "$input" ] && { echo "[!] Khong thay doi."; pause_menu; return; }

    while IFS= read -r pair; do
        pair="$(printf '%s' "$pair" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$pair" ] && continue

        if [[ "$pair" == *":"* ]]; then
            suffix="${pair%%:*}"
            userid="${pair#*:}"
        elif [[ "$pair" == *"="* ]]; then
            suffix="${pair%%=*}"
            userid="${pair#*=}"
        else
            echo "[SKIP] Sai format: $pair"
            continue
        fi

        userid="$(printf '%s' "$userid" | tr -cd '0-9')"
        if [ -z "$userid" ]; then
            echo "[SKIP] UserId loi: $pair"
            continue
        fi

        package="$(normalize_package "$suffix")"
        if [ -z "$package" ]; then
            echo "[SKIP] Package loi: $pair"
            continue
        fi

        upsert_account "$package" "$userid"
        echo "[OK] $package -> $userid"
        added=$((added + 1))
    done < <(printf '%s\n' "$input" | tr ',;' '\n')

    echo
    echo "[OK] Them/cap nhat: $added"
    echo "[OK] Tong accounts: $(account_count)"
    pause_menu
}

show_accounts() {
    clear
    line
    echo "                SAVED ACCOUNTS"
    line
    echo
    echo "PlaceId    : $PLACE_ID"
    echo "ADB device : ${ADB_SERIAL:-Not set}"
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co account."
    else
        local n=1 package userid
        while IFS='|' read -r package userid; do
            [ -z "$package" ] && continue
            printf "[%d] %-24s | UserId %s\n" "$n" "$package" "$userid"
            n=$((n + 1))
        done < "$ACCOUNTS_FILE"
    fi

    pause_menu
}

remove_accounts() {
    clear
    line
    echo "               REMOVE ACCOUNTS"
    line
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Danh sach trong."
        pause_menu
        return
    fi

    local n=1 package userid
    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue
        printf "[%d] %s | %s\n" "$n" "$package" "$userid"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"

    echo
    echo "Nhap suffix can xoa, vi du: A,B,C"
    local input token target tmp="$TOOL_DIR/.remove.tmp"
    read -r -p "Remove > " input < /dev/tty

    cp "$ACCOUNTS_FILE" "$tmp"

    while IFS= read -r token; do
        token="$(printf '%s' "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$token" ] && continue
        target="$(normalize_package "$token")"
        awk -F'|' -v p="$target" '$1 != p' "$tmp" > "$tmp.2"
        mv "$tmp.2" "$tmp"
        echo "[OK] Removed $target"
    done < <(printf '%s\n' "$input" | tr ',;' '\n')

    mv "$tmp" "$ACCOUNTS_FILE"
    echo
    echo "[OK] Con $(account_count) accounts."
    pause_menu
}

clear_accounts() {
    clear
    local confirm
    read -r -p "Xoa TOAN BO account? (y/N): " confirm < /dev/tty
    case "$confirm" in
        y|Y) : > "$ACCOUNTS_FILE"; echo "[OK] Da xoa." ;;
        *) echo "[!] Da huy." ;;
    esac
    pause_menu
}

set_place_id() {
    clear
    line
    echo "                 SET PLACE ID"
    line
    echo
    echo "Hien tai: $PLACE_ID"
    echo

    local id
    read -r -p "PlaceId > " id < /dev/tty

    if [[ "$id" =~ ^[0-9]+$ ]]; then
        PLACE_ID="$id"
        printf '%s\n' "$PLACE_ID" > "$PLACE_FILE"
        echo "[OK] Saved: $PLACE_ID"
    else
        echo "[FAIL] PlaceId phai la so."
    fi

    pause_menu
}

package_installed() {
    local package="$1"
    adbs pm list packages "$package" 2>/dev/null | tr -d '\r' | grep -Fxq "package:$package"
}

package_running() {
    local package="$1"
    adbs pidof "$package" >/dev/null 2>&1
}

launch_clone() {
    local package="$1"
    local out
    out="$(adbs monkey -p "$package" -c android.intent.category.LAUNCHER 1 2>&1)"
    if printf '%s\n' "$out" | grep -qiE 'No activities found|monkey aborted|Error|Exception'; then
        return 1
    fi
    return 0
}

am_output_failed() {
    grep -qiE 'Error:|Error type|Exception|does not exist|unable to resolve|Permission Denial|SecurityException|Activity not started'
}

resolve_component() {
    local package="$1"
    local uri="$2"
    local result

    result="$(
        adbs cmd package resolve-activity --brief \
          -a android.intent.action.VIEW \
          -c android.intent.category.BROWSABLE \
          -d "$uri" \
          -p "$package" \
          2>/dev/null | tr -d '\r' | tail -n1
    )"

    if [[ "$result" == */* ]]; then
        printf '%s\n' "$result"
        return 0
    fi
    return 1
}

find_protocol_component() {
    local package="$1"
    local dump component

    dump="$(adbs dumpsys package "$package" 2>/dev/null | tr -d '\r')"

    component="$(
        printf '%s\n' "$dump" \
          | grep -oE "${package//./\\.}/[A-Za-z0-9_.$]*ActivityProtocolLaunch" \
          | head -n1
    )"

    if [[ "$component" == */* ]]; then
        printf '%s\n' "$component"
        return 0
    fi

    if printf '%s\n' "$dump" | grep -Fq "com.roblox.client.ActivityProtocolLaunch"; then
        printf '%s/%s\n' "$package" "com.roblox.client.ActivityProtocolLaunch"
        return 0
    fi

    return 1
}

start_uri_component() {
    local component="$1"
    local uri="$2"
    local out

    out="$(
        adbs am start -W \
          -a android.intent.action.VIEW \
          -c android.intent.category.DEFAULT \
          -c android.intent.category.BROWSABLE \
          -d "$uri" \
          -n "$component" 2>&1
    )"

    if printf '%s\n' "$out" | am_output_failed; then
        return 1
    fi
    return 0
}

start_uri_package() {
    local package="$1"
    local uri="$2"
    local out

    out="$(
        adbs am start -W \
          -a android.intent.action.VIEW \
          -c android.intent.category.DEFAULT \
          -c android.intent.category.BROWSABLE \
          -d "$uri" \
          -p "$package" 2>&1
    )"

    if printf '%s\n' "$out" | am_output_failed; then
        return 1
    fi
    return 0
}

join_package() {
    local package="$1"
    local roblox_uri="roblox://placeId=${PLACE_ID}"
    local web_uri="https://www.roblox.com/games/start?placeId=${PLACE_ID}"
    local component

    if ! package_installed "$package"; then
        echo "    [FAIL] PACKAGE_NOT_INSTALLED"
        return 3
    fi

    launch_clone "$package" >/dev/null 2>&1 || true
    sleep "$APP_BOOT_DELAY"

    component="$(resolve_component "$package" "$roblox_uri" 2>/dev/null || true)"
    if [ -n "$component" ] && start_uri_component "$component" "$roblox_uri"; then
        echo "    [OK] JOIN via Roblox handler: $component"
        return 0
    fi

    if start_uri_package "$package" "$roblox_uri"; then
        echo "    [OK] JOIN via package Roblox URI"
        return 0
    fi

    component="$(find_protocol_component "$package" 2>/dev/null || true)"
    if [ -n "$component" ] && start_uri_component "$component" "$roblox_uri"; then
        echo "    [OK] JOIN via ProtocolLaunch: $component"
        return 0
    fi

    component="$(resolve_component "$package" "$web_uri" 2>/dev/null || true)"
    if [ -n "$component" ] && start_uri_component "$component" "$web_uri"; then
        echo "    [OK] JOIN via web-to-app: $component"
        return 0
    fi

    if start_uri_package "$package" "$web_uri"; then
        echo "    [OK] JOIN via package web-to-app"
        return 0
    fi

    launch_clone "$package" >/dev/null 2>&1 || true
    echo "    [FAIL] NO_DEEPLINK_HANDLER"
    echo "    Clone mo duoc, nhung manifest khong co handler nhan PlaceId."
    return 2
}

diagnose_packages() {
    clear
    line
    echo "                DIAGNOSE PACKAGES"
    line
    echo

    if ! require_adb; then
        pause_menu
        return
    fi

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co accounts."
        pause_menu
        return
    fi

    local package userid roblox_uri web_uri c1 c2 proto
    roblox_uri="roblox://placeId=${PLACE_ID}"
    web_uri="https://www.roblox.com/games/start?placeId=${PLACE_ID}"

    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue

        echo "----------------------------------------------"
        echo "$package | UserId $userid"

        if ! package_installed "$package"; then
            echo "Installed           : NO"
            continue
        fi

        echo "Installed           : YES"

        c1="$(resolve_component "$package" "$roblox_uri" 2>/dev/null || true)"
        c2="$(resolve_component "$package" "$web_uri" 2>/dev/null || true)"
        proto="$(find_protocol_component "$package" 2>/dev/null || true)"

        echo "Roblox URI handler  : ${c1:-NONE}"
        echo "Web URI handler     : ${c2:-NONE}"
        echo "Protocol activity   : ${proto:-NONE}"

        if [ -n "$c1" ] || [ -n "$c2" ] || [ -n "$proto" ]; then
            echo "Auto-join potential : YES"
        else
            echo "Auto-join potential : NO"
        fi
    done < "$ACCOUNTS_FILE"

    pause_menu
}

test_first_join() {
    clear
    line
    echo "                TEST FIRST JOIN"
    line
    echo

    if ! require_adb; then
        pause_menu
        return
    fi

    local package userid
    IFS='|' read -r package userid < "$ACCOUNTS_FILE"

    if [ -z "$package" ]; then
        echo "[!] Chua co account."
        pause_menu
        return
    fi

    echo "Package : $package"
    echo "UserId  : $userid"
    echo "PlaceId : $PLACE_ID"
    echo
    join_package "$package"
    pause_menu
}

presence_name() {
    case "$1" in
        0) echo "OFFLINE" ;;
        1) echo "ONLINE" ;;
        2) echo "IN GAME" ;;
        3) echo "IN STUDIO" ;;
        4) echo "INVISIBLE" ;;
        *) echo "UNKNOWN" ;;
    esac
}

fetch_presence() {
    local ids body response

    ids="$(cut -d'|' -f2 "$ACCOUNTS_FILE" | grep -E '^[0-9]+$' | sort -u | paste -sd, -)"
    [ -z "$ids" ] && return 1

    body="{\"userIds\":[${ids}]}"

    response="$(
        curl -fsS \
          --connect-timeout 6 \
          --max-time 12 \
          -H 'Content-Type: application/json' \
          -X POST \
          -d "$body" \
          "$PRESENCE_URL" 2>/dev/null
    )" || return 1

    printf '%s\n' "$response" \
      | jq -e '.userPresences | type == "array"' >/dev/null 2>&1 \
      || return 1

    printf '%s\n' "$response"
}

presence_type_for_user() {
    local json="$1"
    local userid="$2"

    printf '%s\n' "$json" \
      | jq -r --arg uid "$userid" \
          '.userPresences[]
           | select((.userId|tostring) == $uid)
           | .userPresenceType' \
      | head -n1
}

test_presence() {
    clear
    line
    echo "                 TEST PRESENCE"
    line
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co account."
        pause_menu
        return
    fi

    local json package userid ptype

    if ! json="$(fetch_presence)"; then
        echo "[FAIL] Roblox Presence API khong phan hoi hop le."
        pause_menu
        return
    fi

    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue
        ptype="$(presence_type_for_user "$json" "$userid")"

        if [[ "$ptype" =~ ^[0-9]+$ ]]; then
            printf "%-24s | %-10s | %s\n" \
              "$package" "$(presence_name "$ptype")" "$userid"
        else
            printf "%-24s | %-10s | %s\n" \
              "$package" "UNKNOWN" "$userid"
        fi
    done < "$ACCOUNTS_FILE"

    echo
    echo "Luu y: Presence co the bi gioi han boi privacy."
    pause_menu
}

can_attempt_now() {
    local package="$1"
    local now last_fail
    now="$(date +%s)"
    last_fail="${LAST_FAIL[$package]:-0}"

    if [ "$last_fail" -gt 0 ] && [ $((now - last_fail)) -lt "$FAIL_RETRY" ]; then
        return 1
    fi
    return 0
}

do_join() {
    local package="$1"
    local rc now
    now="$(date +%s)"

    if ! can_attempt_now "$package"; then
        return 4
    fi

    join_package "$package"
    rc=$?

    if [ "$rc" -eq 0 ]; then
        LAST_JOIN["$package"]="$now"
        MISS_COUNT["$package"]=0
        LAST_FAIL["$package"]=0
    else
        LAST_FAIL["$package"]="$now"
    fi

    return "$rc"
}

join_all_initial() {
    local package userid n=1 total
    total="$(account_count)"

    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue
        echo
        echo "[$n/$total] $package | $userid"
        do_join "$package" || true
        n=$((n + 1))
        [ "$n" -le "$total" ] && sleep "$NEXT_CLIENT_DELAY"
    done < "$ACCOUNTS_FILE"
}

start_auto_rejoin() {
    clear
    line
    echo "              START AUTO REJOIN"
    line
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co account."
        pause_menu
        return
    fi

    if ! require_adb; then
        pause_menu
        return
    fi

    echo "Version      : $VERSION"
    echo "PlaceId      : $PLACE_ID"
    echo "Accounts     : $(account_count)"
    echo "ADB          : $ADB_SERIAL"
    echo "Check delay  : ${CHECK_DELAY}s"
    echo "Confirm miss : $PRESENCE_CONFIRM"
    echo "Join grace   : ${JOIN_GRACE}s"
    echo
    echo "Buoc 1: mo + join tat ca account..."
    echo

    join_all_initial

    echo
    line
    echo "                 MONITOR ACTIVE"
    line
    echo
    echo "CTRL+C de dung."
    echo

    local json api_ok
    local package userid ptype pname
    local now last age miss

    while true; do
        if ! try_adb_reconnect; then
            echo "[$(now_hms)] ADB DISCONNECTED - waiting..."
            sleep "$CHECK_DELAY"
            continue
        fi

        api_ok=1
        if ! json="$(fetch_presence)"; then
            api_ok=0
            echo "[$(now_hms)] Presence API unavailable - skip presence checks"
        fi

        while IFS='|' read -r package userid; do
            [ -z "$package" ] && continue

            now="$(date +%s)"
            last="${LAST_JOIN[$package]:-0}"
            age=$((now - last))

            if [ "$last" -eq 0 ] || [ "$age" -ge "$JOIN_GRACE" ]; then
                if ! package_running "$package"; then
                    echo "[$(now_hms)] $package | PROCESS CLOSED -> REJOIN"
                    if do_join "$package"; then
                        echo "[$(now_hms)] $package | rejoin sent"
                    fi
                    sleep "$NEXT_CLIENT_DELAY"
                    continue
                fi
            fi

            if [ "$api_ok" -eq 0 ]; then
                echo "[$(now_hms)] $package | process OK | presence SKIPPED"
                continue
            fi

            ptype="$(presence_type_for_user "$json" "$userid")"

            if ! [[ "$ptype" =~ ^[0-9]+$ ]]; then
                echo "[$(now_hms)] $package | UNKNOWN presence"
                continue
            fi

            pname="$(presence_name "$ptype")"

            if [ "$last" -gt 0 ] && [ "$age" -lt "$JOIN_GRACE" ]; then
                MISS_COUNT["$package"]=0
                echo "[$(now_hms)] $package | $pname | grace $((JOIN_GRACE-age))s"
                continue
            fi

            if [ "$ptype" -eq 2 ]; then
                MISS_COUNT["$package"]=0
                echo "[$(now_hms)] $package | IN GAME"
                continue
            fi

            miss="${MISS_COUNT[$package]:-0}"
            miss=$((miss + 1))
            MISS_COUNT["$package"]="$miss"

            echo "[$(now_hms)] $package | $pname | miss $miss/$PRESENCE_CONFIRM"

            if [ "$miss" -ge "$PRESENCE_CONFIRM" ]; then
                echo "[$(now_hms)] $package | NOT IN GAME -> REJOIN"
                MISS_COUNT["$package"]=0
                if do_join "$package"; then
                    echo "[$(now_hms)] $package | rejoin sent"
                fi
                sleep "$NEXT_CLIENT_DELAY"
            fi
        done < "$ACCOUNTS_FILE"

        sleep "$CHECK_DELAY"
    done
}

update_tool() {
    clear
    line
    echo "                  UPDATE TOOL"
    line
    echo

    local tmp="$TOOL_DIR/rejoin.sh.new"
    echo "[*] Downloading latest rejoin.sh..."

    if ! curl -fsSL "$REPO_RAW/rejoin.sh" -o "$tmp"; then
        echo "[FAIL] Download failed."
        rm -f "$tmp"
        pause_menu
        return
    fi

    if ! bash -n "$tmp"; then
        echo "[FAIL] File moi co loi syntax. Khong thay file cu."
        rm -f "$tmp"
        pause_menu
        return
    fi

    mv "$tmp" "$TOOL_DIR/rejoin.sh"
    chmod +x "$TOOL_DIR/rejoin.sh"

    echo "[OK] Updated. Restarting..."
    sleep 1
    exec "$TOOL_DIR/rejoin.sh"
}

while true; do
    clear

    echo "╔════════════════════════════════════════════╗"
    echo "║       ROBLOX AUTO REJOIN V9 - ADB          ║"
    echo "╠════════════════════════════════════════════╣"
    printf "║ PlaceId  : %-31s║\n" "$PLACE_ID"
    printf "║ Accounts : %-31s║\n" "$(account_count)"
    printf "║ ADB      : %-31s║\n" "${ADB_SERIAL:-Not set}"
    echo "╠════════════════════════════════════════════╣"
    echo "║ [1] START AUTO REJOIN                      ║"
    echo "║ [2] ADD / UPDATE ACCOUNTS                  ║"
    echo "║ [3] SHOW ACCOUNTS                          ║"
    echo "║ [4] REMOVE ACCOUNTS                        ║"
    echo "║ [5] SET PLACE ID                           ║"
    echo "║ [6] ADB SETUP / RECONNECT                  ║"
    echo "║ [7] DIAGNOSE PACKAGES                      ║"
    echo "║ [8] TEST FIRST JOIN                        ║"
    echo "║ [9] TEST PRESENCE                          ║"
    echo "║ [10] CLEAR ALL ACCOUNTS                    ║"
    echo "║ [U] UPDATE TOOL FROM GITHUB                ║"
    echo "║ [0] EXIT                                   ║"
    echo "╚════════════════════════════════════════════╝"
    echo

    read -r -p "Select > " choice < /dev/tty

    case "$choice" in
        1) start_auto_rejoin ;;
        2) add_accounts ;;
        3) show_accounts ;;
        4) remove_accounts ;;
        5) set_place_id ;;
        6) adb_setup ;;
        7) diagnose_packages ;;
        8) test_first_join ;;
        9) test_presence ;;
        10) clear_accounts ;;
        u|U) update_tool ;;
        0) clear; exit 0 ;;
        *) echo; echo "Lua chon khong hop le."; sleep 1 ;;
    esac
done
