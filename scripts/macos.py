#!/usr/bin/env python3
"""组织本地 macOS 应用的打包、校验、安装与启动。"""

import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent
APP_NAME = "ZhiziTime"
BUNDLE_ID = "com.brian.zhizitime"


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def bundle_path(value):
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = ROOT / path
    if path.is_symlink():
        raise ValueError(f"应用路径不能是符号链接：{path}")
    path = path.resolve()
    if path.suffix != ".app":
        raise ValueError(f"应用路径必须以 .app 结尾：{path}")
    return path


def executable(app):
    return app / "Contents" / "MacOS" / APP_NAME


def verify(app):
    if not app.is_dir():
        raise ValueError(f"找不到应用包，请先运行 task app：{app}")
    with (app / "Contents" / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    expected = {
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleExecutable": APP_NAME,
        "CFBundlePackageType": "APPL",
        "CFBundleIconFile": "AppIcon.icns",
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": True,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f"{app} 的 {key} 应为 {value!r}")
    binary = executable(app)
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError(f"可执行文件不存在或不可执行：{binary}")
    icon = app / "Contents" / "Resources" / "AppIcon.icns"
    if not icon.is_file() or icon.stat().st_size == 0:
        raise ValueError(f"图标不存在或为空：{icon}")
    run("codesign", "--verify", "--deep", "--strict", str(app))


def running_pids(app):
    result = run("ps", "-axo", "pid=,comm=", text=True, capture_output=True)
    target = executable(app).resolve()
    pids = []
    for line in result.stdout.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and Path(fields[1]).is_absolute():
            if Path(fields[1]).resolve() == target:
                pids.append(int(fields[0]))
    return pids


@contextmanager
def staging_directory(parent, prefix):
    work = Path(tempfile.mkdtemp(prefix=prefix, dir=parent))
    try:
        yield work
    finally:
        # 回滚自身失败时保留备份，避免临时目录清理导致旧应用丢失。
        if (work / "previous.app").exists():
            print(f"旧应用备份保留在：{work / 'previous.app'}", file=sys.stderr)
        else:
            shutil.rmtree(work)


def replace_bundle(staged, target, work):
    if target.is_symlink() or (target.exists() and not target.is_dir()):
        raise ValueError(f"拒绝覆盖符号链接或普通文件：{target}")
    if running_pids(target):
        raise ValueError(f"应用正在运行，请先通过菜单栏退出：{target}")
    backup = work / "previous.app"
    had_previous = target.exists()
    if had_previous:
        target.rename(backup)
    try:
        staged.rename(target)
        verify(target)
    except BaseException:
        if target.exists():
            shutil.rmtree(target)
        if had_previous:
            backup.rename(target)
        raise
    if had_previous:
        shutil.rmtree(backup)


def package(binary, app):
    binary = Path(binary).expanduser().resolve()
    if not binary.is_file():
        raise ValueError(f"找不到 release 可执行文件：{binary}")
    app.parent.mkdir(parents=True, exist_ok=True)
    with staging_directory(app.parent, ".zhizi-package-") as work:
        staged = work / app.name
        macos = staged / "Contents" / "MacOS"
        resources = staged / "Contents" / "Resources"
        macos.mkdir(parents=True)
        resources.mkdir()
        shutil.copy2(binary, macos / APP_NAME)
        executable(staged).chmod(0o755)
        shutil.copy2(ROOT / "Resources" / "Info.plist", staged / "Contents" / "Info.plist")
        shutil.copy2(ROOT / "Resources" / "AppIcon.icns", resources / "AppIcon.icns")
        run("codesign", "--force", "--sign", "-", str(staged))
        verify(staged)
        replace_bundle(staged, app, work)
    print(f"已打包并校验：{app}")


def install(app, install_dir):
    verify(app)
    directory = Path(install_dir).expanduser().resolve()
    target = bundle_path(str(directory / f"{APP_NAME}.app"))
    if app == target or app in target.parents or target in app.parents:
        raise ValueError("安装源与目标不能相同或互相包含")
    directory.mkdir(parents=True, exist_ok=True)
    with staging_directory(directory, ".zhizi-install-") as work:
        staged = work / target.name
        shutil.copytree(app, staged, symlinks=True)
        verify(staged)
        replace_bundle(staged, target, work)
    print(f"已安装并校验：{target}")


def launch(app):
    verify(app)
    if running_pids(app):
        print(f"目标应用已在运行：{app}")
        return
    deadline = time.monotonic() + 10
    run("open", "-n", str(app), timeout=10)
    while time.monotonic() < deadline:
        pids = running_pids(app)
        if pids:
            print(f"已确认启动：{app}，PID={pids}")
            return
        time.sleep(0.2)
    raise ValueError(f"10 秒内未发现目标应用进程：{app}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("package", "verify", "install", "launch"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--app", required=True)
        if command == "package":
            subparser.add_argument("--binary", required=True)
        if command == "install":
            subparser.add_argument("--install-dir", required=True)
    args = parser.parse_args()
    app = bundle_path(args.app)
    if args.command == "package":
        package(args.binary, app)
    elif args.command == "verify":
        verify(app)
        print(f"已校验：{app}")
    elif args.command == "install":
        install(app, args.install_dir)
    else:
        launch(app)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, plistlib.InvalidFileException, subprocess.SubprocessError) as error:
        print(f"错误：{error}", file=sys.stderr)
        sys.exit(1)
