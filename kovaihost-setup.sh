#!/usr/bin/env bash
# =============================================================================
#  KovaiHost - VPS Setup Toolkit
#  Ubuntu update, speed test, benchmark, Pterodactyl Panel/Wings, tools, hostname, firewall
#  Usage (online):  bash <(curl -s https://raw.githubusercontent.com/GoldenRex-kahe/kovaihost-setup/main/kovaihost-setup.sh)
#  Usage (local):   sudo bash kovaihost-setup.sh
# =============================================================================

set -o pipefail

# ---------- Colors ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

LOG_FILE="/var/log/kovaihost-setup.log"

# ---------- Helpers ----------
info()    { echo -e "${CYAN}[KovaiHost]${NC} $*"; echo "[INFO] $*" >> "$LOG_FILE"; }
success() { echo -e "${GREEN}[KovaiHost] ✔ $*${NC}"; echo "[OK] $*" >> "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[KovaiHost] ! $*${NC}"; echo "[WARN] $*" >> "$LOG_FILE"; }
error()   { echo -e "${RED}[KovaiHost] ✘ $*${NC}"; echo "[ERROR] $*" >> "$LOG_FILE"; }

RUN_ALL=0

pause() { [[ $RUN_ALL -eq 1 ]] && return; echo; read -rp "$(echo -e "${MAGENTA}Press Enter to return to the KovaiHost menu...${NC}")" _; }

confirm() {
    local reply
    read -rp "$(echo -e "${YELLOW}$1 [y/N]: ${NC}")" reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
  _  __                 _ _   _           _
 | |/ /_____   ____ _(_) | | | | ___  ___| |_
 | ' // _ \ \ / / _` | | | |_| |/ _ \/ __| __|
 | . \ (_) \ V / (_| | | |  _  | (_) \__ \ |_
 |_|\_\___/ \_/ \__,_|_|_|_| |_|\___/|___/\__|

EOF
    echo -e "${NC}${CYAN}        KovaiHost VPS Setup Toolkit${NC}"
    echo -e "${CYAN}   Fast • Reliable • Game Server Hosting${NC}"
    echo -e "${BLUE}=================================================${NC}"
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        echo -e " OS: ${GREEN}${PRETTY_NAME}${NC}  |  Host: ${GREEN}$(hostname)${NC}"
    fi
    echo -e " IP: ${GREEN}$(hostname -I 2>/dev/null | awk '{print $1}')${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

# ---------- Pre-checks ----------
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[KovaiHost] Please run as root (sudo -i first, or sudo bash kovaihost-setup.sh)${NC}"
        exit 1
    fi
}

check_os() {
    if [[ ! -r /etc/os-release ]] || ! grep -qi "ubuntu" /etc/os-release; then
        warn "This script is made for Ubuntu. Other systems may not work."
        confirm "Continue anyway?" || exit 1
    fi
}

ensure_curl() {
    command -v curl >/dev/null 2>&1 || { apt-get update -y && apt-get install -y curl; }
}

# =============================================================================
#  1. Update packages & Ubuntu
# =============================================================================
update_system() {
    banner
    info "Updating package lists and upgrading Ubuntu..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y \
      && apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y \
      && apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y \
      && apt-get autoremove -y && apt-get autoclean -y
    if [[ $? -eq 0 ]]; then
        success "System updated successfully."
    else
        error "Update failed. Check $LOG_FILE and the output above."
    fi
    if [[ $RUN_ALL -eq 0 && -f /var/run/reboot-required ]]; then
        warn "A reboot is required to finish the update."
        confirm "Reboot now?" && reboot
    fi
    pause
}

# =============================================================================
#  2. Speed test (Ookla official CLI)
# =============================================================================
install_speedtest() {
    command -v speedtest >/dev/null 2>&1 && speedtest --version 2>/dev/null | grep -qi ookla && return 0
    info "Installing Ookla Speedtest CLI..."
    local arch
    case "$(uname -m)" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        armv7l)  arch="armhf" ;;
        i386|i686) arch="i386" ;;
        *) error "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${arch}.tgz" -o "$tmp/st.tgz" \
      && tar -xzf "$tmp/st.tgz" -C "$tmp" \
      && install -m 755 "$tmp/speedtest" /usr/local/bin/speedtest
    local rc=$?
    rm -rf "$tmp"
    [[ $rc -eq 0 ]] && success "Speedtest CLI installed." || error "Speedtest install failed."
    return $rc
}

run_speedtest() {
    banner
    ensure_curl
    install_speedtest || { pause; return; }
    info "Running KovaiHost network speed test (Ookla)..."
    echo
    speedtest --accept-license --accept-gdpr
    echo
    if confirm "Run again against a specific server ID?"; then
        speedtest --servers 2>/dev/null | head -n 15
        read -rp "Enter server ID: " sid
        [[ -n "$sid" ]] && speedtest --accept-license --accept-gdpr -s "$sid"
    fi
    pause
}

# =============================================================================
#  3. Benchmark (YABS)
# =============================================================================
run_benchmark() {
    banner
    ensure_curl
    echo -e "${BOLD}KovaiHost Benchmark (YABS - Yet Another Bench Script)${NC}"
    echo "  1) Full benchmark (Disk + Network + Geekbench 6)"
    echo "  2) Disk + Network only (faster, skip Geekbench)"
    echo "  3) Disk + Geekbench only (skip network iperf)"
    echo "  4) Geekbench 6 only"
    echo "  0) Back"
    read -rp "Choose: " b
    case "$b" in
        1) curl -sL https://yabs.sh | bash ;;
        2) curl -sL https://yabs.sh | bash -s -- -g ;;
        3) curl -sL https://yabs.sh | bash -s -- -i ;;
        4) curl -sL https://yabs.sh | bash -s -- -f -i ;;
        0) return ;;
        *) warn "Invalid option." ;;
    esac
    pause
}

# =============================================================================
#  4. Pterodactyl Panel / Wings
# =============================================================================
install_pterodactyl() {
    banner
    ensure_curl
    echo -e "${BOLD}KovaiHost Pterodactyl Installer${NC}"
    echo -e "Uses the community installer: ${CYAN}https://pterodactyl-installer.se${NC}"
    echo -e "It will ask whether to install the Panel, Wings, or both."
    echo
    warn "Tip: point your domain's DNS (A record) to this VPS before installing, for SSL."
    confirm "Start the Pterodactyl installer now?" || return
    bash <(curl -s https://pterodactyl-installer.se)
    success "Pterodactyl installer finished."
    info "Recommended: run option 6 (Firewall) so the Panel/Wings/Minecraft ports are open."
    pause
}

# =============================================================================
#  5. Tools: essential packages, hostname changer
# =============================================================================
install_tools() {
    banner
    info "Installing essential KovaiHost tools..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl wget git nano vim htop iftop net-tools unzip zip tar \
        screen tmux ca-certificates gnupg lsb-release software-properties-common \
        dnsutils iperf3 jq ufw fail2ban

    # fastfetch is the maintained successor of neofetch; fall back to neofetch
    if apt-get install -y fastfetch 2>/dev/null; then
        success "fastfetch installed."
    elif apt-get install -y neofetch; then
        success "neofetch installed."
    else
        warn "Could not install fastfetch or neofetch."
    fi

    systemctl enable --now fail2ban >/dev/null 2>&1 && success "fail2ban enabled (SSH brute-force protection)."

    if confirm "Show system info on every SSH login (KovaiHost MOTD)?"; then
        local fetch; fetch="$(command -v fastfetch || command -v neofetch)"
        if [[ -n "$fetch" ]]; then
            cat > /etc/profile.d/kovaihost-motd.sh << EOF
#!/bin/sh
case "\$-" in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac
echo ""
echo "  Welcome to your KovaiHost VPS"
echo ""
$fetch
EOF
            chmod +x /etc/profile.d/kovaihost-motd.sh
            success "Login MOTD added."
        fi
    fi

    echo
    command -v fastfetch >/dev/null && fastfetch || { command -v neofetch >/dev/null && neofetch; }
    success "Tools installation complete."
    pause
}

change_hostname() {
    banner
    echo -e "${BOLD}KovaiHost Hostname Changer${NC}"
    echo -e "Current hostname: ${GREEN}$(hostname)${NC}"
    echo "Use letters, numbers and '-' only (no spaces). A domain like panel.kovaihost.com also works."
    echo
    local new old short esc
    old="$(hostname)"
    read -rp "New hostname [kovaihost-panel]: " new
    new=${new:-kovaihost-panel}
    # Spaces/underscores aren't allowed in hostnames: "KovaiHost Panel" -> "kovaihost-panel"
    new=$(echo "$new" | tr '[:upper:]' '[:lower:]' | sed -E 's/[ _]+/-/g')

    local label='[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?'
    if [[ ${#new} -gt 253 || ! "$new" =~ ^${label}(\.${label})*$ ]]; then
        error "Invalid hostname: '$new'"
        pause; return
    fi
    if [[ "$new" == "$old" ]]; then
        warn "Hostname is already '$new'."
        pause; return
    fi
    confirm "Change hostname from '$old' to '$new'?" || return

    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "$new"
    else
        echo "$new" > /etc/hostname
        hostname "$new"
    fi

    # /etc/hosts: swap the old name for the new one and keep 127.0.1.1 pointing at it
    short="${new%%.*}"
    cp /etc/hosts /etc/hosts.kovaihost.bak
    esc=$(printf '%s' "$old" | sed 's/[.[\*^$/]/\&/g')
    sed -i -E "s/([[:space:]])${esc}([[:space:]]|$)/\1${new}\2/g" /etc/hosts
    sed -i '/^127\.0\.1\.1[[:space:]]/d' /etc/hosts
    if [[ "$short" != "$new" ]]; then
        echo "127.0.1.1 $new $short" >> /etc/hosts
    else
        echo "127.0.1.1 $new" >> /etc/hosts
    fi

    # Stop cloud-init (used by most VPS providers) from resetting it on reboot
    if [[ -d /etc/cloud ]]; then
        mkdir -p /etc/cloud/cloud.cfg.d
        echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-kovaihost-hostname.cfg
    fi

    success "Hostname changed to '$(hostname)'. Backup of old hosts file: /etc/hosts.kovaihost.bak"
    info "Log out and SSH back in to see the new name in your prompt."
    pause
}

tools_menu() {
    while true; do
        banner
        echo -e "${BOLD}KovaiHost Tools${NC}"
        echo -e "  ${GREEN}1${NC}) Install essential tools (fastfetch/neofetch, htop, fail2ban...)"
        echo -e "  ${GREEN}2${NC}) Change hostname (e.g. vpsq3132 -> kovaihost-panel)"
        echo -e "  ${RED}0${NC}) Back"
        read -rp "$(echo -e "${BOLD}KovaiHost Tools > ${NC}")" t
        case "$t" in
            1) install_tools ;;
            2) change_hostname ;;
            0) return ;;
            *) warn "Invalid option, try again."; sleep 1 ;;
        esac
    done
}

# =============================================================================
#  6. Firewall (UFW) - Panel, Wings, Minecraft, internal Docker network
# =============================================================================
setup_firewall() {
    banner
    command -v ufw >/dev/null 2>&1 || apt-get install -y ufw
    echo -e "${BOLD}KovaiHost Firewall Setup (UFW)${NC}"
    echo "Ports that will be allowed:"
    echo "  22/tcp            SSH"
    echo "  80, 443/tcp       Panel (HTTP/HTTPS, SSL)"
    echo "  8080/tcp          Wings API (Panel <-> Node)"
    echo "  2022/tcp          Wings SFTP"
    echo "  25565-25600 tcp/udp  Minecraft Java servers"
    echo "  19132-19133/udp   Minecraft Bedrock"
    echo "  172.18.0.0/16     Pterodactyl Docker internal network"
    echo

    local ssh_port
    ssh_port=$(grep -Ei '^\s*Port\s+[0-9]+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    ssh_port=${ssh_port:-22}
    read -rp "SSH port [${ssh_port}]: " in; ssh_port=${in:-$ssh_port}
    read -rp "Minecraft port range [25565:25600]: " mc_range; mc_range=${mc_range:-25565:25600}
    mc_range=${mc_range/-/:}

    confirm "Apply these firewall rules?" || return

    # SSH first so we never lock ourselves out
    ufw allow "${ssh_port}/tcp" comment 'KovaiHost SSH'

    ufw default deny incoming
    ufw default allow outgoing

    ufw allow 80/tcp   comment 'KovaiHost Panel HTTP'
    ufw allow 443/tcp  comment 'KovaiHost Panel HTTPS'
    ufw allow 8080/tcp comment 'KovaiHost Wings API'
    ufw allow 2022/tcp comment 'KovaiHost Wings SFTP'

    ufw allow "${mc_range}/tcp" comment 'KovaiHost Minecraft Java'
    ufw allow "${mc_range}/udp" comment 'KovaiHost Minecraft Java (query/voice)'
    ufw allow 19132:19133/udp   comment 'KovaiHost Minecraft Bedrock'

    # Internal communication: game containers <-> host (MySQL, Wings, panel)
    ufw allow from 172.18.0.0/16 comment 'KovaiHost Pterodactyl Docker network'
    ufw allow in on pterodactyl0 comment 'KovaiHost Pterodactyl interface' 2>/dev/null || true
    ufw allow in on docker0      comment 'KovaiHost Docker interface' 2>/dev/null || true

    if confirm "Allow remote MySQL (3306) for game server databases?"; then
        ufw allow 3306/tcp comment 'KovaiHost MySQL'
    fi

    if confirm "Allow extra custom ports (e.g. Discord bots, web apps)?"; then
        read -rp "Ports separated by space (e.g. 3000 8443 30000:30100): " extra
        for p in $extra; do
            ufw allow "$p" comment 'KovaiHost custom'
        done
    fi

    ufw --force enable
    success "Firewall enabled."
    ufw status numbered
    pause
}

# =============================================================================
#  8. Ubuntu release upgrade (e.g. 22.04 -> 24.04)
# =============================================================================
upgrade_release() {
    banner
    . /etc/os-release
    echo -e "${BOLD}KovaiHost Ubuntu Release Upgrade${NC}"
    echo -e "Current version: ${GREEN}${PRETTY_NAME}${NC}"
    echo

    local major=${VERSION_ID%%.*}
    if [[ "$major" -ge 24 ]]; then
        success "You are already on Ubuntu ${VERSION_ID}, the latest LTS. Nothing to do."
        pause; return
    fi

    echo -e "${RED}${BOLD}  !!! WARNING - READ BEFORE CONTINUING !!!${NC}"
    echo -e "${YELLOW}  • This upgrades the whole OS to the next LTS release (22.04 -> 24.04)."
    echo -e "  • TAKE A BACKUP / SNAPSHOT of this VPS first. A failed upgrade can leave it unbootable."
    echo -e "  • It takes 15-30+ minutes and asks questions. Do NOT close the SSH window."
    echo -e "  • Third-party repos (PHP PPA, Docker, etc.) are disabled during the upgrade."
    echo -e "  • The VPS will reboot at the end.${NC}"

    if [[ -d /var/www/pterodactyl || -x /usr/local/bin/wings ]]; then
        echo
        warn "Pterodactyl Panel/Wings is installed on this VPS."
        echo -e "${YELLOW}  • Stop all game servers and tell your users about the downtime."
        echo -e "  • After the upgrade, check the panel and wings, and re-enable disabled repos.${NC}"
    fi

    local free_gb
    free_gb=$(df -BG --output=avail / | tail -n1 | tr -dc '0-9')
    if [[ -n "$free_gb" && "$free_gb" -lt 5 ]]; then
        error "Only ${free_gb}GB free on /. At least 5GB is needed for the upgrade."
        pause; return
    fi

    echo
    local answer
    read -rp "$(echo -e "${RED}Type UPGRADE (in capitals) to continue: ${NC}")" answer
    [[ "$answer" == "UPGRADE" ]] || { warn "Upgrade cancelled."; pause; return; }

    info "Step 1/3: Bringing the current release fully up to date..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y \
      && apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y \
      && apt-get autoremove -y
    if [[ $? -ne 0 ]]; then
        error "Updating the current release failed. Fix that first (see $LOG_FILE)."
        pause; return
    fi
    unset DEBIAN_FRONTEND

    if [[ -f /var/run/reboot-required ]]; then
        warn "A reboot is needed before the release upgrade can start."
        echo -e "${YELLOW}After the reboot, run the KovaiHost script again and choose option 8.${NC}"
        confirm "Reboot now?" && reboot
        pause; return
    fi

    info "Step 2/3: Preparing the release upgrader..."
    apt-get install -y update-manager-core
    sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades 2>/dev/null

    # Over SSH the upgrader starts a backup SSH server on port 1022
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow 1022/tcp comment 'KovaiHost temporary upgrade SSH' >/dev/null
        info "Opened port 1022 for the upgrader's backup SSH. Remove later: ufw delete allow 1022/tcp"
    fi

    info "Step 3/3: Starting the Ubuntu release upgrade. Answer the prompts on screen."
    echo -e "${YELLOW}Tip: when asked to keep or replace config files, keeping your current version (N) is safest.${NC}"
    echo
    do-release-upgrade
    local rc=$?
    echo
    if [[ $rc -eq 0 ]]; then
        success "Release upgrade finished. Reboot if the upgrader did not already."
    else
        error "do-release-upgrade exited with code $rc. Check /var/log/dist-upgrade/ for details."
    fi
    pause
}

# =============================================================================
#  7. Run everything
# =============================================================================
run_all() {
    banner
    info "Full KovaiHost setup: Update -> Speedtest -> Benchmark -> Pterodactyl -> Firewall"
    confirm "Continue with full setup?" || return
    RUN_ALL=1   # skip "Press Enter" stops between steps
    update_system
    run_speedtest
    run_benchmark
    install_pterodactyl
    setup_firewall
    RUN_ALL=0
    success "Full KovaiHost setup complete!"
    if [[ -f /var/run/reboot-required ]]; then
        warn "A reboot is required to finish updates."
        confirm "Reboot now?" && reboot
    fi
    pause
}

# =============================================================================
#  Menu
# =============================================================================
main_menu() {
    while true; do
        banner
        echo -e "  ${GREEN}1${NC}) Update packages & Ubuntu"
        echo -e "  ${GREEN}2${NC}) Network speed test (Ookla)"
        echo -e "  ${GREEN}3${NC}) Benchmark (YABS)"
        echo -e "  ${GREEN}4${NC}) Install Pterodactyl Panel / Wings"
        echo -e "  ${GREEN}5${NC}) Tools (essential packages, change hostname)"
        echo -e "  ${GREEN}6${NC}) Firewall setup (Panel, Wings, Minecraft, internal network)"
        echo -e "  ${GREEN}7${NC}) Run ALL steps (except tools)"
        echo -e "  ${YELLOW}8${NC}) Upgrade Ubuntu release (22.04 -> 24.04) ${RED}[backup first!]${NC}"
        echo -e "  ${RED}0${NC}) Exit"
        echo -e "${BLUE}=================================================${NC}"
        read -rp "$(echo -e "${BOLD}KovaiHost > ${NC}")" choice
        case "$choice" in
            1) update_system ;;
            2) run_speedtest ;;
            3) run_benchmark ;;
            4) install_pterodactyl ;;
            5) tools_menu ;;
            6) setup_firewall ;;
            7) run_all ;;
            8) upgrade_release ;;
            0) echo -e "${GREEN}Thank you for using KovaiHost! Goodbye.${NC}"; exit 0 ;;
            *) warn "Invalid option, try again."; sleep 1 ;;
        esac
    done
}

main() {
    # Also works with "curl ... | bash": read menu answers from the keyboard, not the pipe
    if [[ ! -t 0 && -r /dev/tty ]]; then exec < /dev/tty 2>/dev/null; fi
    require_root
    touch "$LOG_FILE" 2>/dev/null
    check_os
    main_menu
}

main "$@"
