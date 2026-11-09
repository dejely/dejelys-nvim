"""Opt-in root-selection regressions for browsing stable Rust library source."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest

import test_sessions


@unittest.skipUnless(test_sessions.PLUGIN_DIR and shutil.which('nvim') and shutil.which('rustc'),
                     'requires NVIM_TEST_PLUGIN_DIR, nvim, and Rust')
class RustRootTests(unittest.TestCase):
    def setUp(self):
        self.h = test_sessions.SessionTests(methodName='runTest')
        self.h.setUp()
        self.addCleanup(self.h.doCleanups)
        os.environ['RUSTUP_HOME'] = self.h.original_env.get('RUSTUP_HOME', self.h.original_env['HOME'] + '/.rustup')
        os.environ['CARGO_HOME'] = self.h.original_env.get('CARGO_HOME', self.h.original_env['HOME'] + '/.cargo')
        self.sysroot = subprocess.check_output(['rustc', '--print', 'sysroot'], text=True).strip()
        self.library = Path(self.sysroot) / 'lib/rustlib/src/rust/library/alloc/src/lib.rs'
        if not self.library.exists():
            self.skipTest('rust-src is not installed')

    def run_lua(self, body):
        script = self.h.home / 'check-root.lua'
        script.write_text(body)
        env = os.environ.copy()
        env['RUST_LIBRARY_TEST'] = str(self.library)
        env['RUST_ROOT_TEST'] = str(script)
        result = subprocess.run(['nvim', '--headless',
            '+lua local ok,err=pcall(dofile,vim.env.RUST_ROOT_TEST); if not ok then print(err); vim.cmd("cquit 1") end', '+qa!'],
            env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_opening_stdlib_without_project_does_not_run_cargo_metadata(self):
        self.run_lua('''
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, vim.env.RUST_LIBRARY_TEST)
local root
vim.lsp.config.rust_analyzer.root_dir(buf, function(value) root = value end)
vim.wait(1500, function() return vim.fn.execute('messages'):find('public-dependency',1,true) ~= nil end, 30)
local messages = vim.fn.execute('messages')
assert(not messages:find('public-dependency',1,true), messages)
assert(root == nil, 'Standard library was selected as an independent project: ' .. tostring(root))
''')

    def test_normal_project_and_standard_library_share_client(self):
        self.run_lua('''
local project = vim.fn.stdpath('state') .. '/rust-project'
vim.fn.mkdir(project .. '/src', 'p')
vim.fn.writefile({'[package]', 'name="stdlib-browsing-test"', 'version="0.1.0"', 'edition="2021"'}, project .. '/Cargo.toml')
vim.fn.writefile({'pub fn value() -> Vec<i32> { vec![42] }'}, project .. '/src/lib.rs')
vim.cmd.edit(project .. '/src/lib.rs')
assert(vim.wait(10000,function()
  local clients = vim.lsp.get_clients({name='rust_analyzer',bufnr=0})
  return #clients == 1 and clients[1].initialized
end,30), 'Project rust-analyzer did not initialize')
local id = vim.lsp.get_clients({name='rust_analyzer',bufnr=0})[1].id
vim.cmd.edit(vim.env.RUST_LIBRARY_TEST)
assert(vim.wait(5000,function()
  local clients = vim.lsp.get_clients({name='rust_analyzer',bufnr=0})
  return #clients == 1 and clients[1].id == id
end,30), 'Library file did not reuse project client')
assert(#vim.lsp.get_clients({name='rust_analyzer'}) == 1, 'A separate library workspace was created')
assert(not vim.fn.execute('messages'):find('public-dependency',1,true), 'Stable Cargo was invoked on a library manifest')
''')


if __name__ == '__main__':
    unittest.main()
