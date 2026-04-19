import json
import os
import shutil
import stat
import subprocess
import sys
import time
import urllib.request
from urllib.parse import urlparse

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "libs_urls.json")
BUNDLER_PATH = os.path.join(BASE_DIR, "onelua_bundler.lua")
CONFIGS_DIR = os.path.join(BASE_DIR, "configs")
TMP_ROOT = os.path.join(BASE_DIR, "tmp")
TARGET_ROOT = os.path.normpath(os.path.join(BASE_DIR, "../bench/libraries"))

DOWNLOAD_TIMEOUT = 30  # seconds
PROCESS_TIMEOUT = 120  # seconds
VERBOSE_BUNDLER = True

CLEANUP_RETRIES = 5
CLEANUP_RETRY_DELAY = 0.5  # seconds


def check_dependencies() -> None:
    for cmd in ("git", "lua"):
        if shutil.which(cmd) is None:
            raise EnvironmentError(
                f"Required dependency not found in PATH: '{cmd}'. "
                "Please install it and make sure it is accessible from the terminal."
            )


def download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=DOWNLOAD_TIMEOUT) as response:
        return response.read()


def get_extension_from_url(url: str, fallback: str = ".lua") -> str:
    path = urlparse(url).path
    _, ext = os.path.splitext(os.path.basename(path))
    if not ext:
        print(
            f"[WARN] Could not detect extension from URL, defaulting to '{fallback}': {url}"
        )
        return fallback
    return ext


def download_single(lib_name: str, url: str) -> None:
    ext = get_extension_from_url(url)
    lib_dir = os.path.join(TARGET_ROOT, lib_name)
    os.makedirs(lib_dir, exist_ok=True)
    target_path = os.path.join(lib_dir, f"init{ext}")
    data = download(url)
    with open(target_path, "wb") as f:
        f.write(data)
    print(f"[OK] {lib_name} -> {target_path}")


def _is_commit_hash(ref: str) -> bool:
    return 7 <= len(ref) <= 40 and all(c in "0123456789abcdefABCDEF" for c in ref)


def _run_git(*args: str, cwd: str | None = None) -> None:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        timeout=PROCESS_TIMEOUT,
        cwd=cwd,
    )
    if result.returncode != 0:
        raise subprocess.CalledProcessError(
            result.returncode, f"git {args[0]}", stderr=result.stderr.strip()
        )


def clone_repo(repo: str, ref: str, dst: str) -> None:
    if os.path.exists(dst):
        _rmtree(dst)
    if _is_commit_hash(ref):
        _run_git("clone", "--single-branch", repo, dst)
        _run_git("checkout", ref, cwd=dst)
    else:
        _run_git("clone", "--depth", "1", "--branch", ref, "--single-branch", repo, dst)


def run_bundler(repo_dir: str, config_path: str, *, verbose: bool = False) -> None:
    cmd = ["lua", BUNDLER_PATH, "--config", config_path]
    if verbose:
        result = subprocess.run(cmd, cwd=repo_dir, timeout=PROCESS_TIMEOUT)
        stderr = ""
    else:
        result = subprocess.run(
            cmd, cwd=repo_dir, capture_output=True, text=True, timeout=PROCESS_TIMEOUT
        )
        stderr = result.stderr.strip()
    if result.returncode != 0:
        raise subprocess.CalledProcessError(
            result.returncode, "lua bundler", stderr=stderr
        )


def _chmod_tree(path: str) -> None:
    # Git marks objects as read-only; walk the tree and make everything writable
    # before rmtree so it can delete without hitting access errors.
    for root, dirs, files in os.walk(path):
        for name in files + dirs:
            try:
                os.chmod(os.path.join(root, name), stat.S_IWRITE)
            except OSError:
                pass


def _rmtree(path: str) -> None:
    """Remove a directory tree with retry logic for Windows process-lock errors."""
    for attempt in range(1, CLEANUP_RETRIES + 1):
        try:
            _chmod_tree(path)
            shutil.rmtree(path)
            return
        except PermissionError:
            if attempt == CLEANUP_RETRIES:
                break
            time.sleep(CLEANUP_RETRY_DELAY)

    try:
        if sys.platform == "win32":
            subprocess.run(
                ["cmd", "/c", "rmdir", "/s", "/q", path],
                check=True,
                timeout=30,
            )
        else:
            subprocess.run(["rm", "-rf", path], check=True, timeout=30)
    except Exception as e:
        print(f"[WARN] Could not remove temp directory '{path}': {e}")


def cleanup_tmp(path: str) -> None:
    if os.path.exists(path):
        _rmtree(path)


def validate_repo_entry(lib_name: str, value: dict) -> None:
    missing = [key for key in ("repo", "config") if key not in value]
    if missing:
        raise ValueError(
            f"Config entry for '{lib_name}' is missing required field(s): {', '.join(missing)}"
        )


def main() -> None:
    check_dependencies()

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        libs = json.load(f)

    if not isinstance(libs, dict):
        raise TypeError(
            f"Expected a JSON object at the root of '{CONFIG_PATH}', "
            f"got {type(libs).__name__}."
        )

    os.makedirs(TARGET_ROOT, exist_ok=True)
    os.makedirs(TMP_ROOT, exist_ok=True)
    os.makedirs(CONFIGS_DIR, exist_ok=True)

    try:
        for lib_name, value in libs.items():
            try:
                if isinstance(value, str):
                    download_single(lib_name, value)
                    continue

                if not isinstance(value, dict):
                    print(
                        f"[XX] {lib_name}: unsupported config type '{type(value).__name__}'"
                    )
                    continue

                if "config" not in value:
                    url = value.get("url")
                    if not url:
                        print(f"[XX] {lib_name}: missing 'url' field")
                        continue
                    download_single(lib_name, url)
                    continue

                validate_repo_entry(lib_name, value)

                repo = value["repo"]
                ref = value.get("ref", "main")
                config_rel = value["config"]

                repo_dir = os.path.join(TMP_ROOT, lib_name)
                config_path = os.path.join(BASE_DIR, config_rel)

                if not os.path.isfile(config_path):
                    raise FileNotFoundError(f"Bundler config not found: {config_path}")

                clone_repo(repo, ref, repo_dir)
                run_bundler(repo_dir, config_path, verbose=VERBOSE_BUNDLER)
                print(f"[OK] {lib_name}: bundled")

            except subprocess.CalledProcessError as e:
                stderr_hint = f"\n  {e.stderr}" if e.stderr else ""
                print(
                    f"[XX] {lib_name}: command failed with code {e.returncode}{stderr_hint}"
                )
            except Exception as e:
                print(f"[XX] {lib_name}: {e}")
    finally:
        cleanup_tmp(TMP_ROOT)


if __name__ == "__main__":
    main()
