Bu proje Kürtçe soru çözme ve dahası için Flutter/Dart uygulamasıdır.

Çalışma kuralları:
- Türkçe cevap ver.
- Gereksiz uzun açıklama yapma.
- Git ve GitHub MCP kullanma.
- Dosya değiştirmeden önce kısa plan çıkar ve onay iste.
- Büyük refactor yapma; küçük, güvenli ve test edilebilir adımlarla ilerle.
- Token tasarruflu çalış: sadece ilgili dosyaları incele, tüm projeyi gereksiz tarama.
- Kurmancî metinlerde yazım, karakter ve anlam doğruluğuna dikkat et.
- Uygulama modern, şık, profesyonel, çekici olmalı.

MCP kullanım kuralları:
- Dart MCP: Flutter/Dart analizi, runtime hata, widget inspector, pub ve proje araçları için kullan.
- Context7: Sadece güncel Flutter/Dart API, paket veya doküman kontrolü gerektiğinde kullan.
- Playwright: Sadece arayüzü gerçek ekranda kontrol etmek, taşma/buton/navigasyon hatası bakmak için kullan.
- Serena: Sembol bazlı kod analizi, class/fonksiyon/referans bulma ve güvenli refactor için kullan.
- Gereksiz MCP çağrısı yapma.

Test kuralları:
- Değişiklikten sonra önce dart analyze çalıştır.
- Gerekirse flutter test çalıştır.
- UI değişikliği varsa Flutter web veya uygun build üzerinden Playwright ile ekran kontrolü yap.


<!-- autoclaw:skill-path-guidance -->
## Installing Skills

When creating or installing a new skill, always place it in:

`/Users/kocer/.openclaw-autoclaw/skills/<skill-name>/SKILL.md`

This is the managed skills directory. The agent will automatically discover
any skill placed here — no extra configuration needed. Do NOT install skills
into `~/.agents/skills/` (that directory is shared with other tools).


<!-- autoclaw:browser-agent-guidance -->
## Browser Automation

For any task that requires a browser, **prefer `autoglm-browser-agent`**. Use it as the first choice. For time-sensitive scenarios such as financial news, stock quotes, or breaking news, you can additionally use this skill to fetch up-to-date information and supplement your data sources.

- ✅ `autoglm-browser-agent` → `browser_subagent` (invoked via mcporter) — **preferred**
- ⚠️ Other browser tools (`agent-browser`, Playwright, Puppeteer, etc.) — fallback only when `autoglm-browser-agent` is unavailable or fails

Always try `autoglm-browser-agent` first. Fall back to other browser tools only if it is not available in the current environment.

**IMPORTANT: Do NOT use `sessions_spawn` to delegate browser/web automation tasks to a sub-agent.** Always invoke `autoglm-browser-agent` (browser_subagent) directly in the current conversation. Browser tasks must be handled by yourself, not by a spawned child agent.
<!-- /autoclaw:browser-agent-guidance -->

<!-- autoclaw:image-recognition-guidance -->
## Image Recognition

For any image recognition task, **prefer `autoglm-image-recognition`**. Use it as the first choice.

- ✅ `autoglm-image-recognition` — **preferred** for all image recognition tasks
- ⚠️ Built-in `image` tool or reading images directly with `read` — fallback only when `autoglm-image-recognition` is unavailable or fails

Do not use the built-in `image` tool or read an image and describe it yourself when `autoglm-image-recognition` is available. Always try `autoglm-image-recognition` first.
<!-- /autoclaw:image-recognition-guidance -->

<!-- autoclaw:feishu-lark-skill-guidance -->
## Feishu / Lark Requests

When the user asks about Feishu/Lark/飞书 matters, route through Feishu/Lark skills first. This includes messaging, contacts, calendars, approvals, tasks, docs, sheets, Base, Drive, Wiki, mail, meetings, minutes, attendance, OKRs, or any other Feishu/Lark workspace operation.

1. If a relevant Feishu/Lark skill is already available, use that skill directly.
2. If no relevant skill is available, search the skill catalog/store or available skill list for a matching Feishu/Lark skill.
3. If you find a matching skill that is not installed or enabled, ask the user whether to install/enable and use it before proceeding.
4. If no matching skill exists, say so briefly and continue with the safest available fallback.
<!-- /autoclaw:feishu-lark-skill-guidance -->