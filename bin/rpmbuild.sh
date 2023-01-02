#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERNAME="el"
DISTRO="RHEL"
ARCH="$(uname -m)"
VERNUM="$(grep -s ^'VERSION=' /etc/os-release 2>/dev/null | awk -F= '{print $2}' | sed 's|"||g' | tr ' ' '\n' | grep '[0-9]' | awk -F '.' '{print $1}' | grep '^' || echo "")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SPEC_DIR="$HOME/rpmbuild"
LOG_DIR="$HOME/Documents/builds"
BUILDIR="$HOME/.local/tmp/BUILDROOT/BUILD"
BUILDROOT="$HOME/.local/tmp/BUILDROOT/BUILDROOT"
SRCDIR="$HOME/Documents/rpmbuild/$DISTRO/$ARCH/$VERNAME$VERNUM"
TARGETDIR="$HOME/Documents/sourceforge/$DISTRO/$ARCH/$VERNAME$VERNUM"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Clean previous build
for dir in "$SRCDIR" "$TARGETDIR" "$BUILDIR" "$BUILDROOT" "$LOG_DIR"; do
    if [ -n "$dir" ]; then
        rm -Rf "${dir:?}"
        mkdir -p "${dir:?}"
    fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create spec list
ls "$SPEC_DIR"/*/*.spec >"$LOG_DIR/specs.txt"
[ -s "$LOG_DIR/specs.txt" ] || { echo "No spec files found" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Clear status
echo >"$LOG_DIR/build.txt"
echo >"$LOG_DIR/status.txt"
echo >"$LOG_DIR/errors.txt"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finally run rpmbuild
for i in $(cat "$LOG_DIR/specs.txt"); do
    [ -f "$(builtin type -P yum-builddep)" ] && yum-builddep -yy -qq --skip-broken "$i"
    rpmbuild -ba "$i" >>"$LOG_DIR/build.txt" 2>>"$LOG_DIR/errors.txt" && echo "$i exit code $?" >>"$LOG_DIR/status.txt"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
find "$HOME/.gnupg" "$HOME/.ssh" -type f -exec chmod 600 {} \;
find "$HOME/.gnupg" "$HOME/.ssh" -type d -exec chmod 700 {} \;
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Sign rpm packages
find "$SRCDIR/" -iname "*.rpm" >"$LOG_DIR/pkgs.txt"
rpmsign --addsign $(cat "$LOG_DIR/pkgs.txt")
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
