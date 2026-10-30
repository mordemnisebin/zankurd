# T8 — TR / KU metin tablosu

Yeni/değişen arayüz metinleri. Soru bankası içeriği değişmedi.

Gemini 3.8 Flash ve Gemini 4 Argon son metinleri onayladı. Grok 4.7
`ActionRequiredError: usage limit` verdi; AGENTS.md’deki tercih edilen
Gemini + Grok çifti sağlanamadı. Bu nedenle KU metinleri iki model tarafından
incelenmiş taslak olarak kayıtlıdır; Grok onayı varmış gibi sunulmaz.
“Kûpa” mevcut ürün terimi korundu. Timer izafeti Flash önerisiyle “hevrikî”;
Argon son turda bunu da onayladı. Anlam/bilgi değiştiren öneri uygulanmadı.

| Anahtar | TR | KU taslak |
|---|---|---|
| `saveAccountBody` | Hesabını kalıcı yap: Apple, Google ya da e-posta ile. | Hesabê xwe mayînde bike: bi Apple, Google an e-nameyê. |
| `saveAccountSub` | Hesabını kalıcı yap: Apple, Google ya da e-posta ile. | Hesabê xwe mayînde bike: bi Apple, Google an e-nameyê. |
| `presenceVisibilitySub` | Açıkken arkadaşların çevrimiçi olduğunu ve son görülme zamanını görür. Varsayılan kapalı. | Dema vekirî be, hevalên te dibînin ku tu serhêl î û kengî cara dawî hatiyî dîtin. Bi standardî girtî ye. |
| `cupSubmissionForfeitNotPlayed` | Oynamadı · hükmen | Nelîst · têkçûna bi biryarê |
| `joinNewTournament` | Yeni turnuvaya katıl | Tevlî kûpayeke nû bibe |
| `tournamentRunnerUp` | İkinci oldun | Tu bûyî duyemîn |
| `cupOwnedMatchVs` | Sen {my} – {their} {opponent} | Tu {my} – {their} {opponent} |
| `asyncDuelOpenInvite` | Açık davet | Vexwendina vekirî |
| `asyncDuelOpenInviteClosesHours` | {n} sa içinde katılan olmazsa kapanır | Heke di {n} saet de kes tevlî nebe tê girtin |
| `asyncDuelOpenInviteClosesMinutes` | {n} dk içinde katılan olmazsa kapanır | Heke di {n} deqe de kes tevlî nebe tê girtin |
| `timerOpponentSecondsLeft` | Rakibin süresi: {n} saniye kaldı | Dema hevrikî: {n} çirke ma |
| `timerPaused` | Süre durdu | Dem rawestiya |

E5 doğru sayısı mevcut `asyncDuelCorrectCaption` anahtarını kullanır:
`{total} soruda {correct} doğru` / `Ji {total} pirsan {correct} rast`.
E14 mevcut `you` anahtarını kullanır: `Sen` / `Tu`.

Denetim çıktıları: `/Users/kocer/Projects/zankurd_kapisma/t8/2026-10-30/reviews/`.
`gemini_ku_retry.txt`, `argon_final_ku.txt`, `grok_ku.txt`.
