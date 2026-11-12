"""通过临时应用和替身命令验证工作流的副作用与失败恢复。"""

import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("macos_workflow", ROOT / "scripts" / "macos.py")
macos = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(macos)

FAKE_TOOL = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ["WORKFLOW_ROOT"]).resolve()
if Path.cwd().resolve() != root:
    sys.exit("测试命令只能在临时仓库内运行")
if name in ("codesign", "open") and not Path(args[-1]).resolve().is_relative_to(root):
    sys.exit("测试命令拒绝处理临时仓库之外的应用")
with open(os.environ["WORKFLOW_CALLS"], "a") as stream:
    stream.write(json.dumps([name, args, os.getcwd()]) + "\\n")
if name == "swift":
    if os.environ.get("FAIL_BUILD"):
        sys.exit(3)
    binary = Path(".build/release/ZhiziTime")
    binary.parent.mkdir(parents=True, exist_ok=True)
    binary.write_bytes(b"new executable")
    binary.chmod(0o755)
elif name == "codesign":
    path = Path(args[-1])
    if "--verify" in args and os.environ.get("FAIL_VERIFY") == str(path):
        sys.exit(4)
elif name == "ps":
    print(os.environ.get("WORKFLOW_PS", ""))
elif name == "open":
    state = Path(os.environ["WORKFLOW_OPEN_STATE"])
    state.write_text("456 " + str(Path(args[-1]) / "Contents/MacOS/ZhiziTime"))
if name == "ps":
    state = Path(os.environ["WORKFLOW_OPEN_STATE"])
    if state.exists():
        print(state.read_text())
"""


def snapshot(path):
    return {
        str(item.relative_to(path)): item.read_bytes()
        for item in path.rglob("*") if item.is_file()
    }


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="智子 workflow ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        for name in ("Taskfile.yml", "Resources", "scripts"):
            source = ROOT / name
            target = self.root / name
            if source.is_dir():
                shutil.copytree(source, target)
            else:
                shutil.copy2(source, target)
        self.tools = self.root / "fake tools"
        self.tools.mkdir()
        for tool in ("swift", "codesign", "ps", "open"):
            path = self.tools / tool
            path.write_text(FAKE_TOOL)
            path.chmod(0o755)
        self.calls = self.root / "calls.jsonl"
        self.env = dict(os.environ)
        for name in ("APP_DIR", "BUILD_DIR", "APP_NAME", "INSTALL_DIR",
                     "FAIL_BUILD", "FAIL_VERIFY", "WORKFLOW_PS"):
            self.env.pop(name, None)
        self.env.update(
            PATH=f"{self.tools}{os.pathsep}{os.environ['PATH']}",
            WORKFLOW_ROOT=str(self.root),
            WORKFLOW_CALLS=str(self.calls),
            WORKFLOW_OPEN_STATE=str(self.root / "opened"),
        )
        self.app = self.root / "dist" / "ZhiziTime.app"

    def task(self, *args, success=True):
        result = subprocess.run(
            ["task", "--silent", *args], cwd=self.root / "scripts",
            env=self.env, text=True, capture_output=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def recorded(self):
        if not self.calls.exists():
            return []
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def reset_calls(self):
        self.calls.unlink(missing_ok=True)

    def test_package_from_subdirectory_and_space_path(self):
        self.task("macos:app")
        self.assertEqual(macos.executable(self.app).read_bytes(), b"new executable")
        with (self.app / "Contents/Info.plist").open("rb") as stream:
            self.assertEqual(plistlib.load(stream)["CFBundleIdentifier"], "com.brian.zhizitime")
        calls = self.recorded()
        self.assertEqual(calls[0][0], "swift")
        self.assertTrue(any(name == "codesign" and "--sign" in args for name, args, _ in calls))
        self.assertTrue(all(cwd == str(self.root) for _, _, cwd in calls))
        self.assertFalse(any(name == "open" for name, _, _ in calls))

    def test_paths_keep_shell_metacharacters_literal(self):
        self.env["literal"] = "unexpected expansion"
        build = self.root / 'build "raw" $literal `true`'
        build.mkdir()
        binary = build / "ZhiziTime"
        binary.write_bytes(b"selected executable")
        binary.chmod(0o755)
        app = self.root / "dist" / '智子 "raw" $literal `true`.app'
        directory = self.root / '安装 "raw" $literal `true`'
        self.task("macos:app", f"APP_DIR={app}", f"BUILD_DIR={build}")
        self.assertEqual(macos.executable(app).read_bytes(), b"selected executable")
        self.task("macos:install", f"APP_DIR={app}", f"INSTALL_DIR={directory}")
        target = directory / "ZhiziTime.app"
        self.assertEqual(snapshot(target), snapshot(app))
        self.task("macos:launch", f"APP_DIR={target}")
        opened = [args for name, args, _ in self.recorded() if name == "open"]
        self.assertEqual(opened, [["-n", str(target)]])

    def test_build_failure_stops_package_and_launch(self):
        self.env["FAIL_BUILD"] = "1"
        self.task("macos:run", success=False)
        self.assertEqual([entry[0] for entry in self.recorded()], ["swift"])
        self.assertFalse(self.app.exists())

    def test_install_missing_source_preserves_target(self):
        target = self.root / "安装 目录" / "ZhiziTime.app"
        target.mkdir(parents=True)
        (target / "old").write_bytes(b"previous version")
        before = snapshot(target)
        self.task("macos:install", "INSTALL_DIR=安装 目录", success=False)
        self.assertEqual(snapshot(target), before)
        self.assertEqual(self.recorded(), [])

    def test_install_only_and_command_variable_precedence(self):
        self.task("macos:app")
        self.reset_calls()
        self.env["INSTALL_DIR"] = str(self.root / "wrong install")
        self.env["APP_DIR"] = str(self.root / "missing.app")
        self.task("macos:install", "INSTALL_DIR=安装 目录", "APP_DIR=dist/ZhiziTime.app")
        target = self.root / "安装 目录" / "ZhiziTime.app"
        self.assertEqual(snapshot(target), snapshot(self.app))
        self.assertFalse((self.root / "wrong install").exists())
        names = [entry[0] for entry in self.recorded()]
        self.assertNotIn("swift", names)
        self.assertNotIn("open", names)
        self.assertTrue(all("--sign" not in entry[1] for entry in self.recorded()))

    def test_final_signature_failure_restores_previous_bytes(self):
        self.task("macos:app")
        self.task("macos:install", "INSTALL_DIR=安装 目录")
        target = self.root / "安装 目录" / "ZhiziTime.app"
        macos.executable(target).write_bytes(b"old executable")
        before = snapshot(target)
        self.env["FAIL_VERIFY"] = str(target)
        self.task("macos:install", "INSTALL_DIR=安装 目录", success=False)
        self.assertEqual(snapshot(target), before)
        self.assertEqual(list(target.parent.glob(".zhizi-install-*")), [])

    def test_copy_and_staged_verification_failure_preserve_previous_bytes(self):
        self.task("macos:app")
        target = self.root / "安装 目录" / "ZhiziTime.app"
        target.mkdir(parents=True)
        (target / "old").write_bytes(b"keep me")
        before = snapshot(target)
        with mock.patch.object(macos, "verify"), mock.patch.object(
            macos.shutil, "copytree", side_effect=OSError("复制失败")
        ):
            with self.assertRaises(OSError):
                macos.install(self.app, target.parent)
        self.assertEqual(snapshot(target), before)
        with mock.patch.object(macos, "verify", side_effect=[None, ValueError("验签失败")]):
            with self.assertRaises(ValueError):
                macos.install(self.app, target.parent)
        self.assertEqual(snapshot(target), before)

    def test_running_target_is_not_overwritten(self):
        self.task("macos:app")
        self.task("macos:install", "INSTALL_DIR=安装 目录")
        target = self.root / "安装 目录" / "ZhiziTime.app"
        before = snapshot(target)
        self.env["WORKFLOW_PS"] = f"123 {macos.executable(target)}"
        self.task("macos:install", "INSTALL_DIR=安装 目录", success=False)
        self.assertEqual(snapshot(target), before)

    def test_launch_matches_full_path_and_run_order(self):
        self.env["WORKFLOW_PS"] = "123 /unrelated/ZhiziTime.app/Contents/MacOS/ZhiziTime"
        self.task("macos:run")
        calls = self.recorded()
        opened = next(i for i, entry in enumerate(calls) if entry[0] == "open")
        self.assertTrue(any(entry[0] == "codesign" for entry in calls[:opened]))
        self.assertEqual(calls[opened][1], ["-n", str(self.app)])
        self.assertTrue(any(entry[0] == "ps" for entry in calls[opened + 1:]))

    def test_launch_times_out_without_target_process(self):
        with mock.patch.object(macos, "verify"), mock.patch.object(macos, "run"), \
             mock.patch.object(macos, "running_pids", return_value=[]), \
             mock.patch.object(macos.time, "monotonic", side_effect=[0, 11]):
            with self.assertRaisesRegex(ValueError, "10 秒"):
                macos.launch(self.app)

    def test_failed_rollback_keeps_backup(self):
        work = self.root / "rollback"
        work.mkdir()
        target = self.root / "old.app"
        target.mkdir()
        (target / "old").write_bytes(b"recoverable")
        staged = work / "staged.app"
        staged.mkdir()
        before = snapshot(target)
        original_rename = Path.rename

        def rename(path, destination):
            if path.name == "previous.app":
                raise OSError("恢复失败")
            return original_rename(path, destination)

        with mock.patch.object(macos, "running_pids", return_value=[]), \
             mock.patch.object(macos, "verify", side_effect=ValueError("验签失败")), \
             mock.patch.object(Path, "rename", rename):
            with self.assertRaises(OSError):
                macos.replace_bundle(staged, target, work)
        self.assertEqual(snapshot(work / "previous.app"), before)


if __name__ == "__main__":
    unittest.main()
