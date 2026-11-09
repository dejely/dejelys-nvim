"""Real embedded-UI checks; opt in with NVIM_TEST_PLUGIN_DIR and pynvim."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

try:
    import pynvim
except ImportError:
    pynvim = None

REPO = Path(__file__).resolve().parents[1]
PLUGIN_DIR = os.environ.get("NVIM_TEST_PLUGIN_DIR")


@unittest.skipUnless(pynvim and PLUGIN_DIR and shutil.which("nvim"),
                     "requires pynvim, nvim, and NVIM_TEST_PLUGIN_DIR")
class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim-session-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.original_env = os.environ.copy()
        os.environ["HOME"] = str(self.home)
        os.environ["SHELL"] = "/bin/sh"
        os.environ.pop("NVIM_APPNAME", None)
        for kind in ("CONFIG", "DATA", "STATE", "CACHE"):
            os.environ["XDG_" + kind + "_HOME"] = str(self.home / kind.lower())
        self.addCleanup(self.restore_environment)
        shutil.copytree(REPO / "nvim", self.home / "config/nvim")
        data = self.home / "data/nvim"
        data.mkdir(parents=True)
        (data / "lazy").symlink_to(Path(PLUGIN_DIR).resolve(), target_is_directory=True)
        # Reuse installed tool executables, without writing to real config/state.
        mason = Path(self.original_env.get("XDG_DATA_HOME", str(Path(self.original_env["HOME"]) / ".local/share"))) / "nvim/mason"
        if mason.exists():
            (data / "mason").symlink_to(mason, target_is_directory=True)
        self.project = self.home / "project with spaces"
        self.project.mkdir()
        for name in ("one.txt", "two.txt", "three.txt"):
            (self.project / name).write_text("one\ntwo\nthree\nfour\n")
        self.instances = []
        self.addCleanup(self.close_instances)

    def restore_environment(self):
        os.environ.clear()
        os.environ.update(self.original_env)

    def close_instances(self):
        for nvim in self.instances:
            try:
                nvim.command("qa!")
            except (OSError, EOFError):
                pass
            nvim.close()
        self.instances.clear()

    def launch(self, *args):
        nvim = pynvim.attach("child", argv=[shutil.which("nvim"), "--embed", "-i", "NONE", *map(str, args)])
        self.instances.append(nvim)
        nvim.ui_attach(120, 40, rgb=True)
        self.assertTrue(nvim.exec_lua("return vim.wait(5000, function() return require('config.workspace').opened == true end, 20)"))
        return nvim

    def stop(self, nvim):
        try:
            nvim.command("qa!")
        except (OSError, EOFError):
            pass
        nvim.close()
        self.instances.remove(nvim)

    def terminal_count(self, nvim):
        return nvim.exec_lua("local n=0; for _, b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].buftype=='terminal' then n=n+1 end end; return n")

    def test_restart_restores_files_splits_tabs_cursor_and_fresh_terminal(self):
        nvim = self.launch(self.project)
        nvim.command("edit " + nvim.funcs.fnameescape(str(self.project / "one.txt")))
        nvim.command("vsplit " + nvim.funcs.fnameescape(str(self.project / "two.txt")))
        nvim.current.window.cursor = (3, 1)
        nvim.command("tabnew " + nvim.funcs.fnameescape(str(self.project / "three.txt")))
        nvim.command("tabprevious")
        session = Path(nvim.exec_lua("return require('config.sessions').path()"))
        self.stop(nvim)
        self.assertTrue(session.exists())
        self.assertNotIn("term://", session.read_text())
        self.assertNotIn("NvimTree_", session.read_text())
        nvim = self.launch()
        self.assertEqual(nvim.funcs.getcwd(), str(self.project))
        self.assertEqual(len(nvim.tabpages), 2)
        files = [Path(w.buffer.name).name for w in nvim.current.tabpage.windows]
        self.assertIn("one.txt", files)
        self.assertIn("two.txt", files)
        self.assertEqual(Path(nvim.current.buffer.name).name, "two.txt")
        self.assertEqual(nvim.current.window.cursor, (3, 1))
        self.assertEqual(self.terminal_count(nvim), 1)
        nvim.command("SessionRestore")
        self.assertEqual(self.terminal_count(nvim), 1)

    def test_explicit_file_does_not_restore_or_overwrite_project_session(self):
        nvim = self.launch(self.project)
        nvim.command("edit " + nvim.funcs.fnameescape(str(self.project / "one.txt")))
        path = Path(nvim.exec_lua("return require('config.sessions').path()"))
        self.stop(nvim)
        original = path.read_bytes()
        nvim = self.launch(self.project / "two.txt")
        self.assertEqual(Path(nvim.current.buffer.name).name, "two.txt")
        self.assertFalse(nvim.exec_lua("return require('config.workspace').session_enabled"))
        self.stop(nvim)
        self.assertEqual(path.read_bytes(), original)

    def test_modified_buffers_block_restore_and_stop_prevents_autosave(self):
        nvim = self.launch(self.project)
        nvim.command("edit " + nvim.funcs.fnameescape(str(self.project / "one.txt")))
        nvim.command("SessionSave")
        path = Path(nvim.exec_lua("return require('config.sessions').path()"))
        original = path.read_bytes()
        nvim.current.buffer[0] = "unsaved banana"
        result = nvim.exec_lua("local ok, err = require('config.sessions').restore(); return {ok,err}")
        self.assertFalse(result[0])
        self.assertIn("modified", result[1])
        self.assertEqual(nvim.current.buffer[0], "unsaved banana")
        nvim.command("SessionStop")
        self.stop(nvim)
        self.assertEqual(path.read_bytes(), original)

    def test_ctrl_h_and_leader_open_discovery(self):
        nvim = self.launch(self.project)
        nvim.input("\x08")
        self.assertTrue(nvim.exec_lua("return vim.wait(2000, function() for _, b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype == 'wk' and #vim.fn.win_findbuf(b)>0 then return true end end return false end, 20)"))
        nvim.input("\x1b")
        self.assertEqual(nvim.exec_lua("return vim.fn.maparg('<C-h>', 'i')"), "")
        self.assertEqual(nvim.exec_lua("return vim.fn.maparg('<C-h>', 't')"), "")
        nvim.input(" ")
        self.assertTrue(nvim.exec_lua("return vim.wait(2000, function() for _, b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype == 'wk' and #vim.fn.win_findbuf(b)>0 then return true end end return false end, 20)"))
        nvim.input("\x1b")

    def test_sessions_are_separate_per_directory(self):
        nvim = self.launch(self.project)
        nvim.command("edit " + nvim.funcs.fnameescape(str(self.project / "one.txt")))
        path = nvim.exec_lua("return require('config.sessions').path()")
        self.stop(nvim)
        other = self.home / "other project"
        other.mkdir()
        (other / "other.txt").write_text("another project\n")
        nvim = self.launch(other)
        self.assertNotEqual(nvim.exec_lua("return require('config.sessions').path()"), path)
        self.assertFalse(nvim.funcs.bufexists(str(self.project / "one.txt")))
        nvim.command("edit " + nvim.funcs.fnameescape(str(other / "other.txt")))
        self.stop(nvim)
        nvim = self.launch(self.project)
        self.assertEqual(Path(nvim.current.buffer.name).name, "one.txt")
        self.assertFalse(nvim.funcs.bufexists(str(other / "other.txt")))

    def test_headless_checks_do_not_overwrite_session(self):
        nvim = self.launch(self.project)
        nvim.command("edit " + nvim.funcs.fnameescape(str(self.project / "one.txt")))
        path = Path(nvim.exec_lua("return require('config.sessions').path()"))
        self.stop(nvim)
        original = path.read_bytes()
        result = subprocess.run([shutil.which("nvim"), "--headless", str(self.project / "two.txt"), "+qa!"],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
