#!/usr/bin/env bash
set -u
set -o pipefail

die() { printf 'XRAY core manager: %s\n' "$*" >&2; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    die 'run this command as root.'
    exit 1
fi

for required in curl jq unzip systemctl; do
    if ! command -v "$required" >/dev/null 2>&1; then
        die "required command '$required' is missing. Run the setup script again to install dependencies."
        exit 1
    fi
done

XRAY_BIN=$(command -v xray 2>/dev/null || true)
if [[ -z "$XRAY_BIN" || ! -x "$XRAY_BIN" ]]; then
    die 'Xray binary was not found in PATH.'
    exit 1
fi

LATEST_JSON=$(curl -fsSL --retry 2 --connect-timeout 10 https://api.github.com/repos/XTLS/Xray-core/releases/latest) || {
    die 'could not query the Xray release service.'
    exit 1
}
LATEST_TAG=$(jq -er '.tag_name' <<< "$LATEST_JSON") || exit 1
CURRENT_VERSION=$($XRAY_BIN version 2>&1 | awk '/Xray/{print $2; exit}')

printf '\nDev Kevo XRAY Core Manager\n'
printf 'Installed: %s\nLatest:    %s\n\n' "${CURRENT_VERSION:-unknown}" "$LATEST_TAG"
printf '1) Install latest official core (%s)\n' "$LATEST_TAG"
printf '2) Install a specific official version\n'
printf '3) Restore the most recent backup\n'
printf '0) Return to the main menu\n'
read -r -p 'Select: ' choice

case "$choice" in
    0) exec menu ;;
    3)
        backup=$(find "$(dirname "$XRAY_BIN")" -maxdepth 1 -type f -name "$(basename "$XRAY_BIN").backup.*" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)
        if [[ -z "$backup" || ! -x "$backup" ]]; then
            die 'no executable backup is available.'
            exit 1
        fi
        candidate="${XRAY_BIN}.restore.$$"
        install -m 0755 "$backup" "$candidate" && mv -f "$candidate" "$XRAY_BIN" || exit 1
        if systemctl restart xray; then
            printf 'Restored %s and restarted Xray.\n' "$backup"
        else
            die 'Xray did not restart after restoring the backup; inspect systemctl status xray.'
            exit 1
        fi
        ;;
    1) version=$LATEST_TAG ;;
    2)
        read -r -p 'Version (with or without leading v): ' version
        [[ "$version" == v* ]] || version="v${version}"
        [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || {
            die 'version must look like 1.8.4 or v1.8.4.'
            exit 1
        }
        ;;
    *) die 'unknown selection.'; exit 1 ;;
esac

release=$(curl -fsSL --retry 2 --connect-timeout 10 "https://api.github.com/repos/XTLS/Xray-core/releases/tags/${version}") || {
    die "release ${version} was not found or GitHub could not be reached."
    exit 1
}
download_url=$(jq -er '.assets[] | select(.name == "Xray-linux-64.zip") | .browser_download_url' <<< "$release" | head -n1) || {
    die "release ${version} has no Linux x86_64 archive."
    exit 1
}
[[ -n "$download_url" ]] || { die "release ${version} has no Linux x86_64 archive."; exit 1; }

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
if ! curl -fL --retry 3 --connect-timeout 15 "$download_url" -o "$workdir/xray.zip" || ! unzip -tq "$workdir/xray.zip" >/dev/null; then
    die 'download or archive verification failed; the installed core was left unchanged.'
    exit 1
fi
unzip -oq "$workdir/xray.zip" -d "$workdir/unpacked" || exit 1
new_binary="$workdir/unpacked/xray"
[[ -x "$new_binary" ]] || { die 'the release archive did not contain an Xray executable.'; exit 1; }

if [[ -s /etc/xray/config.json ]] && ! "$new_binary" run -test -config /etc/xray/config.json >/dev/null 2>&1; then
    die "${version} rejected /etc/xray/config.json; the installed core was left unchanged."
    exit 1
fi

backup="${XRAY_BIN}.backup.$(date +%Y%m%d%H%M%S)"
candidate="${XRAY_BIN}.new.$$"
cp -p "$XRAY_BIN" "$backup" && install -m 0755 "$new_binary" "$candidate" && mv -f "$candidate" "$XRAY_BIN" || {
    rm -f "$candidate"
    die 'could not install the new core; the existing binary remains available.'
    exit 1
}

if systemctl restart xray; then
    printf 'Installed %s and restarted Xray. Previous core saved at %s\n' "$version" "$backup"
else
    install -m 0755 "$backup" "$candidate" && mv -f "$candidate" "$XRAY_BIN"
    systemctl restart xray >/dev/null 2>&1 || true
    die 'Xray failed to restart; restored the previous core. Check systemctl status xray.'
    exit 1
fi
