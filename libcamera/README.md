# libcamera — IMX241 front-camera support (Fedora)

Stock libcamera has no sensor helper for the Sony **IMX241**, so the IPU3 IPA
fails with:

```
ipu3: Failed to create camera sensor helper for imx241
Failed to initialise the IPU3 IPA
```

and the front camera drops out of `cam -l`. Patch `0004` adds the IMX241
`CameraSensorHelper` (gain/exposure model) plus its entry in the sensor
properties database. It is written against upstream libcamera 0.7.2 and applies
cleanly (`--fuzz=0`) to Fedora's 0.7.1.

## Rebuild Fedora's libcamera with the patch
```bash
# build tooling + all libcamera build deps
sudo dnf install -y rpm-build rpmdevtools
sudo dnf builddep -y libcamera
rpmdev-setuptree

# fetch + unpack the source RPM
dnf download --source libcamera || sudo dnf download --source libcamera --enablerepo='*-source'
rpm -Uvh ~/libcamera-*.src.rpm
cp 0004-libipa-add-imx241-sensor-helper.patch ~/rpmbuild/SOURCES/

# register the patch (%autosetup -p1 applies it), bump release, add changelog
SPEC=~/rpmbuild/SPECS/libcamera.spec
grep -q '^Patch02:' "$SPEC" || \
  sed -i '/^Patch01:/a Patch02: 0004-libipa-add-imx241-sensor-helper.patch' "$SPEC"
sed -i 's/^Release: \([0-9]\+\)%{?dist}$/Release: \1%{?dist}.gb12cam/' "$SPEC"
CL=$(LC_ALL=C date +'%a %b %d %Y')
grep -q 'IMX241 libipa sensor helper' "$SPEC" || \
  sed -i "/^%changelog$/a * $CL You <you@example.com> - add IMX241 libipa sensor helper (patch 0004)\n" "$SPEC"

# verify the patch applies, then build (skip the test suite)
rpmbuild -bp "$SPEC"
rpmbuild -bb --nocheck "$SPEC"

# install rebuilt copies of exactly the subpackages already installed
mapfile -t pkgs < <(rpm -qa --qf '%{NAME}\n' \
  | grep -E '^(libcamera|python3-libcamera)$|^libcamera-(ipa|tools|gstreamer|v4l2|qcam|devel)$' | sort)
rpms=(); for p in "${pkgs[@]}"; do
  f=$(ls ~/rpmbuild/RPMS/x86_64/${p}-*.gb12cam.*.rpm 2>/dev/null) && rpms+=("$f")
done
sudo dnf install -y "${rpms[@]}"

# pin so a dnf update can't revert the patch
sudo dnf install -y dnf5-plugins
sudo dnf versionlock add libcamera libcamera-ipa libcamera-tools
```

Then `cam -l` should list both cameras.

## When a newer libcamera is released
The versionlock holds you at the patched build. To move forward:
```bash
sudo dnf versionlock delete 'libcamera*'
sudo dnf update 'libcamera*'          # get the new base
# then repeat the rebuild above against the new SRPM, and re-lock
```
