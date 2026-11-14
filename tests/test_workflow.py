"""Opt-in UI regressions for workflow shortcuts and bounded file processing."""
import unittest

import test_sessions


@unittest.skipUnless(test_sessions.pynvim and test_sessions.PLUGIN_DIR,
                     'requires pynvim and NVIM_TEST_PLUGIN_DIR')
class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.h = test_sessions.SessionTests(methodName='runTest')
        self.h.setUp()
        self.addCleanup(self.h.doCleanups)
        self.nvim = self.h.launch(self.h.project)

    def wait(self, expression):
        self.assertTrue(self.nvim.exec_lua('return vim.wait(15000, function() return ' + expression + ' end, 30)'),
                        self.nvim.command_output('messages'))

    def test_terminal_reuses_job_and_restores_focus(self):
        n = self.nvim
        editor = n.current.window.handle
        buf = n.exec_lua("return require('config.workspace').terminal_buf")
        job = n.buffers[buf].vars['terminal_job_id']
        n.command('TerminalToggle')
        self.assertEqual(n.funcs.win_findbuf(buf), [])
        self.assertEqual(n.current.window.handle, editor)
        n.command('TerminalToggle')
        self.assertEqual(n.current.buffer.number, buf)
        self.assertEqual(n.buffers[buf].vars['terminal_job_id'], job)
        self.assertEqual(self.h.terminal_count(n), 1)
        n.input('<C-`>')
        self.wait("#vim.fn.win_findbuf(require('config.workspace').terminal_buf) == 0")
        self.assertEqual(n.current.window.handle, editor)
        n.command('TerminalToggle')
        n.exec_lua("vim.fn.chansend(vim.b.terminal_job_id, 'exit\\n')")
        self.wait("require('config.workspace').terminal_buf == nil")
        n.command('TerminalToggle')
        self.assertNotEqual(n.exec_lua("return vim.b.terminal_job_id"), job)
        self.assertEqual(self.h.terminal_count(n), 1)

    def test_lazy_first_use_save_and_palette(self):
        n = self.nvim
        for plugin in ('nvim-cmp', 'conform.nvim', 'fzf-lua', 'nvim-lspconfig'):
            self.assertFalse(n.exec_lua("return require('lazy.core.config').plugins[...]._.loaded ~= nil", plugin), plugin)
        path = self.h.project / 'new.txt'
        n.command('edit ' + n.funcs.fnameescape(str(path)))
        n.input('ihello<C-s>')
        self.wait("vim.fn.filereadable(...) == 1".replace('...', repr(str(path))))
        self.assertEqual(path.read_text(), 'hello\n')
        self.assertTrue(n.exec_lua("return package.loaded.cmp ~= nil"))
        n.input('<Esc>')
        n.command('ConformInfo')
        self.assertTrue(n.exec_lua("return package.loaded.conform ~= nil"))
        n.input('q')
        n.input(' fp')
        self.wait("package.loaded['fzf-lua'] ~= nil and vim.bo.filetype == 'fzf'")
        n.input('<Esc>')

    def test_workspace_diagnostics_include_other_buffers(self):
        n = self.nvim
        n.command('edit ' + n.funcs.fnameescape(str(self.h.project / 'one.txt')))
        n.exec_lua("local ns=vim.api.nvim_create_namespace('workflow-test'); vim.diagnostic.set(ns,0,{{lnum=0,col=0,message='first-buffer-error'}})")
        n.command('edit ' + n.funcs.fnameescape(str(self.h.project / 'two.txt')))
        n.exec_lua("local ns=vim.api.nvim_create_namespace('workflow-test'); vim.diagnostic.set(ns,0,{{lnum=0,col=0,message='second-buffer-error'}})")
        n.input(' dx')
        self.wait("vim.bo.filetype == 'fzf'")
        # A short split may show just one multiline diagnostic at a time.
        self.wait("table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('first%-buffer%-error') ~= nil")
        n.input('<Down>')
        self.wait("table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('second%-buffer%-error') ~= nil")
        n.input('<Esc>')

    def test_large_files_and_growth_restore_normal_features(self):
        n = self.nvim
        path = self.h.project / 'large.lua'
        path.write_text('-- a comment\n' * 85000)
        n.command('edit ' + n.funcs.fnameescape(str(path)))
        self.assertTrue(n.exec_lua("return require('config.large_files').is_large(0)"))
        self.assertEqual(n.exec_lua("return #vim.lsp.get_clients({bufnr=0})"), 0)
        self.assertFalse(n.exec_lua("return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"))
        n.input('i')
        self.wait("package.loaded.cmp ~= nil")
        self.assertEqual(n.exec_lua("return require('cmp').get_config().sources[3].option.get_bufnrs()"), [])
        n.input('<Esc>')
        n.exec_lua("vim.api.nvim_buf_set_lines(0,0,-1,false,{'local value = 1'}); require('config.large_files').refresh(0)")
        self.wait("#vim.lsp.get_clients({bufnr=0,name='lua_ls'}) == 1")
        self.assertFalse(n.exec_lua("return vim.b.large_file"))
        self.assertTrue(n.exec_lua("return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"))
        n.input('A value')
        n.exec_lua("require('cmp').complete({config={sources={require('cmp').get_config().sources[3]}}})")
        self.wait("package.loaded.cmp_buffer.buffers[vim.api.nvim_get_current_buf()] ~= nil")
        n.input('<Esc>')
        # A small file with a pathological line also enters large-file mode.
        n.exec_lua("vim.api.nvim_buf_set_lines(0,0,-1,false,{'--' .. string.rep('x',10001)}); vim.api.nvim_exec_autocmds('TextChanged',{buffer=0})")
        self.assertTrue(n.exec_lua("return vim.b.large_file"))
        self.assertTrue(n.exec_lua("return package.loaded.cmp_buffer.buffers[vim.api.nvim_get_current_buf()] == nil"))
        self.assertEqual(n.exec_lua("return #vim.lsp.get_clients({bufnr=0})"), 0)
        self.assertFalse(n.exec_lua("return require('ibl.config').get_config(0).enabled"))
        n.exec_lua("vim.api.nvim_buf_set_lines(0,0,-1,false,{'local value = 2'}); vim.api.nvim_exec_autocmds('TextChangedI',{buffer=0})")
        self.wait("#vim.lsp.get_clients({bufnr=0,name='lua_ls'}) == 1")
        n.command('vsplit ' + n.funcs.fnameescape(str(self.h.project / 'second.lua')))
        n.exec_lua("vim.api.nvim_buf_set_lines(0,0,-1,false,{'local second = 2'})")
        self.wait("#vim.lsp.get_clients({name='lua_ls'}) == 1 and #vim.lsp.get_clients({bufnr=0}) == 1")
        for key in ('<F2>', '<F12>', '<M-CR>'):
            for mode in ('n', 'i'):
                self.assertTrue(n.funcs.maparg(key, mode))

    def test_f12_and_f2_use_real_lua_language_server(self):
        n = self.nvim
        path = self.h.project / 'navigation.lua'
        path.write_text('local function answer() return 42 end\nprint(answer())\n')
        n.command('edit ' + n.funcs.fnameescape(str(path)))
        self.wait("(function() local c=vim.lsp.get_clients({bufnr=0,name='lua_ls'})[1]; return c and c.initialized end)()")
        n.current.window.cursor = (2, 6)
        n.input('i<F12>')
        self.wait('vim.api.nvim_win_get_cursor(0)[1] == 1')
        n.input('<Esc>')
        n.current.window.cursor = (2, 6)
        n.exec_lua("vim.ui.input=function(_,callback) callback('renamed') end")
        n.input('<F2>')
        self.wait("vim.api.nvim_buf_get_lines(0,0,1,false)[1]:find('function renamed',1,true) ~= nil")
        self.assertIn('print(renamed())', n.current.buffer[:])

    def test_long_line_is_guarded_before_lsp_start(self):
        path = self.h.project / 'long.lua'
        path.write_text('--' + 'x' * 10001 + '\n')
        self.nvim.command('edit ' + self.nvim.funcs.fnameescape(str(path)))
        self.nvim.exec_lua('vim.wait(500)')
        self.assertEqual(self.nvim.exec_lua('return #vim.lsp.get_clients()'), 0)
        self.assertTrue(self.nvim.exec_lua('return vim.b.large_file'))


if __name__ == '__main__':
    unittest.main()
