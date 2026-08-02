/// Görünen ad (display name) doğrulaması.
///
/// 2026-08-02 denetimine kadar adlar HİÇBİR içerik filtresinden geçmiyordu.
/// İstemcide tek kontrol uzunluktu (`2 <= n <= 24`); sunucuda ise
/// `profiles.display_name` için ne CHECK kısıtı, ne tetikleyici, ne de
/// doğrulayan bir RPC vardı. `ChatModerationPolicy` depo genelinde tek bir
/// yerde — `room_chat.dart` — çağrılıyordu ve adlara hiç uygulanmıyordu.
///
/// Ad, sohbet mesajından daha görünür bir yüzeydir: liderlik tablosunda,
/// odalarda, eşleştirmede ve sohbette yabancılara gösterilir ve mesaj gibi
/// akıp gitmez, kalıcıdır. Apple Guideline 1.2 ve Play UGC politikası bu
/// yüzeyi de kapsar.
///
/// ## Bu politika neyi kapsar
///
/// * Uzunluk (görünen karakter sayısıyla, emoji'yi tek karakter sayarak)
/// * Boş/yalnız-boşluk
/// * Görünmez ve kontrol karakterleri (kimlik taklidi ve hizalama kırma)
/// * Bağlantı (reklam/oltalama)
/// * Engellenen sözcükler — liste `ChatModerationPolicy` ile ORTAKTIR
/// * Korunan adlar (destek/yetkili taklidi)
///
/// ## Neden istemci tarafı tek başına yetmez
///
/// Değiştirilmiş bir istemci `profiles` tablosuna doğrudan REST üzerinden
/// yazabilir. Aynı kurallar sunucuda da kuruludur:
/// `supabase/2026-08-02_display_name_moderation.sql`. Buradaki kopya,
/// kullanıcıya *niçin* kabul edilmediğini anında söylemek içindir.
library;

import '../l10n/strings.dart';
import 'chat_moderation_policy.dart';

/// Bir adın kabul edilip edilmediği ve niçin.
enum DisplayNameVerdict {
  allowed,

  /// Boş ya da yalnız boşluk.
  empty,

  /// Görünen karakter sayısı alt sınırın altında.
  tooShort,

  /// Görünen karakter sayısı üst sınırın üstünde.
  tooLong,

  /// Kontrol ya da görünmez karakter içeriyor.
  invalidCharacters,

  /// Bağlantı içeriyor.
  containsLink,

  /// Engellenen sözcük içeriyor.
  blockedWord,

  /// Destek/yetkili taklidi yapan korunan ad.
  reservedName,
}

class DisplayNamePolicy {
  const DisplayNamePolicy._();

  /// İsim kapısındaki mevcut sınırlarla aynı tutuldu; bu düzeltme uzunluk
  /// kuralını değiştirmez, yalnız üzerine içerik kuralları ekler.
  static const int minLength = 2;
  static const int maxLength = 24;

  /// Yetkili/destek taklidini kesen adlar.
  ///
  /// Tam eşleşme YETMEZ: "ZanKurd Destek", "resmi zankurd" gibi biçimler de
  /// aynı işi görür. Bu yüzden sadeleştirilmiş ad içinde **tam sözcük**
  /// olarak aranır.
  static const Set<String> reservedWords = {
    'zankurd',
    'admin',
    'administrator',
    'yonetici',
    'moderator',
    'destek',
    'support',
    'resmi',
    'official',
    'sistem',
    'system',
  };

  /// Sunucunun KENDİ atadığı varsayılan adlar.
  ///
  /// `SupabaseZanKurdRepository.ensureProfile()` her yeni kullanıcıya
  /// `'ZanKurd Oyuncusu'` adını yazar. Bu ad markayı içerdiği için
  /// [reservedWords] kuralına takılıyordu — yani politika olduğu gibi
  /// uygulansaydı **hiçbir yeni kullanıcının profili oluşamazdı**.
  ///
  /// Depo bu sınıftan bir kazayı daha önce yaşadı: `assign_player_tag`
  /// tetikleyicisi düştüğünde `ensureProfile()` istisnayı yutuyor,
  /// uygulama normal görünüyor ama profil satırı hiç oluşmuyordu
  /// (`supabase/applied.md`, 2026-08-01). Aynı tuzağa ikinci kez
  /// düşmemek için sunucu tarafından atanan adlar açıkça muaf tutulur.
  ///
  /// Muafiyet yalnız TAM eşleşmedir: "ZanKurd Destek" hâlâ reddedilir.
  static const Set<String> systemAssignedNames = {'ZanKurd Oyuncusu'};

  /// Görünmez ve kontrol karakterleri.
  ///
  /// Kaçış dizileriyle yazılır: bu karakterlerin kendisi kaynakta görünmez
  /// olduğu için düz yazıldıklarında bir sonraki düzenlemede sessizce
  /// silinebilir ya da bozulabilirler.
  ///
  /// Kapsam: C0/C1 kontrol blokları, sıfır genişlikli birleştiriciler,
  /// yön işaretleri ve yön DEĞİŞTİRİCİLER. Sonuncusu önemli: U+202E ile
  /// yazılan bir ad liderlik tablosunda başka bir adın üstüne taşabilir ya
  /// da tersten okunarak kimlik taklidine yarar.
  static final RegExp _invisible = RegExp(
    '[\u0000-\u001F\u007F-\u009F'
    '\u200B-\u200F' // sıfır genişlikli + LRM/RLM
    '\u202A-\u202E' // yön değiştiriciler
    '\u2060-\u2064'
    '\uFEFF]',
  );

  /// Adda bağlantı arayan desen.
  ///
  /// Sohbet politikasındaki listeye kısaltma servislerinin alan adları da
  /// eklendi (`ly`, `gl`, `co`…): spam'in ad alanına sızma biçimi tam olarak
  /// "bit.ly/xyz" gibi kısa bağlantılardır ve 24 karakterlik bir ada ancak
  /// onlar sığar.
  ///
  /// TLD listesi bilerek KAPALI tutuluyor; "her nokta bağlantıdır" kuralı
  /// "Dr.Ahmet" gibi masum adları da keserdi.
  static final RegExp _link = RegExp(
    r'(https?://|www\.|\b[a-z0-9-]+\.'
    r'(com|net|org|io|me|tk|ru|xyz|link|ly|gl|co|cc|to|im|app|site|info|biz)'
    r'\b)',
    caseSensitive: false,
  );

  /// Adı değerlendirir. Yan etkisizdir.
  static DisplayNameVerdict review(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return DisplayNameVerdict.empty;
    if (_invisible.hasMatch(name)) {
      return DisplayNameVerdict.invalidCharacters;
    }

    // Emoji ve birleşik karakterler tek "görünen karakter" sayılmalı;
    // `String.length` UTF-16 kod birimi sayar ve tek bir emoji'yi 2 sayardı,
    // yani emoji kullanan Kurmancî adlar haksız yere reddedilebilirdi.
    final visible = name.runes.length;
    if (visible < minLength) return DisplayNameVerdict.tooShort;
    if (visible > maxLength) return DisplayNameVerdict.tooLong;

    if (_link.hasMatch(name)) return DisplayNameVerdict.containsLink;

    if (ChatModerationPolicy.containsBlockedWord(name)) {
      return DisplayNameVerdict.blockedWord;
    }

    // Sunucunun kendi atadığı varsayılan ad korunan sözcük denetiminden
    // muaftır; aksi hâlde yeni kullanıcı profili hiç oluşamaz.
    if (!systemAssignedNames.contains(name)) {
      final words = ChatModerationPolicy.normalize(
        name,
      ).split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty);
      if (words.any(reservedWords.contains)) {
        return DisplayNameVerdict.reservedName;
      }
    }

    return DisplayNameVerdict.allowed;
  }

  /// Kısa yol: kullanılabilir mi?
  static bool isAllowed(String raw) =>
      review(raw) == DisplayNameVerdict.allowed;

  /// Karara karşılık gelen anahtar defteri anahtarı.
  ///
  /// Metnin kendisi değil ANAHTAR döner: politika dilden bağımsız kalır ve
  /// iki çağıran ekran (isim kapısı + ayarlar) aynı eşlemeyi paylaşır.
  /// `avatar_frames.dart` da aynı deseni kullanıyor.
  static String messageKeyFor(DisplayNameVerdict verdict) => switch (verdict) {
    DisplayNameVerdict.allowed => '',
    DisplayNameVerdict.empty => K.nameMinLength,
    DisplayNameVerdict.tooShort => K.nameMinLength,
    DisplayNameVerdict.tooLong => K.nameMaxLength,
    DisplayNameVerdict.invalidCharacters => K.nameInvalidChars,
    DisplayNameVerdict.containsLink => K.nameNoLinks,
    DisplayNameVerdict.blockedWord => K.nameBlockedWord,
    DisplayNameVerdict.reservedName => K.nameReserved,
  };
}
