# Workflow memory check

Measured on this host on 2026-11-14, using three fresh runs per scenario.
Values are median PSS in MiB, with the observed range in parentheses.

| Workload | Before | After |
| --- | --- | --- |
| Idle text file | 25.8 (23.9–25.9) | 28.0 (27.9–37.4) |
| 2.27 MB Lua comment file, completion requested | 173.2 (172.6–174.5) | 41.9 (39.6–41.9) |
| Interpreter Rust project, completion requested | 692.8 (691.5–693.9) | 694.3 (685.8–694.7) |

PSS includes Neovim and its descendants, including zsh and language servers.
Kitty is excluded. Each run used an embedded 120×40 UI, isolated HOME/XDG state,
the same installed/locked plugins and tools, and its temporary project as cwd.
The shell used an empty temporary home, so these numbers exclude personal zsh
startup customization. Samples were taken after 1.5 seconds for idle/large files
and 20 seconds for Rust; startup and project-analysis work can still vary.

The Rust fixture copied the interpreter project's source and Cargo manifest,
with its normal standard-library analysis. The large fixture contained 54,000
42-byte comment lines. Completion was requested by entering insert mode; buffer
completion may fall back behind LSP suggestions in the original configuration.
These measurements are workload samples, not a VS Code comparison or a claim
that every process had reached a steady state.

Large-file memory fell substantially because highlighting, buffer-word indexing,
and the Lua server are skipped. Idle and Rust measurements do not establish a
RAM reduction. Opening a text file still loads the file-related plugins; an
empty directory session defers more plugins until an actual file is opened.

A separate three-run Rust cache-capacity-64 experiment measured 690.9 MiB median
(range 670.7–696.7), overlapping the default-cache measurements. The result did
not consistently improve memory, so the default cache and full ordinary-file
language features were retained. No proc-macro/check-on-save features were disabled.

Validation: 31 tests passed with pynvim, installed plugins, Lua LSP, Rust, and
CodeLLDB available. The formatting/EditorConfig/Lua-LSP smoke check also passed.
The embedded tests verify input at Neovim's API boundary. Modified shortcut
delivery through Kitty could not be reliably verified with remote key injection;
the documented Space mappings remain available.

A separate real Kitty check verified command-palette and terminal hide/show
fallbacks through its PTY. Kitty alone measured 78.3 MiB PSS in that single
check; it is not included in the workload table.
