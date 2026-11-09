# Troubleshooting

For debugger setup, breakpoints, executable selection, output, and F-key issues,
see [Debugging](DEBUGGING.md#troubleshooting).

## Ctrl+period and Ctrl+comma

The top bar is Bufferline, and its shortcuts use `BufferLineCycleNext` and
`BufferLineCyclePrev`. The terminal must send distinct Ctrl+punctuation keys.
Kitty supports extended keyboard input; support varies in other terminals and
multiplexers. On non-US keyboard layouts, punctuation can require different keys.

1. Close any fzf picker with Esc; pickers consume their own keys.
2. Check `:verbose nmap <C-.>` and `:verbose imap <C-.>`.
3. Run `:BufferLineCycleNext`. If it works, the buffer action is available and
   the remaining issue is mode, terminal key transmission, or an intercepted key.
4. Test without tmux, or choose another pair of keys in `lua/config/options.lua`.

`Space f b` always provides an alternative. `:bn` / `:bp` cycle listed buffers.
`gt` cycles actual Vim tab pages, which are separate from the top-bar buffer list.

## Language server not working

Run `:checkhealth vim.lsp`, `:Mason`, and `:messages`. Language features attach
only to supported filetypes; `:set filetype?` shows the current one. The installer
includes JS/TS, Python, JSON, and Lua servers. Rust needs a separate
`rust-analyzer` installation on PATH. Restart Neovim after installing it.

For Lua, config files use the Neovim config directory as the workspace root.
Other Lua projects look for .luarc.json, .luarc.jsonc, or .git and avoid selecting
the home directory as their workspace.

## Shortcut popup does not appear

Use normal mode (Esc) and try Ctrl+H or Space ?. Pausing after Space also opens
leader-key hints. Check `:verbose nmap <C-h>` and `:Lazy` for which-key.nvim.
If the terminal intercepts Ctrl+H or sends it as Backspace, Space ? is the
alternative. This binding deliberately does not apply in insert or terminal
input mode, where Ctrl+H normally erases a character.

## Session did not restore

Start with `nvim` or `nvim /path/to/project`. Explicit file arguments, diff mode,
piped stdin, headless invocations, and external `-S` sessions bypass the automatic
session flow. Run `:pwd`: sessions are selected by the current working directory.
Use Space s s to save manually, then restart or use Space s r to restore. Save
or discard modified buffers before a manual restore.

The bottom terminal restarts its shell rather than replaying jobs. Unsaved text
is not session data. SessionStop prevents autosaving only until the next launch.
Headless checks never autosave. Two interactive editors using the same project
share its session file; the last one to exit writes the most recent layout.

## Formatting does nothing

Use `:ConformInfo` to see the selected formatter, executable path, and log.
`Space f m` is manual; formatting on save is not enabled. Install tools in
`:Mason` if bootstrap was skipped. Rust formatting requires `rustfmt` on PATH.
Custom languages such as CSL have no configured formatter. LSP fallback works
only if the attached server supports formatting.

External formatters read project config such as .prettierrc, stylua.toml,
pyproject.toml, and rustfmt.toml. `.editorconfig` controls editor indentation and
is read by formatters that support it. Formatters can have their own defaults
when the project supplies no settings.

## Project search or finder fails

Check `rg --version` and `fzf --version` in the terminal. Add them to PATH or
install with your package manager. Searching is rooted at Neovim's current
directory: use `:pwd` and `:cd /path/to/project`. A running terminal shell has
its own directory and needs its own `cd`.

## Explorer is stale or files are hidden

Enter the explorer or press `R` there to refresh. Filesystem watchers are disabled
to avoid watch-limit issues on large projects. Press `f` there to toggle the
dependency/build folder filter. `H` and `I` toggle dotfile and Git-ignored filters.

## Clipboard or icons

Use `:checkhealth vim.provider` and install the clipboard provider for your
display system. Use the `+` register (`"+y`, `"+p`) explicitly. Icons need a Nerd
Font selected in your terminal. This repo does not install fonts or modify
terminal settings.

## Installation failed

The installer exits on errors and prints the backup location before bootstrapping.
Your previous files stay in that backup even if a download or tool installation
fails. Check network access and prerequisites before retrying.

- Missing system dependency: install the named command, then retry.
- Binary checksum mismatch: do not bypass it; verify the release asset and hash.
- Binary does not run: Linux downloads require a compatible glibc environment;
  musl-based systems should provide their own Neovim/tree-sitter builds and use
  config-only installation. On macOS, follow the official Neovim guidance if the
  OS blocks a downloaded executable.
- Mason failure: open `:MasonLog`; check Node/npm and unzip. An unrelated Python
  virtual environment should not globally replace system tooling in your shell.
- Parser failure: check `cc --version` and `tree-sitter --version`, then try `:TSUpdate`.

To resume after prerequisites are fixed without another config backup, from a
checkout of this repo run:

```sh
nvim --headless '+Lazy! restore' +qa
NVIM_SETUP_BOOTSTRAP="$PWD/scripts/bootstrap.lua" nvim --headless \
  '+lua local ok, err = pcall(dofile, vim.env.NVIM_SETUP_BOOTSTRAP); if not ok then print(err); vim.cmd("cquit 1") end' +qa
```

To abandon the installation, use the restore instructions in [INSTALL.md](INSTALL.md).
Repeated installer runs make separate backups; keep the one containing your
original setup. Always close existing Neovim processes before install or restore.

## Undo seems to remove a large block

An uninterrupted insert session can form one undo block. `u` undoes a change
block, not necessarily one character. In insert mode, `Ctrl+G`, then `u` starts
a new undo block without leaving insert mode. Persistent undo applies to saved
files and does not restore deleted files.
