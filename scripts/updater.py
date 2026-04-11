import json
import os
import urllib.request
from urllib.parse import urlparse

# You can automatically download supported libraries with this script.
# All links and names for folders in `libs.json`
# Be aware of ratelimiting from github.

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "libs.json")
TARGET_ROOT = os.path.normpath(os.path.join(BASE_DIR, "../bench/libraries"))


def get_filename_from_url(url: str, fallback: str = "file.lua") -> str:
    path = urlparse(url).path
    name = os.path.basename(path)
    return name if name else fallback


def get_extension_from_filename(filename: str) -> str:
    _, ext = os.path.splitext(filename)
    return ext if ext else ".lua"


def download(url: str) -> bytes:
    with urllib.request.urlopen(url) as response:
        return response.read()


def process_single_file(url: str, target_path: str):
    data = download(url)
    with open(target_path, "wb") as f:
        f.write(data)


def main():
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        libs = json.load(f)

    os.makedirs(TARGET_ROOT, exist_ok=True)

    for lib_name, value in libs.items():
        lib_dir = os.path.join(TARGET_ROOT, lib_name)
        os.makedirs(lib_dir, exist_ok=True)
        urls = value if isinstance(value, list) else [value]

        if not urls:
            print(f"[XX] {lib_name}: empty list")
            continue

        # Init
        init_url = urls[0]
        init_filename = get_filename_from_url(init_url)
        init_ext = get_extension_from_filename(init_filename)
        init_target = os.path.join(lib_dir, f"init{init_ext}")

        try:
            process_single_file(init_url, init_target)
            print(f"[OK] {lib_name} (init) -> {init_target}")
        except Exception as e:
            print(f"[XX] {lib_name} (init): {e}")
            continue

        # Other
        for extra_url in urls[1:]:
            filename = get_filename_from_url(extra_url)
            target_path = os.path.join(lib_dir, filename)

            try:
                process_single_file(extra_url, target_path)
                print(f"[OK] {lib_name} ({filename}) -> {target_path}")
            except Exception as e:
                print(f"[XX] {lib_name} ({filename}): {e}")


if __name__ == "__main__":
    main()
