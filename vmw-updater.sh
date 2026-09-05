#!/bin/bash

# Harden wget by default
alias wget='wget --https-only --secure-protocol=TLSv1_2'

# Process checking function
check_processes() {
    local processes=("$@")
    while true; do
        declare -A seen_execs=()

        for proc in "${processes[@]}"; do
            # -x ensures exact match of the executable name (ignores arguments)
            # -l outputs both the PID and the process name
            while read -r pid name; do
                if [[ -n "$name" ]]; then
                    seen_execs["$name"]=1
                fi
            done < <(pgrep -l -x "$proc")
        done

        # If the associative array is not empty, some processes are still running
        if (( ${#seen_execs[@]} > 0 )); then
            echo "The following executables are still running:"
            for exec in "${!seen_execs[@]}"; do
                echo " - $exec"
            done
            read -n 1 -s -p "Close them. Press 'n' to quit or any other key to continue..." key
            echo
            [[ ${key,,} == 'n' ]] && { echo "Exiting the script."; exit 0; }
        else
            echo "All specified executables are closed."
            break
        fi
        sleep 1
    done
}

# Network check
if ! ping -q -c 1 -W 2 google.com >/dev/null; then
    read -n 1 -s -p "💥 No internet connection. Check your network and try again."
    exit 1
fi

# Required commands
for cmd in wget grep; do
    if ! command -v $cmd &> /dev/null; then
        read -n 1 -s -p "$cmd is required but not installed. Exiting."
        exit 1
    fi
done

# 🔄 Function to update VMware
update_vmware() {
    echo "==> Updating VMware Workstation..."

    # Paths
    BUNDLE_PATH="$HOME/.vmware/vmware.bundle"
    PKGBUILD_URL="https://raw.githubusercontent.com/archlinux/aur/refs/heads/vmware-workstation/PKGBUILD"

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
      echo "💥 GitHub PKGBUILD not available."
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
        echo "   $BUNDLE_PATH"
        echo "🤨 False call? Press any key or 'n' to quit"
        read -n 1 -s key
        if [[ "$key" == "n" || "$key" == "N" ]]; then
            return 1
        fi
    done

    # Compute SHA256 checksum
    checksum=$(sha256sum "$BUNDLE_PATH" | awk '{print $1}')

    echo "File checksum: $checksum"
    echo "🔍 Verifying bundle against checksum..."
    if echo "$pkgbuild" | grep -q "$checksum"; then
        echo "✅ Checksum verified"
        chmod +x "$BUNDLE_PATH"
        check_processes "vmware-vmx"
        sudo pkill vmware
        sudo "$BUNDLE_PATH"

        if [ -f /usr/bin/vmware-modules.sh ]; then
            /usr/bin/vmware-modules.sh -u
            ret=$?
            while [ $ret -eq 1 ]; do
                echo
                read -n 1 -p "⚠️  Fix the issues and press any key or 'n' to quit " key
                echo
                [[ "$key" == "n" || "$key" == "N" ]] && return 1
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

read -p Done