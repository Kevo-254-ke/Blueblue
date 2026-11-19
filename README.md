# Dev Kevo Custom Script

XRAY and SSH WebSocket setup for Debian and Ubuntu servers using `apt` and `systemd`.

## Supported setup

- 64-bit x86 (`amd64`) Debian or Ubuntu.
- Ubuntu 24.04 was used for the latest clean-install validation. Other Debian and Ubuntu releases may need adjustments.
- Use a clean VPS. Setup replaces existing tunnel services and removes conflicting web server and firewall packages.
- Set a DNS A record for the domain you plan to enter during setup. It must point directly to the VPS while the TLS certificate is issued.

The installer prompts for the domain, public IPv4 address, and timezone. It installs the apt packages and local menu scripts needed for the installation. The XRAY core manager is installed as part of setup and downloads official Xray releases when used.

## Install

Run as root:

```bash
git clone https://github.com/Kevo-254-ke/Blueblue.git /root/Blueblue
cd /root/Blueblue
./setup.sh
```

Use `setup2.sh` for the alternate network setup. The install needs working DNS and outbound HTTPS access to GitHub and the package repositories.

## XRAY core menu

Open the main menu and select **55 — XRAY-CORE MENU**. It can install the latest official release, install a specific official version, and restore the most recent backup. The manager checks the existing config before replacing the binary and rolls back if XRAY fails to restart.

The bandwidth monitor, speed limiter, and traffic tools are installed by setup. Remote backup requires configuring an rclone remote named `dr` with `rclone config` first.
