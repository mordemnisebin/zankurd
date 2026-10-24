import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/error_reporter.dart';
import '../utils/kurmanci_text_key.dart';
import 'question_audio_service.dart';

/// Bir Kurmancî ifadenin paketlenmiş ses kaydı.
///
/// [VerifiedQuestionAudioClip] ile aynı kural: köken, lisans ve konuşmacı
/// boş olamaz; sentetik ses ise [speaker] bunu açıkça söyler. 2026-10-22'de
/// sözlük terimleri Anadil Kurmancî TTS (VoxCPM2 + LoRA) ile üretildi ve
/// her klip MMS-1B (kmr) ile geri okunarak denetlendi (bkz. [provenance]);
/// cihazda Kurmancî TTS sesi neredeyse hiç olmadığından bu kayıtlar ses
/// düğmesinin tek gerçek kaynağıdır. Fark: klip bir soruya değil bir İFADEYE bağlıdır
/// ([kurmanciTextKey]); böylece ders, sözlük ve sorudaki aynı ifade tek
/// kaydı kullanır.
class RecordedClip {
  RecordedClip({
    required this.key,
    required this.text,
    required this.file,
    required this.speaker,
    required this.license,
    required this.provenance,
  }) {
    if ([
      key,
      text,
      file,
      speaker,
      license,
      provenance,
    ].any((value) => value.trim().isEmpty)) {
      throw ArgumentError(
        'Kayıt için key, text, file, speaker, license ve provenance gerekir.',
      );
    }
    if (!_safeFile.hasMatch(file)) {
      throw ArgumentError('Geçersiz ses dosyası adı: $file');
    }
    if (key != kurmanciTextKey(text)) {
      throw ArgumentError('key metinle uyuşmuyor: $key / $text');
    }
  }

  static final _safeFile = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  final String key;
  final String text;
  final String file;
  final String speaker;
  final String license;
  final String provenance;

  String get assetPath => '${RecordedClipCatalog.folder}$file';

  VerifiedQuestionAudioClip toVerifiedClip() => VerifiedQuestionAudioClip(
    questionId: key,
    source: assetPath,
    location: VerifiedAudioLocation.asset,
    provenance: provenance,
    license: license,
  );
}

/// `assets/audio/ku/index.json` içindeki kayıtların kataloğu.
///
/// Eksik ya da bozuk dizin uygulamayı düşürmez: boş katalog döner ve hata
/// [ErrorReporter]a yazılır. Geçersiz tek satır yalnız kendisini düşürür.
class RecordedClipCatalog {
  RecordedClipCatalog(Iterable<RecordedClip> clips)
    : _byKey = {for (final clip in clips.toList().reversed) clip.key: clip};

  static const folder = 'assets/audio/ku/';
  static const indexAsset = '${folder}index.json';

  static final empty = RecordedClipCatalog(const []);

  final Map<String, RecordedClip> _byKey;

  bool get isEmpty => _byKey.isEmpty;
  int get length => _byKey.length;

  RecordedClip? clipForText(String text) => _byKey[kurmanciTextKey(text)];

  static Future<RecordedClipCatalog>? _shared;

  /// Uygulama boyunca bir kez okunan katalog.
  static Future<RecordedClipCatalog> shared() => _shared ??= load();

  static void resetSharedForTesting() => _shared = null;

  static Future<RecordedClipCatalog> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(indexAsset);
      return parse(raw);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'recorded_clip_index load');
      return empty;
    }
  }

  static RecordedClipCatalog parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('index.json bir liste olmalı');
      }
      final clips = <RecordedClip>[];
      for (var i = 0; i < decoded.length; i++) {
        try {
          clips.add(_clipFrom(decoded[i]));
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'recorded_clip_index satır $i',
          );
        }
      }
      return RecordedClipCatalog(clips);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'recorded_clip_index parse');
      return empty;
    }
  }

  static RecordedClip _clipFrom(Object? json) {
    if (json is! Map) throw const FormatException('satır bir nesne olmalı');
    String field(String name) {
      final value = json[name];
      if (value is! String) throw FormatException('$name metin olmalı');
      return value;
    }

    return RecordedClip(
      key: field('key'),
      text: field('text'),
      file: field('file'),
      speaker: field('speaker'),
      license: field('license'),
      provenance: field('provenance'),
    );
  }
}
