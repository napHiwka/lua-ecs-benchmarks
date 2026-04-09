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


def get_extension_from_url(url: str) -> str:
    path = urlparse(url).path
    _, ext = os.path.splitext(path)
    return ext if ext else ".lua"


def download(url: str) -> bytes:
    with urllib.request.urlopen(url) as response:
        return response.read()


def main():
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        libs = json.load(f)

    os.makedirs(TARGET_ROOT, exist_ok=True)

    for name, url in libs.items():
        ext = get_extension_from_url(url)

        lib_dir = os.path.join(TARGET_ROOT, name)
        os.makedirs(lib_dir, exist_ok=True)

        target_file = os.path.join(lib_dir, f"init{ext}")

        try:
            data = download(url)
            with open(target_file, "wb") as f:
                f.write(data)

            print(f"[OK] {name} -> {target_file}")
        except Exception as e:
            print(f"[XX] {name}: {e}")


if __name__ == "__main__":
    main()
