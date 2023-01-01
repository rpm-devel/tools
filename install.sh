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
[ -n "$(builtin type -P git)" ] || { echo "This script requires git" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Setting up rpm development scripts"
git clone -q "https://github.com/rpm-devel/tools" "/tmp/rpm-dev-tools" || { echo "Failed to clone the repo" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -d "$HOME/.local/bin" ]; then
  U_BIN="$HOME/.local/bin"
  cp -R "/tmp/rpm-dev-tools/bin/." "$HOME/.local/bin"
elif [ -d "$HOME/bin" ]; then
  U_BIN="$HOME/bin"
  cp -R "/tmp/rpm-dev-tools/bin/." "$HOME/bin"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "/tmp/rpm-dev-tools" ] && cp -Rf "/tmp/rpm-dev-tools/.rpmmacros" "$HOME/.rpmmacros"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "$HOME/.rpmmacros" ] && [ -f "$U_BIN/create-container.sh" ]; then
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
