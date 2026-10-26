# KovaiHost VPS Setup Toolkit

One-command setup for KovaiHost game server VPS (Ubuntu).

## Run

Log in as root (`sudo -i`), then:

```bash
bash <(curl -s https://raw.githubusercontent.com/GoldenRex-kahe/kovaihost-setup/main/kovaihost-setup.sh)
```

or

```bash
curl -sL https://raw.githubusercontent.com/GoldenRex-kahe/kovaihost-setup/main/kovaihost-setup.sh | bash
```

## Menu

| # | Option | What it does |
|---|--------|--------------|
| 1 | Update Ubuntu | apt update, upgrade, dist-upgrade, autoremove; reboot prompt if needed |
| 2 | Speed test | Installs the official Ookla Speedtest CLI and runs it |
| 3 | Benchmark | YABS: full, skip Geekbench, skip network, or Geekbench only |
| 4 | Pterodactyl | Runs the pterodactyl-installer.se script (Panel / Wings / both) |
| 5 | Tools | Install essentials (fastfetch/neofetch, htop, git, screen, tmux, iperf3, jq, fail2ban, login MOTD) or change the hostname (e.g. `vpsq3132` → `kovaihost-panel`) |
| 6 | Firewall (UFW) | SSH, 80/443, 8080, 2022, Minecraft Java 25565-25600 tcp/udp, Bedrock 19132-19133/udp, Pterodactyl Docker network 172.18.0.0/16 |
| 7 | Run ALL | Steps 1, 2, 3, 4, 6 in order (skips tools) |
| 0 | Exit | |

Logs are written to `/var/log/kovaihost-setup.log`.

## Notes

- Built for Ubuntu 20.04 / 22.04 / 24.04.
- Point your domain's DNS to the VPS before installing the Panel (for SSL).
- Run the firewall step after installing Wings.
