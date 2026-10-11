#!/usr/bin/env python3
"""Install the pinned repository-owned Noto Sans CJK fonts."""

from __future__ import annotations

import argparse
import hashlib
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "fonts"
EXPECTED_SHA256 = {
    "simplified": "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da",
    "traditional": "864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f",
}


def install(source: Path, target: Path, expected_sha256: str) -> None:
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != expected_sha256:
        raise SystemExit(
            f"unexpected SHA-256 for {source}: {digest}; expected {expected_sha256}"
        )
    shutil.copyfile(source, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--simplified-font", required=True, type=Path)
    parser.add_argument("--traditional-font", required=True, type=Path)
    args = parser.parse_args()

    FONT_DIR.mkdir(parents=True, exist_ok=True)
    install(
        args.simplified_font,
        FONT_DIR / "NotoSansSC-UI.ttf",
        EXPECTED_SHA256["simplified"],
    )
    install(
        args.traditional_font,
        FONT_DIR / "NotoSansTC-UI.ttf",
        EXPECTED_SHA256["traditional"],
    )


if __name__ == "__main__":
    main()
