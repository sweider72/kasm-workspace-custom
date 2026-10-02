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

# Google's signing key is scoped to its Chrome repository.
curl --fail --silent --show-error --location \
    https://dl.google.com/linux/linux_signing_key.pub \
    --output /etc/apt/keyrings/google-chrome.asc
gpg --batch --show-keys --with-colons /etc/apt/keyrings/google-chrome.asc \
    | awk -F: '$1 == "fpr" {print $10}' \
    | grep -qx 'EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796'
printf '%s\n' \
    'deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.asc] https://dl.google.com/linux/chrome/deb/ stable main' \
    > /etc/apt/sources.list.d/google-chrome.list

# Nextcloud's client PPA provides newer clients than Jammy's 3.4 package.
add-apt-repository -y ppa:nextcloud-devs/client
apt-get update
apt-get install -y --no-install-recommends \
    thunderbird thunderbird-locale-de \
    nextcloud-desktop nextcloud-desktop-l10n \
    firefox firefox-l10n-de google-chrome-stable \
    gnome-keyring seahorse libsecret-1-0 dbus-x11 xdg-utils

locale-gen de_DE.UTF-8
update-locale LANG=de_DE.UTF-8

# Kasm's official Chrome image uses --no-sandbox inside the isolated container.
# Keep Chrome's credential storage on the desktop keyring and retain warnings.
cat > /usr/local/bin/google-chrome <<'CHROME'
#!/usr/bin/env bash
set -euo pipefail
if ! pgrep -u "$(id -u)" -x chrome >/dev/null; then
    rm -f "$HOME/.config/google-chrome/SingletonLock" \
        "$HOME/.config/google-chrome/SingletonSocket" \
        "$HOME/.config/google-chrome/SingletonCookie"
fi
exec /usr/bin/google-chrome-stable --no-sandbox --no-first-run "$@"
CHROME
chmod 755 /usr/local/bin/google-chrome
# Ensure menu entries use the same container-compatible launcher.
sed -i 's@Exec=/usr/bin/google-chrome-stable@Exec=/usr/local/bin/google-chrome@g' \
    /usr/share/applications/google-chrome.desktop

mkdir -p "$HOME/Desktop"
for application in thunderbird firefox google-chrome; do
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
    thunderbird nextcloud-desktop firefox google-chrome-stable > /etc/workspace-app-versions.txt
apt-get clean
rm -rf /var/lib/apt/lists/*
