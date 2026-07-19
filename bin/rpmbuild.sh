#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607181900-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  LICENSE.md
# @@ReadME           :  rpmbuild.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, Aug 17, 2023 20:28 EDT
# @@File             :  rpmbuild.sh
# @@Description      :  Build RPM packages using ghcr.io/rpm-devel/build:latest
# @@Changelog        :  Rewritten to use the single build container with mock
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607181900-git"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Color helpers
RPMBUILD_USE_COLOR="${RPMBUILD_USE_COLOR:-true}"
if [ -n "${NO_COLOR:-}" ]; then
  RPMBUILD_USE_COLOR="false"
fi

__red() { if [ "$RPMBUILD_USE_COLOR" = "true" ]; then printf '\033[0;31m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi; }
__grn() { if [ "$RPMBUILD_USE_COLOR" = "true" ]; then printf '\033[0;32m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi; }
__yel() { if [ "$RPMBUILD_USE_COLOR" = "true" ]; then printf '\033[0;33m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi; }
__blu() { if [ "$RPMBUILD_USE_COLOR" = "true" ]; then printf '\033[0;34m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi; }
__bld() { if [ "$RPMBUILD_USE_COLOR" = "true" ]; then printf '\033[1m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__help() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS] [specname]

Build RPM packages using ghcr.io/rpm-devel/build:latest.
Each spec is built for every enabled mock target via the build container.

Arguments:
  specname        Build only this package (matches basename without .spec).
                  Omit to build all specs found under \$RPMBUILD_HOST_RPMBUILD_DIR.

Options:
  --target TARGET Build only this mock target (e.g. almalinux-9-x86_64).
                  Can be repeated: --target T1 --target T2
  --no-sign       Skip GPG signing inside the build container.
  --platform ARCH Override docker platform (linux/amd64 or linux/arm64).
  --update        Re-install the latest version of this script.
  --list-targets  Print all enabled mock targets and exit.
  --debug         Enable bash -x tracing.
  --color         Enable colored output (default unless NO_COLOR is set).
  --no-color      Disable colored output.
  -h, --help      Show this help and exit.
  -v, --version   Show script version and exit.

Environment / settings (~/.config/rpm-devel/settings.conf):
  RPMBUILD_IMAGE                 Container image (default: ghcr.io/rpm-devel/build:latest)
  RPMBUILD_GPG_KEY_ID            GPG key identifier for signing
  RPMBUILD_ENABLE_VERSION_7/8/9/10 / RPMBUILD_ENABLE_FEDORA   Toggle target groups
  RPMBUILD_FEDORA_VERSION         Fedora version number (default: 42)
  RPMBUILD_HOST_RPMBUILD_DIR     Host rpmbuild root (default: ~/rpmbuild)
  RPMBUILD_HOST_BUILDS_DIR       Host builds root   (default: ~/Documents/builds)

Output:
  After each build, RPMs are moved from the container output directory
  into the make-repo-compatible tree:
    ~/Documents/builds/rpmbuild/{DISTRO}/{rel}{VER}/{ARCH}/

Note:
  If entries under RPMBUILD_HOST_RPMBUILD_DIR are symlinks into another checkout
  (e.g. ~/rpmbuild/{repo} -> ~/Projects/.../rpm-devel/{repo}), their real
  parent directories are auto-detected and bind-mounted (read-write, since
  spectool writes downloaded sources into the package dir) at the same
  absolute path so the symlinks resolve inside the container.
EOF
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Config defaults (overridden by settings.conf)
RPMBUILD_IMAGE="${RPMBUILD_IMAGE:-ghcr.io/rpm-devel/build:latest}"
RPMBUILD_FEDORA_VERSION="${RPMBUILD_FEDORA_VERSION:-42}"
RPMBUILD_ENABLE_VERSION_7="${RPMBUILD_ENABLE_VERSION_7:-no}"
RPMBUILD_ENABLE_VERSION_8="${RPMBUILD_ENABLE_VERSION_8:-yes}"
RPMBUILD_ENABLE_VERSION_9="${RPMBUILD_ENABLE_VERSION_9:-yes}"
RPMBUILD_ENABLE_VERSION_10="${RPMBUILD_ENABLE_VERSION_10:-yes}"
RPMBUILD_ENABLE_FEDORA="${RPMBUILD_ENABLE_FEDORA:-yes}"
RPMBUILD_HOST_RPMBUILD_DIR="${RPMBUILD_HOST_RPMBUILD_DIR:-$HOME/rpmbuild}"
RPMBUILD_HOST_BUILDS_DIR="${RPMBUILD_HOST_BUILDS_DIR:-$HOME/Documents/builds}"
RPMBUILD_GPG_KEY_ID="${RPMBUILD_GPG_KEY_ID:-}"
RPMBUILD_CONTAINER_PREFIX="${RPMBUILD_CONTAINER_PREFIX:-rpmbuild}"

# Load user config
RPMBUILD_CONFIG_DIR="$HOME/.config/rpm-devel"
RPMBUILD_CONFIG_FILE="settings.conf"
[ -f "$RPMBUILD_CONFIG_DIR/$RPMBUILD_CONFIG_FILE" ] && \
  . "$RPMBUILD_CONFIG_DIR/$RPMBUILD_CONFIG_FILE"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Derived paths
RPMBUILD_LOG_DIR="${RPMBUILD_HOST_BUILDS_DIR}/logs/rpmbuild"
# Build output from container lands in RPMBUILD_HOST_BUILDS_DIR/{mock-target}/
# after the build; we move it to the make-repo tree below.
RPMBUILD_OUTPUT_BASE="${RPMBUILD_HOST_BUILDS_DIR}/rpmbuild"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Map a mock target name to the make-repo directory sub-path.
# e.g. almalinux-9-x86_64 → RHEL/el9/x86_64
__target_to_outdir() {
  local t="$1"
  case "$t" in
    eol/centos-7-x86_64)    echo "RHEL/el7/x86_64" ;;
    eol/centos-7-aarch64)   echo "RHEL/el7/aarch64" ;;
    almalinux-8-x86_64)     echo "RHEL/el8/x86_64" ;;
    almalinux-8-aarch64)    echo "RHEL/el8/aarch64" ;;
    almalinux-9-x86_64)     echo "RHEL/el9/x86_64" ;;
    almalinux-9-aarch64)    echo "RHEL/el9/aarch64" ;;
    almalinux-10-x86_64)    echo "RHEL/el10/x86_64" ;;
    almalinux-10-aarch64)   echo "RHEL/el10/aarch64" ;;
    fedora-*-x86_64)
      local v="${t#fedora-}"; v="${v%-x86_64}"
      echo "Fedora/fc${v}/x86_64" ;;
    fedora-*-aarch64)
      local v="${t#fedora-}"; v="${v%-aarch64}"
      echo "Fedora/fc${v}/aarch64" ;;
    eol/fedora-*-x86_64)
      local v="${t#eol/fedora-}"; v="${v%-x86_64}"
      echo "Fedora/fc${v}/x86_64" ;;
    eol/fedora-*-aarch64)
      local v="${t#eol/fedora-}"; v="${v%-aarch64}"
      echo "Fedora/fc${v}/aarch64" ;;
    *)
      # Sanitise slashes so we get a valid directory component
      echo "OTHER/${t//\//-}" ;;
  esac
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse arguments
RPMBUILD_SINGLE_SPEC=""
RPMBUILD_DO_SIGN=true
RPMBUILD_FORCE_PLATFORM=""
RPMBUILD_OVERRIDE_TARGETS=()

RPMBUILD_setopts=$(\getopt -o "hv" \
  --long "debug,help,version,update,target:,no-sign,platform:,list-targets,color,no-color" \
  -n "${0##*/}" -- "$@" 2>/dev/null)
eval set -- "${RPMBUILD_setopts[@]}" 2>/dev/null

while :; do
  case "$1" in
    --debug)
      shift 1; set -xo pipefail
      ;;
    -h | --help)
      __help; exit 0
      ;;
    -v | --version)
      printf '%s\n' "$VERSION"; exit 0
      ;;
    --update)
      shift 1
      \bash -c "$(\curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
      exit $?
      ;;
    --target)
      RPMBUILD_OVERRIDE_TARGETS+=("$2"); shift 2
      ;;
    --no-sign)
      RPMBUILD_DO_SIGN=false; shift 1
      ;;
    --platform)
      case "$2" in
        amd64|x86_64)  RPMBUILD_FORCE_PLATFORM="linux/amd64" ;;
        arm64|aarch64) RPMBUILD_FORCE_PLATFORM="linux/arm64" ;;
        *)             RPMBUILD_FORCE_PLATFORM="linux/$2" ;;
      esac
      shift 2
      ;;
    --list-targets)
      RPMBUILD_LIST_TARGETS_ONLY=true; shift 1
      ;;
    --color)
      RPMBUILD_USE_COLOR="true"; shift 1
      ;;
    --no-color)
      RPMBUILD_USE_COLOR="false"; shift 1
      ;;
    --)
      shift 1; break
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  if [[ -n "${RPMBUILD_SINGLE_SPEC}" ]]; then
    __red "Only one specname argument is allowed."
    __help; exit 1
  fi
  RPMBUILD_SINGLE_SPEC="$1"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build the list of enabled mock targets
RPMBUILD_ENABLED_TARGETS=()
if [ "${#RPMBUILD_OVERRIDE_TARGETS[@]}" -gt 0 ]; then
  RPMBUILD_ENABLED_TARGETS=("${RPMBUILD_OVERRIDE_TARGETS[@]}")
else
  [ "$RPMBUILD_ENABLE_VERSION_7"  = "yes" ] && RPMBUILD_ENABLED_TARGETS+=("eol/centos-7-x86_64" "eol/centos-7-aarch64")
  [ "$RPMBUILD_ENABLE_VERSION_8"  = "yes" ] && RPMBUILD_ENABLED_TARGETS+=("almalinux-8-x86_64"  "almalinux-8-aarch64")
  [ "$RPMBUILD_ENABLE_VERSION_9"  = "yes" ] && RPMBUILD_ENABLED_TARGETS+=("almalinux-9-x86_64"  "almalinux-9-aarch64")
  [ "$RPMBUILD_ENABLE_VERSION_10" = "yes" ] && RPMBUILD_ENABLED_TARGETS+=("almalinux-10-x86_64" "almalinux-10-aarch64")
  [ "$RPMBUILD_ENABLE_FEDORA"     = "yes" ] && RPMBUILD_ENABLED_TARGETS+=("fedora-${RPMBUILD_FEDORA_VERSION}-x86_64" "fedora-${RPMBUILD_FEDORA_VERSION}-aarch64")
fi

if [ "${#RPMBUILD_ENABLED_TARGETS[@]}" -eq 0 ]; then
  __red "No build targets enabled. Edit $RPMBUILD_CONFIG_DIR/$RPMBUILD_CONFIG_FILE"
  exit 1
fi

if [ "${RPMBUILD_LIST_TARGETS_ONLY:-false}" = "true" ]; then
  printf '%s\n' "${RPMBUILD_ENABLED_TARGETS[@]}"
  exit 0
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Validate docker is present
if ! \command -v docker &>/dev/null; then
  __red "docker is required but not found in PATH"
  exit 1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
\clear
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create directories
\mkdir -p "${RPMBUILD_HOST_RPMBUILD_DIR}" "${RPMBUILD_HOST_BUILDS_DIR}" "${RPMBUILD_LOG_DIR}"

# Fix GPG/SSH permissions
\find "${HOME}/.gnupg" "${HOME}/.ssh" -type f -exec \chmod 600 {} \; 2>/dev/null || true
\find "${HOME}/.gnupg" "${HOME}/.ssh" -type d -exec \chmod 700 {} \; 2>/dev/null || true
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# RPMBUILD_HOST_RPMBUILD_DIR entries are often symlinks into a separate checkout
# tree (e.g. ~/rpmbuild/{repo} -> ~/Projects/.../rpm-devel/{repo}). A plain
# bind mount of RPMBUILD_HOST_RPMBUILD_DIR does not make symlink targets outside it
# resolvable inside the container, so resolve each top-level symlink and
# bind-mount its real parent directory at the identical absolute path.
RPMBUILD_EXTRA_MOUNTS=()
RPMBUILD_seen_parents=()
while IFS= read -r -d '' RPMBUILD_link; do
  RPMBUILD_target="$(\readlink -f -- "${RPMBUILD_link}" 2>/dev/null)" || continue
  [ -z "${RPMBUILD_target}" ] && continue
  RPMBUILD_parent="${RPMBUILD_target%/*}"
  RPMBUILD_dup=false
  for RPMBUILD_p in "${RPMBUILD_seen_parents[@]:-}"; do
    [ "${RPMBUILD_p}" = "${RPMBUILD_parent}" ] && RPMBUILD_dup=true && break
  done
  "${RPMBUILD_dup}" || { RPMBUILD_seen_parents+=("${RPMBUILD_parent}"); RPMBUILD_EXTRA_MOUNTS+=("-v" "${RPMBUILD_parent}:${RPMBUILD_parent}"); }
done < <(\find "${RPMBUILD_HOST_RPMBUILD_DIR}" -maxdepth 1 -type l -print0 2>/dev/null)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build spec list
if [[ -n "${RPMBUILD_SINGLE_SPEC}" ]]; then
  mapfile -t RPMBUILD_found < <(\find -L "${RPMBUILD_HOST_RPMBUILD_DIR}" -name "${RPMBUILD_SINGLE_SPEC}.spec" 2>/dev/null)
  if [[ ${#RPMBUILD_found[@]} -eq 0 ]]; then
    __red "No spec file found for '${RPMBUILD_SINGLE_SPEC}' under ${RPMBUILD_HOST_RPMBUILD_DIR}"
    exit 1
  fi
  if [[ ${#RPMBUILD_found[@]} -gt 1 ]]; then
    __yel "Multiple specs found for '${RPMBUILD_SINGLE_SPEC}'; using: ${RPMBUILD_found[0]}"
  fi
  RPMBUILD_spec_list=("${RPMBUILD_found[0]}")
else
  mapfile -t RPMBUILD_spec_list < <(\find -L "${RPMBUILD_HOST_RPMBUILD_DIR}" -name '*.spec' | \sort)
  if [[ ${#RPMBUILD_spec_list[@]} -eq 0 ]]; then
    __red "No spec files found in ${RPMBUILD_HOST_RPMBUILD_DIR}"
    exit 1
  fi
  printf '%s\n' "${RPMBUILD_spec_list[@]}" >"${RPMBUILD_LOG_DIR}/specs.txt"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Convert a host spec path to the container-side path.
# Host: $HOME/rpmbuild/SPECS/foo.spec  →  Container: /root/rpmbuild/SPECS/foo.spec
__host_to_container_path() {
  local host_path="$1"
  local rel="${host_path#"${RPMBUILD_HOST_RPMBUILD_DIR}"}"
  echo "/root/rpmbuild${rel}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# After a successful container build, move RPMs from the container output
# directory into the make-repo-compatible tree.
__collect_rpms() {
  local target="$1"
  local outdir
  outdir="$(__target_to_outdir "$target")"
  local src_dir="${RPMBUILD_HOST_BUILDS_DIR}/${target}"
  local dst_dir="${RPMBUILD_OUTPUT_BASE}/${outdir}"

  if [ ! -d "${src_dir}" ] || [ -z "$(ls -A "${src_dir}" 2>/dev/null)" ]; then
    __yel "  No output in ${src_dir} — nothing to collect"
    return 0
  fi

  \mkdir -p "${dst_dir}"
  local count=0
  while IFS= read -r -d '' f; do
    \mv -- "$f" "${dst_dir}/"
    count=$((count + 1))
  done < <(\find "${src_dir}" -maxdepth 1 -name "*.rpm" -print0 2>/dev/null)

  if [ "$count" -gt 0 ]; then
    __grn "  Collected ${count} RPM(s) → ${dst_dir}"
  fi
  # Clean up the now-empty target output dir
  \rmdir "${src_dir}" 2>/dev/null || true
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tracking
RPMBUILD_succeeded=()
RPMBUILD_failed=()
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main build loop: for each spec, build every enabled target
for spec_file in "${RPMBUILD_spec_list[@]}"; do
  RPMBUILD_spec_name="${spec_file##*/}"; RPMBUILD_spec_name="${RPMBUILD_spec_name%.spec}"
  \mkdir -p "${RPMBUILD_LOG_DIR}/${RPMBUILD_spec_name}"
  RPMBUILD_container_spec="$(__host_to_container_path "${spec_file}")"

  __blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  __bld "Package: ${RPMBUILD_spec_name}  $(\date +'%Y-%m-%d %H:%M:%S')"

  RPMBUILD_pkg_ok=true

  for target in "${RPMBUILD_ENABLED_TARGETS[@]}"; do
    __yel "  Target: ${target}"

    RPMBUILD_ctr_name="${RPMBUILD_CONTAINER_PREFIX}-$(\tr -dc 'a-z0-9' </dev/urandom | \head -c8)"

    RPMBUILD_local_macros=()
    [ -f "$HOME/.rpmmacros" ] && RPMBUILD_local_macros=("-v" "$HOME/.rpmmacros:/root/.rpmmacros:ro")

    RPMBUILD_platform_flag=()
    [ -n "${RPMBUILD_FORCE_PLATFORM}" ] && RPMBUILD_platform_flag=("--platform" "${RPMBUILD_FORCE_PLATFORM}")

    RPMBUILD_gpg_flag=()
    if "${RPMBUILD_DO_SIGN}" && [ -n "${RPMBUILD_GPG_KEY_ID}" ]; then
      RPMBUILD_gpg_flag=("-e" "RPM_GPG_KEY_ID=${RPMBUILD_GPG_KEY_ID}")
    fi

    RPMBUILD_target_start="${SECONDS}"
    if \docker run --rm --privileged \
        --name "${RPMBUILD_ctr_name}" \
        "${RPMBUILD_platform_flag[@]}" \
        -v "${RPMBUILD_HOST_RPMBUILD_DIR}:/root/rpmbuild" \
        "${RPMBUILD_EXTRA_MOUNTS[@]}" \
        -v "${RPMBUILD_HOST_BUILDS_DIR}:/root/Documents/builds" \
        "${RPMBUILD_local_macros[@]}" \
        -v "$HOME/.gnupg:/root/.gnupg:ro" \
        -e "RPM_TARGET=${target}" \
        "${RPMBUILD_gpg_flag[@]}" \
        "$RPMBUILD_IMAGE" \
        "${RPMBUILD_container_spec}" \
          >>"${RPMBUILD_LOG_DIR}/${RPMBUILD_spec_name}/build-${target//\//-}.txt" \
          2>>"${RPMBUILD_LOG_DIR}/${RPMBUILD_spec_name}/errors-${target//\//-}.txt"; then
      RPMBUILD_target_elapsed=$(( SECONDS - RPMBUILD_target_start ))
      __grn "  SUCCESS: ${RPMBUILD_spec_name} / ${target} (${RPMBUILD_target_elapsed}s)"
      __collect_rpms "${target}"
    else
      RPMBUILD_status_code="$?"
      RPMBUILD_target_elapsed=$(( SECONDS - RPMBUILD_target_start ))
      __red "  FAILED:  ${RPMBUILD_spec_name} / ${target} (exit ${RPMBUILD_status_code}, ${RPMBUILD_target_elapsed}s)"
      __red "  See: ${RPMBUILD_LOG_DIR}/${RPMBUILD_spec_name}/errors-${target//\//-}.txt"
      RPMBUILD_pkg_ok=false
    fi
  done

  if "${RPMBUILD_pkg_ok}"; then
    RPMBUILD_succeeded+=("${RPMBUILD_spec_name}")
  else
    RPMBUILD_failed+=("${RPMBUILD_spec_name}")
  fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Host-side signing pass (catches any RPMs the container didn't sign,
# or provides signing when --no-sign was passed to suppress container signing)
if "${RPMBUILD_DO_SIGN}"; then
  RPMBUILD_gpg_key_count=0
  if \command -v gpg &>/dev/null; then
    RPMBUILD_gpg_key_count=$(\gpg --list-secret-keys 2>/dev/null | \grep -c -- '^sec' || true)
  fi

  if [[ ${RPMBUILD_gpg_key_count} -gt 0 ]]; then
    __blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    __bld "Signing packages in ${RPMBUILD_OUTPUT_BASE}..."
    mapfile -t RPMBUILD_rpms < <(\find "${RPMBUILD_OUTPUT_BASE}" -iname '*.rpm' -not -iname '*.src.rpm' 2>/dev/null)

    if [[ ${#RPMBUILD_rpms[@]} -gt 0 ]]; then
      if \rpmsign --addsign "${RPMBUILD_rpms[@]}" 2>>"${RPMBUILD_LOG_DIR}/sign.err"; then
        __grn "Signed ${#RPMBUILD_rpms[@]} RPM(s)"
      else
        __yel "rpmsign reported errors — check ${RPMBUILD_LOG_DIR}/sign.err"
      fi
    else
      __yel "No RPMs found to sign in ${RPMBUILD_OUTPUT_BASE}"
    fi
  else
    __yel "No GPG secret key found — skipping host-side signing"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Summary
__blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
__bld "Build summary (${#RPMBUILD_ENABLED_TARGETS[@]} target(s))"
__grn "  Succeeded: ${#RPMBUILD_succeeded[@]}"
for _pkg in "${RPMBUILD_succeeded[@]}"; do __grn "    + ${_pkg}"; done
if [[ ${#RPMBUILD_failed[@]} -gt 0 ]]; then
  __red "  Failed:    ${#RPMBUILD_failed[@]}"
  for _pkg in "${RPMBUILD_failed[@]}"; do __red "    - ${_pkg}"; done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[[ ${#RPMBUILD_failed[@]} -eq 0 ]]
# end
