#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg locales software-properties-common

# Jammy's Firefox package is a Snap; use Mozilla's signed DEB repository.
install -d -m 0755 /etc/apt/keyrings
curl --fail --silent --show-error --location \
    https://packages.mozilla.org/apt/repo-signing-key.gpg \
    --output /etc/apt/keyrings/packages.mozilla.org.asc
fingerprint="$(gpg --batch --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc | awk -F: '$1 == "fpr" {print $10; exit}')"
test "$fingerprint" = "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
printf '%s\n' \
    'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main' \
    > /etc/apt/sources.list.d/mozilla.list
printf '%s\n' \
    'Package: firefox*' 'Pin: origin packages.mozilla.org' 'Pin-Priority: 1001' \
    > /etc/apt/preferences.d/mozilla

# Nextcloud's client PPA provides newer clients than Jammy's 3.4 package.
add-apt-repository -y ppa:nextcloud-devs/client
apt-get update
apt-get install -y --no-install-recommends \
    thunderbird thunderbird-locale-de \
    nextcloud-desktop nextcloud-desktop-l10n \
    firefox firefox-l10n-de \
    gnome-keyring seahorse libsecret-1-0 dbus-x11 xdg-utils

locale-gen de_DE.UTF-8
update-locale LANG=de_DE.UTF-8

mkdir -p "$HOME/Desktop"
for application in thunderbird firefox; do
    install -m 0755 "/usr/share/applications/$application.desktop" "$HOME/Desktop/$application.desktop"
    chown 1000:1000 "$HOME/Desktop/$application.desktop"
done

cat > "$HOME/Desktop/nextcloud.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Nextcloud
Comment=Dateien mit Nextcloud synchronisieren
Exec=nextcloud
Icon=Nextcloud
Terminal=false
Categories=Network;
DESKTOP
chmod 755 "$HOME/Desktop/nextcloud.desktop"
chown 1000:1000 "$HOME/Desktop/nextcloud.desktop"

# Set the browser for the OAuth login flow in a newly created profile.
mkdir -p "$HOME/.config"
cat > "$HOME/.config/mimeapps.list" <<'MIME'
[Default Applications]
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
MIME

# One startup owner: our Kasm hook starts both applications.
rm -f /etc/xdg/autostart/nextcloud.desktop /etc/xdg/autostart/org.nextcloud.Nextcloud.desktop

dpkg-query -W -f='${Package}\t${Version}\n' \
    thunderbird nextcloud-desktop firefox > /etc/workspace-app-versions.txt
apt-get clean
rm -rf /var/lib/apt/lists/*
