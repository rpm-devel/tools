#!/usr/bin/env sh
# shellcheck shell=sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202301011710-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.com
# @@License          :  WTFPL
# @@ReadME           :  install.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, Jan 01, 2023 17:10 EST
# @@File             :  install.sh
# @@Description      :
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -z "$(builtin type -P git)" ]; then
  echo "Installing git"
  yum install -yy -q git >/dev/null 2>&1 || { echo "This script requires git" && exit 1; }
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Setting up rpm development scripts"
git clone -q "https://github.com/rpm-devel/tools" "/tmp/rpm-dev-tools" || { echo "Failed to clone the repo" && exit 1; }
[ -d "/tmp/rpm-dev-tools/bin" ] && chmod -Rf 755 "/tmp/rpm-dev-tools/bin" || { echo "Failed to clone the repo" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$USER" = "root" ] || [ "$(whoami)" = "root" ]; then
  echo "Setting bin dir to /usr/local/bin"
  U_BIN="/usr/local/bin"
elif [ -d "$HOME/.bin" ]; then
  echo "Setting bin dir to ~/.bin"
  U_BIN="$HOME/.bin"
elif [ -d "$HOME/bin" ]; then
  echo "Setting bin dir to ~/bin"
  U_BIN="$HOME/bin"
else
  echo "Setting bin dir to ~/.local/bin"
  U_BIN="$HOME/.local/bin"
  mkdir -p "$HOME/.local/bin"
fi
for file in "/tmp/rpm-dev-tools/bin"/*; do
  name="$(basename "$file")"
  echo "Updating $U_BIN/$name"
  cp -Rf "$file" "$U_BIN/$name"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Updating $HOME/.rpmmacros"
cp -Rf "/tmp/rpm-dev-tools/.rpmmacros" "$HOME/.rpmmacros"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "$HOME/.rpmmacros" ] && [ -x "$U_BIN/create-container.sh" ]; then
  echo "Setup has completed successfully"
  rm -Rf "/tmp/rpm-dev-tools"
  exit 0
else
  echo "Setup has failed"
  exit 1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# ex: ts=2 sw=2 et filetype=sh
