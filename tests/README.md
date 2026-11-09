# Checks

Run from the repository root:

```sh
bash -n install.sh scripts/restore.sh
python3 -m unittest discover -s tests -v
```

The Python tests use temporary homes and XDG directories. They exercise config
installation, four-directory backups, symlink preservation, repeated runs,
restore, overlapping XDG paths, and invalid arguments. They do not download
plugins or binaries. Python is needed only for tests, not installation.

For a full networked installation test without changing your real config:

```sh
test_home=$(mktemp -d)
HOME="$test_home" XDG_CONFIG_HOME="$test_home/config" \
  XDG_DATA_HOME="$test_home/data" XDG_STATE_HOME="$test_home/state" \
  XDG_CACHE_HOME="$test_home/cache" bash install.sh --source "$PWD"
```

Inspect the output and use the same environment to launch Neovim. This checks
your actual OS/architecture; it does not prove support on every advertised
platform. Never reuse a test home containing credentials or important files.

After a full isolated install, validate the installed plugins, real Lua/JS/Python
formatting, EditorConfig behavior, punctuation mappings, and Lua server startup:

```sh
HOME="$test_home" XDG_CONFIG_HOME="$test_home/config" \
  XDG_DATA_HOME="$test_home/data" XDG_STATE_HOME="$test_home/state" \
  XDG_CACHE_HOME="$test_home/cache" NVIM_SETUP_SMOKE="$PWD/tests/smoke.lua" \
  "$test_home/.local/bin/nvim" --headless \
  '+lua local ok, err = pcall(dofile, vim.env.NVIM_SETUP_SMOKE); if not ok then print(err); vim.cmd("cquit 1") end' +qa
```

If a compatible existing Neovim was reused, replace the executable path with
`nvim`. These checks do not automate physical terminal key presses or visual UI
acceptance. GitHub Actions runs the offline shell and installer tests only.
