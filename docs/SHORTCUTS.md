# Shortcut guide

`Ctrl+X` means hold Ctrl while pressing X. `Space f b` means press Space, f,
then b separately. Uppercase keys such as `G` require Shift. Commands beginning
with `:` finish with Enter. Space is the configured leader key.

## Modes

| Key | Action |
| --- | --- |
| `Esc` | Return to normal mode from insert or visual mode |
| `i` / `a` | Type before / after the cursor |
| `I` / `A` | Type at the start / end of the line |
| `o` / `O` | Open a line below / above and type |
| `v` / `V` / `Ctrl+V` | Character / line / block selection |
| `Ctrl+O` in insert mode | Execute one normal-mode command, then resume typing |
| `Ctrl+\`, then `Ctrl+N` in terminal input | Return to terminal normal mode |

## Files, top-bar tabs, and windows

| Keys | Mode | Action |
| --- | --- | --- |
| `Ctrl+P`, `Space f f` | Normal | Find project files |
| `Space f g` | Normal | Search file contents with ripgrep |
| `Space f b` | Normal | Pick an open buffer |
| `Ctrl+H` / `Space ?` | Normal | Show shortcut discovery popup |
| `Ctrl+.` / `Ctrl+,` | Normal, insert, terminal input | Next / previous Bufferline tab |
| `Ctrl+^` (often `Ctrl+Shift+6`) | Normal | Alternate between current and previous file |
| `:edit path/to/file` | Normal | Open a file; use Tab for path completion |
| `:enew` | Normal | Start an unnamed buffer |
| `:bdelete` | Normal | Close the current buffer; unsaved changes require saving or explicit discard |
| `:ls` | Normal | List buffers |
| `:w` | Normal | Save the file |
| `:w new-name` | Normal | Write to a new path |
| `:q` | Normal | Close the current window |
| `:wq` | Normal | Save and close the window |
| `:qa` | Normal | Close all windows; refuses unsaved changes |
| `:q!` | Normal | Close this window and abandon changes if its buffer is unloaded |
| `Ctrl+W`, then `h/j/k/l` | Normal, terminal input | Focus left/down/up/right window |
| `Ctrl+W`, then `w` | Normal, terminal input | Cycle windows |
| `:vsplit path` / `:split path` | Normal | Open a vertical / horizontal split |
| `Ctrl+W`, then `=` | Normal | Equalize window sizes |
| `Ctrl+W`, then `+` / `-` | Normal | Increase / decrease window height |
| `Ctrl+W`, then `>` / `<` | Normal | Increase / decrease window width |
| `:cd path/to/project` | Normal | Change Neovim's working directory |
| `:pwd` | Normal | Show working directory |

The file-shaped tabs along the top are **buffers displayed by Bufferline**,
including the terminal buffer. They differ from Vim's actual tab pages, which
hold window layouts. `:tabnew` creates a Vim tab page, `gt` / `gT` cycles actual
tab pages, and `:tabclose` closes one. `:bn` / `:bp` cycles listed buffers in
Neovim's buffer order; Ctrl+period/comma follows Bufferline's visible order.

The punctuation shortcuts require a terminal that transmits these Ctrl key
combinations. See [terminal troubleshooting](TROUBLESHOOTING.md#ctrlperiod-and-ctrlcomma).

## Shortcut discovery

In normal mode, **Ctrl+H** opens the which-key popup immediately; **Space ?** is
an alternative. Press **Esc** to dismiss it. Press a shown key to continue into
its group or execute the mapping. Press **Space** and pause for about 350 ms to
discover leader shortcuts, grouped into files/formatting, sessions, refactoring,
code, diagnostics, and Git changes. Available language/Git mappings depend on
the current buffer.

Ctrl+H is mapped only in normal mode, preserving backspace while typing and in
terminal shells. Use Esc first when typing in a file; from terminal input, use
Ctrl+backslash then Ctrl+N first. Some terminals send the same code for Backspace
and Ctrl+H; if normal-mode Backspace opens the popup, use Space ? and remap Ctrl+H.

## Sessions

| Keys / command | Action |
| --- | --- |
| `Space s s` / `:SessionSave` | Save the current working directory's session |
| `Space s r` / `:SessionRestore` | Restore its saved session |
| `Space s d` / `:SessionStop` | Stop autosaving until Neovim restarts |

Session keys use normal mode. An interactive `nvim` or `nvim path/to/directory`
restores automatically and saves on exit. Sessions include named file buffers,
cursor positions, editor splits, folds, and Vim tab pages. Storage is under
`stdpath('state')/sessions`, keyed by a hash of the working directory. Each
directory gets its own session; symlink paths to the same directory share one.

The explorer is rebuilt and the bottom shell is fresh after a restart. A manual
restore in the same running Neovim reuses its existing bottom terminal. Shell
jobs, terminal contents, unnamed buffers, unsaved file contents, popup windows,
and plugin settings are not session data. Save edits normally before closing;
sessions do not replace saving files or backups. An empty session with no named
file buffers does not replace a saved session.

Explicit file arguments, diff mode, piped stdin, headless runs, and external
`-S` sessions bypass automatic restoration and autosaving. Manual restore
refuses while any buffer has unsaved changes. SessionStop pauses autosaving
only; it leaves the previous saved session available on the next launch.

Use a consistent project directory (`:pwd` / `:cd`) so the expected session is
selected. Sessions contain file paths and native Vim session commands and stay
in your local state directory; they are not committed to this repository.

## File explorer

Global keys, from normal mode:

| Keys | Action |
| --- | --- |
| `Ctrl+N` | Toggle explorer |
| `Space e` | Reveal current file and focus explorer |

Keys below apply **inside the explorer**, where they override normal editing keys.

| Keys | Action |
| --- | --- |
| `j` / `k` | Select next / previous entry |
| `Enter` / `o` | Open a file or expand/collapse a directory |
| `Backspace` | Close the parent directory |
| `Ctrl+V` / `Ctrl+X` | Open in vertical / horizontal split |
| `Ctrl+T` | Open in an actual Vim tab page |
| `a` | Create a file; end a directory name with `/` |
| `r` | Rename selected entry |
| `d` | Delete selected entry (read the confirmation) |
| `c` / `x` / `p` | Mark for copy / cut / paste |
| `C` | Make selected directory the explorer root |
| `u` | Move explorer root to parent directory |
| `f` | Toggle dependency/build directory filter |
| `H` / `I` | Toggle dotfile / Git-ignored-file filter |
| `R` | Refresh tree |
| `q` | Close explorer |
| `g?` | Show the complete explorer key list |

The custom filter hides node_modules, .git, build, dist, target, .next, .expo,
and __pycache__. Dotfiles and ignored files otherwise start visible. Automatic
filesystem watchers are disabled; entering the explorer refreshes it.

Compatibility commands `:NERDTreeToggle`, `:NERDTreeFind`, and `:NERDTreeCWD`
call nvim-tree. The last one roots the explorer at Neovim's working directory.

## Finder

| Keys | Action |
| --- | --- |
| Type text | Narrow results |
| `Ctrl+J` / `Ctrl+K` or arrow keys | Move selection |
| `Enter` | Open selected result |
| `Ctrl+V` / `Ctrl+S` | Open in vertical / horizontal split |
| `Ctrl+T` | Open in an actual Vim tab page |
| `Tab` / `Shift+Tab` | Select entries for multiple results |
| `F4` | Toggle preview |
| `Esc` | Close finder |

These are fzf-lua defaults. Picker-specific keys shown in the picker take priority.

## Movement and search

Use these in normal or visual mode unless stated otherwise. Prefix motions with
a number: `5j` moves down five lines, `3w` moves forward three words.

| Keys | Action |
| --- | --- |
| `h/j/k/l` | Left/down/up/right |
| `w` / `b` / `e` | Next word / previous word / word end |
| `0` / `^` / `$` | Line start / first nonblank / line end |
| `gg` / `G` | File start / file end |
| `42G` / `:42` | Go to line 42 |
| `Ctrl+D` / `Ctrl+U` | Half page down / up |
| `%` | Jump to matching bracket |
| `f` then a character | Move to that character on this line |
| `/text` / `?text` then Enter | Search forward / backward |
| `n` / `N` | Repeat search / reverse search direction |
| `*` / `#` | Search cursor word forward / backward |
| `Ctrl+O` / `Ctrl+I` | Older / newer jump location (normal mode) |
| `:nohlsearch` | Clear current search highlighting |

## Edit, copy, undo

| Keys | Mode | Action |
| --- | --- | --- |
| `u` / `Ctrl+R` | Normal | Undo / redo |
| `Ctrl+O`, then `u` | Insert | Undo and return to typing |
| `Ctrl+O`, then `Ctrl+R` | Insert | Redo and return to typing |
| `.` | Normal | Repeat last change |
| `x` | Normal | Delete character |
| `dd` / `yy` | Normal | Cut / copy line |
| `p` / `P` | Normal | Paste after / before cursor |
| `dw` / `cw` | Normal | Delete / change through next word boundary |
| `ciw` | Normal | Replace current word |
| `ci"` | Normal | Replace text inside double quotes |
| `d` / `y` / `c` | Visual | Cut / copy / replace selection |
| `>` / `<` | Visual | Indent / unindent selection |
| `>>` / `<<` | Normal | Indent / unindent line |
| `gcc` | Normal | Toggle line comment (built into Neovim) |
| `gc` | Visual | Toggle comments on selected lines |
| `"+y` / `"+p` | Normal or visual as applicable | Copy to / paste from system clipboard |
| `:%s/old/new/gc` | Normal command | Replace throughout file with confirmation |

Clipboard access needs a provider such as wl-clipboard on Wayland, xclip on X11,
or macOS pbcopy/pbpaste. Neovim's unnamed register is separate from the system
clipboard. Persistent undo survives saves and restarts; it is not a backup of
deleted files. An uninterrupted typing session can be one undo block.

## Completion, code, and diagnostics

| Keys | Mode | Action |
| --- | --- | --- |
| `Ctrl+Space` | Insert | Request completion suggestions |
| `Tab` / `Shift+Tab` | Insert, select | Next / previous completion when menu is visible |
| `Enter` | Insert | Accept selected completion; without a selection, insert a newline |
| `gd` / `gr` | Normal | Go to definition / find references |
| `K` | Normal | Symbol documentation |
| `Space r n` | Normal | Rename symbol |
| `Space c a` | Normal | Code actions |
| `[d` / `]d` | Normal | Previous / next diagnostic |
| `Space d d` | Normal | List current buffer diagnostics in location list |
| `:lopen` / `:lclose` | Normal | Open / close location list |
| `Space f m` | Normal, visual | Format file / selection |
| `Space i` | Normal | Toggle indentation guides |

Symbol keys are installed when a language server attaches. Diagnostics appear
in the sign column and in a floating message when pausing on the affected line.
Formatting is manual. If no external formatter is configured, Conform attempts
LSP formatting if the attached server supports it. Selection formatting depends
on the formatter's range support.

## Git

These keys appear in buffers attached to a Git repository through gitsigns.

| Keys | Action |
| --- | --- |
| `[h` / `]h` | Previous / next Git change hunk |
| `Space h p` | Preview change hunk |

The setup shows Git status; it does not map commit, push, reset, or staging actions.
Use Git in the terminal for those operations.

## Terminal

| Keys or command | Action |
| --- | --- |
| `i` in terminal normal mode | Start typing in the terminal |
| `Ctrl+\`, then `Ctrl+N` | Leave terminal input for normal mode |
| `Ctrl+W`, then `h/j/k/l` | Move focus directly from terminal input |
| `Ctrl+.` / `Ctrl+,` | Switch visible top-bar tab from terminal input |
| `exit` in the shell | End shell and close its split |
| `:botright 10split \| terminal` | Open another bottom terminal from normal mode |

Changing Neovim's directory does not change a running shell's directory. Type
`cd` in the shell separately. In a terminal, most Ctrl keys belong to the shell;
the custom window and tab shortcuts above are exceptions.

## Inspect mappings

Run `:map`, `:imap`, or `:tmap` for normal/visual, insert, or terminal mappings.
`:verbose nmap <C-.>` shows which file defined the next-tab shortcut.
`:help` opens Neovim documentation. `:help <topic>` searches a specific topic.
