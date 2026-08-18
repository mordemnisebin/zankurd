from __future__ import annotations

import argparse
from pathlib import Path
import shutil

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets" / "question_images"
SUPPORTED = {".png", ".jpg", ".jpeg", ".webp"}
TARGET_SIZE = (900, 520)


def normalize_image(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        image = image.convert("RGB")
        image.thumbnail(TARGET_SIZE, Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", TARGET_SIZE, (245, 245, 245))
        x = (TARGET_SIZE[0] - image.width) // 2
        y = (TARGET_SIZE[1] - image.height) // 2
        canvas.paste(image, (x, y))
        canvas.save(destination, optimize=True)


def import_images(source_dir: Path, *, normalize: bool) -> list[Path]:
    if not source_dir.is_dir():
        raise SystemExit(f"Source folder not found: {source_dir}")

    DESTINATION.mkdir(parents=True, exist_ok=True)
    imported: list[Path] = []
    for source in sorted(source_dir.iterdir()):
        if not source.is_file() or source.suffix.lower() not in SUPPORTED:
            continue
        destination = DESTINATION / f"{source.stem}.png"
        if normalize:
            normalize_image(source, destination)
        elif source.suffix.lower() == ".png":
            shutil.copy2(source, destination)
        else:
            normalize_image(source, destination)
        imported.append(destination)
    return imported


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Import real question images into assets/question_images. "
            "File names must match the image slug used by the question bank, "
            "for example newroz.png or dengbej.jpg."
        ),
    )
    parser.add_argument("source_dir", type=Path)
    parser.add_argument(
        "--no-normalize",
        action="store_true",
        help="Copy PNG files as-is; JPG/WEBP files are still converted to PNG.",
    )
    args = parser.parse_args()

    imported = import_images(args.source_dir, normalize=not args.no_normalize)
    for path in imported:
        print(path.relative_to(ROOT))
    print(f"Imported {len(imported)} image(s).")


if __name__ == "__main__":
    main()
