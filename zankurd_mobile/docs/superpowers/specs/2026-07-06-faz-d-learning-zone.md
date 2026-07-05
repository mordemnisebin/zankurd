# Faz D: Learning Zone — Kurmancî Ders Sistemi
**Tarih:** 2026-07-06 | **Versiyon:** 1.0 | **Durum:** Spec

---

## Vizyonu

ZanKurd'da **öğrenme kolu**: 15-20 **temalı, çift dilli (Kurmancî-Türkçe) mini-ders** sunulacak.
- Alfabe, Sayılar, Renkler, Aile, Coğrafya, Dilbilgisi, Newroz, vb.
- Her ders: **3-5 slayt** + **sesli telaffuz** (TTS)
- **Hazırlık aşaması** (Faz D): Schema + Repository API
- **UI aşaması** (Faz E): LearningScreen + lesson modal

---

## 1. Database Schema

### `lessons` Tablosu
```sql
CREATE TABLE IF NOT EXISTS lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL, -- "alphabet", "numbers", "colors", ...
  title_ku TEXT NOT NULL,
  title_tr TEXT,
  description_ku TEXT,
  category TEXT NOT NULL, -- "alphabet", "numbers", "everyday", "grammar", etc.
  icon_name TEXT, -- Material icon
  order_in_category INT DEFAULT 0,
  language TEXT DEFAULT 'ku', -- Content language (always Kurmancî)
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ
);
```

### `lesson_slides` Tablosu
```sql
CREATE TABLE IF NOT EXISTS lesson_slides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  order_in_lesson INT NOT NULL,
  content_ku TEXT NOT NULL, -- Kurmancî text
  content_tr TEXT, -- Turkish translation (optional)
  example_ku TEXT, -- Example or context
  image_url TEXT, -- Illustrative image (webp)
  audio_url TEXT, -- TTS-generated audio URL
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(lesson_id, order_in_lesson)
);
```

### `user_lesson_progress` Tablosu
```sql
CREATE TABLE IF NOT EXISTS user_lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  completed BOOLEAN DEFAULT FALSE,
  last_viewed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, lesson_id)
);
```

---

## 2. Lesson Content (Seed Data)

### Lesson Slugs (15-20 toplam)
1. **alphabet** — Alfabê Kurmancî (26 harf + diyakritikleri)
2. **numbers** — Hûwander (0-20, rast sayılar, ordinal)
3. **colors** — Reng (8 ana renk)
4. **family** — Malbat (ana, bav, kur, xwişk, mam, dayik...)
5. **greetings** — Silavî (Silav, Çawa ye?, Baş xweş, Şevan...)
6. **food** — Xwarinî (çiya, pê, ava, nan, çîni, goştî...)
7. **animals** — Haywan (çi, biz, reş, filas, heyrî, mêş...)
8. **geography** — Coğrafya (derebarê Kurdistanê)
9. **grammar_noun** — Navdêr (isim — singular, plural, case)
10. **grammar_verb** — Lêker (fiil — temel zaman)
11. **newroz** — Newrozê (Newroz merasimleri, tarih, anlamı)
12. **body** — Laş (kî, çaw, guh, dev, dest, pê...)
13. **clothing** — Jorin (bûrx, şort, kiras, çizme...)
14. **weather** — Hewa (baran, xor, ba, ber...)
15. **time** — Dem (ro, şev, hefte, meh, sal, saet...)
16. **prepositions** — Pêşbagî (li, ber, derdora, çiya, bin...)
17. **emotions** — Bi'ane (şad, bes, ters, tirs, hez...)
18. **house** — Mali (dera, kevon, diqur, sivik...)
19. **profession** — Kesa (misinêr, berja, xanendê, polix...)
20. **daily_phrases** — Gotinên Roj (günlük ifadeler)

---

## 3. Models & Repository API

### Dart Models
```dart
@immutable
class Lesson {
  final String id;
  final String slug;
  final String titleKu;
  final String? titleTr;
  final String category;
  final String? iconName;
  final int order;
  // ...
}

@immutable
class LessonSlide {
  final String id;
  final String lessonId;
  final int order;
  final String contentKu;
  final String? contentTr;
  final String? exampleKu;
  final String? imageUrl;
  final String? audioUrl;
  // ...
}

@immutable
class UserLessonProgress {
  final String userId;
  final String lessonId;
  final bool completed;
  final DateTime? completedAt;
  // ...
}
```

### Repository Interface
```dart
// In ZanKurdRepository
Future<List<Lesson>> loadLessonsByCategory(String category);
Future<Lesson?> loadLesson(String lessonId);
Future<List<LessonSlide>> loadLessonSlides(String lessonId);
Future<void> markLessonCompleted(String lessonId);
Future<UserLessonProgress?> getLessonProgress(String lessonId);
```

---

## 4. Implementation Roadmap

### Faz D (Şu): Backend
- ✅ DB Schema migration
- ✅ Seed 15-20 lesson + slide data
- ✅ Models + Repository API
- ✅ Mock implementation

### Faz E (Sonra): UI
- LearningScreen: lesson grid by category
- LessonDetailScreen: slide carousel + TTS playback
- Progress tracking (checkmarks)
- Completion badge/reward

---

## 5. Seed Data Format

Each lesson = 3-5 slides. Example:

```json
{
  "slug": "numbers",
  "titleKu": "Hûwander",
  "titleTr": "Sayılar",
  "category": "everyday",
  "slides": [
    {
      "order": 1,
      "contentKu": "Sifir (0), Yek (1), Du (2), Sê (3), Çar (4), Pênc (5)",
      "contentTr": "Sıfır, Bir, İki, Üç, Dört, Beş",
      "exampleKu": "Yek + Du = Sê"
    },
    {
      "order": 2,
      "contentKu": "Şeş (6), Heft (7), Heşt (8), Neh (9), Deh (10)",
      "contentTr": "Altı, Yedi, Sekiz, Dokuz, On"
    }
    // ... 3-5 total
  ]
}
```

---

## 6. Notes

- **TTS Audio:** Generate via Supabase Edge Function (Google TTS or Eleven Labs)
- **Images:** Curated illustrations (educational, colorful)
- **Completion reward:** 10 XP per lesson (later: Faz F)
- **Analytics:** Track lesson view/completion for insights
- **Scope:** Faz D = backend only; UI follows after Quest/Contest stabilization

---

**Next step:** Spec review & approval → Faz D implementation plan
