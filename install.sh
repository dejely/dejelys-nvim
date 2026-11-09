#!/usr/bin/env bash
set -euo pipefail

REPOSITORY=https://github.com/dejely/dejelys-nvim.git
ref=${NVIM_SETUP_REF:-v0.3.0}
source_dir=
skip_bootstrap=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --source) [[ $# -ge 2 ]] || { echo '--source needs a directory' >&2; exit 2; }; source_dir=$2; shift 2 ;;
    --skip-bootstrap) skip_bootstrap=1; shift ;;
    --help|-h)
      echo 'Usage: bash install.sh [--source CHECKOUT] [--skip-bootstrap]'
      echo 'Installs config, backs up old config/data/state/cache, and bootstraps tools.'
      echo '--skip-bootstrap only copies config; it skips binaries, plugins and tools.'
      echo 'NVIM_SETUP_REF selects a tag or branch (default: v0.3.0).'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -n ${HOME:-} && $HOME = /* ]] || { echo 'HOME must be an absolute path' >&2; exit 1; }
[[ -z ${NVIM_APPNAME:-} || ${NVIM_APPNAME} = nvim ]] || {
  echo 'Unset NVIM_APPNAME before installing this default nvim configuration.' >&2; exit 1;
}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
cache_home=${XDG_CACHE_HOME:-$HOME/.cache}
for directory in "$config_home" "$data_home" "$state_home" "$cache_home"; do
  [[ $directory = /* ]] || { echo 'XDG directories must be absolute paths' >&2; exit 1; }
done
# Export defaults as well, so nvim and the installer always agree on paths.
export XDG_CONFIG_HOME=$config_home XDG_DATA_HOME=$data_home
export XDG_STATE_HOME=$state_home XDG_CACHE_HOME=$cache_home
export PATH="$HOME/.local/bin:$PATH"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing prerequisite: $1 (see docs/INSTALL.md)" >&2; exit 1; }; }
need git
if [[ $skip_bootstrap = 0 ]]; then
  for tool in curl tar gzip unzip cc make node npm rg fzf; do need "$tool"; done
  if ! command -v sha256sum >/dev/null 2>&1; then need shasum; fi
fi

temporary=$(mktemp -d "${TMPDIR:-/tmp}/dejelys-nvim.XXXXXXXX")
trap 'rm -rf "$temporary"' EXIT
if [[ -n $source_dir ]]; then
  source_dir=$(cd "$source_dir" && pwd -P)
else
  git clone --quiet --depth 1 --branch "$ref" "$REPOSITORY" "$temporary/repository"
  source_dir=$temporary/repository
fi
[[ -f $source_dir/nvim/init.lua && -f $source_dir/nvim/lazy-lock.json ]] || {
  echo 'Source is not a dejelys-nvim checkout' >&2; exit 1;
}

download() {
  local url=$1 destination=$2 expected=$3 actual
  curl --fail --location --retry 3 --silent --show-error "$url" -o "$destination"
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$destination"); actual=${actual%% *}
  else
    actual=$(shasum -a 256 "$destination"); actual=${actual%% *}
  fi
  [[ $actual = "$expected" ]] || { echo "Checksum mismatch: $url" >&2; exit 1; }
}

install_binaries() {
  local platform machine nvim_hash ts_hash nvim_asset ts_asset
  platform=$(uname -s); machine=$(uname -m)
  case "$platform/$machine" in
    Linux/x86_64)
      nvim_asset=nvim-linux-x86_64; ts_asset=tree-sitter-linux-x64
      nvim_hash=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
      ts_hash=7ed56d152c52437397b9fcaa43cf341f49933cecc1ca291843f0d347c6e2cb3a ;;
    Linux/aarch64|Linux/arm64)
      nvim_asset=nvim-linux-arm64; ts_asset=tree-sitter-linux-arm64
      nvim_hash=8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815
      ts_hash=34fcc5c4fa7bdd2058a2a45a03b6eb9a49b03a93b6d52ec750f99b1516d98d33 ;;
    Darwin/arm64)
      nvim_asset=nvim-macos-arm64; ts_asset=tree-sitter-macos-arm64
      nvim_hash=1dbd148222b051ba6c307c4d17a318ed083df018a4f6a5a0ce46955ffc9ab87b
      ts_hash=5a08b66e5713b0c69691611250b2191d07139647a3c6e39ba85954284b634d2d ;;
    Darwin/x86_64)
      nvim_asset=nvim-macos-x86_64; ts_asset=tree-sitter-macos-x64
      nvim_hash=481424f1dbc85f637d57e47d27d042aa9c883e5a4fe9ee64fc4ee9573b221998
      ts_hash=fefe3a26e93d4ef7a16711c18587801d7d96c3dec3305db112fe4143cd900d91 ;;
    *) echo "Unsupported platform: $platform/$machine. Use --skip-bootstrap for config only." >&2; exit 1 ;;
  esac
  mkdir -p "$HOME/.local/bin" "$HOME/.local/opt/dejelys-nvim"
  if ! command -v nvim >/dev/null 2>&1 || ! nvim --clean --headless '+lua if vim.fn.has("nvim-0.12") == 0 then vim.cmd("cquit 1") end' +qa >/dev/null 2>&1; then
    echo 'Installing Neovim v0.12.6 locally...'
    download "https://github.com/neovim/neovim/releases/download/v0.12.6/$nvim_asset.tar.gz" "$temporary/nvim.tar.gz" "$nvim_hash"
    tar -xzf "$temporary/nvim.tar.gz" -C "$temporary"
    mkdir -p "$HOME/.local/opt/dejelys-nvim"
    # A unique destination preserves previous installed binaries and symlink targets.
    local release_dir
    release_dir=$(mktemp -d "$HOME/.local/opt/dejelys-nvim/nvim-v0.12.6.XXXXXXXX")
    cp -R "$temporary/$nvim_asset/." "$release_dir/"
    if [[ -e $HOME/.local/bin/nvim || -L $HOME/.local/bin/nvim ]]; then
      mv "$HOME/.local/bin/nvim" "$release_dir/previous-nvim-launcher"
      echo "Previous nvim launcher saved in $release_dir/previous-nvim-launcher"
    fi
    ln -s "$release_dir/bin/nvim" "$HOME/.local/bin/nvim"
    hash -r
  fi
  local ts_version=
  if command -v tree-sitter >/dev/null 2>&1; then ts_version=$(tree-sitter --version | awk '{print $2}'); fi
  if ! nvim --clean --headless "+lua if not vim.version.ge(vim.version.parse('$ts_version') or {0,0,0}, {0,26,1}) then vim.cmd('cquit 1') end" +qa >/dev/null 2>&1; then
    echo 'Installing tree-sitter v0.27.2 locally...'
    download "https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.2/$ts_asset.gz" "$temporary/tree-sitter.gz" "$ts_hash"
    gzip -dc "$temporary/tree-sitter.gz" > "$temporary/tree-sitter"
    chmod +x "$temporary/tree-sitter"
    if [[ -e $HOME/.local/bin/tree-sitter || -L $HOME/.local/bin/tree-sitter ]]; then
      local saved
      saved=$(mktemp -d "$HOME/.local/opt/dejelys-nvim/tree-sitter-backup.XXXXXXXX")
      mv "$HOME/.local/bin/tree-sitter" "$saved/tree-sitter"
      echo "Previous tree-sitter launcher saved in $saved/tree-sitter"
    fi
    mv "$temporary/tree-sitter" "$HOME/.local/bin/tree-sitter"
    hash -r
  fi
  nvim --clean --headless '+lua assert(vim.fn.has("nvim-0.12") == 1)' +qa
  tree-sitter --version
}

if [[ $skip_bootstrap = 0 ]]; then install_binaries; fi

# Stage a full copy before moving anything in the existing installation.
mkdir -p "$temporary/config" "$config_home" "$state_home/dejelys-nvim/backups"
cp -R "$source_dir/nvim/." "$temporary/config/"
backup=$(mktemp -d "$state_home/dejelys-nvim/backups/$(date +%Y%m%d-%H%M%S).XXXXXXXX")
index=0
for directory in "$config_home/nvim" "$data_home/nvim" "$state_home/nvim" "$cache_home/nvim"; do
  index=$((index + 1))
  printf '%s\n' "$directory" > "$backup/$index.path"
  # Some users point multiple XDG roots at the same directory.
  if [[ -e $directory || -L $directory ]]; then
    mv "$directory" "$backup/$index"
  fi
done
mkdir -p "$config_home/nvim"
cp -R "$temporary/config/." "$config_home/nvim/"
echo "Config installed at: $config_home/nvim"
echo "Previous files saved at: $backup"

if [[ $skip_bootstrap = 0 ]]; then
  # Install missing plugins at their lockfile revisions; never update existing pins.
  nvim --headless '+Lazy! restore' +qa
  export NVIM_SETUP_BOOTSTRAP="$source_dir/scripts/bootstrap.lua"
  # cquit makes Lua failures visible to a pipe installer as a nonzero exit.
  nvim --headless '+lua local ok, err = pcall(dofile, vim.env.NVIM_SETUP_BOOTSTRAP); if not ok then print(err); vim.cmd("cquit 1") end' +qa
fi
echo 'Installed. Add ~/.local/bin to PATH if needed, then run nvim.'
echo 'Optional editor defaults: export EDITOR=nvim VISUAL=nvim'
echo 'Shortcuts: https://github.com/dejely/dejelys-nvim/blob/main/docs/SHORTCUTS.md'
