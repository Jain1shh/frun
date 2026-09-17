#!/usr/bin/env bash
#
# frun — A fast, fuzzy, cross-distro file launcher inspired by KDE's KRunner.
# Built on top of fzf + fd, with safe previews and asynchronous xdg-open launching.
#
# Repository: https://github.com/<your-username>/frun
#
# Copyright (C) 2026  Jainish
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# Requires: bash 4+, fzf, fd (or fdfind), xdg-open
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# -----------------------------------------------------------------------------
# Constants & Globals
# -----------------------------------------------------------------------------

readonly SCRIPT_NAME="$(basename "${0}")"
readonly VERSION="1.0.0"

# Resolve the absolute path to this script so it can safely re-invoke itself
# for preview rendering, regardless of how or from where it was called
# (PATH lookup, relative path, symlink, etc.).
if command -v readlink >/dev/null 2>&1 && readlink -f "${BASH_SOURCE[0]}" >/dev/null 2>&1; then
  readonly SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
elif command -v realpath >/dev/null 2>&1; then
  readonly SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
else
  readonly SCRIPT_PATH="${BASH_SOURCE[0]}"
fi

TARGET_DIR="."
SHOW_HIDDEN=0
declare -a EXCLUDE_EXTS=()
declare -a EXCLUDE_NAMES=()
declare -a EXCLUDE_DIRS=()

FD_BIN=""

# -----------------------------------------------------------------------------
# Output helpers
# -----------------------------------------------------------------------------

_color() {
  # Only emit ANSI color codes when connected to a real terminal.
  if [[ -t 2 ]]; then
    printf '\033[%sm' "$1"
  fi
}
_reset() { _color "0"; }

info() { printf '%s[frun]%s %s\n' "$(_color '1;34')" "$(_reset)" "$*" >&2; }
warn() { printf '%s[frun]%s %s\n' "$(_color '1;33')" "$(_reset)" "$*" >&2; }
err()  { printf '%s[frun]%s %s\n' "$(_color '1;31')" "$(_reset)" "$*" >&2; }
die()  { err "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
${SCRIPT_NAME} v${VERSION}
A KRunner-inspired fuzzy file launcher for the terminal, built on fzf + fd.
Licensed under the GNU General Public License v3.0.

USAGE:
  ${SCRIPT_NAME} [OPTIONS] [DIRECTORY]

ARGUMENTS:
  DIRECTORY                  Directory to search (default: current directory).
                              Scanning is strictly confined to this path.

OPTIONS:
  -H, --hidden                Include hidden files and directories (dotfiles).
                              By default, hidden entries are ignored.
  -e, --exclude-ext EXT       Exclude a file extension (repeatable).
                              Example: -e mp4 -e log
  -n, --exclude-name NAME     Exclude an exact filename (repeatable).
                              Example: -n Thumbs.db -n .DS_Store
  -d, --exclude-dir NAME      Exclude a directory by name, anywhere in the
                              tree (repeatable).
                              Example: -d node_modules -d .git -d .venv
  -v, --version                Print version information and exit.
  -h, --help                   Show this help message and exit.

EXAMPLES:
  ${SCRIPT_NAME}
      Launch the fuzzy finder rooted at the current directory.

  ${SCRIPT_NAME} ~/Projects
      Search inside ~/Projects only.

  ${SCRIPT_NAME} --hidden ~/dotfiles
      Include hidden files while searching ~/dotfiles.

  ${SCRIPT_NAME} -e mp4 -e mkv -d node_modules -d .git ~/Downloads
      Search ~/Downloads, skipping video files and common junk directories.

KEYBINDINGS (inside the picker):
  Enter        Open the highlighted file/folder with the system default app.
  Esc / Ctrl-C Quit without opening anything.
  Ctrl-/       Toggle the preview pane.

DEPENDENCIES:
  fzf          https://github.com/junegunn/fzf
  fd / fdfind  https://github.com/sharkdp/fd
  xdg-open     part of the xdg-utils package

EOF
}

# -----------------------------------------------------------------------------
# Dependency resolution
# -----------------------------------------------------------------------------

check_dependencies() {
  # Auto-detect the fast-find binary. Arch/Fedora/Homebrew ship it as `fd`;
  # Debian/Ubuntu/Mint ship it as `fdfind` (a name collision with an
  # unrelated package forced the rename upstream).
  if command -v fd >/dev/null 2>&1; then
    FD_BIN="fd"
  elif command -v fdfind >/dev/null 2>&1; then
    FD_BIN="fdfind"
  else
    die "Neither 'fd' nor 'fdfind' was found in PATH. Install the 'fd-find' package (Debian/Ubuntu) or 'fd' (Arch/Fedora/Homebrew) and try again."
  fi

  command -v fzf >/dev/null 2>&1 \
    || die "'fzf' was not found in PATH. Install it: https://github.com/junegunn/fzf#installation"

  command -v xdg-open >/dev/null 2>&1 \
    || die "'xdg-open' was not found in PATH. Install the 'xdg-utils' package for your distribution."
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

parse_args() {
  local positional_set=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -H|--hidden)
        SHOW_HIDDEN=1
        shift
        ;;
      -e|--exclude-ext)
        [[ $# -ge 2 ]] || die "Option '$1' requires an argument (e.g. -e mp4)."
        EXCLUDE_EXTS+=("${2#.}")
        shift 2
        ;;
      -n|--exclude-name)
        [[ $# -ge 2 ]] || die "Option '$1' requires an argument (e.g. -n Thumbs.db)."
        EXCLUDE_NAMES+=("$2")
        shift 2
        ;;
      -d|--exclude-dir)
        [[ $# -ge 2 ]] || die "Option '$1' requires an argument (e.g. -d node_modules)."
        EXCLUDE_DIRS+=("$2")
        shift 2
        ;;
      -v|--version)
        printf '%s v%s\n' "${SCRIPT_NAME}" "${VERSION}"
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "Unknown option: '$1'. Run '${SCRIPT_NAME} --help' for usage."
        ;;
      *)
        if [[ "${positional_set}" -eq 1 ]]; then
          die "Only one directory argument is allowed. Unexpected extra argument: '$1'."
        fi
        TARGET_DIR="$1"
        positional_set=1
        shift
        ;;
    esac
  done
}

# -----------------------------------------------------------------------------
# Directory validation
# -----------------------------------------------------------------------------

validate_target_dir() {
  if [[ ! -e "${TARGET_DIR}" ]]; then
    die "Target path does not exist: '${TARGET_DIR}'"
  fi
  if [[ ! -d "${TARGET_DIR}" ]]; then
    die "Target path is not a directory: '${TARGET_DIR}'"
  fi
  if [[ ! -r "${TARGET_DIR}" || ! -x "${TARGET_DIR}" ]]; then
    die "Target directory is not readable/accessible: '${TARGET_DIR}' (check permissions)."
  fi

  # Normalize to an absolute path so behavior is identical regardless of the
  # caller's current working directory, and so previews resolve correctly.
  TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"
}

# -----------------------------------------------------------------------------
# Preview renderer (invoked recursively by fzf, once per highlighted entry)
# -----------------------------------------------------------------------------

render_preview() {
  local rel="$1"
  local target="${FRUN_TARGET_DIR:-.}/${rel}"

  if [[ -d "${target}" ]]; then
    printf '\033[1;34mDirectory:\033[0m %s\n\n' "${target}"
    if command -v eza >/dev/null 2>&1; then
      eza -la --color=always --group-directories-first "${target}" 2>/dev/null
    elif command -v tree >/dev/null 2>&1; then
      tree -C -L 2 "${target}" 2>/dev/null
    else
      ls -la --color=always "${target}" 2>/dev/null
    fi
    return 0
  fi

  if [[ -f "${target}" ]]; then
    if command -v bat >/dev/null 2>&1; then
      bat --style=numbers --color=always --paging=never --line-range=:200 "${target}" 2>/dev/null && return 0
    fi

    if file --mime "${target}" 2>/dev/null | grep -qE 'text/|charset=us-ascii|charset=utf-8'; then
      head -n 200 "${target}" 2>/dev/null
    else
      printf '\033[1;33mBinary or non-text file:\033[0m %s\n\n' "${target}"
      file "${target}" 2>/dev/null || true
      printf '\n\033[2mSize:\033[0m %s\n' "$(du -h "${target}" 2>/dev/null | cut -f1)"
    fi
    return 0
  fi

  printf '\033[1;31mPath no longer exists:\033[0m %s\n' "${target}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  # Internal dispatch: fzf re-invokes this script for every preview render.
  # This keeps preview logic portable (bash function, no shell-quoting
  # gymnastics) instead of relying on the user's $SHELL supporting
  # `export -f`.
  if [[ "${1:-}" == "__preview" ]]; then
    shift
    render_preview "${1:-}"
    exit 0
  fi

  parse_args "$@"
  check_dependencies
  validate_target_dir

  # --- Build the fd command -------------------------------------------------
  local -a fd_cmd=("${FD_BIN}" --color never --base-directory "${TARGET_DIR}")

  if [[ "${SHOW_HIDDEN}" -eq 1 ]]; then
    fd_cmd+=(--hidden)
  fi

  if [[ ${#EXCLUDE_EXTS[@]} -gt 0 ]]; then
    local ext
    for ext in "${EXCLUDE_EXTS[@]}"; do
      [[ -n "${ext}" ]] && fd_cmd+=(--exclude "*.${ext}")
    done
  fi

  if [[ ${#EXCLUDE_NAMES[@]} -gt 0 ]]; then
    local nm
    for nm in "${EXCLUDE_NAMES[@]}"; do
      [[ -n "${nm}" ]] && fd_cmd+=(--exclude "${nm}")
    done
  fi

  if [[ ${#EXCLUDE_DIRS[@]} -gt 0 ]]; then
    local dr
    for dr in "${EXCLUDE_DIRS[@]}"; do
      [[ -n "${dr}" ]] && fd_cmd+=(--exclude "${dr}")
    done
  fi

  fd_cmd+=(".")

  # --- Run the picker --------------------------------------------------------
  # Export TARGET_DIR so the recursive __preview invocations know how to
  # resolve the fd-relative paths fzf hands them.
  export FRUN_TARGET_DIR="${TARGET_DIR}"

  local selection=""
  set +o errexit  # fzf exits non-zero on Esc/Ctrl-C; that is not a script error.
  selection="$(
    "${fd_cmd[@]}" 2>/dev/null | fzf \
      --prompt="⚡ frun ❯ " \
      --pointer="➜" \
      --marker="✓" \
      --height="90%" \
      --layout=reverse \
      --border=rounded \
      --info=inline \
      --header="Enter: open the file │ Esc/Ctrl-C: quit │ Ctrl-/: toggle preview" \
      --header-first \
      --bind="ctrl-/:toggle-preview" \
      --preview="${SCRIPT_PATH} __preview {}" \
      --preview-window="right:60%:wrap,border-left" \
      --color="header:italic:dim,border:blue,prompt:magenta,pointer:magenta"
  )"
  set -o errexit

  if [[ -z "${selection}" ]]; then
    info "No selection made. Exiting."
    exit 0
  fi

  local full_path="${TARGET_DIR}/${selection}"

  if [[ ! -e "${full_path}" ]]; then
    die "Selected path no longer exists on disk: ${full_path}"
  fi

  info "Opening: ${full_path}"

  # Launch asynchronously, fully detached from the terminal's process group,
  # with stdout/stderr silenced — the terminal is never blocked or spammed.
  nohup xdg-open "${full_path}" >/dev/null 2>&1 &
  disown

  exit 0
}

main "$@"
