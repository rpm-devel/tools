#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605220000-git
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
# Color helpers
__red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
__grn() { printf '\033[0;32m%s\033[0m\n' "$*"; }
__yel() { printf '\033[0;33m%s\033[0m\n' "$*"; }
__blu() { printf '\033[0;34m%s\033[0m\n' "$*"; }
__bld() { printf '\033[1m%s\033[0m\n' "$*"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__usage() {
  cat <<EOF
Usage: $(\basename "$0") [OPTIONS] [specname]

Build RPM packages using ghcr.io/rpm-devel/build:latest.
Each spec is built for every enabled mock target via the build container.

Arguments:
  specname        Build only this package (matches basename without .spec).
                  Omit to build all specs found under \$HOST_RPMBUILD_DIR.

Options:
  --target TARGET Build only this mock target (e.g. almalinux-9-x86_64).
                  Can be repeated: --target T1 --target T2
  --no-sign       Skip GPG signing inside the build container.
  --platform ARCH Override docker platform (linux/amd64 or linux/arm64).
  --update        Re-install the latest version of this script.
  --list-targets  Print all enabled mock targets and exit.
  -h, --help      Show this help and exit.

Environment / settings (~/.config/rpm-devel/settings.conf):
  BUILD_IMAGE         Container image (default: ghcr.io/rpm-devel/build:latest)
  RPM_GPG_KEY_ID      GPG key identifier for signing
  ENABLE_VERSION_7/8/9/10 / ENABLE_FEDORA   Toggle target groups
  FEDORA_VERSION      Fedora version number (default: 42)
  HOST_RPMBUILD_DIR   Host rpmbuild root (default: ~/rpmbuild)
  HOST_BUILDS_DIR     Host builds root   (default: ~/Documents/builds)

Output:
  After each build, RPMs are moved from the container output directory
  into the make-repo-compatible tree:
    ~/Documents/builds/rpmbuild/{DISTRO}/{rel}{VER}/{ARCH}/

Note:
  If entries under HOST_RPMBUILD_DIR are symlinks into another checkout
  (e.g. ~/rpmbuild/{repo} -> ~/Projects/.../rpm-devel/{repo}), their real
  parent directories are auto-detected and bind-mounted read-only at the
  same absolute path so the symlinks resolve inside the container.
EOF
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Config defaults (overridden by settings.conf)
BUILD_IMAGE="${BUILD_IMAGE:-ghcr.io/rpm-devel/build:latest}"
FEDORA_VERSION="${FEDORA_VERSION:-42}"
ENABLE_VERSION_7="${ENABLE_VERSION_7:-no}"
ENABLE_VERSION_8="${ENABLE_VERSION_8:-yes}"
ENABLE_VERSION_9="${ENABLE_VERSION_9:-yes}"
ENABLE_VERSION_10="${ENABLE_VERSION_10:-yes}"
ENABLE_FEDORA="${ENABLE_FEDORA:-yes}"
HOST_RPMBUILD_DIR="${HOST_RPMBUILD_DIR:-$HOME/rpmbuild}"
HOST_BUILDS_DIR="${HOST_BUILDS_DIR:-$HOME/Documents/builds}"
RPM_GPG_KEY_ID="${RPM_GPG_KEY_ID:-}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-rpmbuild}"

# Load user config
RPM_BUILD_CONFIG_DIR="$HOME/.config/rpm-devel"
RPM_BUILD_CONFIG_FILE="settings.conf"
[ -f "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE" ] && \
  . "$RPM_BUILD_CONFIG_DIR/$RPM_BUILD_CONFIG_FILE"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Derived paths
LOG_DIR="${HOST_BUILDS_DIR}/logs/rpmbuild"
# Build output from container lands in HOST_BUILDS_DIR/{mock-target}/
# after the build; we move it to the make-repo tree below.
RPM_OUTPUT_BASE="${HOST_BUILDS_DIR}/rpmbuild"
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
SINGLE_SPEC=""
DO_SIGN=true
FORCE_PLATFORM=""
OVERRIDE_TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    update | --update)
      \bash -c "$(\curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
      exit $?
      ;;
    --target)
      OVERRIDE_TARGETS+=("$2"); shift 2
      ;;
    --no-sign)
      DO_SIGN=false; shift
      ;;
    --platform)
      case "$2" in
        amd64|x86_64)  FORCE_PLATFORM="linux/amd64" ;;
        arm64|aarch64) FORCE_PLATFORM="linux/arm64" ;;
        *)             FORCE_PLATFORM="linux/$2" ;;
      esac
      shift 2
      ;;
    --list-targets)
      # Print and exit — populated after arg parsing below
      LIST_TARGETS_ONLY=true; shift
      ;;
    -h | --help)
      __usage; exit 0
      ;;
    -*)
      __red "Unknown option: $1"; __usage; exit 1
      ;;
    *)
      if [[ -n "${SINGLE_SPEC}" ]]; then
        __red "Only one specname argument is allowed."
        __usage; exit 1
      fi
      SINGLE_SPEC="$1"; shift
      ;;
  esac
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build the list of enabled mock targets
ENABLED_TARGETS=()
if [ "${#OVERRIDE_TARGETS[@]}" -gt 0 ]; then
  ENABLED_TARGETS=("${OVERRIDE_TARGETS[@]}")
else
  [ "$ENABLE_VERSION_7"  = "yes" ] && ENABLED_TARGETS+=("eol/centos-7-x86_64" "eol/centos-7-aarch64")
  [ "$ENABLE_VERSION_8"  = "yes" ] && ENABLED_TARGETS+=("almalinux-8-x86_64"  "almalinux-8-aarch64")
  [ "$ENABLE_VERSION_9"  = "yes" ] && ENABLED_TARGETS+=("almalinux-9-x86_64"  "almalinux-9-aarch64")
  [ "$ENABLE_VERSION_10" = "yes" ] && ENABLED_TARGETS+=("almalinux-10-x86_64" "almalinux-10-aarch64")
  [ "$ENABLE_FEDORA"     = "yes" ] && ENABLED_TARGETS+=("fedora-${FEDORA_VERSION}-x86_64" "fedora-${FEDORA_VERSION}-aarch64")
fi

if [ "${#ENABLED_TARGETS[@]}" -eq 0 ]; then
  __red "No build targets enabled. Edit ~/.config/rpm-devel/settings.conf"
  exit 1
fi

if [ "${LIST_TARGETS_ONLY:-false}" = "true" ]; then
  printf '%s\n' "${ENABLED_TARGETS[@]}"
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
\mkdir -p "${HOST_RPMBUILD_DIR}" "${HOST_BUILDS_DIR}" "${LOG_DIR}"

# Fix GPG/SSH permissions
\find "${HOME}/.gnupg" "${HOME}/.ssh" -type f -exec \chmod 600 {} \; 2>/dev/null || true
\find "${HOME}/.gnupg" "${HOME}/.ssh" -type d -exec \chmod 700 {} \; 2>/dev/null || true
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# HOST_RPMBUILD_DIR entries are often symlinks into a separate checkout
# tree (e.g. ~/rpmbuild/{repo} -> ~/Projects/.../rpm-devel/{repo}). A plain
# bind mount of HOST_RPMBUILD_DIR does not make symlink targets outside it
# resolvable inside the container, so resolve each top-level symlink and
# bind-mount its real parent directory at the identical absolute path.
EXTRA_MOUNTS=()
_seen_parents=()
while IFS= read -r -d '' _link; do
  _target="$(\readlink -f -- "${_link}" 2>/dev/null)" || continue
  [ -z "${_target}" ] && continue
  _parent="${_target%/*}"
  _dup=false
  for _p in "${_seen_parents[@]:-}"; do
    [ "${_p}" = "${_parent}" ] && _dup=true && break
  done
  "${_dup}" || { _seen_parents+=("${_parent}"); EXTRA_MOUNTS+=("-v" "${_parent}:${_parent}:ro"); }
done < <(\find "${HOST_RPMBUILD_DIR}" -maxdepth 1 -type l -print0 2>/dev/null)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build spec list
if [[ -n "${SINGLE_SPEC}" ]]; then
  mapfile -t _found < <(\find "${HOST_RPMBUILD_DIR}" -name "${SINGLE_SPEC}.spec" 2>/dev/null)
  if [[ ${#_found[@]} -eq 0 ]]; then
    __red "No spec file found for '${SINGLE_SPEC}' under ${HOST_RPMBUILD_DIR}"
    exit 1
  fi
  if [[ ${#_found[@]} -gt 1 ]]; then
    __yel "Multiple specs found for '${SINGLE_SPEC}'; using: ${_found[0]}"
  fi
  spec_list=("${_found[0]}")
else
  mapfile -t spec_list < <(\find "${HOST_RPMBUILD_DIR}" -name '*.spec' | \sort)
  if [[ ${#spec_list[@]} -eq 0 ]]; then
    __red "No spec files found in ${HOST_RPMBUILD_DIR}"
    exit 1
  fi
  printf '%s\n' "${spec_list[@]}" >"${LOG_DIR}/specs.txt"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Convert a host spec path to the container-side path.
# Host: $HOME/rpmbuild/SPECS/foo.spec  →  Container: /root/rpmbuild/SPECS/foo.spec
__host_to_container_path() {
  local host_path="$1"
  local rel="${host_path#"${HOST_RPMBUILD_DIR}"}"
  echo "/root/rpmbuild${rel}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# After a successful container build, move RPMs from the container output
# directory into the make-repo-compatible tree.
__collect_rpms() {
  local target="$1"
  local outdir
  outdir="$(__target_to_outdir "$target")"
  local src_dir="${HOST_BUILDS_DIR}/${target}"
  local dst_dir="${RPM_OUTPUT_BASE}/${outdir}"

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
succeeded=()
failed=()
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main build loop: for each spec, build every enabled target
for spec_file in "${spec_list[@]}"; do
  spec_name="$(\basename -- "${spec_file%.spec}")"
  \mkdir -p "${LOG_DIR}/${spec_name}"
  container_spec="$(__host_to_container_path "${spec_file}")"

  __blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
  __bld "Package: ${spec_name}  $(\date +'%Y-%m-%d %H:%M:%S')"

  pkg_ok=true

  for target in "${ENABLED_TARGETS[@]}"; do
    __yel "  Target: ${target}"

    ctr_name="${CONTAINER_PREFIX}-$(\tr -dc 'a-z0-9' </dev/urandom | \head -c8)"

    local_macros=()
    [ -f "$HOME/.rpmmacros" ] && local_macros=("-v" "$HOME/.rpmmacros:/root/.rpmmacros:ro")

    platform_flag=()
    [ -n "${FORCE_PLATFORM}" ] && platform_flag=("--platform" "${FORCE_PLATFORM}")

    gpg_flag=()
    if "${DO_SIGN}" && [ -n "${RPM_GPG_KEY_ID}" ]; then
      gpg_flag=("-e" "RPM_GPG_KEY_ID=${RPM_GPG_KEY_ID}")
    fi

    target_start="${SECONDS}"
    if \docker run --rm -it --privileged \
        --name "${ctr_name}" \
        "${platform_flag[@]}" \
        -v "${HOST_RPMBUILD_DIR}:/root/rpmbuild" \
        "${EXTRA_MOUNTS[@]}" \
        -v "${HOST_BUILDS_DIR}:/root/Documents/builds" \
        "${local_macros[@]}" \
        -v "$HOME/.gnupg:/root/.gnupg:ro" \
        -e "RPM_TARGET=${target}" \
        "${gpg_flag[@]}" \
        "$BUILD_IMAGE" \
        "${container_spec}" \
          >>"${LOG_DIR}/${spec_name}/build-${target//\//-}.txt" \
          2>>"${LOG_DIR}/${spec_name}/errors-${target//\//-}.txt"; then
      target_elapsed=$(( SECONDS - target_start ))
      __grn "  SUCCESS: ${spec_name} / ${target} (${target_elapsed}s)"
      __collect_rpms "${target}"
    else
      status_code="$?"
      target_elapsed=$(( SECONDS - target_start ))
      __red "  FAILED:  ${spec_name} / ${target} (exit ${status_code}, ${target_elapsed}s)"
      __red "  See: ${LOG_DIR}/${spec_name}/errors-${target//\//-}.txt"
      pkg_ok=false
    fi
  done

  if "${pkg_ok}"; then
    succeeded+=("${spec_name}")
  else
    failed+=("${spec_name}")
  fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Host-side signing pass (catches any RPMs the container didn't sign,
# or provides signing when --no-sign was passed to suppress container signing)
if "${DO_SIGN}"; then
  gpg_key_count=0
  if \command -v gpg &>/dev/null; then
    gpg_key_count=$(\gpg --list-secret-keys 2>/dev/null | \grep -c -- '^sec' || true)
  fi

  if [[ ${gpg_key_count} -gt 0 ]]; then
    __blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    __bld "Signing packages in ${RPM_OUTPUT_BASE}..."
    mapfile -t _rpms < <(\find "${RPM_OUTPUT_BASE}" -iname '*.rpm' -not -iname '*.src.rpm' 2>/dev/null)

    if [[ ${#_rpms[@]} -gt 0 ]]; then
      if \rpmsign --addsign "${_rpms[@]}" 2>>"${LOG_DIR}/sign.err"; then
        __grn "Signed ${#_rpms[@]} RPM(s)"
      else
        __yel "rpmsign reported errors — check ${LOG_DIR}/sign.err"
      fi
    else
      __yel "No RPMs found to sign in ${RPM_OUTPUT_BASE}"
    fi
  else
    __yel "No GPG secret key found — skipping host-side signing"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Summary
__blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
__bld "Build summary (${#ENABLED_TARGETS[@]} target(s))"
__grn "  Succeeded: ${#succeeded[@]}"
for _pkg in "${succeeded[@]}"; do __grn "    + ${_pkg}"; done
if [[ ${#failed[@]} -gt 0 ]]; then
  __red "  Failed:    ${#failed[@]}"
  for _pkg in "${failed[@]}"; do __red "    - ${_pkg}"; done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[[ ${#failed[@]} -eq 0 ]]
# end
