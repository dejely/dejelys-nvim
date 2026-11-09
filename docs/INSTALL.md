# Installation and maintenance

## Prerequisites

The full installer supports Linux (x86_64, ARM64) and macOS (Intel, Apple Silicon).
WSL with a Linux userland follows the Linux path. Native Windows installation is
not automated. A modern terminal with true color is recommended; Kitty supports
the punctuation shortcuts used here. A Nerd Font is optional for icons.

Have these commands available before running the installer:

- `bash`, `git`, `curl`, `tar`, `gzip`, and `unzip`.
- `cc` (a working C compiler) and `make` for syntax parsers.
- Node.js LTS and `npm` for JS-based language servers and Prettier.
- `sha256sum` or macOS `shasum` for download verification.
- `rg` (ripgrep) and `fzf` for project searching and file pickers. fzf-lua can
  download fzf on demand, but installing it explicitly makes setup predictable.

Examples (package versions depend on your distribution):

```sh
# Fedora
sudo dnf install bash git curl tar gzip unzip gcc make nodejs npm ripgrep fzf

# Ubuntu / Debian
sudo apt update
sudo apt install bash git curl tar gzip unzip build-essential nodejs npm ripgrep fzf

# macOS with Homebrew; the compiler comes from Apple's command-line tools
xcode-select --install
brew install git node ripgrep fzf
```

If your distribution's Node is outdated, install an active LTS release using
[Node's installation instructions](https://nodejs.org/en/download).

Neovim 0.12+ and tree-sitter CLI 0.26.1+ are required by the pinned setup.
The installer preserves compatible installations. Otherwise it downloads
Neovim **0.12.6** and tree-sitter **0.27.2** from their official GitHub releases,
checks fixed SHA-256 hashes, and installs them under your home directory.
It does not run a package manager or request root access.

Optional tools:

- Rust: `rustup component add rust-analyzer rustfmt` if you use rustup, or install
  those tools with your package manager. Both must be on PATH.
- Clipboard: `wl-clipboard` on Wayland or `xclip` on X11. macOS normally supplies
  `pbcopy` and `pbpaste`. Confirm availability with `:checkhealth vim.provider`.
- A Nerd Font selected in your terminal's settings for file and status icons.

## One-line install

Close running Neovim instances, then:

```sh
curl -fsSL https://raw.githubusercontent.com/dejely/dejelys-nvim/v0.1.0/install.sh | bash
```

This uses the tagged **v0.1.0** configuration. Downloaded shell code runs with your
user permissions. To inspect it first, use the checkout method below.

The installer:

1. Checks prerequisites and obtains the tagged configuration.
2. Installs compatible local Neovim/tree-sitter binaries if needed.
3. Backs up existing Neovim config, data, state, and cache (including symlinks).
4. Copies `nvim/` into the active Neovim configuration directory.
5. Installs plugins at `lazy-lock.json` revisions using Lazy restore.
6. Installs language servers, formatters, and syntax parsers synchronously.

It prints the backup directory. Do not run it while another Neovim session is
writing these directories. If tool setup fails, the backup is retained and the
script returns a nonzero status. See [failure recovery](TROUBLESHOOTING.md#installation-failed).

## Inspectable checkout install

```sh
git clone --branch v0.1.0 https://github.com/dejely/dejelys-nvim.git
cd dejelys-nvim
less install.sh
bash install.sh --source "$PWD"
```

The installer copies configuration files; it does not symlink your checkout.
Editing the checkout alone will not update the active config.

For config files only, without installing binaries/plugins/tools:

```sh
bash install.sh --source "$PWD" --skip-bootstrap
```

Config-only mode still backs up all four Neovim directories. Dependencies and
first-launch downloads are then your responsibility. It is useful for testing
or a machine with a separately managed toolchain, not an offline full install.

## Directories and backups

| Content | Default location |
| --- | --- |
| Config | `~/.config/nvim` |
| Plugins, Mason tools, parsers | `~/.local/share/nvim` |
| Undo and last-directory state | `~/.local/state/nvim` |
| Cache | `~/.cache/nvim` |
| Installer backups | `~/.local/state/dejelys-nvim/backups/<timestamp>.<unique suffix>` |
| Downloaded Neovim | `~/.local/opt/dejelys-nvim/nvim-v0.12.6.<unique suffix>` |
| Local launchers | `~/.local/bin/nvim`, `~/.local/bin/tree-sitter` when installed |

`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME` are
respected. They must be absolute paths. This installer targets the default
`nvim` application name; unset `NVIM_APPNAME` first if you use a different one.

Backups contain numbered entries with a sibling `.path` file recording each
original location: 1=config, 2=data, 3=state, 4=cache. Missing original directories
have a path record but no saved entry. Previous local binary launchers, if replaced, are stored separately
at the exact path printed during installation. System binaries are never changed.

## Restore a previous configuration

Close Neovim and use a checkout of this repository:

```sh
bash scripts/restore.sh "$HOME/.local/state/dejelys-nvim/backups/PASTE-THE-EXACT-BACKUP-NAME"
```

The restore script moves the new installation aside and restores saved entries.
It prints where the displaced files went. It also handles a fresh installation
with no original files by moving the new directories aside. It does not remove
locally downloaded binaries or edit your shell. To restore an older local binary
launcher, move the current launcher aside and move the saved `previous-nvim-launcher`
back to `~/.local/bin/nvim` using the path printed by the installer.

## First launch

Ensure `~/.local/bin` is on PATH, then run `nvim` or `nvim /path/to/project`.
Add these to your own shell startup file if desired:

```sh
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim VISUAL=nvim
```

The installer leaves your shell and desktop settings alone. The terminal split
uses `$SHELL` when executable, falling back to zsh or sh. Your shell's own startup
configuration runs normally. See [SHORTCUTS.md](SHORTCUTS.md) for editor usage.

## Updates

For personal changes, edit the active config and keep your own copy in Git.
Re-running the installer makes another backup and replaces the config and plugin
directories with a fresh copy. It preserves the previous undo history in that
backup rather than merging it into the new installation.

For a future release, change both `v0.1.0` occurrences (URL and ref):

```sh
curl -fsSL https://raw.githubusercontent.com/dejely/dejelys-nvim/v0.1.0/install.sh | NVIM_SETUP_REF=v0.1.0 bash
```

To intentionally try the development branch:

```sh
curl -fsSL https://raw.githubusercontent.com/dejely/dejelys-nvim/main/install.sh | NVIM_SETUP_REF=main bash
```

`:Lazy restore` restores the checked-in plugin versions. `:Lazy update` updates
plugins and changes the active lockfile; review changes before committing that
lockfile. `:TSUpdate` updates parsers for the installed treesitter plugin.
Mason tools are installed at registry-current versions during setup; their
versions are not frozen by the plugin lockfile.

## Upstream references

- [Neovim installation](https://github.com/neovim/neovim/blob/master/INSTALL.md)
- [nvim-treesitter requirements](https://github.com/nvim-treesitter/nvim-treesitter#requirements)
- [Conform documentation](https://github.com/stevearc/conform.nvim)
- [Mason documentation](https://github.com/mason-org/mason.nvim)
