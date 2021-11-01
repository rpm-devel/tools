#!/bin/sh

# Clean previous build
rm -Rf /var/tmp/BUILD*
rm -Rf $HOME/Documents/{rpmbuild,sourceforge}
mkdir -p $HOME/Documents/{rpmbuild,sourceforge}

# Create spec list
ls $HOME/rpmbuild/*/*.spec > $HOME/Documents/rpmbuild/build.txt

# Clear status
echo > $HOME/Documents/rpmbuild/status.txt
echo > $HOME/Documents/rpmbuild/errors.txt

#Finally run rpmbuild
for i in $(cat $HOME/Documents/rpmbuild/build.txt); do
    rpmbuild -ba $i && echo "$i exit code $?" >> $HOME/Documents/rpmbuild/status.txt 2>> $HOME/Documents/rpmbuild/errors.txt
done

find "$HOME"/.gnupg "$HOME"/.ssh -type f -exec chmod 600 {} \;
find "$HOME"/.gnupg "$HOME"/.ssh -type d -exec chmod 700 {} \;

#Sign rpm packages
find $HOME/Documents/rpmbuild/ -iname "*.rpm" > $HOME/Documents/rpmbuild/pkgs.txt
rpmsign --addsign $(cat $HOME/Documents/rpmbuild/pkgs.txt)

