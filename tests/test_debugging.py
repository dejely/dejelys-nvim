"""Opt-in debugger checks using real CodeLLDB and embedded Neovim UI."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import unittest

import test_sessions


@unittest.skipUnless(test_sessions.pynvim and test_sessions.PLUGIN_DIR and shutil.which('cc'),
                     'requires pynvim, NVIM_TEST_PLUGIN_DIR, cc, and installed CodeLLDB')
class DebugTests(unittest.TestCase):
    def setUp(self):
        self.h = test_sessions.SessionTests(methodName='runTest')
        self.h.setUp()
        os.environ['RUSTUP_HOME'] = self.h.original_env.get('RUSTUP_HOME', self.h.original_env['HOME'] + '/.rustup')
        os.environ['CARGO_HOME'] = self.h.original_env.get('CARGO_HOME', self.h.original_env['HOME'] + '/.cargo')
        self.addCleanup(self.h.doCleanups)
        self.nvim = self.h.launch(self.h.project)
        if not self.nvim.exec_lua("return vim.fn.executable('codelldb') == 1"):
            self.skipTest('Install CodeLLDB in Mason first')

    def wait(self, condition, timeout=15000):
        self.assertTrue(self.nvim.exec_lua('return vim.wait(..., function() return ' + condition + ' end, 30)', timeout),
                        self.nvim.command_output('messages') + '\n' + self.nvim.exec_lua("return vim.inspect(_G.test_stop_event)"))

    def fixture(self, language='c'):
        if language == 'rust':
            if not shutil.which('rustc'):
                self.skipTest('rustc is unavailable')
            source = self.h.project / 'banana.rs'
            source.write_text('fn main() {\n    let mut banana = 40;\n    banana += 2;\n    println!("{}", banana);\n}\n')
            executable = self.h.project / 'banana-rust'
            env = os.environ.copy()
            env['RUSTUP_HOME'] = self.h.original_env.get('RUSTUP_HOME', self.h.original_env['HOME'] + '/.rustup')
            env['CARGO_HOME'] = self.h.original_env.get('CARGO_HOME', self.h.original_env['HOME'] + '/.cargo')
            subprocess.run(['rustc', '-g', '-C', 'opt-level=0', str(source), '-o', str(executable)], env=env, check=True, capture_output=True)
            line = 3
        else:
            source = self.h.project / ('banana.cpp' if language == 'cpp' else 'banana.c')
            source.write_text('#include <stdio.h>\nint main(void) {\n    int banana = 40;\n    banana += 2;\n    printf("%d\\n", banana);\n    return 0;\n}\n')
            executable = self.h.project / ('banana-' + language)
            subprocess.run(['c++' if language == 'cpp' else 'cc', '-g', '-O0', str(source), '-o', str(executable)], check=True, capture_output=True)
            line = 4
        return source, executable, line

    def launch_debugger(self, source, executable, line):
        self.nvim.command('edit ' + self.nvim.funcs.fnameescape(str(source)))
        self.nvim.current.window.cursor = (line, 0)
        self.nvim.exec_lua("require('config.debugging').action('breakpoint')")
        self.nvim.exec_lua("require('dap').run({name='Fixture',type='codelldb',request='launch',program=...,cwd=vim.fn.getcwd(),terminal='console',stopOnEntry=false})", str(executable))
        self.wait("require('dap').session() ~= nil and require('dap').session().stopped_thread_id ~= nil and require('dap').session().current_frame ~= nil")
        self.wait("require('config.debug_toolbar').win ~= nil")
        self.wait("vim.api.nvim_buf_get_lines(require('config.debug_toolbar').buf,0,1,false)[1]:find('Continue') ~= nil")

    def value(self):
        self.nvim.exec_lua("_G.debug_result=nil; require('dap').session():request('evaluate',{expression='banana',frameId=require('dap').session().current_frame.id,context='watch'},function(err,body) _G.debug_result={error=err,result=body and body.result} end)")
        self.wait('_G.debug_result ~= nil')
        result = self.nvim.exec_lua('return _G.debug_result')
        self.assertFalse(result.get('error'), result)
        return result['result']

    def test_c_debugging_toolbar_controls_and_cleanup(self):
        self.assertFalse(self.nvim.exec_lua("return package.loaded.dap ~= nil"))
        source, executable, line = self.fixture()
        self.launch_debugger(source, executable, line)
        self.assertEqual(self.value(), '40')
        toolbar = self.nvim.exec_lua("return require('config.debug_toolbar').win")
        self.assertNotEqual(self.nvim.current.window.handle, toolbar)
        config = self.nvim.api.win_get_config(toolbar)
        self.assertFalse(config['focusable'])
        self.assertTrue(config['mouse'])
        # Click Step Over through Neovim's mouse input boundary.
        self.nvim.exec_lua("local t=require('config.debug_toolbar'); local text=vim.api.nvim_buf_get_lines(t.buf,0,1,false)[1]; local before=text:sub(1,t.buttons[2].first-1); _G.click_col=vim.fn.strdisplaywidth(before)+1")
        col = int(config['col']) + 1 + self.nvim.exec_lua('return _G.click_col')
        row = int(config['row']) + 1
        self.nvim.api.input_mouse('left', 'press', '', 0, row, col)
        self.nvim.api.input_mouse('left', 'release', '', 0, row, col)
        self.wait("require('dap').session().stopped_thread_id ~= nil and require('dap').session().current_frame ~= nil and require('dap').session().current_frame.line == 5")
        self.assertEqual(self.value(), '42')
        self.assertNotEqual(self.nvim.current.window.handle, toolbar)
        self.nvim.exec_lua("require('config.debugging').action('scopes')")
        self.wait("require('config.debug_toolbar').scope_view ~= nil")
        self.nvim.exec_lua("require('config.debugging').action('scopes')")
        self.nvim.exec_lua("require('config.debugging').action('toolbar')")
        self.assertIsNone(self.nvim.exec_lua("return require('config.debug_toolbar').win"))
        self.nvim.exec_lua("require('config.debugging').action('toolbar')")
        self.nvim.ui_try_resize(48, 20)
        self.wait("vim.api.nvim_win_get_width(require('config.debug_toolbar').win) < 48")
        self.nvim.ui_try_resize(120, 40)
        self.nvim.exec_lua("require('config.debugging').action('repl'); assert(require('config.sessions').save())")
        session_path = Path(self.nvim.exec_lua("return require('config.sessions').path()"))
        self.assertNotIn('debug-toolbar', session_path.read_text())
        self.assertNotIn('dap-repl', session_path.read_text())
        self.nvim.exec_lua("require('config.debugging').action('continue')")
        self.wait("require('dap').session() == nil")
        self.assertIsNone(self.nvim.exec_lua("return require('config.debug_toolbar').win"))

    def test_rust_breakpoint_step_and_stop(self):
        self.launch_debugger(*self.fixture('rust'))
        self.assertEqual(self.value(), '40')
        self.nvim.input('<F10>')
        self.wait("require('dap').session().stopped_thread_id ~= nil and require('dap').session().current_frame ~= nil and require('dap').session().current_frame.line == 4")
        self.assertEqual(self.value(), '42')
        self.nvim.exec_lua("require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")
        self.assertIsNone(self.nvim.exec_lua("return require('config.debug_toolbar').win"))

    def test_variables_refresh_in_same_window_after_each_step(self):
        self.launch_debugger(*self.fixture())
        self.nvim.exec_lua("require('config.debugging').action('scopes')")
        self.wait("table.concat(vim.api.nvim_buf_get_lines(require('config.debug_toolbar').scope_view.buf,0,-1,false),'\\n'):find('banana: 40',1,true) ~= nil")
        window = self.nvim.exec_lua("return require('config.debug_toolbar').scope_view.win")
        buffer = self.nvim.exec_lua("return require('config.debug_toolbar').scope_view.buf")
        self.nvim.input('<F10>')
        self.wait("require('dap').session().current_frame ~= nil and require('dap').session().current_frame.line == 5")
        self.wait("table.concat(vim.api.nvim_buf_get_lines(require('config.debug_toolbar').scope_view.buf,0,-1,false),'\\n'):find('banana: 42',1,true) ~= nil", 3000)
        self.assertEqual(self.nvim.exec_lua("return require('config.debug_toolbar').scope_view.win"), window)
        self.assertEqual(self.nvim.exec_lua("return require('config.debug_toolbar').scope_view.buf"), buffer)
        self.nvim.exec_lua("require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")
        self.assertIsNone(self.nvim.exec_lua("return require('config.debug_toolbar').scope_view"))

    def test_cpp_breakpoint(self):
        if not shutil.which('c++'):
            self.skipTest('C++ compiler unavailable')
        self.launch_debugger(*self.fixture('cpp'))
        self.assertEqual(self.value(), '40')
        self.nvim.exec_lua("require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")

    def test_expanded_object_values_refresh_across_steps(self):
        source = self.h.project / 'inventory.c'
        executable = self.h.project / 'inventory'
        source.write_text('#include <stdio.h>\nstruct Stock { int bananas; int sold; };\nint main(void) {\n    struct Stock inventory = {40, 0};\n    inventory.bananas -= 5;\n    inventory.sold += 5;\n    printf("%d %d\\n", inventory.bananas, inventory.sold);\n    return 0;\n}\n')
        subprocess.run(['cc', '-g', '-O0', str(source), '-o', str(executable)], check=True, capture_output=True)
        self.launch_debugger(source, executable, 5)
        self.nvim.exec_lua("require('config.debugging').action('scopes')")
        self.wait("table.concat(vim.api.nvim_buf_get_lines(require('config.debug_toolbar').scope_view.buf,0,-1,false),'\\n'):find('inventory:',1,true) ~= nil")
        self.nvim.exec_lua("local v=require('config.debug_toolbar').scope_view; for row,text in ipairs(vim.api.nvim_buf_get_lines(v.buf,0,-1,false)) do if text:find('inventory:',1,true) then vim.api.nvim_set_current_win(v.win); vim.api.nvim_win_set_cursor(v.win,{row,0}); break end end")
        self.nvim.input('<CR>')
        def fields(bananas, sold):
            return "(function() local lines=vim.api.nvim_buf_get_lines(require('config.debug_toolbar').scope_view.buf,0,-1,false); local b,s=false,false; for _,line in ipairs(lines) do b=b or line:match('^%s+bananas: " + str(bananas) + "$')~=nil; s=s or line:match('^%s+sold: " + str(sold) + "$')~=nil end; return b and s end)()"
        self.wait(fields(40, 0))
        self.nvim.input('<F10>')
        self.wait(fields(35, 0))
        self.nvim.input('<F10>')
        self.wait(fields(35, 5))
        self.nvim.exec_lua("require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")

    def test_f5_enter_prefills_executable_from_source_project(self):
        source, executable, line = self.fixture('rust')
        target = self.h.project / 'target/debug'
        target.mkdir(parents=True)
        binary = target / 'banana-demo'
        executable.rename(binary)
        (self.h.project / 'Cargo.toml').write_text('[package]\nname="banana-demo"\nversion="0.1.0"\nedition="2021"\n[[bin]]\nname="banana-demo"\npath="banana.rs"\n')
        unrelated = self.h.home / 'unrelated project'
        unrelated.mkdir()
        self.nvim.command('cd ' + self.nvim.funcs.fnameescape(str(unrelated)))
        self.nvim.command('edit ' + self.nvim.funcs.fnameescape(str(source)))
        self.nvim.current.window.cursor = (line, 0)
        # Accept the prefilled value exactly as pressing Enter at the prompt.
        self.nvim.exec_lua("_G.launch_prompt_default=nil; _G.old_debug_input=vim.fn.input; vim.fn.input=function(_,default) _G.launch_prompt_default=default; return default end; require('dap').toggle_breakpoint()")
        self.nvim.input('<F5>')
        self.wait('_G.launch_prompt_default ~= nil')
        self.assertEqual(self.nvim.exec_lua('return _G.launch_prompt_default'), str(binary))
        self.wait("require('dap').session() ~= nil and require('dap').session().current_frame ~= nil")
        self.assertEqual(self.nvim.exec_lua("return require('dap').session().config.cwd"), str(self.h.project))
        self.assertEqual(self.value(), '40')
        self.nvim.exec_lua("vim.fn.input=_G.old_debug_input; require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")

    def test_failed_launch_leaves_no_toolbar(self):
        self.nvim.exec_lua("local d=require('dap'); _G.debug_session_seen=false; d.listeners.on_session['failure-test']=function(_,s) if s then _G.debug_session_seen=true end end; d.run({name='Missing fixture',type='codelldb',request='launch',program='/does-not-exist/banana',terminal='console'})")
        self.wait('_G.debug_session_seen')
        self.wait("require('dap').session() == nil", 20000)
        self.wait("require('config.debug_toolbar').win == nil")

    def test_project_launch_configuration_and_memory(self):
        source, executable, line = self.fixture()
        self.nvim.command('edit ' + self.nvim.funcs.fnameescape(str(source)))
        configs = self.h.project / '.vscode'
        configs.mkdir()
        (configs / 'launch.json').write_text(json.dumps({'version': '0.2.0', 'configurations': [{
            'name': 'Project fixture', 'type': 'lldb', 'request': 'launch',
            'program': str(executable), 'args': [], 'cwd': '${workspaceFolder}', 'terminal': 'console'}]}))
        def pss():
            root = self.nvim.funcs.getpid()
            parents = {}
            for path in Path('/proc').glob('[0-9]*/stat'):
                try:
                    stat = path.read_text(); parents[int(path.parent.name)] = int(stat[stat.rfind(')')+2:].split()[1])
                except (OSError, ValueError):
                    pass
            ids = {root}
            while True:
                children = {pid for pid, parent in parents.items() if parent in ids} - ids
                if not children: break
                ids |= children
            total = 0
            for pid in ids:
                try:
                    for text in Path(f'/proc/{pid}/smaps_rollup').read_text().splitlines():
                        if text.startswith('Pss:'): total += int(text.split()[1])
                except OSError:
                    pass
            return round(total / 1024, 1)
        cold = pss()
        self.nvim.exec_lua("local d=require('dap'); d.configurations.c={}; vim.api.nvim_win_set_cursor(0,{4,0}); d.toggle_breakpoint()")
        baseline = pss()
        self.nvim.exec_lua("vim.ui.select=function(items,_,cb) for _,item in ipairs(items) do if item.name=='Project fixture' then cb(item); return end end cb(nil) end")
        self.nvim.input('<F5>')
        self.wait("require('dap').session() ~= nil and require('dap').session().stopped_thread_id ~= nil and require('dap').session().current_frame ~= nil")
        paused = pss()
        self.nvim.exec_lua("require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")
        time.sleep(0.2)
        print(f'\nPSS (Neovim + child processes, no Kitty): before loading={cold} MiB, loaded idle={baseline} MiB, paused={paused} MiB, stopped={pss()} MiB')

    def test_pause_and_tab_switch_keep_toolbar_in_sync(self):
        source = self.h.project / 'waiting.c'
        executable = self.h.project / 'waiting'
        source.write_text('#include <unistd.h>\nint main(void) {\n    volatile int banana = 1;\n    while (banana) { usleep(10000); }\n    return 0;\n}\n')
        subprocess.run(['cc', '-g', '-O0', str(source), '-o', str(executable)], check=True, capture_output=True)
        self.launch_debugger(source, executable, 4)
        self.nvim.exec_lua("local d=require('dap'); _G.debug_continued=false; d.listeners.after.event_continued['test-running']=function() _G.debug_continued=true end; d.clear_breakpoints(); require('config.debugging').action('continue')")
        self.wait('_G.debug_continued')
        self.wait("require('dap').session().stopped_thread_id == nil")
        self.wait("vim.api.nvim_buf_get_lines(require('config.debug_toolbar').buf,0,1,false)[1]:find('Pause') ~= nil")
        self.nvim.exec_lua("require('dap').listeners.before.event_stopped['test-stop']=function(_,e) _G.test_stop_event=e end; require('config.debugging').action('pause')")
        self.wait("require('dap').session().stopped_thread_id ~= nil and require('dap').session().current_frame ~= nil and require('dap').session().current_frame.scopes ~= nil")
        self.nvim.command('tabnew')
        self.wait("vim.api.nvim_win_get_tabpage(require('config.debug_toolbar').win) == vim.api.nvim_get_current_tabpage()")
        self.nvim.exec_lua("require('config.debugging').action('stop')")
        self.wait("require('dap').session() == nil")


if __name__ == '__main__':
    unittest.main()
