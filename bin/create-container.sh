#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202302201314-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
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
APPNAME="create-container"
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
  __printf_line "7                  - Build version 7 for PLATFORM"
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
__gen_config() {
  cat <<EOF >"$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE"
CONTAINER_NAME="rpmdev$SET_VERSION-$CONTAINER_ARCH"
# get arch from platform variable
CONTAINER_ARCH="$(echo "$PLATFORM" | awk -F '/' '{print $2}')"
# Set Home Directories
HOST_HOME_DIR="${HOST_HOME_DIR:-$HOME}"
CONTAINER_HOME_DIR="${CONTAINER_HOME_DIR:-/root}"
# Docker rootfs location
DOCKER_HOME_DIR="${DOCKER_HOME_DIR:-$HOME/.local/share/rpmbuild}"
# Directory settings
HOST_BUILD_ROOT="${HOST_BUILD_ROOT:-$HOME/Projects/github/rpm-devel}"
HOST_RPM_ROOT="${HOST_RPM_ROOT:-$HOME/Documents/builds/rpmbuild}"
HOST_PKG_ROOT="${HOST_PKG_ROOT:-$HOME/Documents/builds/sourceforge}"
# Where to store rpm sources
CONTAINER_BUILD_ROOT="${CONTAINER_BUILD_ROOT:-$CONTAINER_HOME_DIR/rpmbuild}"
# Where to save the built files
CONTAINER_RPM_ROOT="${CONTAINER_RPM_ROOT:-$CONTAINER_HOME_DIR/Documents/rpmbuild}"
# Where to copy the files to for public repos
CONTAINER_PKG_ROOT="${CONTAINER_PKG_ROOT:-$CONTAINER_HOME_DIR/Documents/sourceforge}"
# Set the default domain name
CONTAINER_DOMAIN="${CONTAINER_DOMAIN:-build.casjaysdev.pro}"
# Package list
RPM_PACKAGES="$RPM_PACKAGES git curl wget sudo bash pinentry rpm-devel "
RPM_PACKAGES+="rpm-sign rpmrebuild rpm-build bash bash-completion yum-utils "

EOF
  [ -f "RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" ] || return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# User defined functions
__cpu_v2_check() {
  flags=$(cat /proc/cpuinfo | grep flags | head -n 1 | cut -d: -f2)
  supports_v2='awk "/cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/ {found=1} END {exit !found}"'
  supports_v3='awk "/avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/ {found=1} END {exit !found}"'
  supports_v4='awk "/avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/ {found=1} END {exit !found}"'
  echo "$flags" | eval $supports_v2 && echo "CPU supports x86-64-v2" || true
  echo "$flags" | eval $supports_v3 && echo "CPU supports x86-64-v3" || true
  echo "$flags" | eval $supports_v4 && echo "CPU supports x86-64-v4" || true
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
    docker exec -it $CONTAINER_NAME $ARGS &>/dev/null
    exitCode=$?
  else
    docker exec -it $CONTAINER_NAME $ARGS
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
  # Set image version and platform
  SET_IMAGE="$1"
  SET_VERSION="${2:-latest}"
  PLATFORM="${3:-$PLATFORM}"
  # get arch from platform variable
  CONTAINER_ARCH="$(echo "$PLATFORM" | awk -F '/' '{print $2}')"
  # Set the container name
  CONTAINER_NAME="rpmdev$SET_VERSION-$CONTAINER_ARCH"
  # Set Home Directories
  HOST_HOME_DIR="${HOST_HOME_DIR:-$HOME}"
  CONTAINER_HOME_DIR="${CONTAINER_HOME_DIR:-/root}"
  # Docker rootfs location
  DOCKER_HOME_DIR="${DOCKER_HOME_DIR:-$HOME/.local/share/rpmbuild}/$SET_IMAGE$SET_VERSION/$CONTAINER_ARCH"
  # Directory settings
  HOST_RPM_ROOT="${HOST_RPM_ROOT:-$HOME/Documents/builds/rpmbuild}"
  HOST_PKG_ROOT="${HOST_PKG_ROOT:-$HOME/Documents/builds/sourceforge}"
  HOST_BUILD_ROOT="${HOST_BUILD_ROOT:-$HOME/Projects/github/rpm-devel}"
  # Where to store rpm sources
  CONTAINER_BUILD_ROOT="${CONTAINER_BUILD_ROOT:-$CONTAINER_HOME_DIR/rpmbuild}"
  # Where to save the built files
  CONTAINER_RPM_ROOT="${CONTAINER_RPM_ROOT:-$CONTAINER_HOME_DIR/Documents/rpmbuild}"
  # Where to copy the files to for public repos
  CONTAINER_PKG_ROOT="${CONTAINER_PKG_ROOT:-$CONTAINER_HOME_DIR/Documents/sourceforge}"
  # Set the default domain name
  CONTAINER_DOMAIN="${CONTAINER_DOMAIN:-build.casjaysdev.pro}"
  # Set the container hostname
  CONTAINER_HOSTNAME="${CONTAINER_HOSTNAME:-$CONTAINER_NAME.$CONTAINER_DOMAIN}"
  # Package list
  RPM_PACKAGES="$RPM_PACKAGES git curl wget sudo bash pinentry rpm-devel "
  RPM_PACKAGES+="rpm-sign rpmrebuild rpm-build bash bash-completion yum-utils "
  # Set cpu information
  CPU_CHECK="$(__cpu_v2_check)"
  # Create Directories
  [ -d "$HOME/.config/rpm-devel/lists" ] || mkdir -p "$HOME/.config/rpm-devel/lists"
  [ -d "$HOME/.config/rpm-devel/scripts" ] || mkdir -p "$HOME/.config/rpm-devel/scripts"
  # Check if CPU is supported
  if [ "$SET_VERSION" = '9' ] && [ "$PLATFORM" = "linux/amd64" ]; then
    [ -n "$(echo "$CPU_CHECK" | grep 'x86-64-v2')" ] || { echo "CPU does not support x86-64-v2" && exit 1; }
  fi
  # Get development package lists
  echo "Getting the default package lists"
  for f in 7 8 9; do
    ret_file="$HOME/.config/rpm-devel/lists/$f.txt"
    ret_url="https://github.com/rpm-devel/tools/raw/main/packages/$f.txt"
    [ -d "$ret_file" ] && rm -Rf "$ret_file"
    if [ ! -s "$ret_file" ] || [ ! -f "$ret_file" ]; then
      echo "Retrieving $ret_url"
      curl -q -LSsf "$ret_url" -o "$ret_file" 2>/dev/null
    fi
    touch "$HOME/.config/rpm-devel/lists/$f.txt"
  done
  # Check if image is set
  if [ -z "$SET_IMAGE" ]; then
    echo "Usage: $APPNAME [imageName] [version] [platform]"
    exit 1
  fi
  # check if the container is running
  if docker ps -a 2>&1 | grep -q "$CONTAINER_NAME"; then
    CONTAINER_EXISTS="true"
  else
    CONTAINER_EXISTS="false"
  fi
  # Delete container
  if [ "$CONTAINER_EXISTS" = "true" ]; then
    if [ "$FORCE_INST" = "true" ]; then
      echo "Deleting existing container: $CONTAINER_NAME"
      docker rm -f $CONTAINER_NAME
      CONTAINER_EXISTS="false"
    else
      echo "Skipping the container creation section"
    fi
  else
    echo "Setting up the container $CONTAINER_NAME with image $SET_IMAGE:$SET_VERSION for $PLATFORM"
  fi
  # Create container if it does not exist
  if [ "$CONTAINER_EXISTS" != "true" ]; then
    cat <<EOF | tee >"$HOME/.config/rpm-devel/scripts/$CONTAINER_NAME"
docker run -d \
  --name $CONTAINER_NAME \
  --platform $PLATFORM \
  --workdir $CONTAINER_HOME_DIR \
  --hostname $CONTAINER_HOSTNAME \
  --env TZ=America/New_York \
  --volume "$HOST_RPM_ROOT:$CONTAINER_RPM_ROOT:z" \
  --volume "$HOST_PKG_ROOT:$CONTAINER_PKG_ROOT:z" \
  --volume "$HOST_BUILD_ROOT:$CONTAINER_BUILD_ROOT:z" \
  --volume "$DOCKER_HOME_DIR:$CONTAINER_HOME_DIR:z" \
  --volume "$HOME/.config/rpm-devel/lists/$SET_VERSION.txt/:/tmp/pkgs.txt:z" \
  --volume "$HOST_HOME_DIR/.local/dotfiles/personal:$CONTAINER_HOME_DIR/.local/dotfiles/personal:z" \
  $SET_IMAGE:$SET_VERSION
sleep 10
EOF
    if [ -f "$HOME/.config/rpm-devel/scripts/$CONTAINER_NAME" ]; then
      chmod 755 "$HOME/.config/rpm-devel/scripts/$CONTAINER_NAME"
      eval "$HOME/.config/rpm-devel/scripts/$CONTAINER_NAME" 2>"/tmp/$CONTAINER_NAME.log" >/dev/null || __error "Failed to create container"
    else
      echo "Failed to create the intall script"
      return 1
    fi
  fi
  docker ps -a 2>&1 | grep -q "$CONTAINER_NAME" || { echo "Failed to create $CONTAINER_NAME" && return 1; }
  docker ps 2>&1 | grep "$CONTAINER_NAME" | grep -qi ' Up ' || { echo "Failed to start $CONTAINER_NAME" && return 1; }
  if [ ! -f "$RPM_BUILD_CONFIG_DIR/containers/$CONTAINER_NAME" ]; then
    __docker_execute -q cp -Rf "/etc/bashrc" "/root/.bashrc"
    __docker_execute -q pkmgr update -q
    __docker_execute -q pkmgr install -q $RPM_PACKAGES
    __docker_execute -q pkmgr clean all
    __docker_execute curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh" -o "/tmp/rpm-dev-tools.sh"
  fi
  if [ "$ENTER_CONTAINER" = "true" ]; then
    echo "Entering container: $CONTAINER_NAME"
    docker exec -it $CONTAINER_NAME /bin/bash
    return $?
  fi
  touch "$RPM_BUILD_CONFIG_DIR/containers/$CONTAINER_NAME"
  return
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
RPM_BUILD_CONFIG_FILE="$APPNAME-settings.conf"
RPM_BUILD_CONFIG_DIR="$HOME/.config/rpm-devel"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# bring in user config
[ -f "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" ] && . "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Argument/Option settings
SETARGS=("$@")
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SHORTOPTS=""
SHORTOPTS+=""
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LONGOPTS="completions:,config,debug,help,options,raw,version"
LONGOPTS+=",platform,update,enter,image:"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ARRAY="all arm amd 7 8 9 "
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
  --image)
    CONTAINER_IMAGE="$2"
    shift 2
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
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes &>/dev/null || exit 1
  fi
else
  echo "This requires a x86_64 distro"
  exit 1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CONTAINER_IMAGE="${CONTAINER_IMAGE:-casjaysdev/rhel}"
[ -d "$RPM_BUILD_CONFIG_DIR/containers" ] || mkdir -p "$RPM_BUILD_CONFIG_DIR/containers"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main application
case "$1" in
all)
  shift $#
  ENTER_CONTAINER="false"
  __setup_build "$CONTAINER_IMAGE" "7" "linux/arm64"
  __setup_build "$CONTAINER_IMAGE" "7" "linux/amd64"
  __setup_build "$CONTAINER_IMAGE" "8" "linux/arm64"
  __setup_build "$CONTAINER_IMAGE" "8" "linux/amd64"
  __setup_build "$CONTAINER_IMAGE" "9" "linux/arm64"
  __setup_build "$CONTAINER_IMAGE" "9" "linux/amd64"
  ;;

arm)
  shift $#
  ENTER_CONTAINER="false"
  __setup_build "$CONTAINER_IMAGE" "7" "linux/arm64"
  __setup_build "$CONTAINER_IMAGE" "8" "linux/arm64"
  __setup_build "$CONTAINER_IMAGE" "9" "linux/arm64"
  ;;

amd)
  shift $#
  ENTER_CONTAINER="false"
  __setup_build "$CONTAINER_IMAGE" "7" "linux/amd64"
  __setup_build "$CONTAINER_IMAGE" "8" "linux/amd64"
  __setup_build "$CONTAINER_IMAGE" "9" "linux/amd64"
  ;;

7)
  shift 1
  ENTER_CONTAINER="false"
  if [ -n "$1" ]; then
    __setup_build "$CONTAINER_IMAGE" "7" "${1:-$PLATFORM}"
  else
    __setup_build "$CONTAINER_IMAGE" "7" "linux/arm64"
    __setup_build "$CONTAINER_IMAGE" "7" "linux/amd64"
  fi
  exit
  ;;

8)
  shift 1
  ENTER_CONTAINER="false"
  if [ -n "$1" ]; then
    __setup_build "$CONTAINER_IMAGE" "8" "${1:-$PLATFORM}"
  else
    __setup_build "$CONTAINER_IMAGE" "8" "linux/arm64"
    __setup_build "$CONTAINER_IMAGE" "8" "linux/amd64"
  fi
  exit
  ;;

9)
  shift 1
  ENTER_CONTAINER="false"
  if [ -n "$1" ]; then
    __setup_build "$CONTAINER_IMAGE" "9" "${1:-$PLATFORM}"
  else
    __setup_build "$CONTAINER_IMAGE" "9" "linux/arm64"
    __setup_build "$CONTAINER_IMAGE" "9" "linux/amd64"
  fi
  exit
  ;;

*)
  shift 1
  [ $# -eq 0 ] && printf 'Usage:\n%s\n%s\n' "$APPNAME [$ARRAY]" "$APPNAME $CONTAINER_IMAGE 8 linux/amd64" && exit 1
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
