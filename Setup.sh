#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$HOME/auto-rejoin"
BIN="$BASE/auto_rejoin.sh"
PICKER="$BASE/select_packages.sh"
CFG="$BASE/config.sh"
LOG="$BASE/rejoin.log"
BOOT_DIR="$HOME/.termux/boot"
BOOT_FILE="$BOOT_DIR/10-auto-rejoin.sh"

mkdir -p "$BASE" "$BOOT_DIR"

if command -v pkg >/dev/null 2>&1; then
  pkg install -y procps coreutils >/dev/null 2>&1 || true
fi

# Default settings. PACKAGES is intentionally empty: user selects from installed apps.
if [ ! -f "$CFG" ]; then
cat > "$CFG" <<'CFGEOF'
# =====================
# AUTO-REJOIN CONFIG
# =====================
PACKAGES=()
JOIN_URIS=()

# Check interval in seconds.
CHECK_SECONDS=15

# 0 = off. Example: 3600 = attempt restart every hour.
RESTART_SECONDS=0

# Delay between relaunching multiple selected apps.
STAGGER_SECONDS=5

# normal = no root, root = su, rish = Shizuku rish.
EXEC_MODE="normal"

SINGLE_INSTANCE=true
CFGEOF
fi

cat > "$PICKER" <<'PICKEREOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$HOME/auto-rejoin"
CFG="$BASE/config.sh"
TMP="$BASE/.packages.tmp"

mkdir -p "$BASE"

scan_packages() {
  # Prefer third-party/user-installed apps so the list is not flooded by Android system packages.
  if /system/bin/pm list packages -3 >/dev/null 2>&1; then
    /system/bin/pm list packages -3 2>/dev/null | sed 's/^package://' | sort -u
  elif /system/bin/cmd package list packages -3 >/dev/null 2>&1; then
    /system/bin/cmd package list packages -3 2>/dev/null | sed 's/^package://' | sort -u
  else
    return 1
  fi
}

mapfile -t ALL_PACKAGES < <(scan_packages)
if [ ${#ALL_PACKAGES[@]} -eq 0 ]; then
  echo "Khong quet duoc package tren may."
  echo "Thu lenh: /system/bin/pm list packages -3"
  exit 1
fi

echo
printf 'Da tim thay %d package nguoi dung.\n' "${#ALL_PACKAGES[@]}"
echo "Nhap tu khoa de loc (vd: roblox), hoac Enter de hien tat ca:"
read -r FILTER

FILTERED=()
for pkg in "${ALL_PACKAGES[@]}"; do
  if [ -z "$FILTER" ] || printf '%s\n' "$pkg" | grep -iF -- "$FILTER" >/dev/null 2>&1; then
    FILTERED+=("$pkg")
  fi
done

if [ ${#FILTERED[@]} -eq 0 ]; then
  echo "Khong co package nao khop '$FILTER'."
  exit 1
fi

echo
for i in "${!FILTERED[@]}"; do
  printf '%3d) %s\n' "$((i+1))" "${FILTERED[$i]}"
done

echo
echo "Nhap so package muon chon. Co the chon nhieu, vd: 1 3 5"
echo "Hoac nhap 'a' de chon tat ca ket qua dang hien:"
read -r -a PICKS

SELECTED=()
if [ ${#PICKS[@]} -eq 1 ] && { [ "${PICKS[0]}" = "a" ] || [ "${PICKS[0]}" = "A" ]; }; then
  SELECTED=("${FILTERED[@]}")
else
  for n in "${PICKS[@]}"; do
    if ! [[ "$n" =~ ^[0-9]+$ ]]; then
      echo "Bo qua gia tri khong hop le: $n"
      continue
    fi
    idx=$((n-1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#FILTERED[@]}" ]; then
      SELECTED+=("${FILTERED[$idx]}")
    else
      echo "Bo qua so ngoai danh sach: $n"
    fi
  done
fi

if [ ${#SELECTED[@]} -eq 0 ]; then
  echo "Chua chon package nao."
  exit 1
fi

# Preserve non-package settings if the config already exists.
CHECK_SECONDS=15
RESTART_SECONDS=0
STAGGER_SECONDS=5
EXEC_MODE="normal"
SINGLE_INSTANCE=true
if [ -f "$CFG" ]; then
  # shellcheck disable=SC1090
  source "$CFG" 2>/dev/null || true
fi

{
  echo '# ====================='
  echo '# AUTO-REJOIN CONFIG'
  echo '# ====================='
  echo 'PACKAGES=('
  for pkg in "${SELECTED[@]}"; do
    printf '  %q\n' "$pkg"
  done
  echo ')'
  echo
  echo 'JOIN_URIS=('
  for _ in "${SELECTED[@]}"; do
    echo '  ""'
  done
  echo ')'
  echo
  printf 'CHECK_SECONDS=%q\n' "${CHECK_SECONDS:-15}"
  printf 'RESTART_SECONDS=%q\n' "${RESTART_SECONDS:-0}"
  printf 'STAGGER_SECONDS=%q\n' "${STAGGER_SECONDS:-5}"
  printf 'EXEC_MODE=%q\n' "${EXEC_MODE:-normal}"
  printf 'SINGLE_INSTANCE=%q\n' "${SINGLE_INSTANCE:-true}"
} > "$CFG"

echo
echo "Da luu package:"
for pkg in "${SELECTED[@]}"; do
  echo "  - $pkg"
done
echo "Config: $CFG"
PICKEREOF

cat > "$BIN" <<'BINEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$HOME/auto-rejoin"
CFG="$BASE/config.sh"
LOG="$BASE/rejoin.log"
LOCKDIR="$BASE/.lock"
PICKER="$BASE/select_packages.sh"

[ -f "$CFG" ] || { echo "Thieu $CFG"; exit 1; }
# shellcheck disable=SC1090
source "$CFG"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"
}

if [ ${#PACKAGES[@]} -eq 0 ]; then
  echo "Chua chon package. Dang mo menu chon app..."
  "$PICKER"
  # Reload after picker writes config.
  # shellcheck disable=SC1090
  source "$CFG"
fi

if [ "${SINGLE_INSTANCE:-true}" = true ]; then
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    log "Auto-rejoin dang chay roi."
    exit 0
  fi
  trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT INT TERM
fi

command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true

run_priv() {
  local cmd="$1"
  case "${EXEC_MODE:-normal}" in
    root) su -c "$cmd" ;;
    rish) rish -c "$cmd" ;;
    *) /system/bin/sh -c "$cmd" ;;
  esac
}

is_running() {
  local pkg="$1"
  pidof "$pkg" >/dev/null 2>&1 && return 0
  ps -A 2>/dev/null | grep -F "$pkg" | grep -v grep >/dev/null 2>&1
}

launch_app() {
  local pkg="$1"
  local uri="${2:-}"

  if [ -n "$uri" ]; then
    log "Mo $pkg bang URI"
    /system/bin/am start -a android.intent.action.VIEW -d "$uri" "$pkg" >>"$LOG" 2>&1 || \
      /system/bin/monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >>"$LOG" 2>&1 || true
  else
    log "Mo $pkg"
    /system/bin/monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >>"$LOG" 2>&1 || \
      /system/bin/am start -p "$pkg" >>"$LOG" 2>&1 || true
  fi
}

force_stop() {
  local pkg="$1"
  run_priv "am force-stop '$pkg'" >>"$LOG" 2>&1
}

last_restart=$(date +%s)
log "Auto-rejoin bat dau: ${PACKAGES[*]}"

for i in "${!PACKAGES[@]}"; do
  pkg="${PACKAGES[$i]}"
  uri="${JOIN_URIS[$i]:-}"
  if ! is_running "$pkg"; then
    launch_app "$pkg" "$uri"
    sleep "${STAGGER_SECONDS:-5}"
  fi
done

while true; do
  now=$(date +%s)

  if [ "${RESTART_SECONDS:-0}" -gt 0 ] && [ $((now-last_restart)) -ge "${RESTART_SECONDS}" ]; then
    log "Den moc restart dinh ky."
    for i in "${!PACKAGES[@]}"; do
      pkg="${PACKAGES[$i]}"
      uri="${JOIN_URIS[$i]:-}"
      if force_stop "$pkg"; then
        sleep 2
      fi
      launch_app "$pkg" "$uri"
      sleep "${STAGGER_SECONDS:-5}"
    done
    last_restart=$(date +%s)
  fi

  for i in "${!PACKAGES[@]}"; do
    pkg="${PACKAGES[$i]}"
    uri="${JOIN_URIS[$i]:-}"
    if ! is_running "$pkg"; then
      log "$pkg da tat/crash -> mo lai"
      launch_app "$pkg" "$uri"
      sleep "${STAGGER_SECONDS:-5}"
    fi
  done

  sleep "${CHECK_SECONDS:-15}"
done
BINEOF

cat > "$BOOT_FILE" <<'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock >/dev/null 2>&1 || true
nohup "$HOME/auto-rejoin/auto_rejoin.sh" >> "$HOME/auto-rejoin/boot.log" 2>&1 &
BOOTEOF

chmod +x "$BIN" "$PICKER" "$BOOT_FILE"

echo
echo "=== AUTO-REJOIN NO KEY v2 ==="
echo "Da cai vao: $BASE"
echo "Tool se quet package tren may de ban chon."
echo

# Run selector immediately when setup is used interactively.
if [ -t 0 ]; then
  "$PICKER" || true
fi

echo
echo "Chon/doi package bat cu luc nao:"
echo "  $PICKER"
echo
echo "Bat auto-rejoin:"
echo "  $BIN"
echo
echo "Dung auto-rejoin:"
echo "  pkill -f '$BIN'"
echo
echo "Xem log:"
echo "  tail -f $LOG"
