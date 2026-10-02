#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg locales software-properties-common

# Ubuntu's Firefox package is a Snap; use Mozilla's signed DEB repository.
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

# Claude Desktop's official repository and key.
curl --fail --silent --show-error --location \
    https://downloads.claude.ai/claude-desktop/key.asc \
    --output /etc/apt/keyrings/claude-desktop.asc
gpg --batch --show-keys --with-colons /etc/apt/keyrings/claude-desktop.asc \
    | awk -F: '$1 == "fpr" {print $10}' \
    | grep -qx '31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE'
printf '%s\n' \
    'deb [arch=amd64 signed-by=/etc/apt/keyrings/claude-desktop.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' \
    > /etc/apt/sources.list.d/claude-desktop.list

# Noble's Thunderbird package is a Snap; use the PPA used by Kasm itself.
add-apt-repository -y ppa:mozillateam/ppa
printf '%s\n' \
    'Package: thunderbird*' 'Pin: release o=LP-PPA-mozillateam' 'Pin-Priority: 1001' \
    > /etc/apt/preferences.d/mozilla-thunderbird

# Nextcloud's official client PPA.
add-apt-repository -y ppa:nextcloud-devs/client
apt-get update
apt-get install -y --no-install-recommends \
    thunderbird thunderbird-locale-de \
    nextcloud-desktop nextcloud-desktop-l10n \
    firefox firefox-l10n-de google-chrome-stable \
    gnome-keyring seahorse libsecret-1-0 dbus-x11 xdg-utils xdotool claude-desktop \
    libreoffice libreoffice-l10n-de

# Pin Tabby to an upstream release and verify GitHub's published SHA-256.
curl --fail --silent --show-error --location \
    'https://github.com/Eugeny/tabby/releases/download/v1.0.237/tabby-1.0.237-linux-x64.deb' --output /tmp/tabby.deb
printf '%s  %s\n' '9b6a440bf513536b99de959be485a064414203220307d687d77a1f1cb9ba92f2' /tmp/tabby.deb | sha256sum --check -
# OpenAI's official amd64 DEB configures its signed update repository.
curl --fail --silent --show-error --location \
    https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb \
    --output /tmp/chatgpt.deb
test "$(dpkg-deb --field /tmp/tabby.deb Architecture)" = amd64
test "$(dpkg-deb --field /tmp/chatgpt.deb Architecture)" = amd64
apt-get install -y --no-install-recommends /tmp/tabby.deb /tmp/chatgpt.deb
rm -f /tmp/tabby.deb /tmp/chatgpt.deb

# Electron apps use the same container launch mode as Kasm's Chrome image.
# Launch on demand, without injecting account details or changing permissions.
for application in tabby chatgpt claude-desktop; do
    test -x "/usr/bin/$application"
    printf '%s\n' '#!/usr/bin/env bash' \
        "exec /usr/bin/$application --no-sandbox \"\$@\"" \
        > "/usr/local/bin/$application"
    chmod 755 "/usr/local/bin/$application"
done

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

# Menu entries also work for existing persistent profiles.
for application in tabby chatgpt claude-desktop; do
    case "$application" in
        tabby) title='Tabby'; category='System;TerminalEmulator;' ;;
        chatgpt) title='ChatGPT'; category='Network;' ;;
        claude-desktop) title='Claude'; category='Network;' ;;
    esac
    cat > "/usr/share/applications/kasm-$application.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$title
Exec=/usr/local/bin/$application
Icon=$application
Terminal=false
Categories=$category
DESKTOP
    install -m 0755 "/usr/share/applications/kasm-$application.desktop" \
        "$HOME/Desktop/kasm-$application.desktop"
    chown 1000:1000 "$HOME/Desktop/kasm-$application.desktop"
done

for application in libreoffice-startcenter libreoffice-writer libreoffice-calc libreoffice-impress; do
    install -m 0755 "/usr/share/applications/$application.desktop" \
        "$HOME/Desktop/$application.desktop"
    chown 1000:1000 "$HOME/Desktop/$application.desktop"
done

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
    thunderbird nextcloud-desktop firefox google-chrome-stable tabby-terminal chatgpt claude-desktop libreoffice libreoffice-l10n-de > /etc/workspace-app-versions.txt
apt-get clean
rm -rf /var/lib/apt/lists/*
