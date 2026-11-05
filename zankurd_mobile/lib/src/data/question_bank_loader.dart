import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/quiz_question.dart';
import '../utils/error_reporter.dart';
import 'curated_question_bank.dart';
import 'question_bank_assets.dart';
import 'question_bank_loader_stub.dart'
    if (dart.library.io) 'question_bank_loader_io.dart';

/// `compute` ile arka isolate'te çalıştırılır; üst düzey olmak zorunda.
///
/// JSON çözme VE `QuizQuestion.fromJson` eşlemesi birlikte arka planda yapılır
/// (alan 9 #9): eskiden yalnız `json.decode` taşınıyor, ~6.800 kaydın nesneye
/// çevrilmesi ana isolate'te kalıyor ve açılış karelerini tutuyordu. Sonuç
/// (`QuizQuestion` değişmez, yalnız düz alanlar) isolate sınırından geçer.
List<QuizQuestion> _parseQuestionBank(String raw) => [
  for (final e in json.decode(raw) as List<dynamic>)
    QuizQuestion.fromJson(e as Map<String, dynamic>),
];

/// Soru bankasını asenkron olarak yükler.
///
/// Eski `offline_question_bank.dart` ve `editorial_question_bank.dart`
/// dosyaları doğrudan Dart const listesiydi (toplam ~1.5 MB kod segmenti).
/// Bu loader onların yerine asset JSON dosyalarını runtime'da okur;
/// bu sayede APK/IPA kodu küçülür, soru güncelleme kolaylaşır.
///
/// Kullanım:
/// ```dart
/// await QuestionBankLoader.instance.load();
/// final questions = QuestionBankLoader.instance.allQuestions;
/// ```
class QuestionBankLoader {
  QuestionBankLoader._();

  static final QuestionBankLoader instance = QuestionBankLoader._();

  List<QuizQuestion> _questions = const [];
  bool _loaded = false;
  final List<String> _failedAssets = [];

  /// Yüklenemeyen paketler: içerik kaybını sağlıklı açılıştan ayırır.
  List<String> get failedAssets => List.unmodifiable(_failedAssets);

  /// Tüm sorular (curated + sentences + community + editorial + offline).
  List<QuizQuestion> get allQuestions {
    _ensureLoadedInTest();
    return _questions;
  }

  bool get isLoaded {
    _ensureLoadedInTest();
    return _loaded;
  }

  void _ensureLoadedInTest() {
    if (_loaded) return;
    final testQuestions = loadSyncIfInTest();
    if (testQuestions != null && testQuestions.isNotEmpty) {
      _questions = List.unmodifiable(testQuestions);
      _loaded = true;
    }
  }

  /// Başarıyla yüklenmiş paketler (yol → sorular). Yeniden denemede yalnız
  /// başarısız paketler tekrar okunur; başarılılar korunur.
  final Map<String, List<QuizQuestion>> _bankCache = {};

  /// Havadaki yükleme: açılıştaki 8 sn'lik sınır beklemeyi bırakınca alttaki
  /// iş sürer; ikinci `load()` onu paylaşır, aynı paketleri iki kez okumaz.
  Future<void>? _inFlight;

  /// Soru listesi değiştikçe artar. Geç tamamlanan (açılış sınırını aşan) ya
  /// da yeniden denenen yükleme sonrası içerik gösteren ekranlar buna
  /// kulak verip kendini yenileyebilir (Codex denetimi 2026-10-29).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// JSON asset'leri okur ve parse eder. Uygulama başlangıcında bir kez
  /// çağrılmalıdır (ör. `main()` içinde ya da `AppShell.initState()`).
  ///
  /// Bir paket okunamadıysa (`failedAssets` dolu) sonraki çağrı yalnız o
  /// paketleri yeniden dener; eskiden `_loaded` bayrağı kısmi hatada bile
  /// kalıcı açıldığından "Tekrar dene" hiçbir şey yapmıyordu.
  Future<void> load() {
    if (_loaded && _failedAssets.isEmpty) return Future<void>.value();
    return _inFlight ??= _loadMissing().whenComplete(() => _inFlight = null);
  }

  Future<void> _loadMissing() async {
    // Hangi bankaların yükleneceği ve hangi sırayla — hepsi
    // `questionBankAssets` içinde, tek yerde. Cümle kurma, topluluk
    // katkısı ve editoryal sorular ayrı asset'lerde tutulur ki kaynakları
    // ve inceleme akışları üretilmiş bankadan bağımsız yürüsün.
    final missing = [
      for (final asset in questionBankAssets)
        if (!_bankCache.containsKey(asset)) asset,
    ];
    _failedAssets.clear();
    final loaded = await Future.wait(missing.map(_loadJson));
    for (var i = 0; i < missing.length; i++) {
      final bank = loaded[i];
      if (bank != null) _bankCache[missing[i]] = bank;
    }

    _questions = [
      ...curatedQuestionBank,
      for (final asset in questionBankAssets) ...?_bankCache[asset],
    ];
    _loaded = true;
    revision.value++;
  }

  /// Test ortamı için soruları manuel olarak yükleme imkanı tanır.
  void setQuestionsForTest(List<QuizQuestion> questions) {
    _questions = List.unmodifiable(questions);
    _loaded = true;
  }

  /// Tek bir JSON asset dosyasını yükler ve `List<QuizQuestion>` döndürür;
  /// okunamazsa `null` (çağıran önbelleğe yazmaz, bir sonraki deneme yeniden
  /// okur).
  Future<List<QuizQuestion>?> _loadJson(String assetPath) async {
    try {
      // `cache: false`: ham metin (≈1,4 MB) çözüldükten sonra bellekte
      // tutulmaz ve yeniden denemede bozuk bir okuma önbellekten
      // dönmez.
      final raw = await rootBundle.loadString(assetPath, cache: false);
      // JSON çözme ARKA İSOLATE'te.
      //
      // Dört asset toplam ~1,4 MB ve en büyüğü tek başına 1,1 MB
      // (offline_questions.json). Çözme UI isolate'inde yapılınca ilk kare
      // o süre boyunca bloklanıyordu — `main()` bu yüklemeyi `runApp`tan
      // önce bekliyor (2026-07-31 denetimi).
      //
      // `json.decode` + `QuizQuestion.fromJson` birlikte taşınıyor.
      // Web'de `compute` senkron çalışır, davranış aynı kalır.
      final list = await compute(_parseQuestionBank, raw);
      return List<QuizQuestion>.unmodifiable(list);
    } catch (_, stack) {
      _failedAssets.add(assetPath);
      // Ham JSON/parsing hatası içerik taşıyabilir. Yalnız paket kimliğini
      // kaydet; diğer bankalarla devam etme davranışı korunur.
      ErrorReporter.record(
        StateError('Question bank could not be loaded: $assetPath'),
        stack,
        reason: 'question_bank_load',
      );
      debugPrint('[QuestionBank] Could not load $assetPath');
      // Asset bulunamazsa veya parse hatası olursa bu paket atlanır
      // (uygulama curated + diğer banka ile devam eder).
      return null;
    }
  }

  /// `id` → soru haritası; `_questions` listesinin KİMLİĞİYLE önbelleğe alınır
  /// (liste yenilenince harita düşer). Kopya kimlikte eski doğrusal taramayla
  /// AYNI davranış: ilk eşleşme kazanır.
  List<QuizQuestion>? _indexSource;
  Map<String, QuizQuestion> _byId = const {};

  /// Belirli bir `id`'ye sahip soruyu bulur (MistakeStore için).
  ///
  /// Eskiden her çağrı ~6.800 soruyu doğrusal tarıyordu (alan 9 #14); hata
  /// defteri her kayıt için bir kez çağırır. Harita bir kez kurulur.
  QuizQuestion? findById(String id) {
    _ensureLoadedInTest();
    if (!identical(_indexSource, _questions)) {
      final map = <String, QuizQuestion>{};
      for (final q in _questions) {
        map.putIfAbsent(q.id, () => q);
      }
      _byId = map;
      _indexSource = _questions;
    }
    return _byId[id];
  }
}
