#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605220000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  LICENSE.md
# @@ReadME           :  create-container.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, Feb 20, 2023 13:14 EST
# @@File             :  create-container.sh
# @@Description      :  Pull and manage the rpm-devel build container
# @@Changelog        :  Rewritten to use ghcr.io/rpm-devel/build:latest
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC2317
set -o pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="create-container"
VERSION="202605220000-git"
RUN_USER="${SUDO_USER:-$USER}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initial debugging
[ "$1" = "--debug" ] && set -x && export SCRIPT_OPTS="--debug" && export _DEBUG="on"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Color helpers
__clr_reset="\033[0m"
__clr_red="\033[0;31m"
__clr_green="\033[0;32m"
__clr_yellow="\033[0;33m"
__clr_cyan="\033[0;36m"
__clr_bold="\033[1m"

__msg_info()  { printf "${__clr_cyan}[INFO]${__clr_reset}  %s\n"   "$*"; }
__msg_ok()    { printf "${__clr_green}[OK]${__clr_reset}    %s\n"  "$*"; }
__msg_warn()  { printf "${__clr_yellow}[WARN]${__clr_reset}  %s\n" "$*"; }
__msg_error() { printf "${__clr_red}[ERROR]${__clr_reset} %s\n"    "$*" >&2; }
__msg_step()  { printf "\n${__clr_bold}==> %s${__clr_reset}\n"     "$*"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Config
RPM_BUILD_CONFIG_DIR="$HOME/.config/rpm-devel"
RPM_BUILD_CONFIG_FILE="settings.conf"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Defaults (overridden by settings.conf)
BUILD_IMAGE="${BUILD_IMAGE:-ghcr.io/rpm-devel/build:latest}"
FEDORA_VERSION="${FEDORA_VERSION:-42}"
HOST_RPMBUILD_DIR="${HOST_RPMBUILD_DIR:-$HOME/rpmbuild}"
HOST_BUILDS_DIR="${HOST_BUILDS_DIR:-$HOME/Documents/builds}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-rpmbuild}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__gen_config() {
  mkdir -p "$RPM_BUILD_CONFIG_DIR"
  cat >"$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" <<EOF
# rpm-devel build settings — edit these values

# Build container image
BUILD_IMAGE="ghcr.io/rpm-devel/build:latest"

# Fedora version to use for 'fedora' shortcut
FEDORA_VERSION="42"

# Enable/disable target groups for rpmbuild.sh
ENABLE_VERSION_7="no"
ENABLE_VERSION_8="yes"
ENABLE_VERSION_9="yes"
ENABLE_VERSION_10="yes"
ENABLE_FEDORA="yes"

# Host directories (mounted into the build container)
HOST_RPMBUILD_DIR="\$HOME/rpmbuild"
HOST_BUILDS_DIR="\$HOME/Documents/builds"

# GPG key identifier used for signing
# RPM_GPG_KEY_ID="CasjaysDev RPM Dev <rpm-devel@casjaysdev.pro>"

# Container name prefix (used to track/remove stale containers)
CONTAINER_PREFIX="rpmbuild"
EOF
  __msg_ok "Created: $RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Load config
[ -f "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" ] && \
  . "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" || \
  __gen_config &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__help() {
  cat <<EOF
${__clr_bold}Usage:${__clr_reset} $APPNAME [OPTIONS] COMMAND [args]

${__clr_bold}Commands:${__clr_reset}
  pull / all          Pull (or update) $BUILD_IMAGE
  enter               Start an interactive shell in the build container
  list                List all available mock build targets
  remove [all]        Remove stale build containers (not the image)
  7 [amd64|arm64]     Enter with RPM_TARGET=eol/centos-7-{arch}
  8 [amd64|arm64]     Enter with RPM_TARGET=almalinux-8-{arch}
  9 [amd64|arm64]     Enter with RPM_TARGET=almalinux-9-{arch}
  10 [amd64|arm64]    Enter with RPM_TARGET=almalinux-10-{arch}
  fedora [amd64|arm64] Enter with RPM_TARGET=fedora-${FEDORA_VERSION}-{arch}

${__clr_bold}Options:${__clr_reset}
  --enter             Equivalent to the 'enter' command
  --platform ARCH     Force docker platform (linux/amd64 or linux/arm64)
  --image IMAGE       Override the build image
  --config            (Re)generate the settings file
  --update            Re-install the latest tools
  --debug             Enable bash -x tracing
  --help              Show this help
  --version           Show script version

${__clr_bold}Mounts (always applied):${__clr_reset}
  \$HOST_RPMBUILD_DIR  → /root/rpmbuild
  \$HOST_BUILDS_DIR    → /root/Documents/builds
  ~/.rpmmacros        → /root/.rpmmacros  (ro)
  ~/.gnupg            → /root/.gnupg      (ro)
EOF
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Resolve docker --platform flag from a plain arch name
__arch_to_platform() {
  case "${1:-}" in
    amd64|x86_64)  echo "linux/amd64" ;;
    arm64|aarch64) echo "linux/arm64" ;;
    "")            echo "" ;;
    *)             echo "linux/$1" ;;
  esac
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build a mock config name from version + arch shorthand
# Usage: __mock_target VER ARCH
# VER: 7|8|9|10|fedora|fedora-rawhide   ARCH: amd64|arm64 (default amd64)
__mock_target() {
  local ver="$1"
  local arch
  case "${2:-amd64}" in
    amd64|x86_64)  arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *)             arch="$2" ;;
  esac
  case "$ver" in
    7)              echo "eol/centos-7-${arch}" ;;
    8)              echo "almalinux-8-${arch}" ;;
    9)              echo "almalinux-9-${arch}" ;;
    10)             echo "almalinux-10-${arch}" ;;
    fedora-rawhide) echo "fedora-rawhide-${arch}" ;;
    fedora)         echo "fedora-${FEDORA_VERSION}-${arch}" ;;
    *)              echo "$ver-${arch}" ;;
  esac
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Pull / update the build image
__pull_image() {
  local platform="${1:-}"
  local platform_flag=()
  [ -n "$platform" ] && platform_flag=("--platform" "$platform")

  __msg_step "Pulling ${BUILD_IMAGE}"
  if \docker pull "${platform_flag[@]}" "$BUILD_IMAGE"; then
    __msg_ok "Image up to date: ${BUILD_IMAGE}"
  else
    __msg_error "Failed to pull ${BUILD_IMAGE}"
    return 1
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Start an interactive shell in the build container
__enter_container() {
  local rpm_target="${1:-}"
  local platform="${2:-}"

  local ctr_name="${CONTAINER_PREFIX}-$(\tr -dc 'a-z0-9' </dev/urandom | \head -c8)"
  local platform_flag=()
  [ -n "$platform" ] && platform_flag=("--platform" "$platform")

  local target_flag=()
  [ -n "$rpm_target" ] && target_flag=("-e" "RPM_TARGET=${rpm_target}")

  local macros_flag=()
  [ -f "$HOME/.rpmmacros" ] && macros_flag=("-v" "$HOME/.rpmmacros:/root/.rpmmacros:ro")

  __msg_step "Entering ${BUILD_IMAGE}${rpm_target:+ (target: ${rpm_target})}"
  \docker run --rm -it --privileged \
    --name "$ctr_name" \
    "${platform_flag[@]}" \
    -v "${HOST_RPMBUILD_DIR}:/root/rpmbuild" \
    -v "${HOST_BUILDS_DIR}:/root/Documents/builds" \
    "${macros_flag[@]}" \
    -v "$HOME/.gnupg:/root/.gnupg:ro" \
    "${target_flag[@]}" \
    "$BUILD_IMAGE"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# List available mock targets
__list_targets() {
  cat <<EOF
${__clr_bold}EOL targets (x86_64 only):${__clr_reset}
  eol/centos-7-x86_64
  eol/centos-7-aarch64
  eol/fedora-{36..41}-x86_64
  eol/fedora-{36..41}-aarch64

${__clr_bold}Supported targets:${__clr_reset}
  almalinux-8-x86_64      almalinux-8-aarch64
  almalinux-9-x86_64      almalinux-9-aarch64
  almalinux-10-x86_64     almalinux-10-aarch64
  fedora-${FEDORA_VERSION}-x86_64    fedora-${FEDORA_VERSION}-aarch64
  fedora-rawhide-x86_64   fedora-rawhide-aarch64

${__clr_bold}Build image:${__clr_reset} ${BUILD_IMAGE}
EOF
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Remove stale build containers (not the image itself)
__remove_containers() {
  local stale
  stale=$(\docker ps -a --format '{{.Names}}' 2>/dev/null | \grep -- "^${CONTAINER_PREFIX}" || true)
  if [ -z "$stale" ]; then
    __msg_info "No stale containers found with prefix: ${CONTAINER_PREFIX}"
    return 0
  fi
  while IFS= read -r ctr; do
    if \docker rm -f "$ctr" &>/dev/null; then
      __msg_ok "Removed: $ctr"
    else
      __msg_warn "Could not remove: $ctr"
    fi
  done <<<"$stale"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Argument parsing
FORCE_PLATFORM=""
ENTER_CONTAINER="false"

setopts=$(\getopt -o "" \
  --long "debug,help,version,config,update,enter,image:,platform:" \
  -n "$APPNAME" -- "$@" 2>/dev/null)
eval set -- "${setopts[@]}" 2>/dev/null

while :; do
  case "$1" in
  --debug)
    shift 1; set -xo pipefail
    export SCRIPT_OPTS="--debug" _DEBUG="on"
    ;;
  --help)
    shift 1; __help; exit 0
    ;;
  --version)
    shift 1; printf '%s\n' "$VERSION"; exit 0
    ;;
  --config)
    shift 1; __gen_config; exit 0
    ;;
  --update)
    shift 1
    \bash -c "$(\curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
    exit $?
    ;;
  --enter)
    shift 1; ENTER_CONTAINER="true"
    ;;
  --image)
    BUILD_IMAGE="$2"; shift 2
    ;;
  --platform)
    FORCE_PLATFORM="$(__arch_to_platform "$2")"; shift 2
    ;;
  --)
    shift 1; break
    ;;
  esac
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
\mkdir -p "${HOST_RPMBUILD_DIR}" "${HOST_BUILDS_DIR}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main dispatch
case "${1:-}" in

pull | all | update)
  __pull_image "${FORCE_PLATFORM}"
  ;;

enter | "")
  if [ "$ENTER_CONTAINER" = "true" ] || [ "${1:-}" = "enter" ]; then
    __enter_container "" "${FORCE_PLATFORM}"
  else
    __help
    exit 1
  fi
  ;;

list)
  __list_targets
  ;;

remove)
  shift 1
  __remove_containers
  ;;

7 | 8 | 9 | 10 | fedora | fedora-rawhide)
  ver="$1"; shift 1
  arch="${1:-amd64}"; [ $# -gt 0 ] && shift 1
  target="$(__mock_target "$ver" "$arch")"
  __enter_container "$target" "${FORCE_PLATFORM:-$(__arch_to_platform "$arch")}"
  ;;

*)
  # Freeform: pass a raw mock config name to enter with that target preset
  # e.g.  create-container.sh almalinux-9-x86_64
  if [ -n "$1" ]; then
    __enter_container "$1" "${FORCE_PLATFORM}"
  else
    __help
    exit 1
  fi
  ;;

esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit ${exitCode:-$?}
# ex: ts=2 sw=2 et filetype=sh
