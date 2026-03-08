#!/bin/bash

# SPDX-License-Identifier: CC0-1.0
# This script is released under the Creative Commons Zero v1.0 Universal license.
# You can copy, modify, distribute, and use it for any purpose without restriction.
# For details, see: https://creativecommons.org/publicdomain/zero/1.0/

# Install git for this script to work.

# This script requires patch, kernel headers and GCC as well.
# sudo dnf install kernel-devel gcc git patch

# Disable "Accelerate 3D graphics" on VMs – Mesa is too new on Fedora to work with VMware

# You ABSOLUTELY SHOULD use QEMU (preferrably) or VirtualBox if you can.
# Don't buy VMware products besides using VMware software for personal use.
# Boycott Broadcom for rampant software enshittification and poor services.

# VMware kernel module installer/uninstaller/hook configurator
# Usage:
#   ./vmware-modules.sh                     → build and install for current kernel
#   ./vmware-modules.sh -u                  → uninstall from current kernel
#   ./vmware-modules.sh <kernel-version>    → build and install for specified kernel
#   ./vmware-modules.sh -u <kernel-version> → uninstall from specified kernel
#   ./vmware-modules.sh -h                  → install script and configure install hook
#   ./vmware-modules.sh -uh                 → configure uninstall hook

set -euo pipefail

# ─────────────────────────────────────────────
# 📦 Hook Setup: -h flag
# ─────────────────────────────────────────────
if [[ "$1" == "-h" ]]; then
    echo "📦 Installing vmware-modules.sh to /usr/bin..."
    sudo cp "$0" /usr/bin/vmware-modules.sh
    sudo chmod +x /usr/bin/vmware-modules.sh

    echo "🔗 Creating kernel-install hook..."
    sudo tee /etc/kernel/install.d/99-vmmodules.install > /dev/null <<'EOF'
#!/bin/bash
COMMAND="$1"
KERNEL_VER="$2"
BOOT_DIR="$3"

echo "$(date) - kernel-install hook triggered: $COMMAND for $KERNEL_VER" >> /var/log/vmware-modules-hook.log

if [[ "$COMMAND" == "add" ]]; then
    /usr/bin/vmware-modules.sh "$KERNEL_VER" >> /var/log/vmware-modules-hook.log 2>&1
fi
EOF

    sudo chmod +x /etc/kernel/install.d/99-vmmodules.install

    echo "✅ kernel-install hook configured. VMware modules will rebuild during kernel installs via dnf."
    exit 0
fi

# ─────────────────────────────────────────────
# 🧹 Hook Removal: -uh flag
# ─────────────────────────────────────────────
if [[ "$1" == "-uh" ]]; then
    echo "🧹 Removing kernel-install hook..."
    sudo rm -f /etc/kernel/install.d/99-vmmodules.install

    echo "🧹 Removing installed script from /usr/bin..."
    sudo rm -f /usr/bin/vmware-modules.sh

    echo "✅ kernel-install hook and script removed successfully."
    exit 0
fi

# ─────────────────────────────────────────────
# 🧩 Argument Parsing
# ─────────────────────────────────────────────
UNINSTALL=false
if [[ "$1" == "-u" ]]; then
    UNINSTALL=true
    shift
fi

TARGET_KERNEL="${1:-$(uname -r)}"
KERNEL_VERSION_SHORT=$(echo "$TARGET_KERNEL" | awk -F. '{print $1"_"$2}')

# ─────────────────────────────────────────────
# 🔻 Uninstall Logic
# ─────────────────────────────────────────────
if $UNINSTALL; then
    echo "🔻 Unloading VMware kernel modules from $TARGET_KERNEL..."
    sudo systemctl stop vmware
    sudo modprobe -r vmmon || echo "vmmon not loaded"
    sudo modprobe -r vmnet || echo "vmnet not loaded"

    if lsmod | grep -q vmmon || lsmod | grep -q vmnet; then
        echo "❌ Modules still loaded. Aborting cleanup."
        sudo systemctl start vmware
        exit 1
    fi

    echo "🧹 Removing installed .ko files..."
    sudo rm -f /lib/modules/$TARGET_KERNEL/extra/vmmon.ko
    sudo rm -f /lib/modules/$TARGET_KERNEL/extra/vmnet.ko

    echo "🔄 Updating module dependencies..."
    sudo depmod -a "$TARGET_KERNEL"

    echo "✅ Cleanup complete. VMware modules removed from $TARGET_KERNEL."
    exit 0
fi

# ─────────────────────────────────────────────
# 🔨 Build & Install Logic
# ─────────────────────────────────────────────
echo "🌐 Checking if the repository is available"
if ! git ls-remote https://aur.archlinux.org/vmware-workstation.git &>/dev/null; then
  echo "❌ Repository is not available. Terminating script."
  exit 1
fi

echo "📁 Creating temporary workspace..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
echo "🧪 Working in: $TMP_DIR"

# Check if the tar files exist
if [[ -f /usr/lib/vmware/modules/source/vmmon.tar && -f /usr/lib/vmware/modules/source/vmnet.tar ]]; then
    echo "📂 Extracting vmmon and vmnet sources..."
    tar -xf /usr/lib/vmware/modules/source/vmmon.tar
    tar -xf /usr/lib/vmware/modules/source/vmnet.tar
else
    echo "⚠️  One or both of the files do not exist."
    echo "🧹 Cleaning up temporary workspace..."
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "📥 Cloning vmware-workstation AUR repo..."
git clone https://aur.archlinux.org/vmware-workstation.git "$TMP_DIR/vmware-workstation"

echo "📁 Renaming vmmon directory..."
mv vmmon-only vmmon

echo "🩹 Applying base patch to vmmon..."
vmmon_patch="$TMP_DIR/vmware-workstation/vmmon.patch"
if [[ -f "$vmmon_patch" ]]; then
    patch -p2 --read-only=ignore --directory=vmmon < "$vmmon_patch"
else
    echo "ℹ️ No vmmon.patch found. Skipping base patch for vmmon."
fi

patch_dir="$TMP_DIR/vmware-workstation"
target_dir=vmmon

echo "📜 Searching for applicable kernel patches..."
patches=$(ls "$patch_dir"/linux*.patch 2>/dev/null | sed -n 's/.*linux\([0-9]\+_[0-9]\+\)\.patch/\1/p' | sort -t_ -k1,1n -k2,2n)

if [[ -n "$patches" ]]; then
    for patch in $patches; do
        if [[ "$patch" < "$KERNEL_VERSION_SHORT" || "$patch" == "$KERNEL_VERSION_SHORT" ]]; then
            patch_file="$patch_dir/linux${patch}.patch"
            if [[ -f "$patch_file" ]]; then
                echo "🩹 Applying patch: linux${patch}.patch"
                patch -p2 --read-only=ignore --directory="$target_dir" < "$patch_file"
            else
                echo "⚠️ Patch file linux${patch}.patch not found. Skipping."
            fi
        fi
    done
else
    echo "ℹ️ No kernel-specific patches found. Skipping patching step."
fi

echo "📁 Renaming patched vmmon directory..."
mv vmmon vmmon-only

echo "📁 Renaming vmnet directory..."
mv vmnet-only vmnet

echo "🩹 Applying base patch to vmnet..."
vmnet_patch="$TMP_DIR/vmware-workstation/vmnet.patch"
if [[ -f "$vmnet_patch" ]]; then
    patch -p2 --read-only=ignore --directory=vmnet < "$vmnet_patch"
else
    echo "ℹ️ No vmnet.patch found. Skipping base patch for vmnet."
fi

echo "📁 Renaming patched vmnet directory..."
mv vmnet vmnet-only

echo "🔨 Building vmmon module for $TARGET_KERNEL..."
cd "$TMP_DIR/vmmon-only"
make -j$(nproc) \
  KERNELRELEASE="$TARGET_KERNEL" \
  VM_UNAME="$TARGET_KERNEL" \
  HEADER_DIR="/lib/modules/$TARGET_KERNEL/build/include"

echo "🔨 Building vmnet module for $TARGET_KERNEL..."
cd "$TMP_DIR/vmnet-only"
make -j$(nproc) \
  KERNELRELEASE="$TARGET_KERNEL" \
  VM_UNAME="$TARGET_KERNEL" \
  HEADER_DIR="/lib/modules/$TARGET_KERNEL/build/include"

echo "📁 Installing compiled modules..."
sudo mkdir -p /lib/modules/$TARGET_KERNEL/extra/
sudo cp "$TMP_DIR/vmmon-only/vmmon.ko" "$TMP_DIR/vmnet-only/vmnet.ko" /lib/modules/$TARGET_KERNEL/extra/

echo "🔄 Reloading module dependencies..."
sudo depmod -a "$TARGET_KERNEL"

if [[ "$TARGET_KERNEL" == "$(uname -r)" ]]; then
    echo "📦 Starting VMware service which will load the modules..."
    sudo systemctl start vmware
else
    echo "ℹ️ Kernel $TARGET_KERNEL is not currently running. Skipping the service."
fi

echo "🧹 Cleaning up temporary workspace..."
rm -rf "$TMP_DIR"

echo "✅ VMware modules built and installed for kernel $TARGET_KERNEL."
