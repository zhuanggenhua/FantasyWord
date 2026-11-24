"""Source-free safety tests for the private ClickMoveTest launcher."""
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import clickmovetest_private as launcher


class PrivateLauncher(unittest.TestCase):
    def test_refuses_checkout_and_git_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "project"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            launcher.require_private(root / "outside")
            for target in (repo / "private", repo / ".git" / "private"):
                with self.assertRaisesRegex(ValueError, "Git"):
                    launcher.require_private(target)

    def test_hydration_requires_exact_bytes_from_either_local_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, store = root / "Unity", root / "LFS"
            repo.mkdir()
            (repo / "file.png").write_bytes(b"rubbish")
            sha = hashlib.sha256(b"blessed").hexdigest()
            pointer = f"version https://git-lfs.github.com/spec/v1\noid sha256:{sha}\nsize 7\n".encode()
            with patch.object(launcher, "read", return_value=pointer):
                with self.assertRaisesRegex(ValueError, "file.png"):
                    launcher.local_original(repo, "file.png", store)
                cache = store / "objects" / sha[:2] / sha[2:4] / sha
                cache.parent.mkdir(parents=True)
                cache.write_bytes(b"blessed")
                self.assertEqual(launcher.local_original(repo, "file.png", store), b"blessed")
                cache.unlink()
                (repo / "file.png").write_bytes(b"blessed")
                self.assertEqual(launcher.local_original(repo, "file.png", store), b"blessed")

    def test_prepare_leaves_no_partial_private_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "prepared"
            with patch.object(launcher, "original_inputs", return_value=[("first", "first.png"), ("bad", "bad.png")]):
                with patch.object(launcher, "local_original", side_effect=[b"exact", ValueError("bad source")]):
                    with self.assertRaisesRegex(ValueError, "bad source"):
                        launcher.prepare(root, out, root / "cache")
            self.assertFalse(out.exists())
            self.assertEqual(list(root.iterdir()), [])
            out.mkdir()
            with self.assertRaises(ValueError):
                launcher.prepare(root, out, root / "cache")


    def test_launch_uses_normal_project_and_only_the_prepared_formal_inputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "source-revision.txt").write_text(launcher.SOURCE, encoding="ascii")
            for dest in launcher.ENV.values():
                p = root / dest
                p.parent.mkdir(parents=True, exist_ok=True)
                if p.suffix == "":
                    p.mkdir(exist_ok=True)
                elif not p.exists():
                    p.touch()
            with patch.dict("os.environ", {"FORMAL_PLAYER_EFFECTS_SOURCE": "wrong",
                                           "FORMAL_DIAGNOSTIC": "unexpected"}):
                with patch.object(launcher.subprocess, "call", return_value=17) as child:
                    self.assertEqual(launcher.run(root, "Godot With Spaces", False, True), 17)
                    cmd = child.call_args.args[0]
                    self.assertEqual(cmd, ["Godot With Spaces", "--path", str(launcher.PROJECT),
                                           "--headless", "--quit-after", "120"])
                    env = child.call_args.kwargs["env"]
                    self.assertNotIn("FORMAL_DIAGNOSTIC", env)
                    self.assertEqual(env["FORMAL_PLAYER_EFFECTS_SOURCE"], str(root / "player-effects.json"))


if __name__ == "__main__":
    unittest.main()
