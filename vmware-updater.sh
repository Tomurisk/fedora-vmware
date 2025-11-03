#!/bin/bash

# Network check
if ! ping -q -c 1 -W 2 google.com >/dev/null; then
    read -p "💥 No internet connection. Check your network and try again."
    exit 1
fi

# Required commands
for cmd in wget grep; do
    if ! command -v $cmd &> /dev/null; then
        read -p "$cmd is required but not installed. Exiting."
        exit 1
    fi
done

# 🔄 Function to update VMware
update_vmware() {
    echo "==> Updating VMware Workstation..."

    # Paths
    BUNDLE_PATH="$HOME/.vmware/vmware.bundle"
    PKGBUILD_URL="https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=vmware-workstation"

    # Get current installed version using vmware -v
    if command -v vmware &>/dev/null; then
        current_version=$(vmware -v | awk '{print $4}')
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

    buildver=$(echo "$pkgbuild" | grep -Po '^_buildver=\K.*')

    if [ "$current_version" == "$buildver" ]; then
        echo "✅ VMware Workstation Build $buildver is already installed."
        return
    fi

    # Fetch the bundle
    echo "🔄 New version available. Downloading from TechPowerUp..."
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
      CDN_SRV="27"  # TechPowerUp NL

    wget --quiet --output-document="$BUNDLE_PATH" \
         --header="Referer: https://www.techpowerup.com/" \
         --post-data="id=2914&server_id=$CDN_SRV" \
         'https://www.techpowerup.com/download/vmware-workstation-pro/'

    if [ $? -ne 0 ] || [ ! -f "$BUNDLE_PATH" ]; then
        echo "💥 Shit hit the fan. TechPowerUp server is inaccessible. Try again later."
        return
    fi

    # Verify download
    if [ ! -f "$BUNDLE_PATH" ]; then
        echo "❌ Download failed or file not found at $BUNDLE_PATH."
        return
    fi

    # Compute SHA256 checksum
    checksum=$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')

    verify_and_run_bundle() {
        echo "File checksum: $checksum"
        echo "🔍 Verifying bundle against checksum..."
        if echo "$pkgbuild" | grep -q "$checksum"; then
            echo "✅ Checksum verified"
            chmod +x "$BUNDLE_PATH"
            sudo "$BUNDLE_PATH"

            if [ -f /usr/bin/vmware-modules.sh ]; then
                /usr/bin/vmware-modules.sh -u
                ret=$?
                while [ $ret -eq 1 ]; do
                    echo
                    read -n 1 -p "⚠️  Fix the issues and press any key or 'q' to quit " key
                    echo
                    [[ "$key" == "q" || "$key" == "Q" ]] && return 1
                    /usr/bin/vmware-modules.sh -u
                    ret=$?
                done
                /usr/bin/vmware-modules.sh
            else
                echo "⚠️  The script /usr/bin/vmware-modules.sh does not exist. Configure the hook."
                return 1
            fi
        else
            rm -rf "$BUNDLE_PATH"
            echo "❌ Checksum mismatch. File may be corrupted or tampered."
            return 1
        fi
    }

    # Main logic
    if echo "$pkgbuild" | grep -q "$checksum"; then
        verify_and_run_bundle
    else
        rm -rf "$BUNDLE_PATH"
        echo "❌ Checksum mismatch. File may be corrupted or tampered."
        echo "🤔 It could also be that TechPowerUp hasn't uploaded the latest one."
        echo "ℹ️  You may also put the bundle yourself within:"
        echo "   $BUNDLE_PATH."
        echo "🤓 It will be verified against checksums."
        read -n 1 -p "🦔 Press any key to quit, or 'm' for manual bundle. Place it before this. " user_choice
        echo

        if [[ "$user_choice" == "m" || "$user_choice" == "M" ]]; then
            while true; do
                if [ -f "$BUNDLE_PATH" ]; then
                    checksum=$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')
                    verify_and_run_bundle
                    break
                else
                    echo "❌ Manual bundle not found at "
                    echo "   $BUNDLE_PATH."
                    read -n 1 -p "📦 Place the bundle and press any key to retry, or 'q' to quit: " retry_key
                    echo
                    [[ "$retry_key" == "q" || "$retry_key" == "Q" ]] && return 1
                fi
            done
        else
            return 1
        fi
    fi
}

update_vmware
# 🧹 Cleanup
rm -rf "$TEMP_DIR"
echo "🎉 VMware is up to date!"

read -p Done