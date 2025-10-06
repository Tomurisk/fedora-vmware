# Author's note
### You ABSOLUTELY SHOULD use QEMU (preferrably) or VirtualBox if you can.
### Don't buy VMware products besides using VMware software for personal use.
### Boycott Broadcom for rampant software enshittification and poor services.

A script that allows minimal effort setup of VMware Workstation and its modules on Fedora.

# How to set everything up
Make sure that Secure Boot is disabled on your computer.

First of all, install the following packages:
```
sudo dnf install kernel-devel gcc git patch curl grep
```

Then save `vmware-updater.sh` wherever you want. You should run that updater at least once a week.

Now run `vmware-modules.sh` (from any directory).

If you have not installed VMware Workstation yet, you may only install the mentioned packages above, and run `vmware-updater.sh`: this will install VMware Workstation on your Fedora system, as well as modules for current kernel. Please note, that you will still have to set up the hook manually, as described below.


# (RECOMMENDED) Surviving kernel upgrades
Run `vmware-modules.sh -h` – a hook will be set up, so modules are rebuilt again on each kernel upgrade.
You may remove the hook by running `vmware-modules.sh -uh`.

This repository is not responsible for the patches or guaranteeing their compatibility with kernel upgrades – it falls upon the [AUR package](https://aur.archlinux.org/packages/vmware-workstation) maintainers. This method is set up to work with latest kernels that the AUR package supports, as such custom kernels (may/will) need manual polishing to work with this project.

# Support for unstable kernels
As of today, only stable branch is supported, as this project depends on the AUR package. However, this may or may not change in the future, depending on which direction its development is heading to.

It essentially means that **beta versions of Fedora are not supported**, at least in the manner they are shipped out-of-the-box.

# Creating new VMs
Disable "Accelerate 3D graphics" on VMs – Mesa is too new on Fedora to work with VMware.
