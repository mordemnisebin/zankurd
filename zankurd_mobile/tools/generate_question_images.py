from __future__ import annotations

from pathlib import Path
import runpy

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "question_images"


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/seguisb.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def palette(stem: str) -> tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]:
    palettes = [
        ((23, 122, 86), (247, 243, 236), (205, 63, 49)),
        ((64, 89, 173), (242, 246, 255), (23, 122, 86)),
        ((189, 123, 43), (255, 247, 230), (64, 89, 173)),
        ((115, 76, 54), (246, 240, 232), (23, 122, 86)),
    ]
    return palettes[sum(stem.encode("utf-8")) % len(palettes)]


def title_from_stem(stem: str) -> str:
    return stem.replace("_", " ").title()


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, max_width: int, fill: tuple[int, int, int], image_font: ImageFont.ImageFont) -> None:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        test = f"{current} {word}".strip()
        bbox = draw.textbbox((0, 0), test, font=image_font)
        if bbox[2] - bbox[0] <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)

    for line in lines[:3]:
        draw.text((x, y), line, font=image_font, fill=fill)
        y += 54


def draw_icon(draw: ImageDraw.ImageDraw, stem: str, accent: tuple[int, int, int], dark: tuple[int, int, int]) -> None:
    if any(key in stem for key in ["ciya", "newal", "cografya", "erd", "sînor", "sinor"]):
        draw.polygon([(90, 390), (245, 145), (405, 390)], fill=accent)
        draw.polygon([(265, 390), (455, 105), (695, 390)], fill=dark)
        draw.polygon([(410, 175), (455, 105), (515, 180)], fill=(247, 243, 236))
    elif any(key in stem for key in ["pirtuk", "cirok", "helbest", "edebiyat", "mem"]):
        draw.rounded_rectangle((95, 135, 680, 390), radius=28, fill=accent)
        draw.line((390, 145, 390, 380), fill=(247, 243, 236), width=6)
        for offset in [0, 42, 84]:
            draw.line((135, 185 + offset, 340, 185 + offset), fill=(247, 243, 236), width=5)
            draw.line((430, 185 + offset, 635, 185 + offset), fill=(247, 243, 236), width=5)
    elif any(key in stem for key in ["muz", "ritm", "stran", "nota", "dengbej", "erbane", "def"]):
        draw.ellipse((120, 255, 245, 380), fill=accent)
        draw.rectangle((220, 120, 252, 320), fill=dark)
        draw.arc((245, 110, 430, 245), 270, 85, fill=dark, width=24)
        draw.ellipse((410, 245, 535, 370), fill=accent)
    elif any(key in stem for key in ["newroz", "agir", "govend", "cand", "kilim"]):
        draw.polygon([(200, 390), (260, 230), (310, 390)], fill=accent)
        draw.polygon([(305, 390), (380, 150), (470, 390)], fill=dark)
        draw.polygon([(440, 390), (505, 250), (575, 390)], fill=accent)
    else:
        draw.rounded_rectangle((120, 135, 660, 390), radius=34, outline=accent, width=10)
        draw.ellipse((175, 195, 285, 305), fill=accent)
        draw.ellipse((495, 195, 605, 305), fill=dark)
        draw.line((285, 250, 495, 250), fill=accent, width=9)


def create_image(stem: str) -> None:
    width, height = 900, 520
    dark, light, accent = palette(stem)
    image = Image.new("RGB", (width, height), light)
    draw = ImageDraw.Draw(image)

    for y in range(height):
        blend = y / height
        r = int(light[0] * (1 - blend) + 255 * blend)
        g = int(light[1] * (1 - blend) + 250 * blend)
        b = int(light[2] * (1 - blend) + 240 * blend)
        draw.line((0, y, width, y), fill=(r, g, b))

    draw.rounded_rectangle((38, 34, width - 38, height - 34), radius=36, fill=(255, 255, 255), outline=(226, 218, 205), width=3)
    draw_icon(draw, stem, accent, dark)

    draw.rounded_rectangle((54, 54, 252, 102), radius=18, fill=dark)
    draw.text((78, 66), "ZanKurd", font=font(26), fill=(255, 255, 255))

    draw_wrapped(draw, title_from_stem(stem), 86, 415, 720, dark, font(42))
    image.save(OUTPUT_DIR / f"{stem}.png")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ns = runpy.run_path(str(ROOT / "tools" / "generate_rich_question_bank.py"))
    questions = ns["build_questions"]()
    stems = sorted(
        {
            Path(str(question["image"]).replace("asset://assets/question_images/", "")).stem
            for question in questions
            if question.get("image")
        }
    )
    for stem in stems:
        create_image(stem)
    print(f"Wrote {len(stems)} images to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
