#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
clear
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$1" = "update" ] || [ "$1" = "--update" ]; then
    bash -c "$(curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
    exit $?
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ARCH="$SET_ARCH"
VERNAME="$SET_NAME"
VERNUM="$SET_VERSION"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DISTRO="RHEL"
ARCH="${ARCH:-$(uname -m)}"
VERNAME="${VERNAME:-$(grep -s '%_osver ' "$HOME/.rpmmacros" | awk -F ' ' '{print $2}' | sed 's|%.*||g' | grep '^' || echo "el")}"
VERNUM="${VERSION:-$(grep -s ^'VERSION=' /etc/os-release 2>/dev/null | awk -F= '{print $2}' | sed 's|"||g' | tr ' ' '\n' | grep '[0-9]' | awk -F '.' '{print $1}' | grep '^' || echo "")}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SPEC_DIR="$HOME/rpmbuild"
LOG_DIR="$HOME/Documents/builds/logs/rpmbuild"
BUILD_DIR="$HOME/.local/tmp/BUILD_ROOT/BUILD"
BUILD_ROOT="$HOME/.local/tmp/BUILD_ROOT/BUILD_ROOT"
SRC_DIR="$HOME/Documents/builds/rpmbuild/$DISTRO/$VERNAME$VERNUM/$ARCH"
TARGET_DIR="$HOME/Documents/builds/sourceforge/$DISTRO/$VERNAME$VERNUM/$ARCH"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export QA_RPATHS="${QA_RPATHS:-$((0x0001 | 0x0010))}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Clean previous build
rm -Rf "${SRC_DIR:?}"/* "${TARGET_DIR:?}"/* "${BUILD_DIR:?}"/* "${BUILD_ROOT:?}"/*
mkdir -p "$SRC_DIR" "$TARGET_DIR" "$BUILD_DIR" "$BUILD_ROOT" "$LOG_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create spec list
ls "$SPEC_DIR"/*/*.spec >"$LOG_DIR/specs.txt" && spec_list="$(grep -Ev '#|^$' "$LOG_DIR/specs.txt")" || spec_list=""
[ -n "$spec_list" ] || { echo "Can not find any spec files in $SPEC_DIR" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
find "$HOME/.gnupg" "$HOME/.ssh" -type f -exec chmod 600 {} \;
find "$HOME/.gnupg" "$HOME/.ssh" -type d -exec chmod 700 {} \;
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finally run rpmbuild
for i in $spec_list; do
    spec_name="$(basename "${i//.spec/}")"
    echo "Building $spec_name package on $(date +'%Y-%m-%d at %H:%M')" | tee -a "$LOG_DIR/$spec_name/errors.txt" "$LOG_DIR/$spec_name/build.txt"
    mkdir -p "$LOG_DIR/$spec_name"
    if [ -f "$(builtin type -P yum-builddep)" ]; then
        echo "Installing dependencies for $spec_name"
        yum-builddep -yy -q --skip-broken "$i" >>"$LOG_DIR/$spec_name/packages.txt"
    fi
    if [ -f "$(builtin type -P rpmbuild)" ]; then
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
find "$SRC_DIR/" -iname "*.rpm" >"$LOG_DIR/pkgs.txt"
rpmsign --addsign "$(<"$LOG_DIR/pkgs.txt")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
