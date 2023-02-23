#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202302201314-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.com
# @@License          :  WTFPL
# @@ReadME           :  rpm-build --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, Feb 20, 2023 13:14 EST
# @@File             :  rpm-build
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
VERSION="202302221946-git"
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
# Disables colorization
[ "$1" = "--raw" ] && export SHOW_RAW="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# pipes fail
set -o pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Send all output to /dev/null
__devnull() {
  tee &>/dev/null && exitCode=0 || exitCode=1
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# Send errors to /dev/null
__devnull2() {
  [ -n "$1" ] && local cmd="$1" && shift 1 || return 1
  eval $cmd "$*" 2>/dev/null && exitCode=0 || exitCode=1
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
# See if the executable exists
__cmd_exists() {
  exitCode=0
  [ -n "$1" ] && local exitCode="" || return 0
  for cmd in "$@"; do
    builtin command -v "$cmd" &>/dev/null && exitCode+=$(($exitCode + 0)) || exitCode+=$(($exitCode + 1))
  done
  [ $exitCode -eq 0 ] || exitCode=3
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for a valid internet connection
__am_i_online() {
  local exitCode=0
  curl -q -LSsfI --max-time 1 --retry 0 "${1:-http://1.1.1.1}" 2>&1 | grep -qi 'server:.*cloudflare' || exitCode=4
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# colorization
if [ "$SHOW_RAW" = "true" ]; then
  __printf_color() { printf '%b' "$1\n" | tr -d '\t' | sed '/^%b$/d;s,\x1B\[ 0-9;]*[a-zA-Z],,g'; }
else
  __printf_color() { printf "%b" "$(tput setaf "${2:-7}" 2>/dev/null)" "$1\n" "$(tput sgr0 2>/dev/null)"; }
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# output version
__version() {
  __printf_color "$VERSION" "6"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Help function - Align to 50
__help() {
  __printf_head "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  __printf_opts "rpm-build:  - $VERSION"
  __printf_head "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  __printf_line "Usage: rpm-build [options] [commands] [linux/amd64,linux/arm64]"
  __printf_line "all                - Build all versions for ARM64 and AMD64"
  __printf_line "arm                - Build all versions for ARM64"
  __printf_line "amd                - Build all versions for AMD64"
  __printf_line "8                  - Build version 8 for PLATFORM"
  __printf_line "9                  - Build version 9 for PLATFORM"
  __printf_head "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  __printf_opts "Other Options"
  __printf_head "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  __printf_line "--help             - Shows this message"
  __printf_line "--config           - Generate user config file"
  __printf_line "--version          - Show script version"
  __printf_line "--options          - Shows all available options"
  __printf_line "--debug            - Enables script debugging"
  __printf_line "--raw              - Removes all formatting on output"
  __printf_head "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# User defined functions
__cpu_v2_check() {
  flags=$(cat /proc/cpuinfo | grep flags | head -n 1 | cut -d: -f2)
  supports_v2='awk "/cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/ {found=1} END {exit !found}"'
  supports_v3='awk "/avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/ {found=1} END {exit !found}"'
  supports_v4='awk "/avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/ {found=1} END {exit !found}"'
  echo "$flags" | eval $supports_v2 && echo "CPU supports x86-64-v2"
  echo "$flags" | eval $supports_v3 && echo "CPU supports x86-64-v3"
  echo "$flags" | eval $supports_v4 && echo "CPU supports x86-64-v4"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__error() {
  echo "${1:-Something went wrong}"
  exit 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__qemu_static_image() {
  docker images 2>&1 | grep -q 'multiarch/qemu-user-static' && return 1 || return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__docker_execute() {
  [ "$1" = "-q" ] && SILENT="true" && shift 1
  local ARGS="$*"
  echo "Executing: $ARGS" && sleep 1
  if [ "$SILENT" = "true" ]; then
    docker exec -it $C_NAME $ARGS &>/dev/null
    exitCode=$?
  else
    docker exec -it $C_NAME $ARGS
    exitCode=$?
  fi
  if [ $exitCode -eq 0 ]; then
    return 0
  elif [ "$FORCE_INST" = "true" ]; then
    echo "Failed to execute $ARGS"
    return 1
  else
    __error "Failed to execute $ARGS"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__setup_build() {
  SET_IMAGE="$1"
  SET_VERSION="${2:-latest}"
  PLATFORM="${3:-$PLATFORM}"
  C_ARCH="$(echo "$PLATFORM" | awk -F '/' '{print $2}')"
  C_HOME_DIR="/root"
  H_HOME_DIR="$HOME"
  C_NAME="rpmdev$SET_VERSION-$C_ARCH"
  C_HOSTNAME="$C_NAME.casjaysdev.com"
  C_BUILD_ROOT="$C_HOME_DIR/rpmbuild"
  H_BUILD_ROOT="$HOME/Projects/github/rpm-devel"
  C_RPM_ROOT="$C_HOME_DIR/Documents/rpmbuild"
  H_RPM_ROOT="$HOME/Documents/builds/rpmbuild"
  C_PKG_ROOT="$C_HOME_DIR/Documents/sourceforge"
  H_PKG_ROOT="$HOME/Documents/builds/sourceforge"
  DOCKER_HOME_DIR="$HOME/.local/share/rpmbuild/$C_ARCH/$SET_IMAGE$SET_VERSION"
  RPM_PACKAGES="$RPM_PACKAGES git curl wget sudo bash pinentry rpm-devel "
  RPM_PACKAGES+="rpm-sign rpmrebuild rpm-build bash bash-completion "
  CPU_CHECK="$(__cpu_v2_check | grep -q 'x86-64-v2' && echo 'x86-64-v2' || echo '')"
  if [ "$SET_VERSION" = '9' ] && [ "$PLATFORM" = "linux/amd64" ]; then
    [ -z "$CPU_CHECK" ] && echo "CPU does not support x86-64-v2" && exit 1
  fi
  if [ -z "$SET_IMAGE" ]; then
    echo "Usage: $APPNAME [imageName] [version] [platform]"
    exit 1
  fi
  if docker ps -a 2>&1 | grep -q "$C_NAME"; then
    CONTAINER_EXISTS="true"
  else
    CONTAINER_EXISTS="false"
  fi
  if [ "$CONTAINER_EXISTS" = "true" ]; then
    if [ "$FORCE_INST" = "true" ]; then
      echo "Deleting existing container: $C_NAME"
      docker rm -f $C_NAME
      CONTAINER_EXISTS="false"
    else
      echo "Skipping the container creation section"
    fi
  else
    echo "Setting up the container $C_NAME with image $SET_IMAGE and version $SET_VERSION for $PLATFORM"
  fi
  if [ "$CONTAINER_EXISTS" != "true" ]; then
    docker run -d \
      --name $C_NAME \
      --platform $PLATFORM \
      --workdir $C_HOME_DIR \
      --hostname $C_HOSTNAME \
      --env TZ=America/New_York \
      --volume "$H_RPM_ROOT:$C_RPM_ROOT:z" \
      --volume "$H_PKG_ROOT:$C_PKG_ROOT:z" \
      --volume "$H_BUILD_ROOT:$C_BUILD_ROOT:z" \
      --volume "$DOCKER_HOME_DIR:$C_HOME_DIR:z" \
      --volume "$H_HOME_DIR/.local/dotfiles/personal:$C_HOME_DIR/.local/dotfiles/personal:z" \
      $SET_IMAGE:$SET_VERSION /usr/sbin/init 2>"/tmp/$C_NAME.log" >/dev/null || __error "Failed to create container"
    sleep 10
  fi
  __docker_execute -q cp -Rf "/etc/bashrc" "/root/.bashrc"
  __docker_execute -q yum install --skip-broken -yy -q epel-release
  __docker_execute -q yum install --skip-broken -yy -q $RPM_PACKAGES
  __docker_execute -q yum clean all
  __docker_execute curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh" -o "/tmp/rpm-dev-tools.sh"
  __docker_execute curl -q -LSsf "https://github.com/pkmgr/centos/raw/main/scripts/development.sh" -o "/tmp/development.sh"
  __docker_execute chmod 755 "/tmp/development.sh" "/tmp/rpm-dev-tools.sh"
  if [ "$ENTER_CONTAINER" = "true" ]; then
    echo "Entering container: $C_NAME"
    docker exec -it $C_NAME /bin/bash
    exit $?
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# User defined variables/import external variables

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for needed applications
#type -P sh &>/dev/null || exit 3       # exit 3 if not found
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set variables

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set additional variables
RPM_BUILD_CONFIG_FILE="settings.conf"
RPM_BUILD_CONFIG_DIR="$HOME/.config/$APPNAME"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# bring in user config
[ -f "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" ] &&
  . "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Argument/Option settings
SETARGS=("$@")
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SHORTOPTS=""
SHORTOPTS+=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LONGOPTS="completions:,config,debug,help,options,raw,version"
LONGOPTS+=",platform,update,enter"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ARRAY="all arm amd 8 9 "
ARRAY+=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LIST=""
LIST+=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup application options
setopts=$(getopt -o "$SHORTOPTS" --long "$LONGOPTS" -n "$APPNAME" -- "$@" 2>/dev/null)
eval set -- "${setopts[@]}" 2>/dev/null
while :; do
  case "$1" in
  --raw)
    shift 1
    export SHOW_RAW="true"
    __printf_column() { tee | grep '^'; }
    __printf_color() { printf '%b\n' "$1" | tr -d '\t' | sed '/^%b$/d;s,\x1B\[ 0-9;]*[a-zA-Z],,g'; }
    ;;
  --debug)
    shift 1
    set -xo pipefail
    export SCRIPT_OPTS="--debug"
    export _DEBUG="on"
    __devnull() { tee || return 1; }
    __devnull2() { eval "$@" |& tee || return 1; }
    ;;
  --completions)
    if [ "$2" = "long" ]; then
      printf '%s\n' "--$LONGOPTS" | sed 's|"||g;s|:||g;s|,|,--|g' | tr ',' '\n'
    elif [ "$2" = "short" ]; then
      printf '%s\n' "-$SHORTOPTS" | sed 's|"||g;s|:||g;s|,|,-|g' | tr ',' '\n'
    elif [ "$2" = "array" ]; then
      printf '%s\n' "$ARRAY" | sed 's|"||g;s|:||g' | tr ',' '\n'
    elif [ "$2" = "list" ]; then
      printf '%s\n' "$LIST" | sed 's|"||g;s|:||g' | tr ',' '\n'
    else
      exit 1
    fi
    shift 2
    exit $?
    ;;
  --options)
    shift 1
    __printf_color "Current options for ${PROG:-$APPNAME}" '4'
    [ -z "$SHORTOPTS" ] || __list_options "Short Options" "-${SHORTOPTS}" ',' '-' 4
    [ -z "$LONGOPTS" ] || __list_options "Long Options" "--${LONGOPTS}" ',' '--' 4
    [ -z "$ARRAY" ] || __list_options "Base Options" "${ARRAY}" ',' '' 4
    exit $?
    ;;
  --version)
    shift 1
    __version
    exit $?
    ;;
  --help)
    shift 1
    __help
    exit $?
    ;;
  --config)
    shift 1
    __gen_config
    exit $?
    ;;
  --platform)
    PLATFORM="$2"
    shift 2
    ;;
  --update)
    shift 1
    bash -c "$(curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
    exit $?
    ;;
  --enter)
    shift 1
    ENTER_CONTAINER="true"
    ;;
  --)
    shift 1
    break
    ;;
  esac
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$(uname -m)" = "x86_64" ]; then
  if __qemu_static_image; then
    echo "Enabling multiarch support"
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &>/dev/null || exit 1
  fi
else
  echo "This requires a x86_64 distro"
  exit 1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main application
case "$1" in
all)
  shift $#
  __setup_build "rockylinux/rockylinux" "8" "linux/arm64"
  __setup_build "rockylinux/rockylinux" "8" "linux/amd64"
  __setup_build "rockylinux/rockylinux" "9" "linux/arm64"
  __setup_build "rockylinux/rockylinux" "9" "linux/amd64"
  ;;

arm)
  shift $#
  __setup_build "rockylinux/rockylinux" "8" "linux/arm64"
  __setup_build "rockylinux/rockylinux" "9" "linux/arm64"
  ;;

amd)
  shift $#
  __setup_build "rockylinux/rockylinux" "8" "linux/amd64"
  __setup_build "rockylinux/rockylinux" "9" "linux/amd64"
  ;;

8)
  shift 1
  __setup_build "rockylinux/rockylinux" "8" "${1:-$PLATFORM}"
  ;;

9)
  shift 1
  __setup_build "rockylinux/rockylinux" "9" "${1:-$PLATFORM}"
  ;;

*)
  shift 1
  [ $# -eq 0 ] && printf 'Usage:\n%s\n%s\n' "$APPNAME [$ARRAY]" "$APPNAME rockylinux/rockylinux 8 linux/amd64" && exit 1
  __setup_build "$1" "$2" "${3:-$PLATFORM}"
  ;;

esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# lets exit with code
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# ex: ts=2 sw=2 et filetype=sh
