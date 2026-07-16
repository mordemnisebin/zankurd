#!/usr/bin/env python3
"""
Fix Turkish-mixed prompts in offline_question_bank.dart
Converts Turkish prompts to Kurmanci while preserving all other fields.
"""

import re
import sys

FILE_PATH = r"C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\lib\src\data\offline_question_bank.dart"

def unescape_dart_string(s):
    """Unescape a Dart single-quoted string content."""
    # Handle \' -> ' and \\ -> \
    result = []
    i = 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            if s[i+1] == "'":
                result.append("'")
                i += 2
                continue
            elif s[i+1] == '\\':
                result.append("\\")
                i += 2
                continue
        result.append(s[i])
        i += 1
    return ''.join(result)

def escape_dart_string(s):
    """Escape a string for Dart single-quoted string."""
    # Escape backslashes first, then single quotes
    s = s.replace('\\', '\\\\')
    s = s.replace("'", "\\'")
    return s

def fix_prompt(prompt):
    """Convert Turkish prompt patterns to Kurmanci. Returns (new_prompt, was_changed)."""
    original = prompt
    
    # TYPE D: Already Kurmanci - keep as is
    # Patterns like: "Wateya Tirkî ya peyva ...", "Peyva Kurmancî ... bi Tirkî çi tê gotin?"
    already_kurmanci_patterns = [
        r"Wateya Tirk[îi] ya peyva",
        r"Peyva Kurmanc[îi].*bi Tirk[îi].*t[êe] gotin",
        r"Peyva .*bi Tirk[îi]",
        r"Hejmara .*bi Tirk[îi]",
        r"Wateya .*k[îi]jan e",
        r"bi Tirk[îi] k[îi]jan watey[êe] digire",
        r"bi Tirk[îi] [çc]i",
        r"bi Tirk[îi] dikarin",
        r"herdu j[îi] bi Tirk[îi]",
        r"Ney[îi]niya",
        r"Fermana .*l[êe]kera",
        r"Pa[şs]gira",
        r"T[îi]p[êe]n",
    ]
    for pat in already_kurmanci_patterns:
        if re.search(pat, prompt):
            return original, False
    
    # TYPE B: Turkish-to-Kurmanci translation questions - KEEP as is
    # e.g. '"teşekkür" anlamına gelen Kurmancî kelime hangisidir?'
    # e.g. '"güzel/iyi" ifadesinin Kurmancî karşılığı nedir?'
    type_b_patterns = [
        r'anlam[ıi]na gelen Kurmanc[îi] kelime hangisidir',
        r'ifadesinin Kurmanc[îi] kar[şs][ıi]l[ıi][ğg][ıi] nedir',
        r"Kurmanc[îi] kar[şs][ıi]l[ıi][ğg][ıi] nedir",
        r"A[şs]a[ğg][ıi]dakilerden hangisi.*anlam[ıi]ndaki Kurmanc[îi] kelimedir",
    ]
    for pat in type_b_patterns:
        if re.search(pat, prompt):
            return original, False
    
    # Now handle TYPE C patterns (Turkish that needs Kurmanci translation)
    
    # Pattern 1: '"X" kavramını gösteren görselde doğru anlam hangisidir?'
    # → 'Di wêneya ku têgiha "X" nîşan dide de, wateya rast kîjan e?'
    m = re.match(r'^"([^"]+)"\s+kavram[ıi]n[ıi]\s+g[öo]steren\s+g[öo]rselde\s+do[ğg]ru\s+anlam\s+hangisidir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di wêneya ku têgiha "{word}" nîşan dide de, wateya rast kîjan e?', True
    
    # Pattern 2: 'Görsel ipucu: "X". Anlamı nedir?'
    # → 'Nîşana wêneyê: "X". Wateya wê çi ye?'
    m = re.match(r'^G[öo]rsel ipucu:\s*"([^"]+)"\.\s*Anlam[ıi]\s+nedir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Nîşana wêneyê: "{word}". Wateya wê çi ye?', True
    
    # Pattern 3: 'Görsel "X" diyor — doğru anlam hangisi?'
    # → 'Wêne "X" dibêje — wateya rast kîjan e?'
    m = re.match(r'^G[öo]rsel\s+"([^"]+)"\s+diyor\s+[—–-]\s+do[ğg]ru\s+anlam\s+hangisi\?$', prompt)
    if m:
        word = m.group(1)
        return f'Wêne "{word}" dibêje — wateya rast kîjan e?', True
    
    # Pattern 4: '"X" görseli hangi anlama gelir?'
    # → 'Wêneya "X" tê çi wateyê?'
    m = re.match(r'^"([^"]+)"\s+g[öo]rseli\s+hangi\s+anlama\s+gelir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Wêneya "{word}" tê çi wateyê?', True
    
    # Pattern 5: 'Bu görsel "X" için: doğru karşılık hangisi?'
    # → 'Ev wêne ji bo "X" e: berambera rast kîjan e?'
    m = re.match(r'^Bu\s+g[öo]rsel\s+"([^"]+)"\s+i[çc]in:\s+do[ğg]ru\s+kar[şs][ıi]l[ıi]k\s+hangisi\?$', prompt)
    if m:
        word = m.group(1)
        return f'Ev wêne ji bo "{word}" e: berambera rast kîjan e?', True
    
    # Pattern 6: 'Resimdeki "X" ne demektir?'
    # → 'Di wêneyê de "X" tê çi wateyê?'
    m = re.match(r'^Resimdeki\s+"([^"]+)"\s+ne\s+demektir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di wêneyê de "{word}" tê çi wateyê?', True
    
    # Pattern 7: '"X" görselinin doğru Türkçe karşılığı hangisidir?'
    # → 'Wêneya "X": berambera Tirkî ya rast kîjan e?'
    m = re.match(r'^"([^"]+)"\s+g[öo]rselinin\s+do[ğg]ru\s+T[üu]rk[çc]e\s+kar[şs][ıi]l[ıi][ğg][ıi]\s+hangisidir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Wêneya "{word}": berambera Tirkî ya rast kîjan e?', True
    
    # Pattern 8: 'Bu görsel hangi kavramı hatırlatır: "X" — doğru anlamı seçin.'
    # → 'Ev wêne kîjan têgihê tîne bîra we: "X" — wateya rast hilbijêrin.'
    m = re.match(r'^Bu\s+g[öo]rsel\s+hangi\s+kavram[ıi]\s+hat[ıi]rlat[ıi]r:\s*"([^"]+)"\s+[—–-]\s+do[ğg]ru\s+anlam[ıi]\s+se[çc]in\.?$', prompt)
    if m:
        word = m.group(1)
        return f'Ev wêne kîjan têgihê tîne bîra we: "{word}" — wateya rast hilbijêrin.', True
    
    # Pattern 9: '"X" kelimesinin Türkçe karşılığı "Y" midir?'
    # → 'Wateya Tirkî ya "X" "Y" e?'
    m = re.match(r'^"([^"]+)"\s+kelimesinin\s+T[üu]rk[çc]e\s+kar[şs][ıi]l[ıi][ğg][ıi]\s+"([^"]+)"\s+midir\?$', prompt)
    if m:
        word_x = m.group(1)
        word_y = m.group(2)
        return f'Wateya Tirkî ya "{word_x}" "{word_y}" e?', True
    
    # Pattern 10: 'Doğru mu, yanlış mı: Kurmancî "X" = "Y".'
    # → 'Rast e an şaş e: Kurmancî "X" = "Y".'
    m = re.match(r'^Do[ğg]ru\s+mu,\s*yanl[ıi][şs]\s+m[ıi]:\s*Kurmanc[îi]\s+"([^"]+)"\s*=\s*"([^"]+)"\.?$', prompt)
    if m:
        word_x = m.group(1)
        word_y = m.group(2)
        return f'Rast e an şaş e: Kurmancî "{word_x}" = "{word_y}".', True
    
    # Pattern 11: 'Kürt kültüründe X en çok hangi alanla ilişkilidir?'
    # → 'Di çanda Kurdî de X herî zêde bi kîjan qadê re têkildar e?'
    m = re.match(r'^K[üu]rt\s+k[üu]lt[üu]r[üu]nde\s+(.+?)\s+en\s+[çc]ok\s+hangi\s+alanla\s+ili[şs]kilidir\?$', prompt)
    if m:
        rest = m.group(1)
        return f'Di çanda Kurdî de {rest} herî zêde bi kîjan qadê re têkildar e?', True
    
    # Pattern 12: 'Kürt kültüründe X hakkında hangisi daha doğrudur?'
    # → 'Di çanda Kurdî de derbarê X de kîjan rasttir e?'
    m = re.match(r"^K[üu]rt\s+k[üu]lt[üu]r[üu]nde\s+(.+?)\s+hakk[ıi]nda\s+hangisi\s+daha\s+do[ğg]rudur\?$", prompt)
    if m:
        rest = m.group(1)
        return f'Di çanda Kurdî de derbarê {rest} de kîjan rasttir e?', True
    
    # Pattern 13: Görsel ipucu 'X': doğru kategori hangisidir?
    # → Nîşana wêneyê 'X': kategoriya rast kîjan e?
    m = re.match(r"^G[öo]rsel\s+ipucu\s+'([^']+)':\s*do[ğg]ru\s+kategori\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Nîşana wêneyê '{word}': kategoriya rast kîjan e?", True
    
    # Pattern 14: Görsel 'X' diyor; hangi alanla bağdaşır?
    # → Wêne 'X' dibêje; bi kîjan qadê re li hev dike?
    m = re.match(r"^G[öo]rsel\s+'([^']+)'\s+diyor;\s*hangi\s+alanla\s+ba[ğg]da[şs][ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"Wêne '{word}' dibêje; bi kîjan qadê re li hev dike?", True
    
    # Pattern 15: Görseldeki 'X' etiketi hangi alana aittir?
    # → Etîketa 'X' ya di wêneyê de aîdî kîjan qadê ye?
    m = re.match(r"^G[öo]rseldeki\s+'([^']+)'\s+etiketi\s+hangi\s+alana\s+aittir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Etîketa '{word}' ya di wêneyê de aîdî kîjan qadê ye?", True
    
    # Pattern 16: 'X' görseli Çand içinde hangi kategoriye girer?
    # → Wêneya 'X' di Çandê de dikeve kîjan kategoriyê?
    m = re.match(r"^'([^']+)'\s+g[öo]rseli\s+(\w+)\s+i[çc]inde\s+hangi\s+kategoriye\s+girer\?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"Wêneya '{word}' di {category}ê de dikeve kîjan kategoriyê?", True
    
    # Pattern 17: 'X' etiketli görsel hangi alanla ilişkilidir?
    # → Wêneya bi etîketa 'X' bi kîjan qadê re têkildar e?
    m = re.match(r"^'([^']+)'\s+etiketli\s+g[öo]rsel\s+hangi\s+alanla\s+ili[şs]kilidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Wêneya bi etîketa '{word}' bi kîjan qadê re têkildar e?", True
    
    # Pattern 18: 'X' görseli hangi kategoriyi işaret eder?
    # → Wêneya 'X' kîjan kategoriyê nîşan dide?
    m = re.match(r"^'([^']+)'\s+g[öo]rseli\s+hangi\s+kategoriyi\s+i[şs]aret\s+eder\?$", prompt)
    if m:
        word = m.group(1)
        return f"Wêneya '{word}' kîjan kategoriyê nîşan dide?", True
    
    # Pattern 19: Görselde 'X' var — doğru kategori hangisi?
    # → Di wêneyê de 'X' heye — kategoriya rast kîjan e?
    m = re.match(r"^G[öo]rselde\s+'([^']+)'\s+var\s+[—–-]\s+do[ğg]ru\s+kategori\s+hangisi\?$", prompt)
    if m:
        word = m.group(1)
        return f"Di wêneyê de '{word}' heye — kategoriya rast kîjan e?", True
    
    # Pattern 20: Bu görseldeki 'X' Çand bağlamında nereye yakındır?
    # → 'X' a di vê wêneyê de di çarçoveya Çandê de nêzîkî kîjan e?
    m = re.match(r"^Bu\s+g[öo]rseldeki\s+'([^']+)'\s+(\w+)\s+ba[ğg]lam[ıi]nda\s+nereye\s+yak[ıi]nd[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"'{word}' a di vê wêneyê de di çarçoveya {category}ê de nêzîkî kîjan e?", True
    
    # Pattern 21: 'X' görseli hangi anlatı türünü işaret eder?
    # → Wêneya 'X' kîjan cureyê vegotinê nîşan dide?
    m = re.match(r"^'([^']+)'\s+g[öo]rseli\s+hangi\s+anlat[ıi]\s+t[üu]r[üu]n[üu]\s+i[şs]aret\s+eder\?$", prompt)
    if m:
        word = m.group(1)
        return f"Wêneya '{word}' kîjan cureyê vegotinê nîşan dide?", True
    
    # Pattern 22: Kürt edebiyatında X ne anlama gelir?
    # → Di edebiyata Kurdî de X tê çi wateyê?
    m = re.match(r"^K[üu]rt\s+edebiyat[ıi]nda\s+(.+?)\s+ne\s+anlama\s+gelir\?$", prompt)
    if m:
        rest = m.group(1)
        return f'Di edebiyata Kurdî de {rest} tê çi wateyê?', True
    
    # Pattern 23: Bu görseldeki 'X' hangi yeryüzü şeklini anlatır?
    # → 'X' a di vê wêneyê de kîjan şiklê erdê vedibêje?
    m = re.match(r"^Bu\s+g[öo]rseldeki\s+'([^']+)'\s+hangi\s+yery[üu]z[üu]\s+[şs]eklini\s+anlat[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' a di vê wêneyê de kîjan şiklê erdê vedibêje?", True
    
    # Pattern 24: Bu görseldeki 'X' doğal çevrede hangi unsuru gösterir?
    # → 'X' a di vê wêneyê de di hawîrdora xwezayî de kîjan hêmanê nîşan dide?
    m = re.match(r"^Bu\s+g[öo]rseldeki\s+'([^']+)'\s+do[ğg]al\s+[çc]evrede\s+hangi\s+unsuru\s+g[öo]sterir\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' a di vê wêneyê de di hawîrdora xwezayî de kîjan hêmanê nîşan dide?", True
    
    # Pattern 25: Bu görseldeki 'X' hangi su varlığını anlatır?
    # → 'X' a di vê wêneyê de kîjan hebûna avê vedibêje?
    m = re.match(r"^Bu\s+g[öo]rseldeki\s+'([^']+)'\s+hangi\s+su\s+varl[ıi][ğg][ıi]n[ıi]\s+anlat[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' a di vê wêneyê de kîjan hebûna avê vedibêje?", True
    
    # Pattern 26: Bu görseldeki 'X' en çok hangi anlatı biçimine yakındır?
    # → 'X' a di vê wêneyê de herî zêde nêzîkî kîjan şêweya vegotinê ye?
    m = re.match(r"^Bu\s+g[öo]rseldeki\s+'([^']+)'\s+en\s+[çc]ok\s+hangi\s+anlat[ıi]\s+bi[çc]imine\s+yak[ıi]nd[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' a di vê wêneyê de herî zêde nêzîkî kîjan şêweya vegotinê ye?", True
    
    # Pattern 27: Kürdistan coğrafyası bağlamında Kurmancîde "X" neye yakındır?
    # → Di çarçoveya erdnîgariya Kurdistanê de, di Kurmancî de "X" nêzîkî çi ye?
    m = re.match(r'^K[üu]rdistan\s+co[ğg]rafyas[ıi]\s+ba[ğg]lam[ıi]nda\s+Kurmanc[îi]de\s+"([^"]+)"\s+neye\s+yak[ıi]nd[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di çarçoveya erdnîgariya Kurdistanê de, di Kurmancî de "{word}" nêzîkî çi ye?', True
    
    # Pattern 28: 'X' konusunda hangisi doğrudur?
    # → Derbarê 'X' de kîjan rast e?
    m = re.match(r"^'([^']+)'\s+konusunda\s+hangisi\s+do[ğg]rudur\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de kîjan rast e?", True
    
    # Pattern 29: 'X' ile ilgili doğru seçenek hangisidir?
    # → Derbarê 'X' de vebijêrka rast kîjan e?
    m = re.match(r"^'([^']+)'\s+ile\s+ilgili\s+do[ğg]ru\s+se[çc]enek\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de vebijêrka rast kîjan e?", True
    
    # Pattern 30: 'X' ile kastedilen doğru nedir?
    # → 'X' bi çi tê xwestin? ya rast çi ye?
    m = re.match(r"^'([^']+)'\s+ile\s+kastedilen\s+do[ğg]ru\s+nedir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Bi '{word}' çi tê xwestin? ya rast çi ye?", True
    
    # Pattern 31: 'X' dendiğinde kastedilen nedir?
    # → Dema 'X' tê gotin, çi tê xwestin?
    m = re.match(r"^'([^']+)'\s+dendi[ğg]inde\s+kastedilen\s+nedir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Dema '{word}' tê gotin, çi tê xwestin?", True
    
    # Pattern 32: 'X' ile bağdaşan doğru açıklama hangisidir?
    # → Derbarê 'X' de ravekirina rast kîjan e?
    m = re.match(r"^'([^']+)'\s+ile\s+ba[ğg]da[şs]an\s+do[ğg]ru\s+a[çc][ıi]klama\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de ravekirina rast kîjan e?", True
    
    # Pattern 33: 'X' ne anlama gelir?
    # → 'X' tê çi wateyê?
    m = re.match(r"^'([^']+)'\s+ne\s+anlama\s+gelir\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' tê çi wateyê?", True
    
    # Pattern 34: 'X' nasıl tanımlanır?
    # → 'X' çawa tê pênasekirin?
    m = re.match(r"^'([^']+)'\s+nas[ıi]l\s+tan[ıi]mlan[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' çawa tê pênasekirin?", True
    
    # Pattern 35: 'X' ile ilgili en doğru bilgi hangisidir?
    # → Derbarê 'X' de agahiya herî rast kîjan e?
    m = re.match(r"^'([^']+)'\s+ile\s+ilgili\s+en\s+do[ğg]ru\s+bilgi\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de agahiya herî rast kîjan e?", True
    
    # Pattern 36: 'X' ifadesinin doğru karşılığı hangisidir?
    # → Berambera rast a biwêja 'X' kîjan e?
    m = re.match(r"^'([^']+)'\s+ifadesinin\s+do[ğg]ru\s+kar[şs][ıi]l[ıi][ğg][ıi]\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Berambera rast a biwêja '{word}' kîjan e?", True
    
    # Pattern 37: 'X' hakkında bilinen doğru nedir?
    # → Derbarê 'X' de ya rast a zanîn çi ye?
    m = re.match(r"^'([^']+)'\s+hakk[ıi]nda\s+bilinen\s+do[ğg]ru\s+nedir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de ya rast a zanîn çi ye?", True
    
    # Pattern 38: 'X' hangi coğrafi unsurdur?
    # → 'X' kîjan hêmana erdnîgariyê ye?
    m = re.match(r"^'([^']+)'\s+hangi\s+co[ğg]rafi\s+unsurdur\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' kîjan hêmana erdnîgariyê ye?", True
    
    # Pattern 39: 'X' coğrafyada neyi ifade eder?
    # → 'X' di erdnîgariyê de çi îfade dike?
    m = re.match(r"^'([^']+)'\s+co[ğg]rafyada\s+neyi\s+ifade\s+eder\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' di erdnîgariyê de çi îfade dike?", True
    
    # Pattern 40: Çand bağlamında 'X' nasıl anlaşılmalıdır?
    # → Di çarçoveya Çandê de 'X' çawa divê bê fêmkirin?
    m = re.match(r"^(\w+)\s+ba[ğg]lam[ıi]nda\s+'([^']+)'\s+nas[ıi]l\s+anla[şs][ıi]lmal[ıi]d[ıi]r\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Di çarçoveya {category}ê de '{word}' çawa divê bê fêmkirin?", True
    
    # Pattern 41: Çand alanında 'X' neyi ifade eder?
    # → Di qada Çandê de 'X' çi îfade dike?
    m = re.match(r"^(\w+)\s+alan[ıi]nda\s+'([^']+)'\s+neyi\s+ifade\s+eder\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Di qada {category}ê de '{word}' çi îfade dike?", True
    
    # Pattern 42: 'X' yalnızca Y dışı alanlara aittir.
    # → 'X' tenê aîdî qadên derveyî Y e.
    m = re.match(r"^'([^']+)'\s+yaln[ıi]zca\s+(\w+)\s+d[ıi][şs][ıi]\s+alanlara\s+aittir\.?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"'{word}' tenê aîdî qadên derveyî {category}ê ye.", True
    
    # Pattern 43: 'X' Muzîk açısından anlamsız bir ifadedir.
    # → 'X' ji aliyê Muzîkê ve biwêjek bêwate ye.
    m = re.match(r"^'([^']+)'\s+(\w+)\s+a[çc][ıi]s[ıi]ndan\s+anlams[ıi]z\s+bir\s+ifadedir\.?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"'{word}' ji aliyê {category}ê ve biwêjek bêwate ye.", True
    
    # Pattern 44: 'X' kavramı neyi karşılar?
    # → Têgiha 'X' çi pêk tîne?
    m = re.match(r"^'([^']+)'\s+kavram[ıi]\s+neyi\s+kar[şs][ıi]lar\?$", prompt)
    if m:
        word = m.group(1)
        return f"Têgiha '{word}' çi pêk tîne?", True
    
    # Pattern 45: 'X' için en isabetli açıklama hangisidir?
    # → Ji bo 'X' ravekirina herî dirust kîjan e?
    m = re.match(r"^'([^']+)'\s+i[çc]in\s+en\s+isabetli\s+a[çc][ıi]klama\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Ji bo '{word}' ravekirina herî dirust kîjan e?", True
    
    # Pattern 46: Çand çerçevesinde 'X' ne anlama gelir?
    # → Di çarçoveya Çandê de 'X' tê çi wateyê?
    m = re.match(r"^(\w+)\s+[çc]er[çc]evesinde\s+'([^']+)'\s+ne\s+anlama\s+gelir\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Di çarçoveya {category}ê de '{word}' tê çi wateyê?", True
    
    # Pattern 47: Çand için 'X' hakkında doğru seçenek hangisidir?
    # → Ji bo Çandê derbarê 'X' de vebijêrka rast kîjan e?
    m = re.match(r"^(\w+)\s+i[çc]in\s+'([^']+)'\s+hakk[ıi]nda\s+do[ğg]ru\s+se[çc]enek\s+hangisidir\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Ji bo {category}ê derbarê '{word}' de vebijêrka rast kîjan e?", True
    
    # Pattern 48: Çand açısından 'X' için doğru ifade hangisidir?
    # → Ji aliyê Çandê ve ji bo 'X' îfadeya rast kîjan e?
    m = re.match(r"^(\w+)\s+a[çc][ıi]s[ıi]ndan\s+'([^']+)'\s+i[çc]in\s+do[ğg]ru\s+ifade\s+hangisidir\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Ji aliyê {category}ê ve ji bo '{word}' îfadeya rast kîjan e?", True
    
    # Pattern 49: Şıklardan hangisi 'X' anlamına gelir?
    # → Kîjan vebijêrk tê wateya 'X'?
    m = re.match(r"^[Şs][ıi]klardan\s+hangisi\s+'([^']+)'\s+anlam[ıi]na\s+gelir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Kîjan vebijêrk tê wateya '{word}'?", True
    
    # Pattern 50: Kurmancî çoğunlukla hangi yazı sistemiyle yazılır?
    # → Kurmancî bi piranî bi kîjan pergala nivîsandinê tê nivîsandin?
    if re.match(r'^Kurmanc[îi]\s+[çc]o[ğg]unlukla\s+hangi\s+yaz[ıi]\s+sistemiyle\s+yaz[ıi]l[ıi]r\?$', prompt):
        return 'Kurmancî bi piranî bi kîjan pergala nivîsandinê tê nivîsandin?', True
    
    # Pattern 51: Kürtçede "X" kelimesi genellikle ne demektir?
    # → Di Kurdî de peyva "X" bi giştî tê çi wateyê?
    m = re.match(r'^K[üu]rt[çc]ede\s+"([^"]+)"\s+kelimesi\s+genellikle\s+ne\s+demektir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di Kurdî de peyva "{word}" bi giştî tê çi wateyê?', True
    
    # Pattern 52: İlk Kürtçe romanlar ağırlıkla hangi dönemde ortaya çıkmıştır?
    # → Romanên Kurdî yên pêşîn bi piranî di kîjan serdemê de derketine?
    if re.match(r'^[İi]lk\s+K[üu]rt[çc]e\s+romanlar\s+a[ğg][ıi]rl[ıi]kla\s+hangi\s+d[öo]nemde\s+ortaya\s+[çc][ıi]km[ıi][şs]t[ıi]r\?$', prompt):
        return 'Romanên Kurdî yên pêşîn bi piranî di kîjan serdemê de derketine?', True
    
    # Pattern 53: İlk Kürt gazetesi hangi adı taşır?
    # → Rojnameya Kurdî ya pêşîn kîjan navî hildigire?
    if re.match(r'^[İi]lk\s+K[üu]rt\s+gazetesi\s+hangi\s+ad[ıi]\s+ta[şs][ıi]r\?$', prompt):
        return 'Rojnameya Kurdî ya pêşîn kîjan navî hildigire?', True
    
    # Pattern 54: 'X' Çand alanında geçerli bir kavram olarak yer alır.
    # → 'X' di qada Çandê de wek têgihek derbasdar cih digire.
    m = re.match(r"^'([^']+)'\s+(\w+)\s+alan[ıi]nda\s+ge[çc]erli\s+bir\s+kavram\s+olarak\s+yer\s+al[ıi]r\.?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"'{word}' di qada {category}ê de wek têgihek derbasdar cih digire.", True
    
    # Pattern 55: 'X' Dîrok alanında bilinen gerçek bir kavramdır.
    # → 'X' di qada Dîrokê de têgihek rastîn a nas e.
    m = re.match(r"^'([^']+)'\s+(\w+)\s+alan[ıi]nda\s+bilinen\s+ger[çc]ek\s+bir\s+kavramd[ıi]r\.?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"'{word}' di qada {category}ê de têgihek rastîn a nas e.", True
    
    # Pattern 56: Kürt müziğinde telli çalgı ifadesi en çok hangi kavramı açıklar?
    # → Di muzîka Kurdî de biwêja amûra têldar herî zêde kîjan têgihê rave dike?
    m = re.match(r'^K[üu]rt\s+m[üu]zi[ğg]inde\s+telli\s+[çc]alg[ıi]\s+ifadesi\s+en\s+[çc]ok\s+hangi\s+kavram[ıi]\s+a[çc][ıi]klar\?$', prompt)
    if m:
        return 'Di muzîka Kurdî de biwêja amûra têldar herî zêde kîjan têgihê rave dike?', True
    
    # Pattern 57: 'X' bir metindeki hangi unsuru anlatır?
    # → 'X' di metnekê de kîjan hêmanê vedibêje?
    m = re.match(r"^'([^']+)'\s+bir\s+metindeki\s+hangi\s+unsuru\s+anlat[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' di metnekê de kîjan hêmanê vedibêje?", True
    
    # Pattern 58: Mecaz Kürt edebiyatıyla ilgili bir kavramdır.
    # → Mecaz têgihek e ku bi edebiyata Kurdî re têkildar e.
    if re.match(r'^Mecaz\s+K[üu]rt\s+edebiyat[ıi]yla\s+ilgili\s+bir\s+kavramd[ıi]r\.?$', prompt):
        return 'Mecaz têgihek e ku bi edebiyata Kurdî re têkildar e.', True
    
    # === NEW PATTERNS (Round 2) ===
    
    # Pattern 59: "Agir" ne demek? / "Cejna Newrozê" ne demek? / "Çiya" ne demek?
    # → "X" tê çi wateyê?
    m = re.match(r'^"([^"]+)"\s+ne\s+demek\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" tê çi wateyê?', True
    
    # Pattern 60: "X" ne demektir? (when not caught by Pattern 6 "Resimdeki...")
    # → "X" tê çi wateyê?
    m = re.match(r'^"([^"]+)"\s+ne\s+demektir\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" tê çi wateyê?', True
    
    # Pattern 61: "Bav û kal" deyimi neyi ifade eder?
    # → Biwêja "X" çi îfade dike?
    m = re.match(r'^"([^"]+)"\s+deyimi\s+neyi\s+ifade\s+eder\?$', prompt)
    if m:
        word = m.group(1)
        return f'Biwêja "{word}" çi îfade dike?', True
    
    # Pattern 62: "Jin, jiyan, azadî" sloganında "jiyan" ne demektir?
    # → Di slogana "X" de "Y" tê çi wateyê?
    m = re.match(r'^"([^"]+)"\s+slogan[ıi]nda\s+"([^"]+)"\s+ne\s+demektir\?$', prompt)
    if m:
        slogan = m.group(1)
        word = m.group(2)
        return f'Di slogana "{slogan}" de "{word}" tê çi wateyê?', True
    
    # Pattern 63: "X" hangi nehrin adıdır?
    # → "X" navê kîjan çem e?
    m = re.match(r'^"([^"]+)"\s+hangi\s+nehrin\s+ad[ıi]d[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" navê kîjan çem e?', True
    
    # Pattern 64: "X" hangi nehrin başka adıdır?
    # → "X" navê din ê kîjan çem e?
    m = re.match(r'^"([^"]+)"\s+hangi\s+nehrin\s+ba[şs]ka\s+ad[ıi]d[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" navê din ê kîjan çem e?', True
    
    # Pattern 65: "X" hangi tür çalgıdır?
    # → "X" kîjan cureyê amûrê ye?
    m = re.match(r'^"([^"]+)"\s+hangi\s+t[üu]r\s+[çc]alg[ıi]d[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" kîjan cureyê amûrê ye?', True
    
    # Pattern 66: "X" hangi şehrin Kürtçe-yerel söylenişidir?
    # → "X" bilêvkirina Kurdî-herêmî ya kîjan bajarî ye?
    m = re.match(r'^"([^"]+)"\s+hangi\s+[şs]ehrin\s+K[üu]rt[çc]e-yerel\s+s[öo]yleni[şs]idir\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" bilêvkirina Kurdî-herêmî ya kîjan bajarî ye?', True
    
    # Pattern 67: "X" hangi şehrin Kürtçe adıdır?
    # → "X" navê Kurdî yê kîjan bajarî ye?
    m = re.match(r'^"([^"]+)"\s+hangi\s+[şs]ehrin\s+K[üu]rt[çc]e\s+ad[ıi]d[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" navê Kurdî yê kîjan bajarî ye?', True
    
    # Pattern 68: "X" bölgesi ağırlıkla hangi ülkededir?
    # → Herêma "X" bi piranî di kîjan welatî de ye?
    m = re.match(r'^"([^"]+)"\s+b[öo]lgesi\s+a[ğg][ıi]rl[ıi]kla\s+hangi\s+[üu]lkededir\?$', prompt)
    if m:
        word = m.group(1)
        return f'Herêma "{word}" bi piranî di kîjan welatî de ye?', True
    
    # Pattern 69: "X" hangi bölgede hüküm sürmüş bir Kürt hanedanıdır?
    # → "X" li kîjan herêmê hukim kiriye, xanedaneke Kurd e?
    m = re.match(r'^"([^"]+)"\s+hangi\s+b[öo]lgede\s+h[üu]k[üu]m\s+s[üu]rm[üu][şs]\s+bir\s+K[üu]rt\s+hanedan[ıi]d[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" li kîjan herêmê hukim kiriye, xanedaneke Kurd e?', True
    
    # Pattern 70: "X" hangi iki kelimeden oluşur?
    # → "X" ji kîjan du peyvan pêk tê?
    m = re.match(r'^"([^"]+)"\s+hangi\s+iki\s+kelimeden\s+olu[şs]ur\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" ji kîjan du peyvan pêk tê?', True
    
    # Pattern 71: "X" hangi gölün yakınındadır?
    # → "X" nêzîkî kîjan golê ye?
    m = re.match(r'^"([^"]+)"\s+hangi\s+g[öo]l[üu]n\s+yak[ıi]n[ıi]ndad[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" nêzîkî kîjan golê ye?', True
    
    # Pattern 72: "X" hangi yöntemi reddeder?
    # → "X" kîjan rêbazê red dike?
    m = re.match(r'^"([^"]+)"\s+hangi\s+y[öo]ntemi\s+reddeder\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" kîjan rêbazê red dike?', True
    
    # Pattern 73: "X" hangi değerleri esas alır?
    # → "X" kîjan nirxan esas digire?
    m = re.match(r'^"([^"]+)"\s+hangi\s+de[ğg]erleri\s+esas\s+al[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" kîjan nirxan esas digire?', True
    
    # Pattern 74: "X" hangi üç krizi aşmayı hedefler?
    # → "X" derbaskirina kîjan sê krîzan armanc dike?
    m = re.match(r'^"([^"]+)"\s+hangi\s+[üu][çc]\s+krizi\s+a[şs]may[ıi]\s+hedefler\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" derbaskirina kîjan sê krîzan armanc dike?', True
    
    # Pattern 75: "X" hangi değerleri önceler?
    # → "X" kîjan nirxan pêşanî dike?
    m = re.match(r'^"([^"]+)"\s+hangi\s+de[ğg]erleri\s+[öo]nceler\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" kîjan nirxan pêşanî dike?', True
    
    # Pattern 76: "X" sanayi toplumundan hangi yönüyle ayrılır?
    # → "X" ji civaka pîşesaziyê bi kîjan aliyê ve cuda dibe?
    m = re.match(r'^"([^"]+)"\s+sanayi\s+toplumundan\s+hangi\s+y[öo]n[üu]yle\s+ayr[ıi]l[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" ji civaka pîşesaziyê bi kîjan aliyê ve cuda dibe?', True
    
    # Pattern 77: "X" düşüncesi hangi ilişkiyi merkeze alır?
    # → Ramana "X" kîjan têkiliyê dike navend?
    m = re.match(r'^"([^"]+)"\s+d[üu][şs][üu]ncesi\s+hangi\s+ili[şs]kiyi\s+merkeze\s+al[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'Ramana "{word}" kîjan têkiliyê dike navend?', True
    
    # Pattern 78: "X" tarzı çalgılar hangi gruba girer?
    # → Amûrên bi şêwaza "X" dikevin kîjan komê?
    m = re.match(r'^"([^"]+)"\s+tarz[ıi]\s+[çc]alg[ıi]lar\s+hangi\s+gruba\s+girer\?$', prompt)
    if m:
        word = m.group(1)
        return f'Amûrên bi şêwaza "{word}" dikevin kîjan komê?', True
    
    # Pattern 79: Amed, Riha ve Mêrdîn gibi şehirler hangi tarihî bölgede yer alır?
    # → Bajarên wek Amed, Riha û Mêrdîn li kîjan herêma dîrokî cih digirin?
    m = re.match(r'^(.+?)\s+gibi\s+[şs]ehirler\s+hangi\s+tarih[îi]\s+b[öo]lgede\s+yer\s+al[ıi]r\?$', prompt)
    if m:
        cities = m.group(1)
        return f'Bajarên wek {cities} li kîjan herêma dîrokî cih digirin?', True
    
    # Pattern 80: Aşağıda 'X' için doğru olan hangisidir?
    # → Li jêr ji bo 'X' ya rast kîjan e?
    m = re.match(r"^A[şs]a[ğg][ıi]da\s+'([^']+)'\s+i[çc]in\s+do[ğg]ru\s+olan\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Li jêr ji bo '{word}' ya rast kîjan e?", True
    
    # Pattern 81: Aşağıdakilerden hangisi 'X' için doğrudur?
    # → Li jêr ji bo 'X' kîjan rast e?
    m = re.match(r"^A[şs]a[ğg][ıi]dakilerden\s+hangisi\s+'([^']+)'\s+i[çc]in\s+do[ğg]rudur\?$", prompt)
    if m:
        word = m.group(1)
        return f"Li jêr ji bo '{word}' kîjan rast e?", True
    
    # Pattern 82: Aşağıdakilerden hangisi 'X' kavramını açıklar?
    # → Li jêr kîjan têgiha 'X' rave dike?
    m = re.match(r"^A[şs]a[ğg][ıi]dakilerden\s+hangisi\s+'([^']+)'\s+kavram[ıi]n[ıi]\s+a[çc][ıi]klar\?$", prompt)
    if m:
        word = m.group(1)
        return f"Li jêr kîjan têgiha '{word}' rave dike?", True
    
    # Pattern 83: 'X' için geçerli tanım hangisidir?
    # → Ji bo 'X' pênaseya derbasdar kîjan e?
    m = re.match(r"^'([^']+)'\s+i[çc]in\s+ge[çc]erli\s+tan[ıi]m\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Ji bo '{word}' pênaseya derbasdar kîjan e?", True
    
    # Pattern 84: 'X' hakkında doğru olan seçenek hangisidir?
    # → Derbarê 'X' de vebijêrka rast kîjan e?
    m = re.match(r"^'([^']+)'\s+hakk[ıi]nda\s+do[ğg]ru\s+olan\s+se[çc]enek\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de vebijêrka rast kîjan e?", True
    
    # Pattern 85: 'X' doğru şekilde nasıl açıklanır?
    # → 'X' bi awayekî rast çawa tê ravekirin?
    m = re.match(r"^'([^']+)'\s+do[ğg]ru\s+[şs]ekilde\s+nas[ıi]l\s+a[çc][ıi]klan[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' bi awayekî rast çawa tê ravekirin?", True
    
    # Pattern 86: 'X' kavramını doğru anlatan ifade hangisidir?
    # → Îfadeya ku têgiha 'X' rast vedibêje kîjan e?
    m = re.match(r"^'([^']+)'\s+kavram[ıi]n[ıi]\s+do[ğg]ru\s+anlatan\s+ifade\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Îfadeya ku têgiha '{word}' rast vedibêje kîjan e?", True
    
    # Pattern 87: 'X' neyi ifade eder?
    # → 'X' çi îfade dike?
    m = re.match(r"^'([^']+)'\s+neyi\s+ifade\s+eder\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' çi îfade dike?", True
    
    # Pattern 88: 'X' ifadesi Y bağlamında anlamlıdır.
    # → Biwêja 'X' di çarçoveya Y de watedar e.
    m = re.match(r"^'([^']+)'\s+ifadesi\s+(\w+)\s+ba[ğg]lam[ıi]nda\s+anlaml[ıi]d[ıi]r\.?$", prompt)
    if m:
        word = m.group(1)
        category = m.group(2)
        return f"Biwêja '{word}' di çarçoveya {category}ê de watedar e.", True
    
    # Pattern 89: 'X' ile ilgili doğru bilgi hangisidir?
    # → Derbarê 'X' de agahiya rast kîjan e?
    m = re.match(r"^'([^']+)'\s+ile\s+ilgili\s+do[ğg]ru\s+bilgi\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de agahiya rast kîjan e?", True
    
    # Pattern 90: "X" (Y) hangi tür çalgıdır? / "X" (Y) hangi gölün yakınındadır?
    # → Handle parenthetical notes: "X" (Y) → extract X
    m = re.match(r'^"([^"]+)"\s+\([^)]+\)\s+hangi\s+t[üu]r\s+[çc]alg[ıi]d[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" kîjan cureyê amûrê ye?', True
    
    m = re.match(r'^"([^"]+)"\s+\([^)]+\)\s+hangi\s+g[öo]l[üu]n\s+yak[ıi]n[ıi]ndad[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" nêzîkî kîjan golê ye?', True
    
    # Pattern 91: "X" sözcüğü hangi iki kelimeden oluşur?
    # → "X" ji kîjan du peyvan pêk tê?
    m = re.match(r'^"([^"]+)"\s+s[öo]zc[üu][ğg][üu]\s+hangi\s+iki\s+kelimeden\s+olu[şs]ur\?$', prompt)
    if m:
        word = m.group(1)
        return f'"{word}" ji kîjan du peyvan pêk tê?', True
    
    # Pattern 92: "Cizîr ve Botan" adları hangi tarihî bölgeyle anılır?
    # → Navên "X" bi kîjan herêma dîrokî ve tên bibîranîn?
    m = re.match(r'^"([^"]+)"\s+adlar[ıi]\s+hangi\s+tarih[îi]\s+b[öo]lgeyle\s+an[ıi]l[ıi]r\?$', prompt)
    if m:
        word = m.group(1)
        return f'Navên "{word}" bi kîjan herêma dîrokî ve tên bibîranîn?', True
    
    # Pattern 93: X eserlerini hangi dilde yazmıştır?
    # → X berhemên xwe bi kîjan zimanî nivîsandiye?
    m = re.match(r'^(.+?)\s+eserlerini\s+hangi\s+dilde\s+yazm[ıi][şs]t[ıi]r\?$', prompt)
    if m:
        name = m.group(1)
        return f'{name} berhemên xwe bi kîjan zimanî nivîsandiye?', True
    
    # Pattern 94: X devlete karşı hangi tutumu benimser?
    # → X li hemberî dewletê kîjan helwestê dipejirîne?
    m = re.match(r'^(.+?)\s+devlete\s+kar[şs][ıi]\s+hangi\s+tutumu\s+benimser\?$', prompt)
    if m:
        name = m.group(1)
        return f'{name} li hemberî dewletê kîjan helwestê dipejirîne?', True
    
    # Pattern 95: X üç temel ekseni hangileridir?
    # → Sê tewereyên bingehîn ên X kîjan in?
    m = re.match(r'^(.+?)\s+[üu][çc]\s+temel\s+ekseni\s+hangileridir\?$', prompt)
    if m:
        name = m.group(1)
        return f'Sê tewereyên bingehîn ên {name} kîjan in?', True
    
    # Pattern 96: X türü içecek hangi ana malzemeyle ilişkilidir?
    # → Vexwarina ji cureyê X bi kîjan madeya sereke re têkildar e?
    m = re.match(r'^(.+?)\s+t[üu]r[üu]\s+i[çc]ecek\s+hangi\s+ana\s+malzemeyle\s+ili[şs]kilidir\?$', prompt)
    if m:
        name = m.group(1)
        return f'Vexwarina ji cureyê {name} bi kîjan madeya sereke re têkildar e?', True
    
    # Pattern 97: Bu görseldeki 'X' hangi yeryüzü biçimine yakındır? (without "en çok")
    # → 'X' a di vê wêneyê de nêzîkî kîjan şiklê erdê ye?
    m = re.match(r"^Bu\s+g[öo]rseldeki\s+'([^']+)'\s+hangi\s+yery[üu]z[üu]\s+bi[çc]imine\s+yak[ıi]nd[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' a di vê wêneyê de nêzîkî kîjan şiklê erdê ye?", True
    
    # Pattern 98: Bir soru bankasında "X" alanı hangi teknik işe yarar?
    # → Di banka pirsan de qada "X" ji bo kîjan karê teknîkî ye?
    m = re.match(r'^Bir\s+soru\s+bankas[ıi]nda\s+"([^"]+)"\s+alan[ıi]\s+hangi\s+teknik\s+i[şs]e\s+yarar\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di banka pirsan de qada "{word}" ji bo kîjan karê teknîkî ye?', True
    
    # Pattern 99: X alanında 'Y' geçerli bir kavram olarak yer alır.
    # → Di qada X de 'Y' wek têgihek derbasdar cih digire.
    m = re.match(r"^(\w+)\s+alan[ıi]nda\s+'([^']+)'\s+ge[çc]erli\s+bir\s+kavram\s+olarak\s+yer\s+al[ıi]r\.?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Di qada {category}ê de '{word}' wek têgihek derbasdar cih digire.", True
    
    # Pattern 100: X bilgisinde 'Y' ile ilgili doğru olan hangisidir?
    # → Di zanîna X de derbarê 'Y' de ya rast kîjan e?
    m = re.match(r"^(\w+)\s+bilgisinde\s+'([^']+)'\s+ile\s+ilgili\s+do[ğg]ru\s+olan\s+hangisidir\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Di zanîna {category}ê de derbarê '{word}' de ya rast kîjan e?", True
    
    # Pattern 101: Hangisi X içinde 'Y' kavramını doğru yerleştirir?
    # → Kîjan di X de têgiha 'Y' rast bi cih dike?
    m = re.match(r"^Hangisi\s+(\w+)\s+i[çc]inde\s+'([^']+)'\s+kavram[ıi]n[ıi]\s+do[ğg]ru\s+yerle[şs]tirir\?$", prompt)
    if m:
        category = m.group(1)
        word = m.group(2)
        return f"Kîjan di {category}ê de têgiha '{word}' rast bi cih dike?", True
    
    # Pattern 102: Hangisi 'X' kişisini doğru tanıtır?
    # → Kîjan kesê/a 'X' rast dide nasîn?
    m = re.match(r"^Hangisi\s+'([^']+)'\s+ki[şs]isini\s+do[ğg]ru\s+tan[ıi]t[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f"Kîjan kesê/a '{word}' rast dide nasîn?", True
    
    # Pattern 103: Hangisi 'X' yerini doğru tanımlar?
    # → Kîjan cihê 'X' rast tarîf dike?
    m = re.match(r"^Hangisi\s+'([^']+)'\s+yerini\s+do[ğg]ru\s+tan[ıi]mlar\?$", prompt)
    if m:
        word = m.group(1)
        return f"Kîjan cihê '{word}' rast tarîf dike?", True
    
    # Pattern 104: Hangisi 'X' kavramını doğru betimler?
    # → Kîjan têgiha 'X' rast şirove dike?
    m = re.match(r"^Hangisi\s+'([^']+)'\s+kavram[ıi]n[ıi]\s+do[ğg]ru\s+betimler\?$", prompt)
    if m:
        word = m.group(1)
        return f"Kîjan têgiha '{word}' rast şirove dike?", True
    
    # Pattern 105: Eyyubiler hangi şehirleri uzun süre merkez edinmiştir?
    # → Eyyubiyan kîjan bajaran ji bo demek dirêj wek navend bi kar anîne?
    m = re.match(r'^Eyyubiler\s+hangi\s+[şs]ehirleri\s+uzun\s+s[üu]re\s+merkez\s+edinmi[şs]tir\?$', prompt)
    if m:
        return 'Eyyubiyan kîjan bajaran ji bo demek dirêj wek navend bi kar anîne?', True
    
    # Pattern 106: Hawar dergisi Kürtçe için özellikle hangi katkıyla hatırlanır?
    # → Kovara Hawar bi taybetî bi kîjan tevkariyê tê bibîranîn?
    m = re.match(r'^Hawar\s+dergisi\s+K[üu]rt[çc]e\s+i[çc]in\s+[öo]zellikle\s+hangi\s+katk[ıi]yla\s+hat[ıi]rlan[ıi]r\?$', prompt)
    if m:
        return 'Kovara Hawar bi taybetî bi kîjan tevkariyê tê bibîranîn?', True
    
    # Pattern 107: Kurmancî'de "X" ne demek? / Kurmancî'de "X" fiili ne demek?
    # → Di Kurmancî de "X" tê çi wateyê? / Di Kurmancî de lêkera "X" tê çi wateyê?
    m = re.match(r"^Kurmanc[îi]'de\s+\"([^\"]+)\"\s+fiili\s+ne\s+demek\?$", prompt)
    if m:
        word = m.group(1)
        return f'Di Kurmancî de lêkera "{word}" tê çi wateyê?', True
    
    m = re.match(r"^Kurmanc[îi]'de\s+\"([^\"]+)\"\s+ne\s+demek\?$", prompt)
    if m:
        word = m.group(1)
        return f'Di Kurmancî de "{word}" tê çi wateyê?', True
    
    # Pattern 108: Kurmancî'de "X" hangi sayıdır?
    # → Di Kurmancî de "X" kîjan hejmar e?
    m = re.match(r"^Kurmanc[îi]'de\s+\"([^\"]+)\"\s+hangi\s+say[ıi]d[ıi]r\?$", prompt)
    if m:
        word = m.group(1)
        return f'Di Kurmancî de "{word}" kîjan hejmar e?', True
    
    # Pattern 109: Kurmancî'de "X" hangi renktir?
    # → Di Kurmancî de "X" kîjan reng e?
    m = re.match(r"^Kurmanc[îi]'de\s+\"([^\"]+)\"\s+hangi\s+renktir\?$", prompt)
    if m:
        word = m.group(1)
        return f'Di Kurmancî de "{word}" kîjan reng e?', True
    
    # Pattern 110: Kurmancîde "X" denince kastedilen "Y" midir?
    # → Di Kurmancî de dema "X" tê gotin, "Y" tê xwestin?
    m = re.match(r'^Kurmanc[îi]de\s+"([^"]+)"\s+denince\s+kastedilen\s+"([^"]+)"\s+midir\?$', prompt)
    if m:
        word_x = m.group(1)
        word_y = m.group(2)
        return f'Di Kurmancî de dema "{word_x}" tê gotin, "{word_y}" tê xwestin?', True
    
    # Pattern 111: Kurmancîde "X" demek için hangi sözcük kullanılır?
    # TYPE B: Turkish-to-Kurmanci, keep as is
    m = re.match(r'^Kurmanc[îi]de\s+"([^"]+)"\s+demek\s+i[çc]in\s+hangi\s+s[öo]zc[üu]k\s+kullan[ıi]l[ıi]r\?$', prompt)
    if m:
        return original, False  # TYPE B, keep
    
    # Pattern 112: Kürt bayrağında yer alan üç temel renk hangileridir?
    # → Sê rengên bingehîn ên li ser ala Kurdî kîjan in?
    m = re.match(r'^K[üu]rt\s+bayra[ğg][ıi]nda\s+yer\s+alan\s+[üu][çc]\s+temel\s+renk\s+hangileridir\?$', prompt)
    if m:
        return 'Sê rengên bingehîn ên li ser ala Kurdî kîjan in?', True
    
    # Pattern 113: Kürt halk kültüründe dağlara verilen önem en çok neyle açıklanır?
    # → Di çanda gelêrî ya Kurdî de girîngiya ku ji çiyayan re tê dayîn herî zêde bi çi tê ravekirin?
    m = re.match(r'^K[üu]rt\s+halk\s+k[üu]lt[üu]r[üu]nde\s+da[ğg]lara\s+verilen\s+[öo]nem\s+en\s+[çc]ok\s+neyle\s+a[çc][ıi]klan[ıi]r\?$', prompt)
    if m:
        return 'Di çanda gelêrî ya Kurdî de girîngiya ku ji çiyayan re tê dayîn herî zêde bi çi tê ravekirin?', True
    
    # Pattern 114: Kürt kültüründe "X" ne demek?
    # → Di çanda Kurdî de "X" tê çi wateyê?
    m = re.match(r'^K[üu]rt\s+k[üu]lt[üu]r[üu]nde\s+"([^"]+)"\s+ne\s+demek\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di çanda Kurdî de "{word}" tê çi wateyê?', True
    
    # Pattern 115: Kürt kültüründe ağıtlar hangi işleve sıkça sahiptir?
    # → Di çanda Kurdî de zêmar bi giştî xwedî kîjan fonksiyonê ne?
    m = re.match(r'^K[üu]rt\s+k[üu]lt[üu]r[üu]nde\s+a[ğg][ıi]tlar\s+hangi\s+i[şs]leve\s+s[ıi]k[çc]a\s+sahiptir\?$', prompt)
    if m:
        return 'Di çanda Kurdî de zêmar bi giştî xwedî kîjan fonksiyonê ne?', True
    
    # Pattern 116: Kürt mutfağında "X" neyi ifade eder? / Kürt mutfağında X en genel olarak nedir?
    # → Di pêjgeha Kurdî de "X" çi îfade dike?
    m = re.match(r'^K[üu]rt\s+mutfa[ğg][ıi]nda\s+"([^"]+)"\s+neyi\s+ifade\s+eder\?$', prompt)
    if m:
        word = m.group(1)
        return f'Di pêjgeha Kurdî de "{word}" çi îfade dike?', True
    
    m = re.match(r'^K[üu]rt\s+mutfa[ğg][ıi]nda\s+(.+?)\s+en\s+genel\s+olarak\s+nedir\?$', prompt)
    if m:
        rest = m.group(1)
        return f'Di pêjgeha Kurdî de {rest} bi awayekî giştî çi ye?', True
    
    # Pattern 117: Mahabad Cumhuriyeti hangi yıl kurulmuştur?
    # → Komara Mahabadê di kîjan salê de hatiye damezrandin?
    m = re.match(r'^Mahabad\s+Cumhuriyeti\s+hangi\s+y[ıi]l\s+kurulmu[şs]tur\?$', prompt)
    if m:
        return 'Komara Mahabadê di kîjan salê de hatiye damezrandin?', True
    
    # Pattern 118: Mehmed Uzun eserlerini ağırlıkla hangi dilde yazmıştır?
    # → Mehmed Uzun berhemên xwe bi piranî bi kîjan zimanî nivîsandiye?
    m = re.match(r'^Mehmed\s+Uzun\s+eserlerini\s+a[ğg][ıi]rl[ıi]kla\s+hangi\s+dilde\s+yazm[ıi][şs]t[ıi]r\?$', prompt)
    if m:
        return 'Mehmed Uzun berhemên xwe bi piranî bi kîjan zimanî nivîsandiye?', True
    
    # Pattern 119: Newroz efsanesinde Dehak nasıl biri olarak anlatılır?
    # → Di efsaneya Newrozê de Dehak wek kesekî çawa tê vegotin?
    m = re.match(r'^Newroz\s+efsanesinde\s+(.+?)\s+nas[ıi]l\s+biri\s+olarak\s+anlat[ıi]l[ıi]r\?$', prompt)
    if m:
        rest = m.group(1)
        return f'Di efsaneya Newrozê de {rest} wek kesekî çawa tê vegotin?', True
    
    # Pattern 120: Newroz hangi mevsim ve ayla özdeşleşir?
    # → Newroz bi kîjan demsal û mehê re têkildar e?
    m = re.match(r'^Newroz\s+hangi\s+mevsim\s+ve\s+ayla\s+[öo]zde[şs]le[şs]ir\?$', prompt)
    if m:
        return 'Newroz bi kîjan demsal û mehê re têkildar e?', True
    
    # Pattern 121: Selahaddin Eyyubi hangi savaşın ardından Kudüs'ü geri almıştır?
    # → Selahaddînê Eyûbî piştî kîjan şerî Qudsê vegerand?
    m = re.match(r"^Selahaddin\s+Eyyubi\s+hangi\s+sava[şs][ıi]n\s+ard[ıi]ndan\s+Kud[üu]s'[üu]\s+geri\s+alm[ıi][şs]t[ıi]r\?$", prompt)
    if m:
        return "Selahaddînê Eyûbî piştî kîjan şerî Qudsê vegerand?", True
    
    # Pattern 122: Selahaddin Eyyubi hangi şehirde doğmuştur?
    # → Selahaddînê Eyûbî li kîjan bajarî ji dayik bûye?
    m = re.match(r'^Selahaddin\s+Eyyubi\s+hangi\s+[şs]ehirde\s+do[ğg]mu[şs]tur\?$', prompt)
    if m:
        return 'Selahaddînê Eyûbî li kîjan bajarî ji dayik bûye?', True
    
    # Pattern 123: 'X' hakkında doğru olan hangisidir? (without "seçenek")
    # → Derbarê 'X' de ya rast kîjan e?
    m = re.match(r"^'([^']+)'\s+hakk[ıi]nda\s+do[ğg]ru\s+olan\s+hangisidir\?$", prompt)
    if m:
        word = m.group(1)
        return f"Derbarê '{word}' de ya rast kîjan e?", True
    
    # Pattern 124: 'X' hangi yönüyle bilinir?
    # → 'X' bi kîjan aliyê xwe ve tê nasîn?
    m = re.match(r"^'([^']+)'\s+hangi\s+y[öo]n[üu]yle\s+bilinir\?$", prompt)
    if m:
        word = m.group(1)
        return f"'{word}' bi kîjan aliyê xwe ve tê nasîn?", True
    
    # Pattern 125: Jineolojî en kısa nasıl açıklanabilir?
    # → Jineolojî çawa dikare bi awayekî herî kurt were ravekirin?
    m = re.match(r'^Jineoloj[îi]\s+en\s+k[ıi]sa\s+nas[ıi]l\s+a[çc][ıi]klanabilir\?$', prompt)
    if m:
        return 'Jineolojî çawa dikare bi awayekî herî kurt were ravekirin?', True
    
    # Pattern 126: Kobanê şehri hangi ülkenin sınırları içindedir?
    # → Bajarê Kobanê di nav sînorên kîjan welatî de ye?
    m = re.match(r'^Koban[êe]\s+[şs]ehri\s+hangi\s+[üu]lkenin\s+s[ıi]n[ıi]rlar[ıi]\s+i[çc]indedir\?$', prompt)
    if m:
        return 'Bajarê Kobanê di nav sînorên kîjan welatî de ye?', True
    
    # Pattern 127: Hewramî (Hawraman) bölgesi hangi iki ülkenin sınır kuşağındadır?
    # → Herêma Hewramî (Hawraman) di kêleka sînorê kîjan du welatan de ye?
    m = re.match(r'^Hewram[îi]\s+\(Hawraman\)\s+b[öo]lgesi\s+hangi\s+iki\s+[üu]lkenin\s+s[ıi]n[ıi]r\s+ku[şs]a[ğg][ıi]ndad[ıi]r\?$', prompt)
    if m:
        return 'Herêma Hewramî (Hawraman) di kêleka sînorê kîjan du welatan de ye?', True
    
    # If no pattern matched, return original
    return original, False


def process_file():
    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    total_lines = len(lines)
    changed_count = 0
    skipped_already_kurmanci = 0
    kept_type_b = 0
    
    i = 0
    while i < total_lines:
        line = lines[i]
        # Match prompt lines: they look like:     prompt: '...',
        # Use a more careful regex that handles Dart string escaping
        m = re.match(r"^(\s+prompt:\s*)'(.*)',\s*$", line)
        if m:
            indent = m.group(1)
            raw_prompt = m.group(2)
            # Unescape Dart string escapes (\' -> ', \\ -> \)
            prompt_text = unescape_dart_string(raw_prompt)
            
            new_prompt, was_changed = fix_prompt(prompt_text)
            
            if was_changed:
                # Re-escape for Dart string
                escaped = escape_dart_string(new_prompt)
                lines[i] = f"{indent}'{escaped}',"
                changed_count += 1
                if changed_count <= 10:
                    print(f"  Line {i+1}: '{prompt_text[:80]}...' -> '{new_prompt[:80]}...'")
            elif new_prompt != prompt_text:
                # Was identified as already Kurmanci or TYPE B
                if re.search(r"Wateya Tirk|Peyva Kurmanc|Hejmara", prompt_text):
                    skipped_already_kurmanci += 1
                else:
                    kept_type_b += 1
        
        i += 1
    
    print(f"\nSummary:")
    print(f"  Total lines: {total_lines}")
    print(f"  Prompts changed: {changed_count}")
    print(f"  Already Kurmanci (kept): {skipped_already_kurmanci}")
    print(f"  TYPE B Turkish-to-Kurmanci (kept): {kept_type_b}")
    
    # Write back
    new_content = '\n'.join(lines)
    with open(FILE_PATH, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"\nFile updated successfully!")


if __name__ == '__main__':
    process_file()
