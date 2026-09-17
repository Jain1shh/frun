#!/usr/bin/env bash
#
# install.sh — Installs `frun` to a system-wide location (/usr/local/bin by
# default) and gives it execute permissions. Safe to re-run to upgrade.
#
# Licensed under the GNU General Public License v3.0.
# See LICENSE for details.
#
# Usage:
#   ./install.sh                 # install from a local frun.sh in this dir
#   curl -fsSL <raw-url>/install.sh | bash   # install by downloading frun.sh
#
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

readonly REPO_RAW_URL="https://raw.githubusercontent.com/<your-username>/frun/main/frun.sh"
readonly INSTALL_DIR="${FRUN_INSTALL_DIR:-/usr/local/bin}"
readonly BIN_NAME="frun"
readonly SCRIPT_SOURCE="frun.sh"

info() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found. Please install it first."
}

print_dependency_help() {
  cat <<'EOF'

Some runtime dependencies for frun are missing. Install them with your
distro's package manager:

  Debian / Ubuntu / Mint:
    sudo apt update && sudo apt install fzf fd-find xdg-utils
    # Debian/Ubuntu ships the binary as 'fdfind' — frun detects this automatically.

  Fedora:
    sudo dnf install fzf fd-find xdg-utils

  Arch / Manjaro:
    sudo pacman -S fzf fd xdg-utils

  openSUSE:
    sudo zypper install fzf fd xdg-utils

EOF
}

main() {
  info "Installing ${BIN_NAME} to ${INSTALL_DIR} ..."

  # Only shell out to sudo if we actually need elevated permissions.
  local sudo_cmd=""
  if [[ "${EUID}" -ne 0 && ! -w "${INSTALL_DIR}" ]]; then
    require_cmd sudo
    sudo_cmd="sudo"
  fi

  if [[ ! -d "${INSTALL_DIR}" ]]; then
    info "Creating ${INSTALL_DIR} ..."
    ${sudo_cmd} mkdir -p "${INSTALL_DIR}"
  fi

  local source_path
  local cleanup_tmp=0
  if [[ -f "${SCRIPT_SOURCE}" ]]; then
    source_path="${SCRIPT_SOURCE}"
    info "Using local copy: ${source_path}"
  else
    require_cmd curl
    source_path="$(mktemp)"
    cleanup_tmp=1
    info "Downloading ${BIN_NAME} from ${REPO_RAW_URL} ..."
    curl -fsSL "${REPO_RAW_URL}" -o "${source_path}" \
      || die "Failed to download ${BIN_NAME}. Check your network connection or the URL."
  fi

  [[ -s "${source_path}" ]] || die "Source script is empty or missing: ${source_path}"

  info "Copying and setting executable permissions (may prompt for your password) ..."
  ${sudo_cmd} install -m 755 "${source_path}" "${INSTALL_DIR}/${BIN_NAME}" \
    || die "Failed to install to ${INSTALL_DIR}. Check write permissions."

  if [[ "${cleanup_tmp}" -eq 1 ]]; then
    rm -f "${source_path}"
  fi

  echo
  if command -v "${BIN_NAME}" >/dev/null 2>&1; then
    info "${BIN_NAME} installed successfully! Run '${BIN_NAME} --help' to get started."
  else
    err "${BIN_NAME} was copied to ${INSTALL_DIR}, but that directory doesn't appear to be on your PATH."
    err "Add it with: export PATH=\"${INSTALL_DIR}:\$PATH\""
  fi

  echo
  info "Checking runtime dependencies (fzf, fd/fdfind, xdg-utils) ..."
  local missing=0
  command -v fzf >/dev/null 2>&1 || { err "Missing dependency: fzf"; missing=1; }
  if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
    err "Missing dependency: fd (Arch/Fedora) or fdfind (Debian/Ubuntu)"
    missing=1
  fi
  command -v xdg-open >/dev/null 2>&1 || { err "Missing dependency: xdg-open (xdg-utils)"; missing=1; }

  if [[ "${missing}" -eq 1 ]]; then
    print_dependency_help
    exit 1
  else
    info "All dependencies are satisfied. You're all set!"
  fi
}

main "$@"
