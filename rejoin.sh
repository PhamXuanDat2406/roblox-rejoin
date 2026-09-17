#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# ROBLOX AUTO REJOIN V8 - TERMUX / ANDROID
# package: com.free.nokaX
# mapping: package | Roblox UserId
#
# START AUTO REJOIN:
#   1) Open + join all saved clones immediately.
#   2) Monitor Roblox Presence API in one batch request.
#   3) If an account is NOT IN GAME twice in a row,
#      rejoin only that account's clone.
#   4) API/network failures are NOT treated as offline.
# ============================================================

TOOL_DIR="$HOME/roblox-rejoin"
ACCOUNTS_FILE="$TOOL_DIR/accounts.txt"
PLACE_FILE="$TOOL_DIR/placeid.txt"

BASE_PACKAGE="com.free.noka"
DEFAULT_PLACE_ID="1730877806"

PRESENCE_URL="https://presence.roblox.com/v1/presence/users"

OPEN_DELAY=2
NEXT_CLIENT_DELAY=5
CHECK_DELAY=15

# Wait after a rejoin before judging presence again.
REJOIN_COOLDOWN=60

# Number of consecutive valid "not in game" checks before rejoining.
CONFIRM_MISSES=2

mkdir -p "$TOOL_DIR"
touch "$ACCOUNTS_FILE"

if [ -s "$PLACE_FILE" ]; then
    PLACE_ID="$(head -n1 "$PLACE_FILE" | tr -cd '0-9')"
fi
[ -z "$PLACE_ID" ] && PLACE_ID="$DEFAULT_PLACE_ID"

# Runtime monitoring state.
declare -A MISS_COUNT
declare -A LAST_REJOIN

pause_menu() {
    echo
    read -r -p "Nhan Enter de tiep tuc..." < /dev/tty
}

account_count() {
    local n
    n="$(grep -cve '^[[:space:]]*$' "$ACCOUNTS_FILE" 2>/dev/null)"
    [ -z "$n" ] && n=0
    echo "$n"
}

normalize_package() {
    local token="$1"

    token="$(printf '%s' "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$token" ] && return 1

    case "$token" in
        base|BASE|goc|GOC)
            printf '%s\n' "$BASE_PACKAGE"
            ;;
        com.free.noka*)
            printf '%s\n' "$token"
            ;;
        *)
            # Keep suffix exactly as typed: A -> com.free.nokaA
            printf '%s%s\n' "$BASE_PACKAGE" "$token"
            ;;
    esac
}

# Add or update a single package -> userid mapping.
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

    echo "=============================================="
    echo "              ADD ACCOUNTS / CLIENS"
    echo "=============================================="
    echo
    echo "Nhap NHIEU acc cung luc theo dang:"
    echo
    echo "  A:USERID,B:USERID,C:USERID"
    echo
    echo "Vi du:"
    echo "  A:123456789,B:987654321,C:555555555"
    echo
    echo "Tool se luu:"
    echo "  com.free.nokaA | 123456789"
    echo "  com.free.nokaB | 987654321"
    echo "  com.free.nokaC | 555555555"
    echo
    echo "Neu co package goc com.free.noka:"
    echo "  base:123456789"
    echo
    echo "Co the vao ADD ACCOUNTS nhieu lan de them tiep."
    echo "Nhap lai cung package se CAP NHAT UserId."
    echo

    local input pair left right package added
    read -r -p "Add > " input < /dev/tty

    [ -z "$input" ] && {
        echo
        echo "[!] Khong co gi duoc them."
        pause_menu
        return
    }

    added=0

    # Separate entries by comma or semicolon.
    while IFS= read -r pair; do
        pair="$(printf '%s' "$pair" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$pair" ] && continue

        left="${pair%%:*}"
        right="${pair#*:}"

        if [ "$left" = "$pair" ]; then
            echo "[SKIP] Sai format: $pair"
            continue
        fi

        right="$(printf '%s' "$right" | tr -cd '0-9')"

        if [ -z "$right" ]; then
            echo "[SKIP] UserId khong hop le: $pair"
            continue
        fi

        package="$(normalize_package "$left")"

        if [ -z "$package" ]; then
            echo "[SKIP] Package khong hop le: $pair"
            continue
        fi

        upsert_account "$package" "$right"
        echo "[OK] $package -> $right"
        added=$((added + 1))

    done < <(printf '%s\n' "$input" | tr ',;' '\n')

    echo
    echo "[OK] Da them/cap nhat: $added"
    echo "[OK] Tong accounts: $(account_count)"

    pause_menu
}

show_accounts() {
    clear

    echo "=============================================="
    echo "                 SAVED ACCOUNTS"
    echo "=============================================="
    echo
    echo "PlaceId: $PLACE_ID"
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co account nao."
    else
        local n=1 package userid

        while IFS='|' read -r package userid; do
            [ -z "$package" ] && continue
            printf "[%d] %-25s | UserId: %s\n" "$n" "$package" "$userid"
            n=$((n + 1))
        done < "$ACCOUNTS_FILE"
    fi

    pause_menu
}

remove_accounts() {
    clear

    echo "=============================================="
    echo "                REMOVE ACCOUNTS"
    echo "=============================================="
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Danh sach dang trong."
        pause_menu
        return
    fi

    echo "Nhap suffix can xoa, co the nhap nhieu:"
    echo
    echo "  A,B,C"
    echo
    echo "Hoac full package."
    echo
    echo "Danh sach:"
    echo

    local package userid n=1
    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue
        printf "[%d] %s | %s\n" "$n" "$package" "$userid"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"

    echo

    local input token target temp
    read -r -p "Remove > " input < /dev/tty

    [ -z "$input" ] && {
        echo "[!] Da huy."
        pause_menu
        return
    }

    temp="$TOOL_DIR/.accounts.remove"
    cp "$ACCOUNTS_FILE" "$temp"

    while IFS= read -r token; do
        [ -z "$token" ] && continue
        target="$(normalize_package "$token")"
        awk -F'|' -v p="$target" '$1 != p' "$temp" > "$temp.2"
        mv "$temp.2" "$temp"
        echo "[OK] Remove: $target"
    done < <(printf '%s\n' "$input" | tr ',;' '\n')

    mv "$temp" "$ACCOUNTS_FILE"

    echo
    echo "[OK] Con lai $(account_count) accounts."
    pause_menu
}

clear_accounts() {
    clear

    echo "=============================================="
    echo "                CLEAR ALL ACCOUNTS"
    echo "=============================================="
    echo

    local confirm
    read -r -p "Xoa TOAN BO danh sach? (y/N): " confirm < /dev/tty

    case "$confirm" in
        y|Y)
            : > "$ACCOUNTS_FILE"
            echo "[OK] Da xoa tat ca."
            ;;
        *)
            echo "[!] Da huy."
            ;;
    esac

    pause_menu
}

set_place_id() {
    clear

    echo "=============================================="
    echo "                  SET PLACE ID"
    echo "=============================================="
    echo
    echo "Hien tai: $PLACE_ID"
    echo

    local new_id
    read -r -p "PlaceId > " new_id < /dev/tty

    if [[ "$new_id" =~ ^[0-9]+$ ]]; then
        PLACE_ID="$new_id"
        printf '%s\n' "$PLACE_ID" > "$PLACE_FILE"
        echo
        echo "[OK] Da luu PlaceId: $PLACE_ID"
    else
        echo
        echo "[!] PlaceId phai la so."
    fi

    pause_menu
}

is_fatal_am_error() {
    grep -qiE \
      'Error type 3|Activity class .* does not exist|unable to resolve Intent|Permission Denial|SecurityException|Exception occurred|No activities found'
}

# Open the clone's launcher first.
open_clone() {
    local package="$1"
    local output

    output="$(monkey -p "$package" -c android.intent.category.LAUNCHER 1 2>&1)"

    if printf '%s\n' "$output" | is_fatal_am_error; then
        return 1
    fi

    return 0
}

# Attempt official Roblox direct-to-app deep link inside one package.
join_client() {
    local package="$1"
    local uri="roblox://placeId=${PLACE_ID}"
    local output component

    echo "[+] $package"

    # Step 1: open this clone/app task.
    if ! open_clone "$package"; then
        echo "    [FAIL] Khong mo duoc package."
        return 1
    fi

    sleep "$OPEN_DELAY"

    # Step 2: ask Android which activity inside THIS package handles roblox://.
    component="$(
        cmd package resolve-activity --brief \
          -a android.intent.action.VIEW \
          -c android.intent.category.BROWSABLE \
          -d "$uri" \
          -p "$package" \
          2>/dev/null | tail -n1
    )"

    if [[ "$component" == */* ]]; then
        output="$(
            am start --user 0 -W \
              -a android.intent.action.VIEW \
              -c android.intent.category.DEFAULT \
              -c android.intent.category.BROWSABLE \
              -d "$uri" \
              -n "$component" \
              2>&1
        )"

        if ! printf '%s\n' "$output" | is_fatal_am_error; then
            echo "    [OK] Open + Join via resolved activity"
            LAST_REJOIN["$package"]="$(date +%s)"
            MISS_COUNT["$package"]=0
            return 0
        fi
    fi

    # Step 3: package-scoped resolver.
    output="$(
        am start --user 0 -W \
          -a android.intent.action.VIEW \
          -c android.intent.category.DEFAULT \
          -c android.intent.category.BROWSABLE \
          -d "$uri" \
          -p "$package" \
          2>&1
    )"

    if ! printf '%s\n' "$output" | is_fatal_am_error; then
        echo "    [OK] Open + Join via package resolver"
        LAST_REJOIN["$package"]="$(date +%s)"
        MISS_COUNT["$package"]=0
        return 0
    fi

    # Step 4: common Roblox activity retained by many clones.
    output="$(
        am start --user 0 -W \
          -a android.intent.action.VIEW \
          -c android.intent.category.DEFAULT \
          -c android.intent.category.BROWSABLE \
          -d "$uri" \
          -n "${package}/com.roblox.client.ActivityProtocolLaunch" \
          2>&1
    )"

    if ! printf '%s\n' "$output" | is_fatal_am_error; then
        echo "    [OK] Open + Join via ActivityProtocolLaunch"
        LAST_REJOIN["$package"]="$(date +%s)"
        MISS_COUNT["$package"]=0
        return 0
    fi

    echo "    [FAIL] App mo duoc nhung clone khong nhan deep link."
    return 1
}

join_all_now() {
    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co account."
        return 1
    fi

    local total current ok fail package userid
    total="$(account_count)"
    current=0
    ok=0
    fail=0

    echo
    echo "=============================================="
    echo "                  JOIN ALL NOW"
    echo "=============================================="
    echo
    echo "PlaceId  : $PLACE_ID"
    echo "Accounts : $total"
    echo

    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue

        current=$((current + 1))
        echo "----------------------------------------------"
        echo "[$current/$total] $package | UserId $userid"

        if join_client "$package"; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi

        [ "$current" -lt "$total" ] && sleep "$NEXT_CLIENT_DELAY"

    done < "$ACCOUNTS_FILE"

    echo
    echo "JOIN DONE   OK:$ok   FAIL:$fail"
    echo
}

internet_ok() {
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1
}

# Query every saved user in ONE API call.
# Prints raw JSON to stdout. Failure = non-zero exit, never interpreted as offline.
fetch_presence() {
    local ids body response

    ids="$(
        cut -d'|' -f2 "$ACCOUNTS_FILE" \
          | grep -E '^[0-9]+$' \
          | sort -u \
          | paste -sd, -
    )"

    [ -z "$ids" ] && return 1

    body="{\"userIds\":[${ids}]}"

    response="$(
        curl -fsS \
          --connect-timeout 5 \
          --max-time 10 \
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

monitor_presence_once() {
    local response="$1"
    local now package userid ptype pname last elapsed miss

    now="$(date +%s)"

    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue

        # Read this user's presence from the valid batch response.
        ptype="$(
            printf '%s\n' "$response" \
              | jq -r --arg uid "$userid" \
                  '.userPresences[]
                   | select((.userId|tostring) == $uid)
                   | .userPresenceType' \
              | head -n1
        )"

        # Missing user in an otherwise valid response = unknown, not offline.
        if ! [[ "$ptype" =~ ^[0-9]+$ ]]; then
            echo "[$(date +%H:%M:%S)] $package | User $userid | UNKNOWN"
            continue
        fi

        pname="$(presence_name "$ptype")"

        last="${LAST_REJOIN[$package]:-0}"
        elapsed=$((now - last))

        # During cooldown, show status but don't accumulate misses.
        if [ "$last" -gt 0 ] && [ "$elapsed" -lt "$REJOIN_COOLDOWN" ]; then
            MISS_COUNT["$package"]=0
            echo "[$(date +%H:%M:%S)] $package | $pname | cooldown $((REJOIN_COOLDOWN - elapsed))s"
            continue
        fi

        if [ "$ptype" -eq 2 ]; then
            MISS_COUNT["$package"]=0
            echo "[$(date +%H:%M:%S)] $package | User $userid | IN GAME"
            continue
        fi

        # A valid state other than InGame counts as a miss.
        miss="${MISS_COUNT[$package]:-0}"
        miss=$((miss + 1))
        MISS_COUNT["$package"]="$miss"

        echo "[$(date +%H:%M:%S)] $package | User $userid | $pname | check $miss/$CONFIRM_MISSES"

        if [ "$miss" -ge "$CONFIRM_MISSES" ]; then
            echo "[!] $package is not InGame -> REJOIN"
            MISS_COUNT["$package"]=0

            join_client "$package"

            # Avoid hitting the next clone immediately after switching apps.
            sleep "$NEXT_CLIENT_DELAY"
        fi

    done < "$ACCOUNTS_FILE"
}

start_auto_rejoin() {
    clear

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "=============================================="
        echo "              START AUTO REJOIN"
        echo "=============================================="
        echo
        echo "[!] Chua co account."
        echo "[+] Vao ADD ACCOUNTS / CLIENS truoc."
        pause_menu
        return
    fi

    echo "=============================================="
    echo "              START AUTO REJOIN"
    echo "=============================================="
    echo
    echo "1. Mo + join tat ca account ngay."
    echo "2. Sau do check Presence moi ${CHECK_DELAY}s."
    echo "3. Khong InGame ${CONFIRM_MISSES} lan lien tiep -> rejoin dung clone."
    echo "4. Sau rejoin cho cooldown ${REJOIN_COOLDOWN}s."
    echo

    # Immediate first launch.
    join_all_now

    echo
    echo "=============================================="
    echo "               MONITOR ACTIVE"
    echo "=============================================="
    echo
    echo "Presence API : $PRESENCE_URL"
    echo "Check delay  : ${CHECK_DELAY}s"
    echo "Confirm      : ${CONFIRM_MISSES} checks"
    echo "Cooldown     : ${REJOIN_COOLDOWN}s"
    echo
    echo "CTRL+C de dung."
    echo

    local was_offline=0 response

    while true; do

        if ! internet_ok; then
            if [ "$was_offline" -eq 0 ]; then
                echo
                echo "[$(date +%H:%M:%S)] INTERNET LOST"
                echo "[!] Cho Internet quay lai..."
            fi

            was_offline=1
            sleep "$CHECK_DELAY"
            continue
        fi

        if [ "$was_offline" -eq 1 ]; then
            echo
            echo "[$(date +%H:%M:%S)] INTERNET RESTORED"
            echo "[+] Rejoin ALL sau khi mat mang."
            join_all_now
            was_offline=0
        fi

        # API error never counts as an offline account.
        if ! response="$(fetch_presence)"; then
            echo "[$(date +%H:%M:%S)] Presence API unavailable -> SKIP"
            sleep "$CHECK_DELAY"
            continue
        fi

        monitor_presence_once "$response"

        sleep "$CHECK_DELAY"
    done
}

test_presence() {
    clear

    echo "=============================================="
    echo "                TEST PRESENCE"
    echo "=============================================="
    echo

    if [ ! -s "$ACCOUNTS_FILE" ]; then
        echo "[!] Chua co account."
        pause_menu
        return
    fi

    local response package userid ptype pname

    if ! response="$(fetch_presence)"; then
        echo "[FAIL] Khong goi duoc Roblox Presence API."
        pause_menu
        return
    fi

    while IFS='|' read -r package userid; do
        [ -z "$package" ] && continue

        ptype="$(
            printf '%s\n' "$response" \
              | jq -r --arg uid "$userid" \
                  '.userPresences[]
                   | select((.userId|tostring) == $uid)
                   | .userPresenceType' \
              | head -n1
        )"

        if [[ "$ptype" =~ ^[0-9]+$ ]]; then
            pname="$(presence_name "$ptype")"
            printf "%-25s | %-12s | %s\n" "$package" "$pname" "$userid"
        else
            printf "%-25s | %-12s | %s\n" "$package" "UNKNOWN" "$userid"
        fi
    done < "$ACCOUNTS_FILE"

    pause_menu
}

test_first_join() {
    clear

    echo "=============================================="
    echo "              TEST FIRST ACCOUNT"
    echo "=============================================="
    echo

    local package userid
    IFS='|' read -r package userid < "$ACCOUNTS_FILE"

    if [ -z "$package" ]; then
        echo "[!] Chua co account."
    else
        echo "Package : $package"
        echo "UserId  : $userid"
        echo "PlaceId : $PLACE_ID"
        echo
        join_client "$package"
    fi

    pause_menu
}

open_overlay_settings() {
    clear

    echo "=============================================="
    echo "        TERMUX BACKGROUND PERMISSION"
    echo "=============================================="
    echo
    echo "Neu client dau mo duoc nhung client sau khong mo,"
    echo "bat Display over other apps cho Termux."
    echo
    echo "Dang mo Settings..."
    echo

    am start --user 0 \
      -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
      -d "package:com.termux" >/dev/null 2>&1

    echo
    echo "Bat quyen neu may co muc nay roi quay lai Termux."

    pause_menu
}

while true; do
    clear

    echo "╔════════════════════════════════════════════╗"
    echo "║        ROBLOX AUTO REJOIN V8               ║"
    echo "╠════════════════════════════════════════════╣"
    printf "║ PlaceId  : %-31s║\n" "$PLACE_ID"
    printf "║ Accounts : %-31s║\n" "$(account_count)"
    echo "╠════════════════════════════════════════════╣"
    echo "║ [1] START AUTO REJOIN                      ║"
    echo "║ [2] ADD ACCOUNTS / CLIENS                  ║"
    echo "║ [3] SHOW ACCOUNTS                          ║"
    echo "║ [4] REMOVE ACCOUNTS                        ║"
    echo "║ [5] SET PLACE ID                           ║"
    echo "║ [6] TEST PRESENCE                          ║"
    echo "║ [7] TEST FIRST ACCOUNT JOIN                ║"
    echo "║ [8] TERMUX BACKGROUND PERMISSION           ║"
    echo "║ [9] CLEAR ALL ACCOUNTS                     ║"
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
        6) test_presence ;;
        7) test_first_join ;;
        8) open_overlay_settings ;;
        9) clear_accounts ;;
        0) clear; exit 0 ;;
        *) echo; echo "Lua chon khong hop le."; sleep 1 ;;
    esac
done
