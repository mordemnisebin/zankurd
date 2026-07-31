/// Oda sohbeti için içerik süzgeci.
///
/// ## Niçin var
///
/// Apple App Store Review Kılavuzu 1.2, kullanıcı üretimi içerik barındıran
/// uygulamalarda dört şeyi zorunlu kılar:
///
/// 1. uygunsuz içeriği süzme yöntemi,
/// 2. içerik bildirme mekanizması,
/// 3. tacizciyi engelleme yolu,
/// 4. yayımlanmış iletişim bilgisi.
///
/// 2026-07-31 denetiminde `_sendMessage` metni yalnız `trim()` edip
/// gönderiyordu ve depoda küfür filtresi, bildirme, engelleme ya da
/// susturma yoktu. Sohbet o sırada hiçbir ekranda mount edilmediği için
/// canlı bir risk değildi; geri getirilirken dördü birlikte geldi.
///
/// ## Niçin sunucu tarafı da gerekiyor
///
/// Bu sınıf istemci tarafıdır ve tek başına yeterli DEĞİLDİR: değiştirilmiş
/// bir istemci doğrudan REST üzerinden yazabilir. Aynı kural
/// `room_messages` üzerinde bir BEFORE INSERT tetikleyicisiyle de kuruludur
/// (`supabase/2026-07-31_chat_moderation.sql`). İstemci tarafı, kullanıcıya
/// *niçin* gönderilemediğini anında söylemek için var.
///
/// ## Liste hakkında
///
/// Kelime listesi bilerek dar ve iki dillidir. Geniş bir liste masum
/// metinleri de yakalar ("sik" → "sikke", "got" Kurmancîde "söz") ve
/// kullanıcı sohbeti bırakır. Bu yüzden eşleşme **tam sözcük** üzerinden
/// yapılır, alt dizi araması yapılmaz.
library;

/// Bir mesajın gönderilip gönderilemeyeceği ve niçin.
enum ChatModerationVerdict {
  /// Gönderilebilir.
  allowed,

  /// Boş ya da yalnız boşluk.
  empty,

  /// Uzunluk sınırını aşıyor.
  tooLong,

  /// Engellenen sözcük içeriyor.
  blockedWord,

  /// Bağlantı içeriyor — oltalama ve reklam yüzeyi.
  containsLink,

  /// Aynı karakterin aşırı tekrarı (spam/bağırma).
  spam,
}

class ChatModerationPolicy {
  const ChatModerationPolicy._();

  /// Tek mesaj için üst sınır. Oda sohbeti kısa konuşma içindir; uzun
  /// metin hem paneli taşırır hem spam yüzeyi açar.
  static const int maxLength = 240;

  /// Aynı karakterin üst üste kaç kez tekrarlanabileceği.
  static const int maxRepeatRun = 6;

  /// Tam sözcük olarak engellenen ifadeler (Türkçe + Kurmancî).
  ///
  /// Küçük harfe indirgenmiş ve aksanları sadeleştirilmiş hâlleriyle
  /// karşılaştırılır, böylece "S1K" ya da "şerefsİz" gibi kaçamaklar da
  /// yakalanır. Liste kısa tutuluyor: amaç sözlük olmak değil, en sık
  /// görülen doğrudan hakaretleri kesmek.
  ///
  /// ## Listeden bilerek çıkarılanlar
  ///
  /// Sadeleştirme aksanları düzlediği için bazı hakaretler masum
  /// sözcüklerle çakışıyor ve bekçi testi bunu yakaladı:
  ///
  /// * `göt` → `got`, ama "got" Kurmancîde "dedi"dir ("Got û gotin").
  /// * `kerê` → `kere`, ama "kere" Türkçede "defa"dır ("üç kere").
  /// * `heywan` Kurmancîde düpedüz "hayvan" demek.
  /// * `gu`, `aq`, `oc` iki-üç harfli; çakışma olasılıkları çok yüksek.
  /// * `salak`, `aptal` hafif ve günlük konuşmada geçiyor; sohbeti
  ///   kilitlemek kazançtan çok kayıp.
  ///
  /// Yanlış pozitif, kaçırılan hakaretten pahalıdır: filtre masum bir
  /// cümleyi reddettiğinde kullanıcı sohbeti bırakır.
  static const Set<String> blockedWords = {
    // Türkçe
    'orospu', 'piç', 'yavsak', 'sikeyim', 'siktir', 'amk',
    'orospucocugu', 'gavat', 'serefsiz', 'ibne', 'pezevenk',
    'yarrak', 'amina', 'sikik', 'gerizekali',
    // Kurmancî
    'qehpik', 'qehbe', 'kerbeşo', 'quna', 'bêşeref',
  };

  /// Bağlantı arayan kaba desen. Sohbet oyun içi konuşma içindir;
  /// dışarı bağlantı hem reklam hem oltalama yüzeyidir.
  static final RegExp _linkPattern = RegExp(
    r'(https?://|www\.|\b[a-z0-9-]+\.(com|net|org|io|me|tk|ru|xyz|link)\b)',
    caseSensitive: false,
  );

  /// Aksanları ve rakam-harf kaçamaklarını sadeleştirir.
  ///
  /// "ş1kt1r" ya da "ŞEREFSİZ" gibi yazımlar liste karşılaştırmasında
  /// düz hâlleriyle eşleşsin diye.
  static String _normalize(String input) {
    const map = {
      'ı': 'i',
      'İ': 'i',
      'ş': 's',
      'Ş': 's',
      'ğ': 'g',
      'Ğ': 'g',
      'ü': 'u',
      'Ü': 'u',
      'ö': 'o',
      'Ö': 'o',
      'ç': 'c',
      'Ç': 'c',
      'î': 'i',
      'Î': 'i',
      'ê': 'e',
      'Ê': 'e',
      'û': 'u',
      'Û': 'u',
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '@': 'a',
      r'$': 's',
    };
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(map[char] ?? char);
    }
    return buffer.toString();
  }

  /// Mesajı değerlendirir. Yan etkisizdir.
  static ChatModerationVerdict review(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return ChatModerationVerdict.empty;
    if (text.length > maxLength) return ChatModerationVerdict.tooLong;
    if (_linkPattern.hasMatch(text)) return ChatModerationVerdict.containsLink;

    // Aynı karakterin uzun tekrarı: "aaaaaaaaaa" ya da "!!!!!!!!!!".
    var run = 1;
    for (var i = 1; i < text.length; i++) {
      run = text[i] == text[i - 1] ? run + 1 : 1;
      if (run > maxRepeatRun) return ChatModerationVerdict.spam;
    }

    // Tam sözcük eşleşmesi: alt dizi araması masum kelimeleri yakalardı
    // ("gu" → "gulan", "got" → Kurmancîde "söz").
    final normalized = _normalize(text);
    final words = normalized
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.isNotEmpty);
    final blocked = blockedWords.map(_normalize).toSet();
    for (final word in words) {
      if (blocked.contains(word)) return ChatModerationVerdict.blockedWord;
    }

    return ChatModerationVerdict.allowed;
  }

  /// Kısa yol: gönderilebilir mi?
  static bool isAllowed(String raw) =>
      review(raw) == ChatModerationVerdict.allowed;
}
