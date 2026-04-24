#!/usr/bin/env sh
# shellcheck shell=sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202604240000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  install.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, Jan 01, 2023 17:10 EST
# @@File             :  install.sh
# @@Description      :  Install rpm-devel tools
# @@Changelog        :  Better error handling, dnf/yum detection, --force flag, trap cleanup
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# POSIX sh — no bashisms
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="install.sh"
VERSION="202604240000-git"
REPO_URL="https://github.com/rpm-devel/tools"
CLONE_DIR="/tmp/rpm-dev-tools-$$"
MACROS_URL="https://github.com/rpm-devel/tools/raw/main/.rpmmacros"
INSTALL_EXIT=0
FORCE=false
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Cleanup on exit (trap works in POSIX sh)
_cleanup() {
  [ -d "${CLONE_DIR}" ] && rm -rf "${CLONE_DIR}"
}
trap _cleanup EXIT INT TERM
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Logging (no color — stays POSIX, works in any terminal)
info()  { printf '[INFO]  %s\n' "$*"; }
ok()    { printf '[OK]    %s\n' "$*"; }
warn()  { printf '[WARN]  %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__usage() {
  cat <<EOF
Usage: ${APPNAME} [OPTIONS]

Install rpm-devel tools from ${REPO_URL}

Options:
  -h, --help     Show this help message and exit
  -v, --version  Print version and exit
  -f, --force    Overwrite existing files (including .rpmmacros)

EOF
  exit 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Detect package manager: prefer dnf, fall back to yum
__detect_pkg_mgr() {
  if command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MGR="yum"
  else
    PKG_MGR=""
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Ensure git is available; install it if not
__ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  warn "git not found — attempting to install..."
  __detect_pkg_mgr

  if [ -n "${PKG_MGR}" ]; then
    "${PKG_MGR}" install -y -q git || die "Failed to install git via ${PKG_MGR}"
    ok "git installed via ${PKG_MGR}"
  elif command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git || die "Failed to install git via apt-get"
    ok "git installed via apt-get"
  else
    die "git is not installed and no supported package manager was found"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Determine the installation bin directory
__pick_bin_dir() {
  if [ "$(id -u)" -eq 0 ] || [ "${USER:-}" = "root" ] || [ "$(id -un 2>/dev/null)" = "root" ]; then
    U_BIN="/usr/local/bin"
    info "Running as root; bin dir: ${U_BIN}"
  elif [ -d "${HOME}/.bin" ]; then
    U_BIN="${HOME}/.bin"
    info "Bin dir: ${U_BIN}"
  elif [ -d "${HOME}/bin" ]; then
    U_BIN="${HOME}/bin"
    info "Bin dir: ${U_BIN}"
  else
    U_BIN="${HOME}/.local/bin"
    info "Bin dir: ${U_BIN} (will create if missing)"
    mkdir -p "${U_BIN}" || die "Failed to create ${U_BIN}"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if the installed copy of a tool is already current (compares VERSION line)
__is_current() {
  local dest="$1"
  local src="$2"

  [ -f "${dest}" ] || return 1  # not installed

  local installed_ver remote_ver
  installed_ver="$(grep -m1 '^##@Version' "${dest}" 2>/dev/null | awk '{print $NF}')"
  remote_ver="$(grep -m1 '^##@Version' "${src}" 2>/dev/null | awk '{print $NF}')"

  [ -z "${installed_ver}" ] && return 1  # no version tag — treat as stale
  [ -z "${remote_ver}" ]    && return 1

  [ "${installed_ver}" = "${remote_ver}" ]
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install all scripts from the cloned bin/ directory
__install_scripts() {
  local src_dir="${CLONE_DIR}/bin"
  [ -d "${src_dir}" ] || die "Cloned repo missing bin/ directory"

  chmod -R 755 "${src_dir}" || die "Failed to set permissions on ${src_dir}"

  local installed=0
  local skipped=0

  for src_file in "${src_dir}"/*; do
    [ -f "${src_file}" ] || continue
    name="$(basename "${src_file}")"
    dest="${U_BIN}/${name}"

    if [ "${FORCE}" = "false" ] && __is_current "${dest}" "${src_file}"; then
      info "Skipping ${name} (already current)"
      skipped=$((skipped + 1))
      continue
    fi

    cp -f "${src_file}" "${dest}" || { error "Failed to install ${name} to ${dest}"; INSTALL_EXIT=1; continue; }
    chmod 755 "${dest}"
    ok "Installed ${dest}"
    installed=$((installed + 1))
  done

  ok "Scripts: ${installed} installed, ${skipped} already current."
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install .rpmmacros — skip if exists unless --force
__install_rpmmacros() {
  local src="${CLONE_DIR}/.rpmmacros"
  local dest="${HOME}/.rpmmacros"

  if [ ! -f "${src}" ]; then
    warn ".rpmmacros not found in cloned repo; skipping."
    return 0
  fi

  if [ -f "${dest}" ] && [ "${FORCE}" = "false" ]; then
    info "${dest} already exists; skipping (use --force to overwrite)."
    return 0
  fi

  cp -f "${src}" "${dest}" || die "Failed to install .rpmmacros to ${dest}"
  ok ".rpmmacros installed at ${dest}"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    __usage ;;
    -v|--version) echo "${APPNAME} ${VERSION}"; exit 0 ;;
    -f|--force)   FORCE=true ;;
    *) warn "Unknown option: $1"; __usage ;;
  esac
  shift
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main
info "Starting ${APPNAME} ${VERSION}"

__ensure_git
__pick_bin_dir

info "Cloning ${REPO_URL} to ${CLONE_DIR}..."
git clone -q "${REPO_URL}" "${CLONE_DIR}" || die "Failed to clone ${REPO_URL}"
ok "Clone complete."

__install_scripts
__install_rpmmacros

# Final sanity check
if [ -f "${HOME}/.rpmmacros" ] || [ "${INSTALL_EXIT}" -eq 0 ]; then
  ok "Setup complete. Tools are in ${U_BIN}."
  exit 0
else
  error "Setup finished with errors."
  exit 1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# ex: ts=2 sw=2 et filetype=sh
