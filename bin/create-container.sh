#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202301011534-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.com
# @@License          :  WTFPL
# @@ReadME           :  create-container.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, Jan 01, 2023 15:34 EST
# @@File             :  create-container.sh
# @@Description      :
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0" 2>/dev/null)"
VERSION="202301011534-git"
HOME="${USER_HOME:-$HOME}"
USER="${SUDO_USER:-$USER}"
RUN_USER="${SUDO_USER:-$USER}"
SCRIPT_SRC_DIR="${BASH_SOURCE%/*}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Reopen in a terminal
#if [ ! -t 0 ] && { [ "$1" = --term ] || [ $# = 0 ]; }; then { [ "$1" = --term ] && shift 1 || true; } && TERMINAL_APP="TRUE" myterminal -e "$APPNAME $*" && exit || exit 1; fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initial debugging
[ "$1" = "--debug" ] && set -x && export SCRIPT_OPTS="--debug" && export _DEBUG="on"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SET_IMAGE="$1"
SET_VERSION="$2"
C_HOME_DIR="/home/build"
C_NAME="build$SET_VERSION"
C_HOSTNAME="$C_NAME.casjaysdev.com"
C_BUILD_ROOT="$C_HOME_DIR/rpmbuild"
H_BUILD_ROOT="$HOME/Projects/github/rpm-devel"
C_RPM_ROOT="$C_HOME_DIR/Documents/rpmbuild"
H_RPM_ROOT="$HOME/Documents/builds/rpmbuild"
C_PKG_ROOT="$C_HOME_DIR/Documents/sourceforge"
H_PKG_ROOT="$HOME/Documents/builds/sourceforge"
DOCKER_HOME_DIR="$HOME/.local/share/rpmbuild/$SET_IMAGE$SET_VERSION"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__error() {
  echo "${1:-Something went wrong}"
  exit 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute() {
  echo "Executing $*" && sleep 1
  docker exec -it $C_NAME "$@"
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Setting up the container $C_NAME with $SET_IMAGE:$SET_VERSION"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
docker run -d \
  --name $C_NAME \
  --hostname $C_HOSTNAME \
  -e TZ=America/New_York \
  -v "$DOCKER_HOME_DIR:$C_HOME_DIR" \
  -v "$H_BUILD_ROOT:$C_BUILD_ROOT:z" \
  -v "$H_RPM_ROOT:$C_RPM_ROOT:z" \
  -v "$H_PKG_ROOT:$C_PKG_ROOT:z" \
  $SET_IMAGE:$SET_VERSION init &>/dev/null || __error
sleep 10
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute yum install epel-release git curl wget sudo -yy || __error "Failed to install packages"
__docker_execute git clone "https://github.com/casjay-dotfiles/scripts" "/usr/local/share/CasjaysDev/scripts"
__docker_execute /usr/local/share/CasjaysDev/scripts/install.sh /usr/local/share/CasjaysDev/scripts/install.sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute git clone "https://github.com/rpm-devel/tools" "/tmp/tools"
__docker_execute cp -Rf "/tmp/tools/bin/." "$C_HOME_DIR/.local/bin/"
__docker_execute cp -Rf "/tmp/tools/.rpmmacros" "$C_HOME_DIR/$rpmmacros"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute bash -c "$(curl -q -LSsf "https://github.com/pkmgr/centos/raw/main/scripts/development.sh")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
