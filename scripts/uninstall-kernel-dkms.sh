#!/bin/bash
# Remove the Galaxy Book 10.6 camera DKMS module (restores stock in-tree modules).
set -euo pipefail
NAME=galaxybook12-camera; VER=1.0
sudo dkms remove -m "$NAME" -v "$VER" --all 2>/dev/null || true
sudo rm -rf "/usr/src/$NAME-$VER"
sudo depmod -a
echo "Removed. Reboot to fall back to the stock in-tree modules."
