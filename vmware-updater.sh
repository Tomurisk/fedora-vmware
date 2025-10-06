#!/bin/bash

# Required commands
for cmd in curl grep; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd is required but not installed. Exiting."
        exit 1
    fi
done

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

    # Fetch PKGBUILD and extract latest version
    pkgbuild=$(curl -sf "$PKGBUILD_URL")
    if [ $? -ne 0 ] || [ -z "$pkgbuild" ]; then
        echo "💥 Shit hit the fan. AUR is inaccessible. Try again later."
        return
    fi

    pkgver=$(echo "$pkgbuild" | grep -Po '^pkgver=\K.*')

    if [ "$current_version" == "$pkgver" ]; then
        echo "✅ VMware Workstation $pkgver is already installed."
        return
    fi

    # Fetch the bundle
    echo "🔄 New version available. Downloading from TechPowerUp NL server..."
    rm -rf "$BUNDLE_PATH"
    mkdir -p "$(dirname "$BUNDLE_PATH")"

    curl -sfL -o "$BUNDLE_PATH" \
     --data-raw "id=2914&server_id=27" \
     --referer https://www.techpowerup.com/ \
     'https://www.techpowerup.com/download/vmware-workstation-pro/'

    if [ $? -ne 0 ] || [ ! -f "$BUNDLE_PATH" ]; then
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