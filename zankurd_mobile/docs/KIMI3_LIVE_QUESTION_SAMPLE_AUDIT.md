# KIMI3 — Canlı Soru Örneklem Denetimi (50 soru)

Tarih: 2026-07-19 · Hedef: https://zankurd.com/ · Yöntem: misafir "Denetmen" oturumu, her soru kategori quizinin 1. sorusu olarak canlıda açıldı ve görsel incelendi. Kanıtlar: `output/kimi3_live_visual_audit/2026-07-19/q01…q50-*.png` (+ önceki quiz koşularından 38, 56, 85, 113, 139, 146, 152).

## Kapsam
| Kategori | Alt kategoriler | Soru sayısı |
|---|---|---|
| Ziman | Rêziman, Peyvnasî, Rastnivîsîn | 10 (+ günlük quiz tekrarları) |
| Muzîk | Dengbêjî, Muzîka Nûjen, Amûrên Muzîkê | 5 |
| Siyaset | Dîroka Siyasî, Siyaseta Nûjen, Tevgerên Civakî | 5 (q16–q20) |
| Teknolojî | 2 alt kategori | 5 |
| Paradîgma | 3 alt kategori | 5 |
| Wêje | 3 alt kategori | 5 |
| Dîrok | 3 alt kategori | 5 |
| Erdnîgarî | 3 alt kategori | 5 |
| Çand | 3 alt kategori | 5 |

Toplam: 50 canlı soru. Tür dağılımı: ~34 Hilbijartin (4 şık), ~14 Rast/Xelet, 3 görselli (Entik etiketli: q34, q36, q47).

## Özet istatistik
| Bulgu | Sayı | Oran |
|---|---|---|
| Dil karışımı (Kurmancî soru + Türkçe şık veya tam tersi) | ~20/50 | %40 |
| Tamamen Türkçe soru + şık (meta/test içeriği dahil) | ~7/50 | %14 |
| Şablon soru kökü ("Di asta X de, ji bo dersa Y kîjan vebijark…") | 8/50 | %16 |
| Şablon T/F kalıbı ("…were nirxandin" → Rast / "…dûr e" → Şaş) | 12/50 | %24 |
| Doğru cevap bariz biçimde en uzun şık | ~10 uzun-şıklı sorunun ~9'u | belirgin |
| Kategori/alt kategori ↔ içerik uyumsuzluğu | ~12/50 | %24 |
| Tekrarlanan aynı çeldirici metni (farklı sorularda) | 3 grup | — |
| Şüpheli/çift-doğru veya anlamsız | 3 | — |
| ç/ê/î/ş/û karakter bozulması | 0 büyük hata; 3 yazım şüphesi | düşük |

## Sorun türleri ve kanıtlar

### 1. Meta/test içeriği canlıda (P1)
Teknolojî kategorisi (23 pirs) soruları uygulamanın kendi veri şeması hakkında ve tamamen Türkçe:
- q21 "Kaynak sütunu CSV'de ne işe yarar?" → D
- q22 "ZanKurd'da soruların altındaki açıklama (şîrove) ne işe yarar?" → D
- q24 "Bir soruda açıklama alanı neden önemlidir?" → C (en uzun şık, açık ara)
Öneri: bu kategori yayına hazır içerikle doldurulana dek gizlenmeli.

### 2. Tahmin edilebilir T/F şablonları (P2)
- "...dikare were nirxandin." kalıbı → her zaman Rast (q32 Melayê Bateyî, q37 Mîrgeha Erdelanê)
- "...bi tevahî ji qada X dûr e." kalıbı → her zaman Şaş (q26, q38, q41, q42)
Öğrenci içeriği bilmeden kalıptan cevaplayabilir. Öneri: Rast ve Şaş için aynı kalıbın iki yönlü varyantları üretilsin.

### 3. Doğru cevap en uzun şık (P2)
q09 (D), q13 (D), q27 (D), q30 (D), q35 (D), q40 (B), q46 (D), q48 (D), q50 (D): açıklamalı/uzun şıklı sorularda doğru cevap neredeyse sistematik olarak en uzun ve en "resmi" ifade. Öneri: çeldiriciler de benzer uzunluk ve üsluba getirilsin.

### 4. Şablon soru kökü (P2)
"Di asta {destpêk/navîn/pêşketî} de, ji bo dersa {X} kîjan vebijark ravekirina têgeha '{Y}' bi awayekî rast temam dike?" — q13, q15, q27, q35, q43, q46, q48, q50. Yapay/şablon hissi güçlü; doğal Kurmancî soru üslubu değil.

### 5. Çeldirici havuzu tekrarı (P2)
- "destana neteweyî ya kurdî ya ku hîmê Mem û Zîna Xanî pêk tîne" → q35-A, q48-A, q50-A (3 kez)
- "amûra bayê ya çobanan ku bi dengê xwe yê xemgîn û lîrik tê naskirin" → q13-C, q15-A
- "amûra lêdanê ya zildar ku di muzîka kurdî…" → q13-D, q15-C

### 6. Kategori ↔ içerik uyumsuzluğu (P2)
- Ziman·Rêziman (gramer) → kelime çeviri soruları (q01, q02, q10; FAZ1'deki "pîr"/"kedi" de öyle)
- Ziman·Rastnivîsîn (yazım) → anlam T/F (q05 "nan=ekmek", q06 "nivîsandin=yazmak")
- Paradîgma → kimya (q29 xenon atom numarası), aşı/WHO (q30)
- Çand → müzik aleti sorusu (q49 def), Muzîk kategorisi varken
- Muzîk·Dengbêjî → tembur tanımı (q11)
- Günlük quiz (Dersê rojane) Q1 iki ayrı koşuda da aynı soru: "pîr" (P1 — tekrar/deterministik sıra; kanıt 146, 173)

### 7. Dil karışımı (P2)
Kurmancî soru kökü + Türkçe şıklar yaygın (Ziman vocab serisi tasarım gereği olabilir ama tutarsız): q11, q28, q34, q36, q44, q47, q49. Tamamen Türkçe sorular: q21, q22, q24, q33 ("Şerefname adlı eserin yazarı kimdir?"), q49 ("Kürt müziğinin en eski çalgılarından def…"). q28 hem kökte hem şıklarda karışık: "'kadın akademileri' çawa tê pênasekirin?" + Türkçe şıklar.

### 8. Şüpheli / hatalı sorular (tek tek)
| # | Soru | Sorun | Öneri |
|---|---|---|---|
| q10 | "Dijwateya 'germ' çi ye?" A Hênik / B Şil / C Zuwa / D Sar | Çift doğru riski: "sar" ve "hênik" ikisi de germ'in karşıtı sayılabilir | Hênik'i başka çeldiriciyle değiştir |
| q39 | "'Lozan Antlaşması' sernavek rast e ku beşek ji zanîna dîrokê ye." | Anlamsız/bozuk önerme; T/F kalıbına zorlanmış | Yeniden yaz veya sil |
| q37 | "Mîrgeha Erdelanê" | "mîrgeh" şüpheli biçim (mîrnişîn/mîrîtî beklenir) | Yazım gözden geçir |
| q34 | "kîjan cureyê vegottinê nîşan dide?" | "vegottinê" yazımı şüpheli (vegotinê?) | Yazım gözden geçir |
| q27 | "…çêtir tê fêmkirin?" | "çêtir" doğal değil ("baştir"/"çawa") | Yeniden ifade et |
| q36 | "Wêneya 'birincil kaynak' kîjan kategoriyê nîşan dide?" | Türkçe terim gömülü + meta-kategori sorusu + anlamsız çeldiriciler (Spor) | Soru tasarımını değiştir |
| q47 | "'yerel kıyafetler' heye — kategoriya rast kîjan e?" | Türkçe gömülü + kategori-tahmin sorusu (içerik değil) | Kültür içeriği sorulsun |
| q12 | uzun Botan/lawik sorusu | Şık türleri heterojen (kişi/grup/kavram) + 5 satır kök | Kök kısaltılsın, şık türü birleşsin |

### 9. Görselli sorular (olumlu + not)
q34, q36, q47 görselleri düzgün render oluyor, layout bozulmuyor. Ancak üçü de "görsel hangi kategoriye ait" tarzı yüzeysel sorular.

### 10. Açıklama (şîrove)
50 soruluk gözlem + tüm quiz koşularında reveal sonrası açıklama UI'ı hiç görünmedi (P0 Piştre hatası nedeniyle ileri akış doğrulanamadı). "bilgi edindirme amaçlanmıştır" kalıbı canlı gözlemde görülmedi — doğrulanamadı. Sağ üstteki "!" ikonu açıklama değil "Pirsê ragihîne" (soru bildir) diyalogu açıyor (kanıt 121).

### Olumlu notlar
- ç/ê/î/ş/û karakter bütünlüğü genel olarak sağlam (piçûk, nivîsandin, çîrok, Şaş tutarlı).
- Kelime çeviri sorularının çekirdek havuzu (pisîk, kanî, wêne, spas, nan, berf, mîsk) doğru ve öğretici.
- Yinelenen şık aynı soru içinde görülmedi.
