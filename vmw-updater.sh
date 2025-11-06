#!/bin/bash

# Process checking function
check_processes() {
    local processes=("$@")
    while true; do
        local running=false
        declare -A seen_execs=()

        for proc in "${processes[@]}"; do
            # pgrep -f parodys visus procesus, kurie turi net ir pavadinima argumente pvz. adb -s genymotion-device-id shell
            mapfile -t pids < <(pgrep -f "$proc")
            if (( ${#pids[@]} > 0 )); then
                running=true
                for pid in "${pids[@]}"; do
                    exec_name=$(ps -p "$pid" -o comm=)
                    seen_execs["$exec_name"]=1
                done
            fi
        done

        if $running; then
            echo "The following executables are still running:"
            for exec in "${!seen_execs[@]}"; do
                echo " - $exec"
            done
            read -n 1 -s -p "Close them. Press 'n' to quit or any other key to continue..." key
            echo
            [[ $key == 'n' ]] && { echo "Exiting the script."; exit 0; }
        else
            echo "All specified executables are closed."
            break
        fi
        sleep 1
    done
}

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
    echo "🔄 New version available. Save the new bundle as"
    echo "   $BUNDLE_PATH"
    read -p "When done, press any key to continue"

    # Ensure the bundle exists
    while [ ! -f "$BUNDLE_PATH" ]; do
        echo "❌ Bundle not found at"
    read -p "   $BUNDLE_PATH"
    done

    # Compute SHA256 checksum
    checksum=$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')

    echo "File checksum: $checksum"
    echo "🔍 Verifying bundle against checksum..."
    if echo "$pkgbuild" | grep -q "$checksum"; then
        echo "✅ Checksum verified"
        chmod +x "$BUNDLE_PATH"
        check_processes "vmware-vmx"
        sudo pkill -f vmware
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

update_vmware
# 🧹 Cleanup
rm -rf "$TEMP_DIR"

read -p Done