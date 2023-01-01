#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Clean previous build
rm -Rf "$HOME/.local/tmp/BUILDROOT/BUILD"
rm -Rf "$HOME/.local/tmp/BUILDROOT/BUILDROOT"
for dir in rpmbuild sourceforge; do
    rm -Rf "$HOME/Documents/$dir/$ARCH/$VERNAME$VERNUM"
    mkdir -p "$HOME/Documents/$dir/$ARCH/$VERNAME$VERNUM"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create spec list
ls "$HOME/rpmbuild"/*/*.spec >"$HOME/Documents/rpmbuild/build.txt"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Clear status
echo >"$HOME/Documents/rpmbuild/status.txt"
echo >"$HOME/Documents/rpmbuild/errors.txt"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finally run rpmbuild
for i in $(cat $HOME/Documents/rpmbuild/build.txt); do
    [ -f "$(builtin type -P yum-builddep)" ] && yum-builddep -yy --skip-broken "$i"
    rpmbuild -ba "$i" && echo "$i exit code $?" >>"$HOME/Documents/rpmbuild/status.txt" 2>>"$HOME/Documents/rpmbuild/errors.txt"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
find "$HOME"/.gnupg "$HOME"/.ssh -type f -exec chmod 600 {} \;
find "$HOME"/.gnupg "$HOME"/.ssh -type d -exec chmod 700 {} \;
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Sign rpm packages
find "$HOME/Documents/rpmbuild/" -iname "*.rpm" >"$HOME/Documents/rpmbuild/pkgs.txt"
rpmsign --addsign $(cat "$HOME/Documents/rpmbuild/pkgs.txt")
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
