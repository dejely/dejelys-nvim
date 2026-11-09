# Debugging Rust, C, and C++

This setup uses nvim-dap with CodeLLDB. A small floating toolbar sits near the
top while a debug session is active. Click its controls or use the keyboard.
It does not open large panels automatically. Ctrl+H remains the shortcut guide.

## Start a session

1. Build your program with debug symbols:

   ```sh
   # Rust: the normal debug profile includes symbols
   cargo build

   # C / C++: example commands
   cc -g -O0 main.c -o app
   c++ -g -O0 main.cpp -o app
   ```

2. Open the source file in Neovim. Place the cursor on an executable line and
   press **Space b b** to add a breakpoint.
3. Press **F5**. It switches to the open source file's project directory before
   selecting a launch configuration. The generic executable prompt prefills a
   compiled binary when it finds exactly one, so **Enter** accepts it. Otherwise,
   choose an executable file (for Rust, usually under `target/debug/`).
4. At the breakpoint, inspect variables and step through the code. The toolbar
   switches its first control between Continue and Pause as the program stops
   or runs. Use Stop or **Space b q** to end the session.

The debugger does not compile your program. Rebuild after source changes.
Project roots are detected from Cargo.toml, CMakeLists.txt, Makefile, or .git;
standalone files use their containing directory. Executable detection searches
`target/debug`, `build`, and the project root, excluding scripts and shared
libraries. Custom output directories and multiple executables require selecting
the binary path yourself. Accepting a directory does not start a program.
Files in custom languages such as CSL are input to your interpreter: debug the
Rust interpreter implementation, and pass the CSL file as a program argument.
Direct source-level debugging of CSL would need support inside the interpreter.

## Keys

All keys below use normal mode. They also appear in Ctrl+H under **Space b → Debug**.

| Keys | Action |
| --- | --- |
| `F5` | Start / continue |
| `F10` | Step over |
| `F11` | Step into |
| `Shift+F11` | Step out |
| `Space b b` | Toggle breakpoint |
| `Space b c` | Set a conditional breakpoint; cancel leaves it unchanged |
| `Space b p` | Pause the running program |
| `Space b u` | Hide / show toolbar during the active session |
| `Space b v` | Toggle floating variables/scopes |
| `Space b e` | Inspect the expression under the cursor |
| `Space b r` | Toggle debug output / REPL in a small bottom split |
| `Space b q` | Stop debugging |

The toolbar does not take keyboard focus when it appears. Mouse clicks return
focus to the editor after running an action. It resizes with the editor and
uses icons on narrow terminals. Hover or variables windows are temporary;
**q** or **Esc** closes the variables window. Continue and stepping are available
from the toolbar; Pause appears while running. The toolbar closes when debugging
ends, including disconnects and launch failures. Hiding it lasts for that session.

Program output is captured in the debug REPL by the default `terminal: "console"`
setting; open it with Space b r. This default is for programs that do not need
interactive stdin. For an interactive program, set `terminal` to `"integrated"`
in its launch configuration; a separate debug terminal then handles its input.
Your ordinary bottom shell is independent of the debugger.

## Project-specific configuration

nvim-dap automatically reads `.vscode/launch.json` in the working directory.
Use ordinary JSON without trailing commas. Here is a Rust interpreter example:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug interpreter",
      "type": "codelldb",
      "request": "launch",
      "program": "${workspaceFolder}/target/debug/your-interpreter",
      "args": ["examples/program.csl"],
      "cwd": "${workspaceFolder}",
      "terminal": "console",
      "stopOnEntry": false
    }
  ]
}
```

Replace the executable and example path with your project's actual files.
Argument arrays preserve paths containing spaces. `"type": "lldb"` is also
accepted for configurations written for VS Code's CodeLLDB extension. The same
settings work for C and C++ executables. Launch configurations stay in each
project; this shared setup contains no project-specific executable paths.

## Tools and resource usage

The full installer includes CodeLLDB through Mason. Existing installations can
run `:MasonInstall codelldb`. `:DapShowLog` opens debugger logs.

nvim-dap is loaded only after a debug key/command or an explicit `require('dap')`.
The adapter and target process are launched only when a debug session starts;
setting a breakpoint does not start them. Plugins stay loaded after first use,
but the session's debugger process exits when stopped. Actual RAM usage depends
on the program, debug symbols, and adapter; the tiny toolbar is only one part.

Debug windows and the default REPL are excluded from saved editor sessions.
Restarting Neovim restores your source files and layout, not a running debugger
or its breakpoints. Python and JavaScript debugging are not configured in this
release. Linux integration tests cover Rust, C, and C++; macOS support is
configured but has not been tested on a Mac.

## Troubleshooting

- **CodeLLDB missing:** run `:MasonInstall codelldb` and retry. For installation
  errors, inspect `:MasonLog` and check platform compatibility.
- **Breakpoint not reached:** use the rebuilt binary with `-g` and low/no
  optimization, and place it on an executable source line.
- **Executable launch fails:** verify its path, executable permissions, required
  shared libraries, arguments, and `:DapShowLog`. Cancel the executable prompt
  to return to editing without a session.
- **“Run aborted” after Enter:** the prompt contained a folder rather than a
  compiled executable, or you cancelled it. Build first and select the binary
  file, such as `target/debug/cmsc124-interpreter`. The default is a file only
  when exactly one compiled executable is found.
- **F-keys do something else:** your terminal, desktop, or laptop Fn layer may
  intercept them. Use toolbar clicks or `:DapContinue` / `:DapStepOver`, or remap
  them in `lua/config/debugging.lua`.
- **Program expects stdin:** choose `terminal: "integrated"` in the project's
  launch configuration. Output-only console mode does not provide normal stdin.

Upstream: [nvim-dap](https://github.com/mfussenegger/nvim-dap),
[CodeLLDB manual](https://github.com/vadimcn/codelldb/blob/master/MANUAL.md).
