#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607181900-git
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
VERSION="202607181900-git"
RUN_USER="${SUDO_USER:-$USER}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initial debugging
[ "$1" = "--debug" ] && set -x && export SCRIPT_OPTS="--debug" && export _DEBUG="on"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Color helpers
CREATE_CONTAINER_USE_COLOR="${CREATE_CONTAINER_USE_COLOR:-true}"
if [ -n "${NO_COLOR:-}" ]; then
  CREATE_CONTAINER_USE_COLOR="false"
fi

CREATE_CONTAINER_CLR_RESET=""
CREATE_CONTAINER_CLR_RED=""
CREATE_CONTAINER_CLR_GREEN=""
CREATE_CONTAINER_CLR_YELLOW=""
CREATE_CONTAINER_CLR_CYAN=""
CREATE_CONTAINER_CLR_BOLD=""

if [ "$CREATE_CONTAINER_USE_COLOR" = "true" ]; then
  CREATE_CONTAINER_CLR_RESET=$'\033[0m'
  CREATE_CONTAINER_CLR_RED=$'\033[0;31m'
  CREATE_CONTAINER_CLR_GREEN=$'\033[0;32m'
  CREATE_CONTAINER_CLR_YELLOW=$'\033[0;33m'
  CREATE_CONTAINER_CLR_CYAN=$'\033[0;36m'
  CREATE_CONTAINER_CLR_BOLD=$'\033[1m'
fi

__msg_info()  { printf "${CREATE_CONTAINER_CLR_CYAN}[INFO]${CREATE_CONTAINER_CLR_RESET}  %s\n"   "$*"; }
__msg_ok()    { printf "${CREATE_CONTAINER_CLR_GREEN}[OK]${CREATE_CONTAINER_CLR_RESET}    %s\n"  "$*"; }
__msg_warn()  { printf "${CREATE_CONTAINER_CLR_YELLOW}[WARN]${CREATE_CONTAINER_CLR_RESET}  %s\n" "$*"; }
__msg_error() { printf "${CREATE_CONTAINER_CLR_RED}[ERROR]${CREATE_CONTAINER_CLR_RESET} %s\n"    "$*" >&2; }
__msg_step()  { printf "\n${CREATE_CONTAINER_CLR_BOLD}==> %s${CREATE_CONTAINER_CLR_RESET}\n"     "$*"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Config
CREATE_CONTAINER_CONFIG_DIR="$HOME/.config/rpm-devel"
CREATE_CONTAINER_CONFIG_FILE="settings.conf"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Defaults (overridden by settings.conf)
CREATE_CONTAINER_IMAGE="${CREATE_CONTAINER_IMAGE:-ghcr.io/rpm-devel/build:latest}"
CREATE_CONTAINER_FEDORA_VERSION="${CREATE_CONTAINER_FEDORA_VERSION:-42}"
CREATE_CONTAINER_HOST_RPMBUILD_DIR="${CREATE_CONTAINER_HOST_RPMBUILD_DIR:-$HOME/rpmbuild}"
CREATE_CONTAINER_HOST_BUILDS_DIR="${CREATE_CONTAINER_HOST_BUILDS_DIR:-$HOME/Documents/builds}"
CREATE_CONTAINER_PREFIX="${CREATE_CONTAINER_PREFIX:-rpmbuild}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__gen_config() {
  \mkdir -p "$CREATE_CONTAINER_CONFIG_DIR"
  \cat >"$CREATE_CONTAINER_CONFIG_DIR/$CREATE_CONTAINER_CONFIG_FILE" <<EOF
# rpm-devel build settings — edit these values
# Read by both create-container.sh (CREATE_CONTAINER_*) and rpmbuild.sh
# (RPMBUILD_*); shared settings are duplicated under both prefixes so
# either script picks up your changes.

# Build container image
CREATE_CONTAINER_IMAGE="ghcr.io/rpm-devel/build:latest"
RPMBUILD_IMAGE="ghcr.io/rpm-devel/build:latest"

# Fedora version to use for 'fedora' shortcut
CREATE_CONTAINER_FEDORA_VERSION="42"
RPMBUILD_FEDORA_VERSION="42"

# Enable/disable target groups for rpmbuild.sh
RPMBUILD_ENABLE_VERSION_7="no"
RPMBUILD_ENABLE_VERSION_8="yes"
RPMBUILD_ENABLE_VERSION_9="yes"
RPMBUILD_ENABLE_VERSION_10="yes"
RPMBUILD_ENABLE_FEDORA="yes"

# Host directories (mounted into the build container)
CREATE_CONTAINER_HOST_RPMBUILD_DIR="\$HOME/rpmbuild"
CREATE_CONTAINER_HOST_BUILDS_DIR="\$HOME/Documents/builds"
RPMBUILD_HOST_RPMBUILD_DIR="\$HOME/rpmbuild"
RPMBUILD_HOST_BUILDS_DIR="\$HOME/Documents/builds"

# GPG key identifier used for signing
# RPMBUILD_GPG_KEY_ID="CasjaysDev RPM Dev <rpm-devel@casjaysdev.pro>"

# Container name prefix (used to track/remove stale containers)
CREATE_CONTAINER_PREFIX="rpmbuild"
RPMBUILD_CONTAINER_PREFIX="rpmbuild"
EOF
  __msg_ok "Created: $CREATE_CONTAINER_CONFIG_DIR/$CREATE_CONTAINER_CONFIG_FILE"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Load config
[ -f "$CREATE_CONTAINER_CONFIG_DIR/$CREATE_CONTAINER_CONFIG_FILE" ] && \
  . "$CREATE_CONTAINER_CONFIG_DIR/$CREATE_CONTAINER_CONFIG_FILE" || \
  __gen_config &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__help() {
  cat <<EOF
${CREATE_CONTAINER_CLR_BOLD}Usage:${CREATE_CONTAINER_CLR_RESET} $APPNAME [OPTIONS] COMMAND [args]

${CREATE_CONTAINER_CLR_BOLD}Commands:${CREATE_CONTAINER_CLR_RESET}
  pull / all          Pull (or update) $CREATE_CONTAINER_IMAGE
  enter               Start an interactive shell in the build container
  list                List all available mock build targets
  remove [all]        Remove stale build containers (not the image)
  7 [amd64|arm64]     Enter with RPM_TARGET=eol/centos-7-{arch}
  8 [amd64|arm64]     Enter with RPM_TARGET=almalinux-8-{arch}
  9 [amd64|arm64]     Enter with RPM_TARGET=almalinux-9-{arch}
  10 [amd64|arm64]    Enter with RPM_TARGET=almalinux-10-{arch}
  fedora [amd64|arm64] Enter with RPM_TARGET=fedora-${CREATE_CONTAINER_FEDORA_VERSION}-{arch}

${CREATE_CONTAINER_CLR_BOLD}Options:${CREATE_CONTAINER_CLR_RESET}
  --color             Enable colored output (default unless NO_COLOR is set)
  --enter             Equivalent to the 'enter' command
  --platform ARCH     Force docker platform (linux/amd64 or linux/arm64)
  --image IMAGE       Override the build image
  --config            (Re)generate the settings file
  --update            Re-install the latest tools
  --debug             Enable bash -x tracing
  --help              Show this help
  --version           Show script version

${CREATE_CONTAINER_CLR_BOLD}Mounts (always applied):${CREATE_CONTAINER_CLR_RESET}
  \$CREATE_CONTAINER_HOST_RPMBUILD_DIR  → /root/rpmbuild
  \$CREATE_CONTAINER_HOST_BUILDS_DIR    → /root/Documents/builds
  ~/.rpmmacros        → /root/.rpmmacros  (ro)
  ~/.gnupg            → /root/.gnupg      (ro)

If entries under \$CREATE_CONTAINER_HOST_RPMBUILD_DIR are symlinks into another checkout
(e.g. ~/rpmbuild/{repo} -> ~/Projects/.../rpm-devel/{repo}), their real
parent directories are auto-detected and bind-mounted (read-write, since
spectool writes downloaded sources into the package dir) at the same
absolute path so the symlinks resolve inside the container.
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
    fedora)         echo "fedora-${CREATE_CONTAINER_FEDORA_VERSION}-${arch}" ;;
    *)              echo "$ver-${arch}" ;;
  esac
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Pull / update the build image
__pull_image() {
  local platform="${1:-}"
  local platform_flag=()
  [ -n "$platform" ] && platform_flag=("--platform" "$platform")

  __msg_step "Pulling ${CREATE_CONTAINER_IMAGE}"
  if \docker pull "${platform_flag[@]}" "$CREATE_CONTAINER_IMAGE"; then
    __msg_ok "Image up to date: ${CREATE_CONTAINER_IMAGE}"
  else
    __msg_error "Failed to pull ${CREATE_CONTAINER_IMAGE}"
    return 1
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Resolve extra mounts so top-level symlinks under CREATE_CONTAINER_HOST_RPMBUILD_DIR
# (e.g. ~/rpmbuild/{repo} -> ~/Projects/.../rpm-devel/{repo}) are reachable
# inside the container: bind-mount each real parent dir at the same path.
__extra_symlink_mounts() {
  local link target parent dup p
  local seen_parents=()
  while IFS= read -r -d '' link; do
    target="$(\readlink -f -- "$link" 2>/dev/null)" || continue
    [ -z "$target" ] && continue
    parent="${target%/*}"
    dup=false
    for p in "${seen_parents[@]:-}"; do
      [ "$p" = "$parent" ] && dup=true && break
    done
    if ! $dup; then
      seen_parents+=("$parent")
      printf '%s\n%s\n' "-v" "${parent}:${parent}"
    fi
  done < <(\find "${CREATE_CONTAINER_HOST_RPMBUILD_DIR}" -maxdepth 1 -type l -print0 2>/dev/null)
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Start an interactive shell in the build container
__enter_container() {
  local rpm_target="${1:-}"
  local platform="${2:-}"

  local ctr_name="${CREATE_CONTAINER_PREFIX}-$(\tr -dc 'a-z0-9' </dev/urandom | \head -c8)"
  local platform_flag=()
  [ -n "$platform" ] && platform_flag=("--platform" "$platform")

  local target_flag=()
  [ -n "$rpm_target" ] && target_flag=("-e" "RPM_TARGET=${rpm_target}")

  local macros_flag=()
  [ -f "$HOME/.rpmmacros" ] && macros_flag=("-v" "$HOME/.rpmmacros:/root/.rpmmacros:ro")

  local extra_mounts=()
  mapfile -t extra_mounts < <(__extra_symlink_mounts)

  __msg_step "Entering ${CREATE_CONTAINER_IMAGE}${rpm_target:+ (target: ${rpm_target})}"
  \docker run --rm -it --privileged \
    --name "$ctr_name" \
    "${platform_flag[@]}" \
    -v "${CREATE_CONTAINER_HOST_RPMBUILD_DIR}:/root/rpmbuild" \
    "${extra_mounts[@]}" \
    -v "${CREATE_CONTAINER_HOST_BUILDS_DIR}:/root/Documents/builds" \
    "${macros_flag[@]}" \
    -v "$HOME/.gnupg:/root/.gnupg:ro" \
    "${target_flag[@]}" \
    "$CREATE_CONTAINER_IMAGE"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# List available mock targets
__list_targets() {
  cat <<EOF
${CREATE_CONTAINER_CLR_BOLD}EOL targets (x86_64 only):${CREATE_CONTAINER_CLR_RESET}
  eol/centos-7-x86_64
  eol/centos-7-aarch64
  eol/fedora-{36..41}-x86_64
  eol/fedora-{36..41}-aarch64

${CREATE_CONTAINER_CLR_BOLD}Supported targets:${CREATE_CONTAINER_CLR_RESET}
  almalinux-8-x86_64      almalinux-8-aarch64
  almalinux-9-x86_64      almalinux-9-aarch64
  almalinux-10-x86_64     almalinux-10-aarch64
  fedora-${CREATE_CONTAINER_FEDORA_VERSION}-x86_64    fedora-${CREATE_CONTAINER_FEDORA_VERSION}-aarch64
  fedora-rawhide-x86_64   fedora-rawhide-aarch64

${CREATE_CONTAINER_CLR_BOLD}Build image:${CREATE_CONTAINER_CLR_RESET} ${CREATE_CONTAINER_IMAGE}
EOF
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Remove stale build containers (not the image itself)
__remove_containers() {
  local stale
  stale=$(\docker ps -a --format '{{.Names}}' 2>/dev/null | \grep -- "^${CREATE_CONTAINER_PREFIX}" || true)
  if [ -z "$stale" ]; then
    __msg_info "No stale containers found with prefix: ${CREATE_CONTAINER_PREFIX}"
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
CREATE_CONTAINER_FORCE_PLATFORM=""
CREATE_CONTAINER_ENTER_CONTAINER="false"

CREATE_CONTAINER_setopts=$(\getopt -o "hv" \
  --long "debug,help,version,config,update,enter,color,no-color,image:,platform:" \
  -n "$APPNAME" -- "$@" 2>/dev/null)
eval set -- "${CREATE_CONTAINER_setopts[@]}" 2>/dev/null

while :; do
  case "$1" in
  --debug)
    shift 1; set -xo pipefail
    export SCRIPT_OPTS="--debug" _DEBUG="on"
    ;;
  -h | --help)
    shift 1; __help; exit 0
    ;;
  -v | --version)
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
  --color)
    shift 1; CREATE_CONTAINER_USE_COLOR="true"
    ;;
  --no-color)
    shift 1; CREATE_CONTAINER_USE_COLOR="false"
    ;;
  --enter)
    shift 1; CREATE_CONTAINER_ENTER_CONTAINER="true"
    ;;
  --image)
    CREATE_CONTAINER_IMAGE="$2"; shift 2
    ;;
  --platform)
    CREATE_CONTAINER_FORCE_PLATFORM="$(__arch_to_platform "$2")"; shift 2
    ;;
  --)
    shift 1; break
    ;;
  esac
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
\mkdir -p "${CREATE_CONTAINER_HOST_RPMBUILD_DIR}" "${CREATE_CONTAINER_HOST_BUILDS_DIR}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main dispatch
case "${1:-}" in

pull | all | update)
  __pull_image "${CREATE_CONTAINER_FORCE_PLATFORM}"
  ;;

enter | "")
  if [ "$CREATE_CONTAINER_ENTER_CONTAINER" = "true" ] || [ "${1:-}" = "enter" ]; then
    __enter_container "" "${CREATE_CONTAINER_FORCE_PLATFORM}"
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
  CREATE_CONTAINER_ver="$1"; shift 1
  CREATE_CONTAINER_arch="${1:-amd64}"; [ $# -gt 0 ] && shift 1
  CREATE_CONTAINER_target="$(__mock_target "$CREATE_CONTAINER_ver" "$CREATE_CONTAINER_arch")"
  __enter_container "$CREATE_CONTAINER_target" "${CREATE_CONTAINER_FORCE_PLATFORM:-$(__arch_to_platform "$CREATE_CONTAINER_arch")}"
  ;;

*)
  # Freeform: pass a raw mock config name to enter with that target preset
  # e.g.  create-container.sh almalinux-9-x86_64
  if [ -n "$1" ]; then
    __enter_container "$1" "${CREATE_CONTAINER_FORCE_PLATFORM}"
  else
    __help
    exit 1
  fi
  ;;

esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit "$?"
# ex: ts=2 sw=2 et filetype=sh
