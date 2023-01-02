#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERNAME="el"
DISTRO="RHEL"
ARCH="$(uname -m)"
VERNUM="$(grep -s ^'VERSION=' /etc/os-release 2>/dev/null | awk -F= '{print $2}' | sed 's|"||g' | tr ' ' '\n' | grep '[0-9]' | awk -F '.' '{print $1}' | grep '^' || echo "")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SPEC_DIR="$HOME/rpmbuild"
LOG_DIR="$HOME/Documents/logs"
BUILDIR="$HOME/.local/tmp/BUILDROOT/BUILD"
BUILDROOT="$HOME/.local/tmp/BUILDROOT/BUILDROOT"
SRCDIR="$HOME/Documents/rpmbuild/$DISTRO/$ARCH/$VERNAME$VERNUM"
TARGETDIR="$HOME/Documents/sourceforge/$DISTRO/$ARCH/$VERNAME$VERNUM"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Clean previous build
rm -Rf "${SRCDIR:?}"/* "${TARGETDIR:?}"/* "${BUILDIR:?}"/* "${BUILDROOT:?}"/* "${LOG_DIR:?}"/*
mkdir -p "$SRCDIR" "$TARGETDIR" "$BUILDIR" "$BUILDROOT" "$LOG_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create spec list
ls "$SPEC_DIR"/*/*.spec >"$LOG_DIR/specs.txt"
[ -s "$LOG_DIR/specs.txt" ] || { echo "No spec files found" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
find "$HOME/.gnupg" "$HOME/.ssh" -type f -exec chmod 600 {} \;
find "$HOME/.gnupg" "$HOME/.ssh" -type d -exec chmod 700 {} \;
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finally run rpmbuild
for i in $(cat "$LOG_DIR/specs.txt"); do
    spec_name="$(basename "${i//.spec/}")"
    mkdir -p "$LOG_DIR/$spec_name"
    if [ -f "$(builtin type -P yum-builddep)" ]; then
        echo "Installing dependencies for $spec_name"
        yum-builddep -yy -q --skip-broken "$i" >"$LOG_DIR/$spec_name/packages.txt"
    fi
    if [ -f "$(builtin type -P rpmbuild)" ]; then
        echo "Building $spec_name package"
        rpmbuild -ba "$i" 2>"$LOG_DIR/$spec_name/errors.txt" >"$LOG_DIR/$spec_name/build.txt"
        statusCode="$?"
        echo "$i exit code $statusCode" >>"$LOG_DIR/$spec_name/status.txt"
        if [ $statusCode -eq 0 ]; then
            echo "Done building $spec_name"
        else
            echo "Failed to build $i"
            echo "See $LOG_DIR/$spec_name/errors.txt for details"
        fi
        printf '\n%s\n' "# - - - - - - - - - - - - - - - - -"
    fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Sign rpm packages
find "$SRCDIR/" -iname "*.rpm" >"$LOG_DIR/pkgs.txt"
rpmsign --addsign $(cat "$LOG_DIR/pkgs.txt")
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
