#!/bin/bash
# VMware kernel module installer/uninstaller
# Usage:
#   ./vmware-modules.sh           → build and install modules
#   ./vmware-modules.sh -u       → uninstall modules
#   ./vmware-modules.sh --uninstall → uninstall modules

set -e

# Handle uninstall flag
if [[ "$1" == "-u" || "$1" == "--uninstall" ]]; then
    echo "🔻 Unloading VMware kernel modules..."
    sudo modprobe -r vmmon || echo "vmmon not loaded"
    sudo modprobe -r vmnet || echo "vmnet not loaded"

    echo "🧹 Removing installed .ko files..."
    sudo rm -f /lib/modules/$(uname -r)/extra/vmmon.ko
    sudo rm -f /lib/modules/$(uname -r)/extra/vmnet.ko

    echo "🔄 Updating module dependencies..."
    sudo depmod -a

    echo "✅ Cleanup complete. VMware modules removed and system restored."
    exit 0
fi

echo "📁 Creating temporary workspace..."
TMP_DIR=$(mktemp -d)
echo "🧪 Working in: $TMP_DIR"

echo "📥 Cloning vmware-workstation AUR repo..."
git clone https://aur.archlinux.org/vmware-workstation.git "$TMP_DIR/vmware-workstation"

echo "📦 Preparing module build directory..."
mkdir -p "$TMP_DIR/vmware-modules"
cd "$TMP_DIR/vmware-modules"

echo "📂 Extracting vmmon and vmnet sources..."
tar -xf /usr/lib/vmware/modules/source/vmmon.tar
tar -xf /usr/lib/vmware/modules/source/vmnet.tar

echo "📁 Renaming vmmon directory..."
mv vmmon-only vmmon

echo "🩹 Applying base patch to vmmon..."
patch -p2 --read-only=ignore --directory=vmmon < "$TMP_DIR/vmware-workstation/vmmon.patch"

echo "🔍 Detecting current kernel version..."
kernel_version=$(uname -r | awk -F. '{print $1"_"$2}')
echo "🧠 Kernel version detected: $kernel_version"

patch_dir="$TMP_DIR/vmware-workstation"
target_dir=vmmon

echo "📜 Searching for applicable kernel patches..."
patches=$(ls "$patch_dir"/linux*.patch 2>/dev/null | sed -n 's/.*linux\([0-9]\+_[0-9]\+\)\.patch/\1/p' | sort -t_ -k1,1n -k2,2n)

for patch in $patches; do
    if [[ "$patch" < "$kernel_version" || "$patch" == "$kernel_version" ]]; then
        echo "🩹 Applying patch: linux${patch}.patch"
        patch -p2 --read-only=ignore --directory="$target_dir" < "$patch_dir/linux${patch}.patch"
    fi
done

echo "📁 Renaming patched directories..."
mv vmmon vmmon-only
mv vmnet-only vmnet

echo "🩹 Applying base patch to vmnet..."
patch -p2 --read-only=ignore --directory=vmnet < "$TMP_DIR/vmware-workstation/vmnet.patch"

echo "📁 Renaming patched vmnet directory..."
mv vmnet vmnet-only

echo "🔨 Building vmmon module..."
cd "$TMP_DIR/vmware-modules/vmmon-only"
make -j$(nproc) KERNELRELEASE="$(uname -r)"

echo "🔨 Building vmnet module..."
cd "$TMP_DIR/vmware-modules/vmnet-only"
make -j$(nproc) KERNELRELEASE="$(uname -r)"

echo "📁 Installing compiled modules..."
sudo cp "$TMP_DIR/vmware-modules/vmmon-only/vmmon.ko" "$TMP_DIR/vmware-modules/vmnet-only/vmnet.ko" /lib/modules/$(uname -r)/extra/

echo "🔄 Reloading module dependencies..."
sudo depmod -a

echo "📦 Loading vmmon and vmnet modules..."
sudo modprobe vmmon
sudo modprobe vmnet

echo "🧹 Cleaning up temporary workspace..."
rm -rf "$TMP_DIR"

echo "✅ All done! VMware modules built, installed, and loaded successfully."