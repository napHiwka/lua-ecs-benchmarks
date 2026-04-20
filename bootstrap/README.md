# Bootstrap

Prepares the benchmark environment by downloading and bundling all third-party Lua libraries. Libraries are not stored in the repository; run this script whenever you clone the repo or want to update them.

## Requirements

- Python 3.8+
- `git` available in PATH
- `lua` available in PATH

## Usage

```bash
cd bootstrap
python main.py
```

Fetched libraries are placed in `bench/libraries/<lib-name>/init.lua`.  
Temporary files are cleaned up automatically on exit.

## Configuration

`libs_urls.json` defines what to download. Each entry is one of:

```jsonc
{
  // Direct URL download
  "lib-name": "https://example.com/lib.lua",

  // URL inside an object (no bundling)
  "lib-name": { "url": "https://example.com/lib.lua" },

  // Clone a repo and run the bundler
  "lib-name": {
    "repo": "https://github.com/owner/repo",
    "ref": "v1.0.0", // branch, tag, commit; defaults to "main"
    "config": "configs/lib-name.json"
  }
}
```

> **Commits:** if `ref` is a 7-40 character hex string, the script clones the full history and checks out that commit. Use a branch or tag wherever possible to keep clones shallow and fast.
