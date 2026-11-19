dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')

# // Root Checking
if [ "${EUID}" -ne 0 ]; then
		echo -e "${EROR} Please Run This Script As Root User !"
		exit 1
fi
if ! command -v apt-get >/dev/null 2>&1 || [[ ! -r /etc/os-release ]]; then
		printf 'Dev Kevo setup supports Debian or Ubuntu systems using apt.\n' >&2
		exit 1
fi
. /etc/os-release
if [[ " ${ID:-} ${ID_LIKE:-} " != *debian* && " ${ID:-} ${ID_LIKE:-} " != *ubuntu* ]]; then
		printf 'Dev Kevo setup supports Debian or Ubuntu systems using apt. Detected: %s\n' "${PRETTY_NAME:-unknown}" >&2
		exit 1
fi
if [[ "$(uname -m)" != x86_64 && "$(uname -m)" != amd64 ]]; then
		printf 'Dev Kevo setup currently requires 64-bit x86 (amd64).\n' >&2
		exit 1
fi
clear
# // Exporting Language to UTF-8
export LANG='en_US.UTF-8'
export LANGUAGE='en_US.UTF-8'

# // Export Color & Information
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'
BIRed='\033[1;91m'
red='\e[1;31m'
bo='\e[1m'
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
# // Export Banner Status Information
export EROR="[${RED} ERROR ${NC}]"
export INFO="[${YELLOW} INFO ${NC}]"
export OKEY="[${GREEN} OKEY ${NC}]"
export PENDING="[${YELLOW} PENDING ${NC}]"
export SEND="[${YELLOW} SEND ${NC}]"
export RECEIVE="[${YELLOW} RECEIVE ${NC}]"

# // Export Align
export BOLD="\e[1m"
export WARNING="${RED}\e[5m"
export UNDERLINE="\e[4m"

# // Exporting URL Host
export Server_URL="raw.githubusercontent.com/Kevo-254-ke/Blueblue/main/test"
export Server1_URL="raw.githubusercontent.com/Kevo-254-ke/Blueblue/main/limit"
export Server_Port="443"
export Server_IP="underfined"
export Script_Mode="Stable"
export Auther=".geovpn"

# // Exporting Script Version
export VERSION="1.1"
 
# Ask for the server details that vary between installations.
default_ip=$(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)
default_timezone=$(cat /etc/timezone 2>/dev/null || true)
[[ -n "$default_timezone" ]] || default_timezone=$(timedatectl show -p Timezone --value 2>/dev/null || true)
[[ -n "$default_timezone" ]] || default_timezone=UTC

while true; do
    read -r -p "Server domain (DNS A record should point to this VPS): " DOMAIN
    DOMAIN=${DOMAIN,,}
    if [[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; then break; fi
    echo "Enter a valid hostname, for example vpn.example.com."
done
while true; do
    read -r -p "Public IPv4 address [${default_ip}]: " IP
    IP=${IP:-$default_ip}
    if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && awk -F. '($1<=255)&&($2<=255)&&($3<=255)&&($4<=255)' <<< "$IP" | grep -q 1; then break; fi
    echo "Enter a valid public IPv4 address."
done
while true; do
    read -r -p "Timezone [${default_timezone}]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-$default_timezone}
    if [[ -e "/usr/share/zoneinfo/${TIMEZONE}" && "$TIMEZONE" != /* && "$TIMEZONE" != *..* ]]; then break; fi
    echo "Enter a timezone from /usr/share/zoneinfo (for example Europe/London)."
done
export DOMAIN IP TIMEZONE
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
printf '%s\n' "$TIMEZONE" > /etc/timezone

# // cek old script
if [[ -r /etc/xray/domain ]]; then

echo -e "${INFO} Having Script Detected !"
echo -e "${INFO} If You Replacing Script, All Client Data On This VPS Will Be Cleanup !"
read -p "Are You Sure Wanna Replace Script ? (Y/N) " josdong
if [[ $josdong == "Y" ]]; then
clear
echo -e "${INFO} Starting Replacing Script !"
elif [[ $josdong == "y" ]]; then
clear
echo -e "${INFO} Starting Replacing Script !"
rm -rf /var/lib/scrz-prem 
elif [[ $josdong == "N" ]]; then
echo -e "${INFO} Action Canceled !"
exit 1
elif [[ $josdong == "n" ]]; then
echo -e "${INFO} Action Canceled !"
exit 1
else
echo -e "${EROR} Your Input Is Wrong !"
exit 1
fi

# Preserve a matching host certificate before the clean install removes /etc/xray.
if openssl x509 -in /etc/xray/xray.crt -noout -checkhost "$DOMAIN" >/dev/null 2>&1; then
    CERT_PUBLIC_KEY=$(openssl x509 -in /etc/xray/xray.crt -pubkey -noout 2>/dev/null | openssl sha256)
    KEY_PUBLIC_KEY=$(openssl pkey -in /etc/xray/xray.key -pubout 2>/dev/null | openssl sha256)
    if [[ -n "$CERT_PUBLIC_KEY" && "$CERT_PUBLIC_KEY" == "$KEY_PUBLIC_KEY" ]]; then
        install -d -m 700 /root/.blueblue-ssl
        install -m 644 /etc/xray/xray.crt /root/.blueblue-ssl/xray.crt
        install -m 600 /etc/xray/xray.key /root/.blueblue-ssl/xray.key
        echo "Matching certificate saved for the clean install."
    fi
fi
clear
fi

# Stop prior Blueblue services and remove the legacy SSH WebSocket unit before reinstalling.
systemctl stop ssh-ws.service xray.service ws-stunnel.service stunnel5.service rc-local.service >/dev/null 2>&1 || true
systemctl disable ssh-ws.service xray.service ws-stunnel.service stunnel5.service rc-local.service >/dev/null 2>&1 || true
pkill -x badvpn-udpgw >/dev/null 2>&1 || true
rm -f /etc/systemd/system/ssh-ws.service /etc/systemd/system/xray@.service /usr/local/etc/ssh-ws.py
systemctl daemon-reload >/dev/null 2>&1 || true

echo -e "${GREEN}Starting Installation............${NC}"
# // Go To Root Directory
cd /root/
# // Remove
apt-get remove --purge nginx* -y
apt-get remove --purge nginx-common* -y
apt-get remove --purge nginx-full* -y
apt-get remove --purge dropbear* -y
apt-get remove --purge stunnel4* -y
apt-get remove --purge apache2* -y
apt-get remove --purge ufw* -y
apt-get remove --purge firewalld* -y
apt-get remove --purge exim4* -y
apt autoremove -y

# // Update
apt update -y

# // Install Requirement Tools
apt-get --reinstall --fix-missing install -y ca-certificates sudo dpkg psmisc socat jq ruby wondershaper python3 python-is-python3 python3-lib2to3 tmux nmap bzip2 gzip coreutils wget screen rsyslog iftop htop net-tools zip unzip vim curl nano sed gnupg gnupg1 bc apt-transport-https build-essential gcc g++ automake make autoconf perl m4 dos2unix dropbear libreadline-dev zlib1g-dev libssl-dev dirmngr libxml-parser-perl neofetch git lsof iptables iptables-persistent
apt-get --reinstall --fix-missing install -y ca-certificates libreadline-dev zlib1g-dev libssl-dev python3 python-is-python3 python3-lib2to3 screen curl jq bzip2 gzip coreutils rsyslog iftop htop zip unzip net-tools sed gnupg gnupg1 bc sudo apt-transport-https build-essential dirmngr libxml-parser-perl neofetch screenfetch git lsof openssl easy-rsa fail2ban tmux vnstat dropbear libsqlite3-dev socat cron bash-completion ntpdate xz-utils sudo apt-transport-https gnupg2 dnsutils lsb-release chrony netcat-openbsd resolvconf
gem install lolcat --no-document

# // Update & Upgrade
apt update -y
apt upgrade -y
apt dist-upgrade -y

# // Clear
clear
clear && clear && clear
clear;clear;clear

# // Folder Sistem Yang Tidak Boleh Di Hapus
mkdir -p /usr/bin
# // Remove File & Directory
rm -fr /usr/local/bin/xray
rm -fr /usr/local/bin/stunnel
rm -fr /usr/local/bin/stunnel5
rm -fr /etc/nginx
rm -fr /var/lib/scrz-prem/
rm -fr /usr/bin/xray
rm -fr /etc/xray
rm -fr /usr/local/etc/xray
# // Making Directory 
mkdir -p /etc/nginx
mkdir -p /var/lib/scrz-prem/
mkdir -p /usr/bin/xray
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray
if [[ -s /root/.blueblue-ssl/xray.crt && -s /root/.blueblue-ssl/xray.key ]]; then
    install -m 644 /root/.blueblue-ssl/xray.crt /etc/xray/xray.crt
    install -m 600 /root/.blueblue-ssl/xray.key /etc/xray/xray.key
fi

#rm -fr /etc/xray/domain
# // String / Request Data
mkdir -p /var/lib/scrz-prem >/dev/null 2>&1
echo "IP=$IP" > /var/lib/scrz-prem/ipvps.conf
printf '%s\n' "$DOMAIN" > /etc/xray/domain
mkdir -p /etc/v2ray
printf '%s\n' "$DOMAIN" > /etc/v2ray/domain
printf '%s\n' "$DOMAIN" > /root/domain

sleep 2

#install jembot
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e "                          ⇱ INSTALL DOMAIN ⇲            "
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1
# Host is configured above; skip cf.sh because it expects a Cloudflare API token.
#install jembot
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m           ⇱ Install Jembot ⇲            \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1 
cp /root/Blueblue/jembot.sh ./jembot.sh && chmod +x jembot.sh && ./jembot.sh
#install ssh-vpn
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m          ⇱ Install SSH / WS ⇲           \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1
cp /root/Blueblue/ssh-vpn.sh ./ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh
#install ins-xray
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m            ⇱ Install Xray ⇲             \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1 
cp /root/Blueblue/ins-xray.sh ./ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
cp /root/Blueblue/set-br.sh ./set-br.sh && chmod +x set-br.sh && ./set-br.sh

# // Download Data
echo -e "${GREEN}Download Data${NC}"
install -m 0755 /root/Blueblue/add-ws.sh /usr/bin/add-ws
install -m 0755 /root/Blueblue/add-ssws.sh /usr/bin/add-ssws
install -m 0755 /root/Blueblue/add-socks.sh /usr/bin/add-socks
install -m 0755 /root/Blueblue/add-vless.sh /usr/bin/add-vless
install -m 0755 /root/Blueblue/add-tr.sh /usr/bin/add-tr
install -m 0755 /root/Blueblue/add-trgo.sh /usr/bin/add-trgo
install -m 0755 /root/Blueblue/autoreboot.sh /usr/bin/autoreboot
install -m 0755 /root/Blueblue/restart.sh /usr/bin/restart
install -m 0755 /root/Blueblue/tendang.sh /usr/bin/tendang
install -m 0755 /root/Blueblue/clearlog.sh /usr/bin/clearlog
install -m 0755 /root/Blueblue/running.sh /usr/bin/running
install -m 0755 /root/Blueblue/cek-trafik.sh /usr/bin/cek-trafik
install -m 0755 /root/Blueblue/speedtes_cli.py /usr/bin/cek-speed
install -m 0755 /root/Blueblue/cek-bandwidth.sh /usr/bin/cek-bandwidth
install -m 0755 /root/Blueblue/ram.sh /usr/bin/cek-ram
install -m 0755 /root/Blueblue/limit-speed.sh /usr/bin/limit-speed
install -m 0755 /root/Blueblue/menu-vless.sh /usr/bin/menu-vless
install -m 0755 /root/Blueblue/menu-vmess.sh /usr/bin/menu-vmess
install -m 0755 /root/Blueblue/menu-socks.sh /usr/bin/menu-socks
install -m 0755 /root/Blueblue/menu-ss.sh /usr/bin/menu-ss
install -m 0755 /root/Blueblue/menu-trojan.sh /usr/bin/menu-trojan
install -m 0755 /root/Blueblue/menu-trgo.sh /usr/bin/menu-trgo
install -m 0755 /root/Blueblue/menu-ssh.sh /usr/bin/menu-ssh
install -m 0755 /root/Blueblue/usernew.sh /usr/bin/usernew
# wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/Kevo-254-ke/Blueblue/main/menu.sh"
install -m 0755 /root/Blueblue/menu4.sh /usr/bin/menu
install -m 0755 /root/Blueblue/xraychanger.sh /usr/bin/xraychanger
install -m 0755 /root/Blueblue/webmin.sh /usr/bin/wbm
install -m 0755 /root/Blueblue/xp.sh /usr/bin/xp
install -m 0755 /root/Blueblue/dns.sh /usr/bin/dns
install -m 0755 /root/Blueblue/netf.sh /usr/bin/netf
install -m 0755 /root/Blueblue/bbr.sh /usr/bin/bbr
#wget -q -O /usr/bin/del-xrays "https://raw.githubusercontent.com/Kevo-254-ke/Blueblue/main/del-xrays.sh"
#wget -q -O /usr/bin/user-xrays "https://raw.githubusercontent.com/Kevo-254-ke/Blueblue/main/user-xrays.sh"
chmod +x /usr/bin/add-ws
chmod +x /usr/bin/add-ssws
chmod +x /usr/bin/add-socks
chmod +x /usr/bin/add-vless
chmod +x /usr/bin/add-tr
chmod +x /usr/bin/add-trgo
chmod +x /usr/bin/usernew
chmod +x /usr/bin/autoreboot
chmod +x /usr/bin/restart
chmod +x /usr/bin/tendang
chmod +x /usr/bin/clearlog
chmod +x /usr/bin/running
chmod +x /usr/bin/cek-trafik
chmod +x /usr/bin/cek-speed
chmod +x /usr/bin/cek-bandwidth
chmod +x /usr/bin/cek-ram
chmod +x /usr/bin/limit-speed
chmod +x /usr/bin/menu-vless
chmod +x /usr/bin/menu-vmess
chmod +x /usr/bin/menu-ss
chmod +x /usr/bin/menu-socks
chmod +x /usr/bin/menu-trojan
chmod +x /usr/bin/menu-trgo
chmod +x /usr/bin/menu-ssh
chmod +x /usr/bin/menu
chmod +x /usr/bin/wbm
chmod +x /usr/bin/xp
chmod +x /usr/bin/dns
chmod +x /usr/bin/netf
chmod +x /usr/bin/bbr
#chmod +x /usr/bin/del-xrays
#chmod +x /usr/bin/user-xrays


# Remove schedules from previous Blueblue installs; use one managed cron file.
sed -i -E '/^[[:space:]]*0[[:space:]]+(0|1|2|3|4|5|6|7|23)[[:space:]]+\*[[:space:]]+\*[[:space:]]+root[[:space:]]+(\/usr\/bin\/)?(xp|delete|cleaner|reboot|backup)$/d' /etc/crontab
sed -i -E '/^[[:space:]]*5[[:space:]]+23[[:space:]]+\*[[:space:]]+\*[[:space:]]+root[[:space:]]+\/usr\/bin\/backup$/d' /etc/crontab
cd

#cat > /etc/cron.d/re_otm <<-END
#SHELL=/bin/sh
#PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
#0 7 * * * root /sbin/reboot
#END

cat > /etc/cron.d/xp_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/xp
0 1 * * * root /usr/bin/delete
0 2 * * * root /usr/bin/cleaner
0 3 * * * root /usr/bin/xp
0 4 * * * root /usr/bin/delete
0 5 * * * root reboot
0 7 * * * root /usr/bin/cleaner
END

cat > /etc/cron.d/cl_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 1 * * * root /usr/bin/clearlog
END

cat > /home/re_otm <<-END
7
END

service cron restart >/dev/null 2>&1
service cron reload >/dev/null 2>&1

clear
cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END
chmod 644 /root/.profile

if [ -f "/root/log-install.txt" ]; then
rm -fr /root/log-install.txt 
fi
if [ -f "/etc/afak.conf" ]; then
rm -fr /etc/afak.conf 
fi
if [ ! -f "/etc/log-create-user.log" ]; then
echo "Log All Account " > /etc/log-create-user.log
fi
history -c
aureb=$(cat /home/re_otm)
b=11
if [ $aureb -gt $b ]
then
gg="PM"
else
gg="AM"
fi
echo -e "[ ${green}Pleas Wait Update DB ${NC} ]"
# Removed the upstream license/IP upload to an unrelated GitHub account.
echo "1.1" >> /home/.ver
rm -fr /root/limit
curl -sS ifconfig.me > /etc/myipvps
echo " "
echo "====================-[ Dev Kevo Custom Script ]-===================="
echo ""
echo "------------------------------------------------------------"
echo ""
echo ""
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - OpenSSH                 : 22"  | tee -a log-install.txt
echo "   - SSH Websocket           : 80" | tee -a log-install.txt
echo "   - SSH SSL Websocket       : 443" | tee -a log-install.txt
echo "   - Stunnel5                : 447, 777" | tee -a log-install.txt
echo "   - Dropbear                : 109, 143" | tee -a log-install.txt
echo "   - Badvpn                  : 7100-7300" | tee -a log-install.txt
echo "   - Nginx                   : 81" | tee -a log-install.txt
echo "   - XRAY  Vmess TLS         : 443" | tee -a log-install.txt
echo "   - XRAY  Vmess None TLS    : 80" | tee -a log-install.txt
echo "   - XRAY  Vless TLS         : 443" | tee -a log-install.txt
echo "   - XRAY  Vless None TLS    : 80" | tee -a log-install.txt
echo "   - Trojan GRPC             : 443" | tee -a log-install.txt
echo "   - Trojan WS               : 443" | tee -a log-install.txt
echo "   - Trojan GO               : 443" | tee -a log-install.txt
#echo "   - Trojan GFW              : 443" | tee -a log-install.txt
echo "   - Sodosok WS/GRPC         : 443" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Server Information & Other Features"  | tee -a log-install.txt
echo "   - Timezone                : ${TIMEZONE}"  | tee -a log-install.txt
echo "   - Fail2Ban                : [ON]"  | tee -a log-install.txt
echo "   - Dflate                  : [ON]"  | tee -a log-install.txt
echo "   - IPtables                : [ON]"  | tee -a log-install.txt
echo "   - Auto-Reboot             : [ON]"  | tee -a log-install.txt
echo "   - IPv6                    : [OFF]"  | tee -a log-install.txt
echo "   - Autoreboot Off          : $aureb:00 $gg GMT + 8" | tee -a log-install.txt
echo "   - Autobackup Data" | tee -a log-install.txt
echo "   - AutoKill Multi Login User" | tee -a log-install.txt
echo "   - Auto Delete Expired Account" | tee -a log-install.txt
echo "   - Fully automatic script" | tee -a log-install.txt
echo "   - VPS settings" | tee -a log-install.txt
echo "   - Admin Control" | tee -a log-install.txt
echo "   - Change port" | tee -a log-install.txt
echo "   - Restore Data" | tee -a log-install.txt
echo "   - Full Orders For Various Services" | tee -a log-install.txt
echo ""
echo ""
echo "------------------------------------------------------------"
echo ""
echo "===============-[ Dev Kevo ]-==============="
echo -e ""
echo ""
echo "" | tee -a log-install.txt
rm -fr /root/weleh.sh 
rm -fr /root/jembot.sh 
rm -fr /root/ssh-vpn.sh
rm -fr /root/ins-xray.sh
rm -fr /root/setup.sh
history -c

read -p "$( echo -e "Press ${orange}[ ${NC}${green}Enter${NC} ${CYAN}]${NC} For Reboot") "
echo "Install complete. Reboot the server when ready."
