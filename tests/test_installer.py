"""Exercise install/restore in temporary homes; never touch the real config."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dejelys-nvim-test-")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / "home with spaces"
        self.home.mkdir()
        self.env = os.environ.copy()
        self.env.pop("NVIM_APPNAME", None)
        self.env["HOME"] = str(self.home)
        for kind in ("CONFIG", "DATA", "STATE", "CACHE"):
            self.env["XDG_" + kind + "_HOME"] = str(self.home / kind.lower())

    def call(self, *args, success=True):
        result = subprocess.run(["bash", *map(str, args)], env=self.env,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def install(self):
        return self.call(REPO / "install.sh", "--source", REPO, "--skip-bootstrap")

    def backup(self):
        return sorted((self.home / "state/dejelys-nvim/backups").iterdir())[-1]

    def test_install_restore_preserves_every_directory(self):
        for kind in ("config", "data", "state", "cache"):
            original = self.home / kind / "nvim"
            original.mkdir(parents=True)
            (original / "sentinel").write_text(kind)
        self.install()
        backup = self.backup()
        self.assertTrue((self.home / "config/nvim/init.lua").is_file())
        for number, kind in enumerate(("config", "data", "state", "cache"), 1):
            self.assertEqual((backup / str(number) / "sentinel").read_text(), kind)
        self.call(REPO / "scripts/restore.sh", backup)
        for kind in ("config", "data", "state", "cache"):
            self.assertEqual((self.home / kind / "nvim/sentinel").read_text(), kind)
        self.call(REPO / "scripts/restore.sh", backup, success=False)

    def test_fresh_install_restore(self):
        self.install()
        self.call(REPO / "scripts/restore.sh", self.backup())
        self.assertFalse((self.home / "config/nvim").exists())

    def test_existing_symlink_is_preserved(self):
        target = self.home / "original config"
        target.mkdir()
        (target / "sentinel").write_text("keep")
        (self.home / "config").mkdir()
        (self.home / "config/nvim").symlink_to(target, target_is_directory=True)
        self.install()
        self.assertTrue((self.backup() / "1").is_symlink())
        self.call(REPO / "scripts/restore.sh", self.backup())
        self.assertTrue((self.home / "config/nvim").is_symlink())
        self.assertEqual((target / "sentinel").read_text(), "keep")

    def test_repeated_install_makes_separate_backups(self):
        self.install()
        self.install()
        self.assertEqual(len(list((self.home / "state/dejelys-nvim/backups").iterdir())), 2)

    def test_overlapping_xdg_roots_restore_once(self):
        for kind in ("CONFIG", "DATA", "STATE", "CACHE"):
            self.env["XDG_" + kind + "_HOME"] = str(self.home / "state")
        original = self.home / "state/nvim"
        original.mkdir(parents=True)
        (original / "sentinel").write_text("keep")
        self.install()
        self.call(REPO / "scripts/restore.sh", self.backup())
        self.assertEqual((original / "sentinel").read_text(), "keep")

    def test_invalid_arguments_fail_without_config_changes(self):
        self.call(REPO / "install.sh", "--unknown", success=False)
        self.call(REPO / "install.sh", "--source", success=False)
        self.env["XDG_CONFIG_HOME"] = "relative/path"
        self.call(REPO / "install.sh", "--skip-bootstrap", success=False)
        self.assertFalse((self.home / "config").exists())


if __name__ == "__main__":
    unittest.main()
