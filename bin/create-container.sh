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
[ "$1" = "--force" ] && FORCE_INST="true" && shift 1
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__error() {
  echo "${1:-Something went wrong}"
  exit 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute() {
  local ARGS="$*"
  echo "Executing: $ARGS" && sleep 1
  docker exec -it $C_NAME "$@"
  if [ $? -eq 0 ]; then
    return 0
  elif [ "$FORCE_INST" = "true" ]; then
    echo "Failed to execute $ARGS"
    return 1
  else
    __error "Failed to execute $ARGS"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SET_IMAGE="$1"
SET_VERSION="${2:-latest}"
C_HOME_DIR="/home/build"
C_NAME="rpm-build$SET_VERSION"
C_HOSTNAME="$C_NAME.casjaysdev.com"
C_BUILD_ROOT="$C_HOME_DIR/rpmbuild"
H_BUILD_ROOT="$HOME/Projects/github/rpm-devel"
C_RPM_ROOT="$C_HOME_DIR/Documents/rpmbuild"
H_RPM_ROOT="$HOME/Documents/builds/rpmbuild"
C_PKG_ROOT="$C_HOME_DIR/Documents/sourceforge"
H_PKG_ROOT="$HOME/Documents/builds/sourceforge"
DOCKER_HOME_DIR="$HOME/.local/share/rpmbuild/$SET_IMAGE$SET_VERSION"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -n "$SET_IMAGE" ] || { echo "Usage: $APPNAME [imageName] [version]" && exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if docker ps -a 2>&1 | grep -q "$C_NAME"; then
  CONTAINER_EXiSTS="true"
else
  CONTAINER_EXiSTS="false"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$CONTAINER_EXiSTS" = "true" ]; then
  echo "A container already exist with the name $C_NAME"
  [ "$FORCE_INST" = "true" ] || exit 1
else
  echo "Setting up the container $C_NAME with image $SET_IMAGE:$SET_VERSION"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$CONTAINER_EXiSTS" != "true" ]; then
  docker run -d \
    --name $C_NAME \
    --hostname $C_HOSTNAME \
    -e TZ=America/New_York \
    -v "$DOCKER_HOME_DIR:$C_HOME_DIR" \
    -v "$H_BUILD_ROOT:$C_BUILD_ROOT:z" \
    -v "$H_RPM_ROOT:$C_RPM_ROOT:z" \
    -v "$H_PKG_ROOT:$C_PKG_ROOT:z" \
    $SET_IMAGE:$SET_VERSION init &>/dev/null || __error "Failed to create container"
  sleep 10
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute yum install epel-release git curl wget sudo -yy -q &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute git clone -q "https://github.com/casjay-dotfiles/scripts" "/usr/local/share/CasjaysDev/scripts" &>/dev/null
__docker_execute /usr/local/share/CasjaysDev/scripts/install.sh &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute bash -c "$(curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")" &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute bash -c "$(curl -q -LSsf "https://github.com/pkmgr/centos/raw/main/scripts/development.sh")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
