#!/bin/bash
# Install the Galaxy Book 10.6 camera kernel modules via DKMS.
set -euo pipefail
NAME=galaxybook12-camera; VER=1.0
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="/usr/src/$NAME-$VER"

echo "== prerequisites =="
sudo dnf install -y dkms "kernel-devel-$(uname -r)" make gcc binutils \
  elfutils-libelf-devel curl patch tar xz

sudo rm -rf "$SRC"; sudo mkdir -p "$SRC"
sudo cp -r "$HERE/kernel/." "$SRC/"
sudo chmod +x "$SRC/dkms-make.sh"

# remove any prior static install.sh copy so DKMS is the sole owner
sudo rm -rf "/lib/modules/$(uname -r)/updates/galaxybook12-camera"

sudo dkms add -m "$NAME" -v "$VER" 2>/dev/null || true
sudo dkms build -m "$NAME" -v "$VER"
sudo dkms install -m "$NAME" -v "$VER"
sudo depmod -a

echo
echo "Installed. REBOOT required (the SONY258A<->INT3472 ACPI dependency is"
echo "built only during device enumeration)."
echo "Verify after reboot:"
echo "  sudo dmesg | grep -E 'Connected .* cameras|DW9806B'"
echo "  cam -l"
