# dejely's nvim

A Neovim setup with a file explorer, searchable files, a bottom terminal,
completion, language servers, formatting, and a dark Catppuccin theme.

## Install

On Linux or macOS, install the [prerequisites](docs/INSTALL.md#prerequisites), then run:

```sh
curl -fsSL https://raw.githubusercontent.com/dejely/dejelys-nvim/v0.1.0/install.sh | bash
```

The installer backs up your existing Neovim config, plugins, state, and cache.
It installs Neovim 0.12.6 and tree-sitter 0.27.2 locally if compatible versions
are missing, verifies those downloads against pinned SHA-256 checksums, and
installs the locked plugins, language tools, and syntax parsers. It does not use
sudo or edit your shell configuration. Close Neovim before installing.

Run `nvim` afterward. If needed, add this to your shell configuration:

```sh
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim VISUAL=nvim
```

For an inspectable installation, dependency instructions, updates, or restoring
your old setup, see [Installation](docs/INSTALL.md).

## Everyday keys

**Space is the leader key.** Press the keys in sequence: `Space f f`, for example.
Most shortcuts use normal mode; press `Esc` first.

| Keys | Action |
| --- | --- |
| `Ctrl+P` or `Space f f` | Find a file |
| `Space f g` | Search project contents |
| `Space f b` | Choose an open file |
| `Ctrl+.` / `Ctrl+,` | Next / previous tab in the top bar |
| `Ctrl+N` | Toggle the file explorer |
| `Space e` | Reveal the current file in the explorer |
| `Ctrl+W`, then `h/j/k/l` | Focus left/down/up/right window |
| `Space f m` | Format the file or selection |
| `gd` / `gr` | Definition / references |
| `K` | Documentation under the cursor |
| `Space r n` | Rename a symbol |
| `:w` / `:q` | Save / close a window (press Enter) |
| `u` / `Ctrl+R` | Undo / redo |
| `Ctrl+O`, then `u` | Undo while typing, then return to insert mode |

The [complete shortcut guide](docs/SHORTCUTS.md) covers movement, selection,
copy/paste, buffers, actual Vim tab pages, completion, diagnostics, Git, terminals,
and the explorer. [Troubleshooting](docs/TROUBLESHOOTING.md) covers terminal keys,
language tools, clipboard support, and installation failures.

## What opens

The explorer appears on the left, your shell opens in a small bottom split, and
focus starts in the editor. That layout is skipped for headless runs, piped input,
diff mode, and restored sessions. Launch with `nvim path/to/project` or
`nvim path/to/file`. With no argument, the last interactive working directory is
restored; open files and shell history are not restored.

## Included

- Catppuccin Macchiato, charcoal background, absolute line numbers, four-space fallback indentation.
- Bufferline, nvim-tree, fzf-lua, lualine, indentation guides, and Git change markers.
- TypeScript/JavaScript, Python, JSON, and Lua language servers installed through Mason.
- Rust language support when `rust-analyzer` is available on PATH.
- StyLua, Prettier, Ruff, and optional rustfmt formatting through Conform.
- Project indentation through `.editorconfig`; manual formatting with project formatter settings.
- Persistent undo under Neovim's state directory.
- Syntax parsers for Rust, JS/TS/TSX, Python, JSON/JSONC, Lua, Vimscript, Markdown, Bash, HTML, CSS, and YAML.
- Plugin revisions recorded in `nvim/lazy-lock.json`.

This is the portable version of my configuration. It chooses your shell and does
not include my desktop shortcuts, terminal font settings, shell customizations,
or CAD environment handling. A Nerd Font is optional but improves file icons.

## Customize

| File after installation | Purpose |
| --- | --- |
| `~/.config/nvim/init.lua` | Leader key and plugin bootstrap |
| `lua/config/options.lua` | Editor settings and tab shortcuts |
| `lua/config/workspace.lua` | Startup layout and remembered directory |
| `lua/config/explorer.lua` | Explorer filters and actions |
| `lua/config/lsp.lua` | Language servers and diagnostics |
| `lua/config/completion.lua` | Completion keys and sources |
| `lua/config/formatting.lua` | Formatters and format shortcut |
| `lua/config/theme.lua` | Theme and terminal colors |
| `lua/plugins/init.lua` | Plugin declarations |

Paths above assume default XDG directories. Restart Neovim after editing Lua.
Use `:Lazy`, `:Mason`, `:ConformInfo`, `:checkhealth`, and `:messages` to inspect
your setup. For development checks, see [tests/README.md](tests/README.md).

## License

MIT for the configuration and installer. Plugins and downloaded tools retain
their own licenses; their source repositories are linked in the plugin declarations.
