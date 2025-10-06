#!/bin/bash

# Network check
if ! ping -q -c 1 -W 2 google.com >/dev/null; then
    read -p "💥 No internet connection. Check your network and try again."
    exit 1
fi

# Required commands
for cmd in wget grep; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd is required but not installed. Exiting."
        exit 1
    fi
done

# 🔄 Function to update VMware
update_vmware() {
    echo "==> Updating VMware Workstation..."

    # Paths
    BUNDLE_PATH="$HOME/.vmware/vmware-workstation-linux.bundle"
    PKGBUILD_URL="https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=vmware-workstation"

    # Get current installed version using vmware -v
    if command -v vmware &>/dev/null; then
        current_version=$(vmware -v | awk '{print $3}')
    else
        current_version="none"
    fi

    pkgbuild=$(
      wget -q \
        --tries=1 \
        --timeout=5 \
        --dns-timeout=3 \
        --connect-timeout=3 \
        --read-timeout=5 \
        -O - "$PKGBUILD_URL"
    ) || {
      echo "💥 Shit hit the fan. AUR is inaccessible. Try again later."
      return
    }

    pkgver=$(echo "$pkgbuild" | grep -Po '^pkgver=\K.*')

    if [ "$current_version" == "$pkgver" ]; then
        echo "✅ VMware Workstation $pkgver is already installed."
        return
    fi

    # Fetch the bundle
    echo "🔄 New version available. Downloading from TechPowerUp NL server..."
    rm -rf "$BUNDLE_PATH"
    mkdir -p "$(dirname "$BUNDLE_PATH")"

    # CDN Server Options
    # CDN_SRV="3"   # TechPowerUp US-2
    # CDN_SRV="5"   # TechPowerUp UK-1
    # CDN_SRV="11"  # TechPowerUp US-4
    # CDN_SRV="12"  # TechPowerUp US-5
    # CDN_SRV="15"  # TechPowerUp SG
    # CDN_SRV="16"  # TechPowerUp US-3
    # CDN_SRV="19"  # TechPowerUp US-1
    # CDN_SRV="20"  # TechPowerUp US-7
    # CDN_SRV="21"  # TechPowerUp US-8
    # CDN_SRV="22"  # TechPowerUp UK-2
    # CDN_SRV="24"  # TechPowerUp US-10
    # CDN_SRV="25"  # TechPowerUp DE
    # CDN_SRV="26"  # TechPowerUp US-9
    # CDN_SRV="27"  # TechPowerUp NL

    BUNDLE_URL="https://www.techpowerup.com/download/vmware-workstation-pro/?id=2914&server_id=27"

    wget -q \
      --tries=1 \
      --timeout=5 \
      --dns-timeout=3 \
      --connect-timeout=3 \
      --read-timeout=5 \
      --referer="https://www.techpowerup.com/" \
      -O "$BUNDLE_PATH" "$BUNDLE_URL"

    if [ ! -f "$BUNDLE_PATH" ] || [ "$(stat -c%s "$BUNDLE_PATH")" -eq 0 ]; then
        echo "💥 Shit hit the fan. TechPowerUp NL server is inaccessible. Try again later."
        return
    fi

    # Verify download
    if [ ! -f "$BUNDLE_PATH" ]; then
        echo "❌ Download failed or file not found at $BUNDLE_PATH."
        return
    fi

    # Compute SHA256 checksum
    checksum=$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')
    echo "Downloaded file checksum: $checksum"

    # Check if checksum exists in PKGBUILD
    if echo "$pkgbuild" | grep -q "$checksum"; then
        echo "✅ Checksum verified against PKGBUILD"
        chmod +x "$BUNDLE_PATH"
        sudo "$BUNDLE_PATH"
        vmware-modules.sh -u
        ret=$?
        while [ $ret -eq 1 ]; do
            echo
            read -n 1 -p "⚠️  Fix the issues and press any key or 'q' to quit " key
            echo

            if [[ "$key" == "q" || "$key" == "Q" ]]; then
                exit 1
            fi

            vmware-modules.sh -u
            ret=$?
        done
        vmware-modules.sh
    else
        echo "❌ Checksum mismatch. File may be corrupted or tampered."
        return
    fi
}

update_vmware
# 🧹 Cleanup
rm -rf "$TEMP_DIR"
echo "🎉 VMware is up to date!"

read -p Done