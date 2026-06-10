from __future__ import annotations

from pathlib import Path
import random
import runpy

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "question_images"


def seeded(stem: str) -> random.Random:
    return random.Random(sum((i + 1) * b for i, b in enumerate(stem.encode("utf-8"))))


def lerp(a: int, b: int, t: float) -> int:
    return int(a * (1 - t) + b * t)


def gradient_background(
    draw: ImageDraw.ImageDraw,
    width: int,
    height: int,
    top: tuple[int, int, int],
    bottom: tuple[int, int, int],
) -> None:
    for y in range(height):
        t = y / max(1, height - 1)
        draw.line(
            (0, y, width, y),
            fill=(
                lerp(top[0], bottom[0], t),
                lerp(top[1], bottom[1], t),
                lerp(top[2], bottom[2], t),
            ),
        )


def draw_landscape(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (134, 190, 226), (247, 239, 211))
    sun_x = rng.randint(90, width - 120)
    draw.ellipse((sun_x, 54, sun_x + 96, 150), fill=(255, 204, 103))
    draw.rectangle((0, 350, width, height), fill=(80, 132, 87))
    for layer, color in enumerate([(55, 101, 132), (43, 116, 87), (87, 132, 91)]):
        y_base = 392 - layer * 38
        points = [(0, y_base)]
        for x in range(-80, width + 160, 130):
            points.extend([(x + 70, rng.randint(120, 255) + layer * 28), (x + 150, y_base)])
        points.append((width, y_base))
        points.append((width, height))
        points.append((0, height))
        draw.polygon(points, fill=color)
    for _ in range(12):
        x = rng.randint(20, width - 20)
        y = rng.randint(365, height - 22)
        draw.line((x, y, x, y - rng.randint(28, 56)), fill=(64, 87, 54), width=4)
        draw.ellipse((x - 14, y - 62, x + 14, y - 28), fill=(42, 105, 67))


def draw_water(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (118, 188, 226), (231, 243, 248))
    draw.rectangle((0, 310, width, height), fill=(40, 132, 179))
    for i in range(12):
        y = 330 + i * 16
        color = (190, 229, 242) if i % 2 == 0 else (87, 164, 201)
        for x in range(-80, width, 180):
            draw.arc((x, y - 26, x + 160, y + 26), 15, 165, fill=color, width=4)
    draw.polygon([(90, 335), (238, 170), (394, 335)], fill=(65, 116, 92))
    draw.polygon([(324, 335), (514, 134), (724, 335)], fill=(79, 111, 159))


def draw_fire_festival(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (34, 37, 64), (128, 67, 75))
    draw.rectangle((0, 360, width, height), fill=(48, 54, 63))
    for x in range(120, width - 80, 95):
        draw.ellipse((x, 310, x + 34, 344), fill=(48, 40, 42))
        draw.rectangle((x + 12, 342, x + 23, 410), fill=(31, 35, 43))
    cx = width // 2
    for color, scale in [((255, 210, 80), 1.0), ((238, 92, 54), 0.82), ((255, 151, 64), 0.58)]:
        draw.polygon(
            [
                (cx - int(120 * scale), 390),
                (cx - int(40 * scale), 240),
                (cx, 320 - int(130 * scale)),
                (cx + int(46 * scale), 250),
                (cx + int(118 * scale), 390),
            ],
            fill=color,
        )
    for _ in range(55):
        x = rng.randint(0, width)
        y = rng.randint(20, 230)
        draw.ellipse((x, y, x + 3, y + 3), fill=(255, 224, 150))


def draw_book_scene(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (235, 226, 209), (197, 174, 145))
    draw.rounded_rectangle((130, 118, 770, 420), radius=24, fill=(245, 238, 220))
    draw.polygon([(450, 118), (770, 150), (770, 420), (450, 390)], fill=(234, 223, 201))
    draw.line((450, 128, 450, 400), fill=(130, 92, 68), width=8)
    for side in [0, 1]:
        x0 = 180 if side == 0 else 500
        for i in range(8):
            y = 168 + i * 24
            draw.line((x0, y, x0 + rng.randint(160, 230), y), fill=(139, 118, 91), width=4)
    draw.rectangle((0, 420, width, height), fill=(109, 83, 66))


def draw_music_scene(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (48, 43, 82), (132, 73, 105))
    draw.ellipse((122, 280, 318, 430), fill=(166, 105, 62))
    draw.ellipse((164, 308, 276, 398), fill=(235, 199, 137))
    draw.rectangle((292, 235, 648, 270), fill=(115, 76, 53))
    draw.ellipse((620, 222, 704, 282), fill=(166, 105, 62))
    for offset in [0, 10, 20, 30]:
        draw.line((285, 242 + offset, 668, 248 + offset), fill=(238, 217, 180), width=2)
    for x, y in [(220, 120), (360, 82), (570, 128), (690, 92)]:
        draw.ellipse((x, y + 48, x + 34, y + 82), fill=(250, 218, 125))
        draw.rectangle((x + 30, y, x + 38, y + 64), fill=(250, 218, 125))


def draw_people_scene(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (231, 219, 201), (202, 171, 139))
    draw.rectangle((0, 374, width, height), fill=(117, 91, 70))
    colors = [(51, 93, 154), (177, 62, 74), (33, 126, 91), (217, 151, 58)]
    for i, x in enumerate(range(145, 760, 100)):
        y = 250 + (i % 2) * 18
        draw.ellipse((x, y, x + 48, y + 48), fill=(122, 83, 58))
        draw.polygon([(x - 18, y + 62), (x + 24, y + 40), (x + 70, y + 62), (x + 86, y + 190), (x - 34, y + 190)], fill=colors[i % len(colors)])
        if i > 0:
            draw.line((x - 36, y + 92, x - 68, y + 78), fill=(122, 83, 58), width=8)


def draw_history_scene(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (222, 204, 171), (166, 137, 98))
    draw.rounded_rectangle((126, 96, 774, 418), radius=20, fill=(235, 216, 177))
    for _ in range(14):
        x = rng.randint(180, 690)
        y = rng.randint(140, 350)
        draw.rectangle((x, y, x + rng.randint(38, 92), y + 8), fill=(130, 94, 61))
    draw.ellipse((330, 164, 570, 348), outline=(91, 64, 49), width=12)
    draw.line((510, 315, 668, 430), fill=(91, 64, 49), width=18)
    draw.ellipse((356, 190, 544, 322), outline=(249, 237, 207), width=8)


def draw_language_scene(draw: ImageDraw.ImageDraw, rng: random.Random, width: int, height: int) -> None:
    gradient_background(draw, width, height, (224, 237, 246), (202, 216, 235))
    for i, (x, y, color) in enumerate(
        [(124, 132, (64, 89, 173)), (360, 96, (38, 130, 91)), (572, 150, (203, 76, 86))]
    ):
        draw.rounded_rectangle((x, y, x + 210, y + 140), radius=28, fill=color)
        draw.polygon([(x + 50, y + 140), (x + 92, y + 140), (x + 54, y + 184)], fill=color)
        for j in range(3):
            draw.line((x + 42, y + 44 + j * 28, x + 168, y + 44 + j * 28), fill=(240, 244, 250), width=7)
    draw.arc((190, 332, 710, 430), 200, 340, fill=(84, 105, 140), width=9)


def scene_for(stem: str):
    if any(k in stem for k in ["av", "gol", "cem", "re", "hewa"]):
        return draw_water
    if any(k in stem for k in ["ciya", "newal", "erd", "daristan", "sinor", "goc", "yerlesik"]):
        return draw_landscape
    if any(k in stem for k in ["newroz", "govend", "bayram", "kilim", "kiyafet", "misafir", "mutfak"]):
        return draw_fire_festival if "newroz" in stem else draw_people_scene
    if any(k in stem for k in ["dengbej", "ritim", "melodi", "stran", "def", "erbane", "tembur", "nota", "koro", "solo"]):
        return draw_music_scene
    if any(k in stem for k in ["cirok", "helbest", "roman", "destan", "karakter", "tema", "mecaz", "kafiye", "anlatici", "diyalog", "pirtuk"]):
        return draw_book_scene
    if any(k in stem for k in ["kaynak", "tarih", "kronoloji", "arkeoloji", "mezopotamya", "ticaret", "etkilesim", "yorum"]):
        return draw_history_scene
    if any(k in stem for k in ["heval", "zarok", "xwendekar", "spas", "nav", "dil", "zanin", "rast"]):
        return draw_language_scene
    return draw_landscape


def create_image(stem: str) -> None:
    scale = 2
    width, height = 900 * scale, 520 * scale
    image = Image.new("RGB", (width, height), (235, 235, 235))
    draw = ImageDraw.Draw(image)
    scene_for(stem)(draw, seeded(stem), width, height)
    image = image.filter(ImageFilter.SMOOTH_MORE)
    image = image.resize((900, 520), Image.Resampling.LANCZOS)
    image.save(OUTPUT_DIR / f"{stem}.png", optimize=True)


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
