# Kategori Ustalık Unvanları — Tasarım Dokümanı

**Tarih:** 2026-06-16  
**Durum:** Onaylandı

## Amaç

Her kategori için doğru cevap sayısına dayalı 3 aşamalı ustalık sistemi ekle. Oyuncular ilerlediğinde görsel unvan rozetleri kazanır; bu motivasyonu artırır ve uzun vadeli yeniden oynama değeri yaratır.

---

## Seviyeler

| Seviye | Eşik (kategori başına doğru) | Kurmancî | Türkçe | Renk |
|--------|------------------------------|----------|--------|------|
| — | 0 | — (unvansız) | — | — |
| 1 | 20 | Xwendekar | Öğrenci | Mavi (`Colors.blue`) |
| 2 | 100 | Pispor | Uzman | Mor (`Colors.purple`) |
| 3 | 400 | Mamoste | Usta | Altın (`AppTheme.gold`) |

Doğrular **her sorunun kendi kategorisine** göre sayılır (quiz odasının kategorisi değil). Böylece karma quiz veya günlük quiz senaryolarında da doğru izleme yapılır.

---

## Mimari

### 1. `MasteryLevel` enum — `lib/src/models/mastery_level.dart`

```dart
enum MasteryLevel { none, xwendekar, pispor, mamoste }
```

Extension'lar: `threshold` (int), `titleKu` (String), `titleTr` (String), `badgeColor` (Color), `icon` (IconData).

`MasteryLevel.fromCorrectCount(int count)` factory: count < 20 → none, < 100 → xwendekar, < 400 → pispor, ≥ 400 → mamoste.

### 2. `MasteryStore` — `lib/src/data/mastery_store.dart`

`SharedPreferences` tabanlı. Her kategori için `zankurd.mastery.<kategori>` key'inde int saklar.

```dart
static Future<MasteryStore> load()
Future<MasteryLevel?> addCorrect(String category, int count)
// Mevcut seviyeyi kontrol eder, count ekler, yeni seviyeyi kontrol eder.
// Seviye atladıysa yeni MasteryLevel döner; atlamadıysa null döner.
int correctCount(String category)
MasteryLevel levelFor(String category)
int nextThreshold(String category) // bir sonraki eşik (400 üstü de 400 döner)
```

Singleton pattern (AchievementStore ile aynı): `_instance` cache + `resetInstance()` (testler için).

### 3. Quiz Sonuç Entegrasyonu — `quiz_result_screen.dart`

`_QuizResultScreenState.initState()` içinde mevcut `AchievementStore` yüklemesinin yanına:

```dart
final store = await MasteryStore.load();
// answerRecords üzerinden kategori bazında doğru say
final correctByCategory = <String, int>{};
for (final record in widget.answerRecords) {
  if (record.isCorrect) {
    correctByCategory[record.category] =
        (correctByCategory[record.category] ?? 0) + 1;
  }
}
// Seviye atlamalarını topla
final promotions = <String, MasteryLevel>{};
for (final entry in correctByCategory.entries) {
  final newLevel = await store.addCorrect(entry.key, entry.value);
  if (newLevel != null) promotions[entry.key] = newLevel;
}
```

Seviye atlaması varsa sonuç ekranının üstüne altın rengi kutlama banner'ı:

```
🎓  Ziman kategorisinde Pispor oldun!
```

Birden fazla atlama varsa birden fazla banner (yığılmış).

### 4. Kategori Gridi — `category_grid.dart`

`_CategoryGridState` → `initState`'te `MasteryStore.load()`, ardından her kategori için `levelFor(category)`.

Mevcut `GridView` kartının altına küçük rozet satırı:
- Unvan yoksa: boş (`SizedBox.shrink()`)
- Unvan varsa: `★ Xwendekar` (mavi metin, 10px)

### 5. Profil Ekranı — `profile_screen.dart`

Mevcut `_achievements` bölümünden sonra yeni "Kategorî Ustalığı / Kategori Ustalığı" bölümü.

Her kategori için satır:
- Soldaki: kategori adı (Kurmancî)
- Ortada: renkli `Chip` → `★ Xwendekar` (seviye yoksa gri `Başlangıç`)
- Sağda: `LinearProgressIndicator` + `(45/100)` etiketi
  - İlerleme: `correctCount / nextThreshold` (0.0–1.0)
  - Mamoste olanlar için tam dolu bar + `✓`

### 6. Testler — `test/mastery_store_test.dart`

- `addCorrect` kümülatif sayım doğruluğu
- `levelFor` → 4 boundary değeri (0, 19, 20, 99, 100, 399, 400)
- `addCorrect` → seviye atlama tespiti (null vs MasteryLevel döner)
- `addCorrect` aynı kategoriyi birden fazla çağırma
- `resetInstance` testler arası izolasyon

---

## Veri Akışı

```
QuizScreen (sorular cevaplandı)
  → QuizResultScreen (answerRecords ile)
    → MasteryStore.addCorrect(category, correctCount) per category
      → SharedPreferences güncelleme
      → seviye atlama → kutlama banner

CategoryGrid / ProfileScreen
  → MasteryStore.load() → levelFor / correctCount
    → rozet / ilerleme çubuğu render
```

---

## Kısıtlamalar

- **Yalnızca yerel:** Supabase senkronizasyonu yok. Cihaz değiştirilirse sıfırlanır (AchievementStore ile aynı karar).
- **Siyaset/Paradigma kategorileri dahil:** Tüm 8 kategori izlenir.
- **Geri sayım yok:** Yanlış cevap sayımı azaltmaz; sadece doğrular eklenir.
