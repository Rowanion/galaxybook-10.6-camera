#!/bin/bash
# Build the Galaxy Book 10.6 camera modules for a given kernel.
# Invoked by DKMS as: bash dkms-make.sh ${kernelver}
#
# Replicates upstream build-module.sh: fetches the matching mainline kernel
# source, extracts the stock imx258 / ipu-bridge / int3472 drivers, applies the
# five patches, and builds five modules against the target kernel's headers.
set -euo pipefail
KVER="${1:?kernelver required}"
KSHORT="${KVER%%-*}"
MAJOR="${KSHORT%%.*}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HEADERS="/lib/modules/$KVER/build"
JOBS="${JOBS:-$(nproc)}"
CACHE="/var/cache/galaxybook12-camera"
ARCHIVE="$CACHE/linux-$KSHORT.tar.xz"
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-$KSHORT.tar.xz"

[ -d "$HEADERS" ] || { echo "ERROR: no kernel headers at $HEADERS" >&2; exit 1; }
mkdir -p "$CACHE"
[ -f "$ARCHIVE" ] || { echo "Fetching linux-$KSHORT source..."; \
  curl --fail --location --retry 3 -o "$ARCHIVE" "$URL"; }

SRC="$CACHE/linux-$KSHORT"
if [ ! -f "$SRC/drivers/media/i2c/imx258.c" ]; then
  mkdir -p "$SRC"
  tar -xJf "$ARCHIVE" -C "$CACHE" \
    "linux-$KSHORT/drivers/media/i2c/imx258.c" \
    "linux-$KSHORT/drivers/media/pci/intel/ipu-bridge.c" \
    "linux-$KSHORT/drivers/platform/x86/intel/int3472/discrete.c" \
    "linux-$KSHORT/drivers/platform/x86/intel/int3472/discrete_quirks.c" \
    "linux-$KSHORT/drivers/platform/x86/intel/int3472/clk_and_regulator.c" \
    "linux-$KSHORT/drivers/platform/x86/intel/int3472/led.c"
fi

OUT="$HERE/out"; rm -rf "$OUT"
M="$OUT/drivers/media/i2c"; B="$OUT/drivers/media/pci/intel"
I="$OUT/drivers/platform/x86/intel/int3472"
mkdir -p "$M" "$B" "$I"
cp "$SRC/drivers/media/i2c/imx258.c" "$M/imx258.c"
cp "$HERE/dw9806b.c" "$M/dw9806b.c"
cp "$HERE/imx241.c" "$HERE/imx241-regs.h" "$M/"
cp "$SRC/drivers/media/pci/intel/ipu-bridge.c" "$B/ipu-bridge.c"
cp "$SRC"/drivers/platform/x86/intel/int3472/{discrete,discrete_quirks,clk_and_regulator,led}.c "$I/"

for p in "$HERE"/patches/000*.patch; do
  patch -d "$OUT" -p1 --no-backup-if-mismatch < "$p"
done

printf '%s\n' 'obj-m += imx258.o' 'obj-m += imx241.o' 'obj-m += dw9806b.o' > "$M/Makefile"
printf '%s\n' 'obj-m += ipu-bridge.o' > "$B/Makefile"
printf '%s\n' 'obj-m += intel_skl_int3472_discrete.o' \
  'intel_skl_int3472_discrete-y := discrete.o discrete_quirks.o clk_and_regulator.o led.o' > "$I/Makefile"

make -C "$HEADERS" M="$M" modules -j"$JOBS" CONFIG_DEBUG_INFO_BTF_MODULES=
make -C "$HEADERS" M="$B" modules -j"$JOBS" CONFIG_DEBUG_INFO_BTF_MODULES=
make -C "$HEADERS" M="$I" modules -j"$JOBS" CONFIG_DEBUG_INFO_BTF_MODULES=
echo "Built 5 camera modules for $KVER"
