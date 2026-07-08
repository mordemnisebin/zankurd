# ZanKurd Visual Identity Proposal

Durum: Kod degisikligi yok. Bu belge yalnizca tasarim yonu ve onay icindir.

## Ana Kimlik

ZanKurd icin ana karakter premium dark theme olmali: mat antrasit yuzeyler, net tipografi, kontrollu canli aksanlar ve akademik ama sikici olmayan bir egitim hissi. Mevcut uygulamada `AppTheme.backgroundGradient`, `AppPanel`, kategori gorselleri, `PlayerAvatar`, rozetler, coin/XP ve progress yapilari zaten var. Modernlestirme bu mevcut temeli bozmak yerine daha tutarli, daha ferah ve daha hiyerarsik hale getirmeli.

## Renk Sistemi

| Alan | Onerilen aksan | Kullanim |
|---|---|---|
| Ana ogrenme / quiz | Yesil-turkuaz | Quiz CTA, progress, dogru cevap, ogrenme akisi |
| 1vs1 | Sicak rekabet kirmizi-turuncu | VS rozeti, radar, eslesme CTA |
| Takim / oda | Mavi-mor | Oda hero, oyuncu listesi, takim status kartlari |
| Liderlik | Altin/amber | Podium, madalya, skor vurgusu |
| Pesbaz / contest | Canli gorev aksani | Etkinlik temasi, badge, sure/progress |
| Cark / gunluk odul | Kontrollu altin + mor | Cark merkezi, odul karti, cooldown chip |
| Profil | Guvenilir yesil + altin | Avatar, seviye, XP, basari rozetleri |
| Shop | Premium altin | Coin bakiyesi, satin alma CTA, sahip olunan durum |

## Yuzeyler

- Ana arka plan: koyu, dusuk kontrastli gradient; gorsel yorgunluk yaratmayan mat ton.
- Kartlar: `AppPanel` karakterini koruyan 16-20px radius, ince border, hafif shadow.
- Hero kartlar: sadece kritik ekran ustlerinde daha zengin gradient; her kartta gradient kullanilmamali.
- Dialog/bottom sheet: koyu yuzey, net baslik, tek ana CTA, ikincil eylem ghost/outlined.

## Tipografi

- Basliklar kisa ve guclu olmali: ekran ismi veya mod amaci.
- Uzun aciklamalar 1-2 satirla sinirlanmali; detaylar chip, rozet ve progress ile anlatilmali.
- Kurmanci metinlerde kesilme riskine karsi `maxLines`, `overflow` ve genislik paylasimi oncelikli olmali.

## Ikon ve Gorsellik

- Mevcut Material icon kullanimi korunabilir; ikonlar mod kimligiyle eslesmeli.
- Kategori kartlarinda `CategoryVisuals` gorselleri ana guc olarak kalmali.
- Quiz ve sonuc ekraninda ikonlar metin yogunlugunu azaltmak icin metric tile, chip ve state badge olarak kullanilmali.
- Ucuz gradient, asiri parlak neon, karmasik susleme ve amator ikonlardan kacinilmali.

## Light/Dark Uyumu

Ana karakter dark olsa da light mod bozulmamali. Onay sonrasi uygulama asamasinda sabit beyaz/siyah metinler yalniz gercek koyu gradient ustunde kullanilmali; diger alanlarda context-aware tema renkleri tercih edilmeli. Bu belge kod degistirmez, sadece sonraki uygulama riskini isaretler.

## Uygulama Prensibi

Ilk uygulama paketi kucuk olmali: ana sayfa, kategori ve quiz gibi yuksek etkili ama kontrollu ekranlar. Supabase, auth, route, quiz logic, oda logic, 1vs1/team state ve database dosyalarina dokunulmamali.
