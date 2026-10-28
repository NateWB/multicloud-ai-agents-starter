#!/usr/bin/env python3
"""Quick pre-flight check: are the CLIs installed and logged in?

Run: python3 scripts/preflight.py
Checks installation only; it never prints credentials or account IDs.
"""
import shutil
import subprocess

TOOLS = {
    "terraform": ["terraform", "version"],
    "aws": ["aws", "--version"],
    "az": ["az", "version"],
    "gcloud": ["gcloud", "--version"],
    "claude": ["claude", "--version"],
    "gemini": ["gemini", "--version"],
}


def main() -> None:
    for name, cmd in TOOLS.items():
        if shutil.which(cmd[0]) is None:
            print(f"[MISSING] {name}")
            continue
        try:
            subprocess.run(cmd, capture_output=True, timeout=20, check=True)
            print(f"[ok]      {name}")
        except Exception as exc:  # noqa: BLE001
            print(f"[ERROR]   {name}: {type(exc).__name__}")


if __name__ == "__main__":
    main()
