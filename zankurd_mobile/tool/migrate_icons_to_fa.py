#!/usr/bin/env python3
"""Material Icons -> FontAwesomeIcons (solid stil, .data ile düz IconData'ya
köprülenmiş) tek seferlik migrasyon scripti.

FontAwesomeIcons.X bir FaIconData döndürür (Icon widget'ıyla tip uyumsuz);
.data alanı ise düz bir IconData sarmalar — bunu Icons.X'in yerine
doğrudan kullanabiliriz. Bu, hem SDK uyumluluğunu (plain IconData, final
class sorunu yok) hem geniş kapsamı (2141 ikon) bir arada verir.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib" / "src"

MAPPING = {
    "chevron_right_rounded": "chevronRight",
    "emoji_events_rounded": "trophy",
    "emoji_events_outlined": "trophy",
    "emoji_events": "trophy",
    "star_rounded": "star",
    "stars_outlined": "star",
    "star_outline_rounded": "star",
    "workspace_premium_outlined": "medal",
    "workspace_premium_rounded": "medal",
    "check_rounded": "check",
    "check": "check",
    "task_alt_rounded": "circleCheck",
    "task_alt": "circleCheck",
    "check_circle_outline": "circleCheck",
    "check_circle": "circleCheck",
    "check_circle_rounded": "circleCheck",
    "check_circle_outline_rounded": "circleCheck",
    "bolt_rounded": "bolt",
    "refresh_rounded": "arrowsRotate",
    "refresh": "arrowsRotate",
    "refresh_outlined": "arrowsRotate",
    "play_arrow_rounded": "play",
    "local_fire_department_rounded": "fire",
    "local_fire_department": "fire",
    "local_fire_department_outlined": "fire",
    "casino_outlined": "dice",
    "monetization_on": "coins",
    "monetization_on_rounded": "coins",
    "monetization_on_outlined": "coins",
    "menu_book_outlined": "bookOpen",
    "menu_book_rounded": "bookOpen",
    "lock_outlined": "lock",
    "lock_outline": "lock",
    "lock": "lock",
    "lock_outline_rounded": "lock",
    "lock_clock_outlined": "lock",
    "auto_awesome_rounded": "wandMagicSparkles",
    "auto_awesome_outlined": "wandMagicSparkles",
    "auto_awesome_motion_outlined": "wandMagicSparkles",
    "arrow_forward_rounded": "arrowRight",
    "arrow_forward": "arrowRight",
    "arrow_forward_outlined": "arrowRight",
    "arrow_forward_ios_rounded": "chevronRight",
    "visibility_off": "eyeSlash",
    "visibility": "eye",
    "visibility_rounded": "eye",
    "school_rounded": "graduationCap",
    "school_outlined": "graduationCap",
    "person_outline": "user",
    "person": "user",
    "person_rounded": "user",
    "military_tech_rounded": "medal",
    "military_tech_outlined": "medal",
    "hourglass_empty_rounded": "hourglass",
    "hourglass_top_rounded": "hourglassStart",
    "home_rounded": "house",
    "home_outlined": "house",
    "home": "house",
    "flag_outlined": "flag",
    "close_rounded": "xmark",
    "close": "xmark",
    "category_outlined": "tableCells",
    "category_rounded": "tableCells",
    "cancel_outlined": "circleXmark",
    "cancel": "circleXmark",
    "auto_stories_rounded": "bookOpenReader",
    "timer_outlined": "stopwatch",
    "timer_off_outlined": "stopwatch",
    "text_fields_rounded": "font",
    "text_format_rounded": "font",
    "abc_rounded": "font",
    "sports_esports_rounded": "gamepad",
    "sports_esports_outlined": "gamepad",
    "sports_esports": "gamepad",
    "quiz_outlined": "question",
    "quiz_rounded": "question",
    "question_mark": "question",
    "help_outline_rounded": "circleQuestion",
    "help_outline": "circleQuestion",
    "public_rounded": "globe",
    "public_outlined": "globe",
    "psychology_outlined": "brain",
    "psychology_alt_rounded": "brain",
    "music_note_rounded": "music",
    "music_note_outlined": "music",
    "meeting_room_outlined": "doorOpen",
    "lightbulb_outline": "lightbulb",
    "lightbulb_outline_rounded": "lightbulb",
    "email_outlined": "envelope",
    "celebration_rounded": "champagneGlasses",
    "celebration_outlined": "champagneGlasses",
    "add_circle_outline": "circlePlus",
    "trending_up_rounded": "arrowTrendUp",
    "translate_rounded": "language",
    "translate_outlined": "language",
    "language": "language",
    "track_changes_rounded": "bullseye",
    "today_rounded": "calendarDays",
    "calendar_month_outlined": "calendarDays",
    "storefront_outlined": "store",
    "speed_outlined": "gaugeHigh",
    "speed_rounded": "gaugeHigh",
    "send_rounded": "paperPlane",
    "schedule_rounded": "clock",
    "access_time_rounded": "clock",
    "access_time_outlined": "clock",
    "save_outlined": "floppyDisk",
    "replay_rounded": "arrowRotateLeft",
    "skip_next_rounded": "forward",
    "shuffle_rounded": "shuffle",
    "person_add_alt_rounded": "userPlus",
    "person_add_alt_1_rounded": "userPlus",
    "group_add_outlined": "userPlus",
    "people_outline": "peopleGroup",
    "people_rounded": "peopleGroup",
    "people_alt_rounded": "peopleGroup",
    "group_outlined": "peopleGroup",
    "groups_outlined": "peopleGroup",
    "groups_2_rounded": "peopleGroup",
    "groups_2_outlined": "peopleGroup",
    "family_restroom_rounded": "peopleRoof",
    "diversity_3_outlined": "peopleGroup",
    "diversity_2_rounded": "peopleGroup",
    "palette_outlined": "palette",
    "palette_rounded": "palette",
    "style_outlined": "paintbrush",
    "notifications_off_outlined": "bellSlash",
    "notifications_active_outlined": "bell",
    "login": "rightToBracket",
    "login_rounded": "rightToBracket",
    "logout_rounded": "rightFromBracket",
    "light_mode_outlined": "sun",
    "wb_sunny_rounded": "sun",
    "dark_mode_outlined": "moon",
    "leaderboard_rounded": "chartColumn",
    "leaderboard_outlined": "chartColumn",
    "analytics_outlined": "chartLine",
    "insights_rounded": "chartLine",
    "keyboard_arrow_down_rounded": "chevronDown",
    "keyboard_arrow_up_rounded": "chevronUp",
    "grid_view_rounded": "tableCells",
    "grid_view_outlined": "tableCells",
    "favorite_border_rounded": "heart",
    "error_outline_rounded": "triangleExclamation",
    "error_outline": "triangleExclamation",
    "warning_amber_rounded": "triangleExclamation",
    "diamond_rounded": "gem",
    "chat_bubble_outline_rounded": "comment",
    "chat_bubble_rounded": "comment",
    "chat_rounded": "comment",
    "bookmark_rounded": "bookmark",
    "bookmark_border": "bookmark",
    "bookmark": "bookmark",
    "bookmark_outline": "bookmark",
    "bookmark_added_outlined": "bookmark",
    "bookmark_remove_outlined": "bookmark",
    "badge_outlined": "idBadge",
    "auto_fix_high_rounded": "wandMagicSparkles",
    "face_retouching_natural_rounded": "faceSmile",
    "arrow_back_rounded": "arrowLeft",
    "arrow_back": "arrowLeft",
    "work_rounded": "briefcase",
    "waving_hand_rounded": "hand",
    "volume_up_outlined": "volumeHigh",
    "volume_off_outlined": "volumeXmark",
    "touch_app_rounded": "handPointer",
    "theater_comedy_rounded": "masksTheater",
    "terrain_rounded": "mountain",
    "landscape_rounded": "mountain",
    "stairs_rounded": "stairs",
    "shopping_cart_outlined": "cartShopping",
    "shopping_bag_outlined": "bagShopping",
    "shield_rounded": "shield",
    "shield_outlined": "shield",
    "shield_moon_rounded": "shieldHalved",
    "privacy_tip_outlined": "shieldHalved",
    "share_rounded": "shareNodes",
    "settings_rounded": "gear",
    "settings_outlined": "gear",
    "sentiment_very_dissatisfied_outlined": "faceFrown",
    "sentiment_satisfied_rounded": "faceSmile",
    "search": "magnifyingGlass",
    "restaurant_rounded": "utensils",
    "report_gmailerrorred_outlined": "triangleExclamation",
    "play_circle_fill": "circlePlay",
    "photo_library_outlined": "images",
    "photo_camera": "camera",
    "pets_rounded": "paw",
    "park_rounded": "tree",
    "numbers_rounded": "hashtag",
    "mic_rounded": "microphone",
    "location_on_rounded": "locationDot",
    "local_florist_rounded": "seedling",
    "list_alt_rounded": "listCheck",
    "library_books_outlined": "book",
    "layers_outlined": "layerGroup",
    "info_outline_rounded": "circleInfo",
    "inbox_outlined": "inbox",
    "image_outlined": "image",
    "image_not_supported_outlined": "image",
    "how_to_vote_outlined": "squareCheck",
    "gavel_rounded": "gavel",
    "format_quote_rounded": "quoteLeft",
    "flip_to_front_rounded": "clone",
    "flip_to_back_rounded": "layerGroup",
    "fact_check_outlined": "squareCheck",
    "eco_rounded": "leaf",
    "edit_rounded": "pen",
    "dynamic_feed_rounded": "barsStaggered",
    "devices_other_rounded": "mobileScreen",
    "devices_other_outlined": "mobileScreen",
    "delete_forever_outlined": "trashCan",
    "copy_all_rounded": "copy",
    "cloud_rounded": "cloud",
    "circle_outlined": "circle",
    "checkroom_rounded": "shirt",
    "checklist_rounded": "squareCheck",
    "checklist_outlined": "squareCheck",
    "balance_outlined": "scaleBalanced",
    "assignment_turned_in_outlined": "squareCheck",
    "account_balance_wallet_outlined": "wallet",
    "account_balance_rounded": "buildingColumns",
    "account_balance_outlined": "buildingColumns",
    "accessibility_rounded": "personCircleCheck",
    "smart_toy_outlined": "robot",
    "draw_outlined": "pen",
    "animation_outlined": "clapperboard",
}

STYLE_PREFIX = "AppIcons"


def main():
    duotone_names_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if duotone_names_path and duotone_names_path.exists():
        valid = set(duotone_names_path.read_text().split())
        missing = [(m, f) for m, f in MAPPING.items() if f not in valid]
        if missing:
            print("HATA: FontAwesomeIcons'ta olmayan hedef isimler:")
            for m, f in missing:
                print(f"  {m} -> {f}")
            sys.exit(1)

    changed_files = []
    total_subs = 0
    for path in ROOT.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        original = text

        def repl(match):
            nonlocal total_subs
            name = match.group(1)
            if name not in MAPPING:
                return match.group(0)
            total_subs += 1
            return f"{STYLE_PREFIX}.{MAPPING[name]}"

        text = re.sub(r"(?<![A-Za-z0-9_])Icons\.([a-zA-Z_0-9]+)", repl, text)

        if text != original:
            needs_import = f"{STYLE_PREFIX}." in text and (
                "package:zankurd_mobile/src/theme/app_icons.dart" not in text
            )
            if needs_import:
                lines = text.split("\n")
                insert_at = 0
                for i, line in enumerate(lines):
                    if line.startswith("import "):
                        insert_at = i + 1
                lines.insert(
                    insert_at,
                    "import 'package:zankurd_mobile/src/theme/app_icons.dart';",
                )
                text = "\n".join(lines)
            path.write_text(text, encoding="utf-8")
            changed_files.append(str(path))

    print(f"Değiştirilen dosya sayısı: {len(changed_files)}")
    print(f"Toplam ikon değişimi: {total_subs}")


if __name__ == "__main__":
    main()
