# ⚡ frun

**A fast, fuzzy CLI file launcher for the terminal.**
Instantly search, preview, and open any file or folder — powered by [`fzf`](https://github.com/junegunn/fzf) and [`fd`](https://github.com/sharkdp/fd), and portable across every major Linux distro.

![shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![license: GPLv3](https://img.shields.io/badge/license-GPLv3-blue)
![platform: linux](https://img.shields.io/badge/platform-Linux-informational)

---

## Table of contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation-step-by-step)
- [Usage](#️-usage)
- [How it works](#-how-it-works)
- [Troubleshooting](#️-troubleshooting)
- [Uninstalling](#-uninstalling)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

- **Blazing-fast fuzzy search** over any directory tree, powered by `fd` + `fzf`.
- **Scoped scanning** — pass a directory and `frun` never looks outside it.
- **Hidden-file control** — dotfiles are ignored by default; opt in with one flag.
- **Powerful exclusions** — skip specific extensions, filenames, or whole directories (`node_modules`, `.git`, `.venv`, `.mp4`, and anything else you name).
- **Rich split-pane preview** — directory listings on one side, syntax-aware file previews on the other (uses `bat`/`eza`/`tree` if installed, with safe plain-text fallbacks).
- **Zero-lag launching** — press Enter and your file opens in its default app via `xdg-open`, fired off asynchronously so your terminal is never blocked or flooded with output.
- **True cross-distro portability** — auto-detects `fd` vs. `fdfind` so the same script runs unmodified on Arch, Fedora, Ubuntu, Debian, Mint, and derivatives.
- **Single self-contained script** — no runtime dependencies beyond standard `bash` and the three tools listed below.
- **Free and open source**, licensed under the **GNU General Public License v3.0**.

---

## 📋 Prerequisites

`frun` is a thin, well-behaved wrapper around three well-known tools. Install these first.

| Tool | Purpose | Debian/Ubuntu/Mint | Fedora | Arch/Manjaro |
|---|---|---|---|---|
| [`fzf`](https://github.com/junegunn/fzf) | Fuzzy picker UI | `sudo apt install fzf` | `sudo dnf install fzf` | `sudo pacman -S fzf` |
| [`fd`](https://github.com/sharkdp/fd) | Fast recursive search | `sudo apt install fd-find` *(binary is `fdfind`)* | `sudo dnf install fd-find` | `sudo pacman -S fd` |
| `xdg-utils` | Provides `xdg-open` | `sudo apt install xdg-utils` | `sudo dnf install xdg-utils` | `sudo pacman -S xdg-utils` |

> **Note:** Debian/Ubuntu/Mint package `fd` under the binary name `fdfind` due to a naming conflict with an unrelated package already in their repos. `frun` detects and handles this automatically — you don't need to alias or configure anything.

**Optional, for richer previews (auto-detected if present):**
- [`bat`](https://github.com/sharkdp/bat) — syntax-highlighted file previews
- [`eza`](https://github.com/eza-community/eza) — colorized, modern directory listings
- `tree` — fallback directory listings if neither of the above is installed

---

## 🚀 Installation (step-by-step)

### Step 1 — Install the prerequisites

Pick the command for your distro from the table above and run it in a terminal. For example, on Ubuntu/Debian/Mint:

```bash
sudo apt update
sudo apt install fzf fd-find xdg-utils
```

### Step 2 — Get the source

Clone the repository:

```bash
git clone https://github.com/Jain1shh/frun.git
cd frun
```

### Step 3 — Run the installer

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Detect whether it needs `sudo` (only if `/usr/local/bin` isn't writable by your user).
2. Copy `frun.sh` into `/usr/local/bin/frun` with executable permissions (`755`).
3. Verify that `fzf`, `fd`/`fdfind`, and `xdg-open` are all present, and print clear install commands for anything still missing.

### Step 4 — Confirm it's on your `PATH`

`/usr/local/bin` is on `PATH` by default on virtually every Linux distribution. Confirm with:

```bash
which frun
```

If nothing prints, add it to your shell's startup file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Step 5 — Run it

```bash
frun --help
```

If that prints the usage banner, you're fully set up. Try it for real:

```bash
frun ~/Documents
```

### Alternative — one-line remote install

```bash
curl -fsSL https://raw.githubusercontent.com/Jain1shh/frun/main/install.sh | bash
```

This downloads `frun.sh` directly and runs the same install steps as above.

### Alternative — fully manual install

If you'd rather skip `install.sh` entirely:

```bash
git clone https://github.com/Jain1shh/frun.git
cd frun
chmod +x frun.sh
sudo install -m 755 frun.sh /usr/local/bin/frun
```

### Installing to a different location

By default, `install.sh` installs to `/usr/local/bin`. Override this with the `FRUN_INSTALL_DIR` environment variable — useful for a per-user install without `sudo`:

```bash
mkdir -p ~/.local/bin
FRUN_INSTALL_DIR="$HOME/.local/bin" ./install.sh
```

Make sure `~/.local/bin` is on your `PATH` (most distros add it automatically if the directory exists at login).

---

## 🕹️ Usage

```
frun [OPTIONS] [DIRECTORY]
```

If no directory is given, `frun` searches the current working directory.

### Basic

```bash
frun
```
Launch the picker rooted at the current directory.

```bash
frun ~/Projects
```
Search only inside `~/Projects`.

### Directory Aliases

If you frequently search inside a particular directory, you can create a shell alias for it.

```bash
alias frunproj='frun ~/Projects'
alias frundoc='frun ~/Documents'
```

Now you can simply run:

```bash
frunproj
```

to search inside `~/Projects`, or:

```bash
frundoc
```

to search inside `~/Documents`.

This is useful for directories you search frequently, so you don't have to type the full path every time.

### Include hidden files

```bash
frun --hidden ~/dotfiles
# or
frun -H ~/dotfiles
```
By default, dotfiles and hidden directories (`.git`, `.config`, etc.) are skipped.

### Exclude by extension

```bash
frun -e mp4 -e mkv -e log ~/Downloads
```
Repeat `-e`/`--exclude-ext` for each extension you want to skip.

### Exclude by exact filename

```bash
frun -n Thumbs.db -n .DS_Store ~/Pictures
```

### Exclude by directory name

```bash
frun -d node_modules -d .git -d .venv ~/Code
```
Matches the directory name anywhere in the tree — no need to specify full paths.

### Combine everything

```bash
frun --hidden -e mp4 -e iso -d node_modules -d .git -d target ~/Workspace
```

### Full flag reference

```
ARGUMENTS:
  DIRECTORY                  Directory to search (default: current directory)

OPTIONS:
  -H, --hidden                Include hidden files and directories
  -e, --exclude-ext EXT       Exclude a file extension (repeatable)
  -n, --exclude-name NAME     Exclude an exact filename (repeatable)
  -d, --exclude-dir NAME      Exclude a directory by name (repeatable)
  -v, --version                Print version and exit
  -u, --update                 Check for a newer release and self-update in place.
  -h, --help                   Show help and exit
```

### Keybindings inside the picker

| Key | Action |
|---|---|
| `Enter` | Open the highlighted file/folder in its default app |
| `Esc` / `Ctrl-C` | Quit without opening anything |
| `Ctrl-/` | Toggle the preview pane |
| `↑` / `↓` or type to filter | Navigate / fuzzy search |

---

## 🧠 How it works

1. `frun` resolves the correct `fd` binary for your distro (`fd` or `fdfind`).
2. It builds an `fd` command scoped strictly to your target directory, applying your hidden-file and exclusion flags as native `fd` filters (fast, since filtering happens at the search layer, not after).
3. The result stream is piped into `fzf`, configured with a rounded-border layout and a live split-pane preview.
4. The preview pane re-invokes `frun` itself in a hidden internal mode to render either a directory listing or a file preview — this keeps preview rendering fully portable without relying on shell-specific function exporting.
5. On `Enter`, the selected path is handed to `xdg-open`, launched with `nohup ... & disown` so it detaches completely from the terminal session — no blocking, no leftover output.

---

## 🛠️ Troubleshooting

**"Neither 'fd' nor 'fdfind' was found in PATH"**
Install `fd-find` (Debian/Ubuntu) or `fd` (Arch/Fedora) — see the Prerequisites table above.

**"command not found: frun" after installing**
The install directory isn't on your `PATH`. See [Step 4](#step-4--confirm-its-on-your-path) above.

**Nothing opens when I press Enter**
Confirm `xdg-open <some-file>` works on its own outside `frun`. This usually indicates a missing or misconfigured desktop MIME database (common on minimal/headless installs) — try `sudo apt install xdg-desktop-portal` or your distro's equivalent.

**Preview pane is empty for text files**
Install `bat` for the best experience; `frun` falls back to `head`/`file` automatically if it's absent.

**Permission denied during `./install.sh`**
The installer only invokes `sudo` if `/usr/local/bin` isn't writable by your user. If you'd rather avoid `sudo` entirely, see [Installing to a different location](#installing-to-a-different-location).

---

## 🗑️ Uninstalling

```bash
sudo rm /usr/local/bin/frun
```

(Or `rm "$FRUN_INSTALL_DIR/frun"` if you installed to a custom location.)

---

## 🤝 Contributing

Issues and pull requests are welcome at [github.com/Jain1shh/frun](https://github.com/Jain1shh/frun). Please keep changes POSIX-friendly where possible and test against both `fd` and `fdfind` naming before submitting. By contributing, you agree that your contributions will be licensed under the GPLv3, matching the rest of the project.

---

## 📄 License

`frun` is free software, licensed under the **GNU General Public License v3.0 (GPLv3)**.

This means you're free to use, study, modify, and redistribute `frun`, provided that:
- any distributed modified versions are also licensed under the GPLv3,
- the source code remains available to anyone you distribute the software to, and
- you preserve the copyright and license notices.

See the [`LICENSE`](LICENSE) file for the full legal text.

```
frun - A fast, fuzzy, cross-distro CLI file launcher.
Copyright (C) 2026  Jainish

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
```

---

## Contact

GitHub: [@Jain1shh](https://github.com/Jain1shh)