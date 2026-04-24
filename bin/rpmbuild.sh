#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Color output helpers
_red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
_grn() { printf '\033[0;32m%s\033[0m\n' "$*"; }
_yel() { printf '\033[0;33m%s\033[0m\n' "$*"; }
_blu() { printf '\033[0;34m%s\033[0m\n' "$*"; }
_bld() { printf '\033[1m%s\033[0m\n' "$*"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [specname]

Build RPM packages from spec files.

Arguments:
  specname      Build only this package (matches basename without .spec).
                Omit to build all specs found under \$HOME/rpmbuild.

Options:
  --no-sign     Skip GPG signing of built packages.
  --update      Re-download and install the latest version of this script.
  -h, --help    Show this help and exit.

Environment:
  SET_ARCH      Override architecture (default: uname -m).
  SET_NAME      Override OS name component (default: from ~/.rpmmacros).
  SET_VERSION   Override OS version component (default: from /etc/os-release).
EOF
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse arguments
SINGLE_SPEC=""
DO_SIGN=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        update|--update)
            bash -c "$(curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
            exit $?
            ;;
        --no-sign)
            DO_SIGN=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            _red "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -n "${SINGLE_SPEC}" ]]; then
                _red "Only one specname argument is allowed."
                usage
                exit 1
            fi
            SINGLE_SPEC="$1"
            shift
            ;;
    esac
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
clear
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Resolve build variables
ARCH="${SET_ARCH:-}"
VERNAME="${SET_NAME:-}"
VERNUM="${SET_VERSION:-}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DISTRO="RHEL"
ARCH="${ARCH:-$(uname -m)}"
VERNAME="${VERNAME:-$(grep -s '%_osver ' "${HOME}/.rpmmacros" | awk -F ' ' '{print $2}' | sed 's|%.*||g' | grep '^' || echo "el")}"
VERNUM="${VERNUM:-$(grep -s '^VERSION=' /etc/os-release 2>/dev/null | awk -F= '{print $2}' | sed 's|"||g' | tr ' ' '\n' | grep '[0-9]' | awk -F '.' '{print $1}' | grep '^' || echo "")}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SPEC_DIR="${HOME}/rpmbuild"
LOG_DIR="${HOME}/Documents/builds/logs/rpmbuild"
BUILD_DIR="${HOME}/.local/tmp/BUILD_ROOT/BUILD"
BUILD_ROOT="${HOME}/.local/tmp/BUILD_ROOT/BUILD_ROOT"
SRC_DIR="${HOME}/Documents/builds/rpmbuild/${DISTRO}/${VERNAME}${VERNUM}/${ARCH}"
TARGET_DIR="${HOME}/Documents/builds/sourceforge/${DISTRO}/${VERNAME}${VERNUM}/${ARCH}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export QA_RPATHS="${QA_RPATHS:-$((0x0001 | 0x0010))}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Validate required tools
_check_tool() {
    local tool="$1"
    if ! command -v "${tool}" &>/dev/null; then
        _red "Required tool not found: ${tool}"
        return 1
    fi
}

_check_tool rpmbuild || exit 1

# Determine builddep command (prefer dnf on EL8+, fall back to yum-builddep)
BUILDDEP_CMD=""
if command -v dnf &>/dev/null; then
    BUILDDEP_CMD="dnf builddep"
elif command -v yum-builddep &>/dev/null; then
    BUILDDEP_CMD="yum-builddep"
fi

# Determine if spectool is available
HAS_SPECTOOL=false
command -v spectool &>/dev/null && HAS_SPECTOOL=true
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Validate that key variables resolved to non-empty paths
_validate_path_var() {
    local varname="$1"
    local varval="$2"
    if [[ -z "${varval}" ]]; then
        _red "Variable ${varname} resolved to empty — cannot continue."
        exit 1
    fi
}

_validate_path_var "SRC_DIR"    "${SRC_DIR}"
_validate_path_var "TARGET_DIR" "${TARGET_DIR}"
_validate_path_var "BUILD_DIR"  "${BUILD_DIR}"
_validate_path_var "BUILD_ROOT" "${BUILD_ROOT}"
_validate_path_var "LOG_DIR"    "${LOG_DIR}"
_validate_path_var "SPEC_DIR"   "${SPEC_DIR}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Safe directory cleanup — guard each path explicitly before globbing
_safe_clean_dir() {
    local dir="$1"
    # Require at least 3 path components so we never accidentally operate on / or /home
    local depth
    depth=$(awk -F'/' '{print NF-1}' <<<"${dir}")
    if [[ ${depth} -lt 3 ]]; then
        _red "Refusing to clean shallow path: ${dir}"
        exit 1
    fi
    if [[ -d "${dir}" ]]; then
        find "${dir}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi
}

_safe_clean_dir "${SRC_DIR}"
_safe_clean_dir "${TARGET_DIR}"
_safe_clean_dir "${BUILD_DIR}"
_safe_clean_dir "${BUILD_ROOT}"

mkdir -p "${SRC_DIR}" "${TARGET_DIR}" "${BUILD_DIR}" "${BUILD_ROOT}" "${LOG_DIR}"

# Verify directories are writable after creation
for _dir in "${SRC_DIR}" "${TARGET_DIR}" "${BUILD_DIR}" "${BUILD_ROOT}" "${LOG_DIR}"; do
    if [[ ! -w "${_dir}" ]]; then
        _red "Directory is not writable: ${_dir}"
        exit 1
    fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build spec list
if [[ -n "${SINGLE_SPEC}" ]]; then
    # Find the spec matching the given name
    mapfile -t _found < <(find "${SPEC_DIR}" -name "${SINGLE_SPEC}.spec" 2>/dev/null)
    if [[ ${#_found[@]} -eq 0 ]]; then
        _red "No spec file found for '${SINGLE_SPEC}' under ${SPEC_DIR}"
        exit 1
    fi
    if [[ ${#_found[@]} -gt 1 ]]; then
        _yel "Multiple spec files found for '${SINGLE_SPEC}'; using the first:"
        _yel "  ${_found[0]}"
    fi
    mapfile -t spec_list < <(printf '%s\n' "${_found[0]}")
else
    mapfile -t spec_list < <(find "${SPEC_DIR}" -name '*.spec' | sort)
    if [[ ${#spec_list[@]} -eq 0 ]]; then
        _red "Cannot find any spec files in ${SPEC_DIR}"
        exit 1
    fi
    printf '%s\n' "${spec_list[@]}" >"${LOG_DIR}/specs.txt"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Fix GPG/SSH permissions
find "${HOME}/.gnupg" "${HOME}/.ssh" -type f -exec chmod 600 {} \; 2>/dev/null || true
find "${HOME}/.gnupg" "${HOME}/.ssh" -type d -exec chmod 700 {} \; 2>/dev/null || true
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tracking arrays for summary
succeeded=()
failed=()
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build loop
for spec_file in "${spec_list[@]}"; do
    spec_name="$(basename "${spec_file%.spec}")"
    mkdir -p "${LOG_DIR}/${spec_name}"

    _blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    _bld "Building: ${spec_name}  ($(date +'%Y-%m-%d %H:%M:%S'))"
    echo "Building ${spec_name} package on $(date +'%Y-%m-%d at %H:%M')" \
        | tee "${LOG_DIR}/${spec_name}/build.txt" "${LOG_DIR}/${spec_name}/errors.txt" >/dev/null

    pkg_start="${SECONDS}"

    # Install build dependencies
    if [[ -n "${BUILDDEP_CMD}" ]]; then
        _yel "  Installing build deps for ${spec_name}..."
        if ${BUILDDEP_CMD} -y --skip-broken "${spec_file}" \
                >>"${LOG_DIR}/${spec_name}/packages.txt" 2>&1; then
            _grn "  Dependencies installed."
        else
            _yel "  Warning: builddep reported errors (continuing)."
        fi
    else
        _yel "  No builddep command found (yum-builddep/dnf) — skipping dependency install."
    fi

    # Download sources via spectool
    if "${HAS_SPECTOOL}"; then
        _yel "  Fetching sources for ${spec_name}..."
        if spectool -g -R "${spec_file}" >>"${LOG_DIR}/${spec_name}/build.txt" 2>&1; then
            _grn "  Sources fetched."
        else
            _yel "  Warning: spectool reported errors (sources may already exist)."
        fi
    fi

    # Run rpmbuild
    _yel "  Running rpmbuild for ${spec_name}..."
    if rpmbuild -ba "${spec_file}" \
            >>"${LOG_DIR}/${spec_name}/build.txt" \
            2>>"${LOG_DIR}/${spec_name}/errors.txt"; then
        pkg_elapsed=$(( SECONDS - pkg_start ))
        _grn "  SUCCESS: ${spec_name} (${pkg_elapsed}s)"
        echo "${spec_file} exit code 0" >>"${LOG_DIR}/${spec_name}/status.txt"
        succeeded+=("${spec_name}")
    else
        status_code="$?"
        pkg_elapsed=$(( SECONDS - pkg_start ))
        _red "  FAILED: ${spec_name} (exit ${status_code}, ${pkg_elapsed}s)"
        _red "  See: ${LOG_DIR}/${spec_name}/errors.txt"
        echo "${spec_file} exit code ${status_code}" >>"${LOG_DIR}/${spec_name}/status.txt"
        failed+=("${spec_name}")
    fi
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Sign packages
if "${DO_SIGN}"; then
    # Check for a usable GPG key before attempting to sign
    gpg_key_count=0
    if command -v gpg &>/dev/null; then
        gpg_key_count=$(gpg --list-secret-keys 2>/dev/null | grep -c '^sec' || true)
    fi

    if [[ ${gpg_key_count} -eq 0 ]]; then
        _yel "No GPG secret key found — skipping package signing."
        _yel "Use --no-sign to suppress this message."
    else
        _blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        _bld "Signing packages in ${SRC_DIR}..."
        find "${SRC_DIR}" -iname '*.rpm' >"${LOG_DIR}/pkgs.txt"

        if [[ ! -s "${LOG_DIR}/pkgs.txt" ]]; then
            _yel "No RPM packages found to sign."
        else
            # Sign in batches via xargs to avoid ARG_MAX limits
            if xargs -a "${LOG_DIR}/pkgs.txt" -d '\n' -r rpmsign --addsign; then
                _grn "Packages signed successfully."
            else
                _red "rpmsign reported errors — check packages manually."
            fi
        fi
    fi
else
    _yel "Skipping package signing (--no-sign)."
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Summary
_blu "# - - - - - - - - - - - - - - - - - - - - - - - - - - -"
_bld "Build summary"
_grn "  Succeeded: ${#succeeded[@]}"
if [[ ${#succeeded[@]} -gt 0 ]]; then
    for _pkg in "${succeeded[@]}"; do
        _grn "    + ${_pkg}"
    done
fi
if [[ ${#failed[@]} -gt 0 ]]; then
    _red "  Failed:    ${#failed[@]}"
    for _pkg in "${failed[@]}"; do
        _red "    - ${_pkg}"
    done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[[ ${#failed[@]} -eq 0 ]]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
