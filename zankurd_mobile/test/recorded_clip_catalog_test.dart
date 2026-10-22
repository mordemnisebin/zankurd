import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/services/recorded_clip_catalog.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';

/// Ses kaydı dizininin bekçisi.
///
/// ## Kusur
///
/// Bozuk ya da eksik `index.json` uygulamayı açılışta düşürürse tek bir yanlış
/// virgül bütün sürümü bozar; tek geçersiz satır da bütün kayıtları
/// sessizleştirmemeli. Köken ve lisansı olmayan kayıt, doğrulanmamış sesi
/// "insan sesi" diye sunar (bkz. `VerifiedQuestionAudioClip`).
void main() {
  Map<String, String> row(String text, {String? key, String file = 'a.m4a'}) =>
      {
        'key': key ?? kurmanciTextKey(text),
        'text': text,
        'file': file,
        'speaker': 'konuşmacı-1',
        'license': 'CC-BY-4.0',
        'provenance': 'stüdyo kaydı 2026-10',
      };

  test(
    'geçerli dizin: ifade (büyük harf, noktalama fark etmez) kaydı bulur',
    () {
      final catalog = RecordedClipCatalog.parse(
        jsonEncode([row('Rojbaş'), row('Navê te çi ye?', file: 'b.m4a')]),
      );
      expect(catalog.length, 2);
      expect(catalog.clipForText('rojbaş!')?.file, 'a.m4a');
      expect(catalog.clipForText('Navê te çi ye')?.file, 'b.m4a');
      expect(
        catalog.clipForText('Rojbas'),
        isNull,
        reason: 's ile ş ayrı harf',
      );
      expect(catalog.clipForText('Rojbaş')?.assetPath, 'assets/audio/ku/a.m4a');
    },
  );

  test('boş dizin boş katalog verir', () {
    final catalog = RecordedClipCatalog.parse('[]');
    expect(catalog.isEmpty, isTrue);
    expect(catalog.clipForText('Rojbaş'), isNull);
  });

  test('bozuk JSON ve liste olmayan kök çökertmez', () {
    expect(RecordedClipCatalog.parse('{{{').isEmpty, isTrue);
    expect(RecordedClipCatalog.parse('{"a":1}').isEmpty, isTrue);
  });

  test('geçersiz satır yalnız kendini düşürür', () {
    final catalog = RecordedClipCatalog.parse(
      jsonEncode([
        row('Rojbaş'),
        {...row('Şevbaş'), 'license': ''}, // lisans zorunlu
        {...row('Êvarbaş'), 'provenance': '  '}, // köken zorunlu
        row('Spas', file: '../kaçak.m4a'), // yol kaçışı
        row('Silav', key: 'yanlis_anahtar'), // anahtar metinle uyuşmuyor
        {'key': 1}, // tür hatası
        'metin', // nesne değil
      ]),
    );
    expect(catalog.length, 1);
    expect(catalog.clipForText('Rojbaş'), isNotNull);
  });

  test('yinelenen anahtarda ilk kayıt kazanır', () {
    final catalog = RecordedClipCatalog.parse(
      jsonEncode([
        row('Rojbaş', file: 'ilk.m4a'),
        row('Rojbaş', file: 'ikinci.m4a'),
      ]),
    );
    expect(catalog.length, 1);
    expect(catalog.clipForText('Rojbaş')?.file, 'ilk.m4a');
  });

  test('load: eksik dizin boş katalog verir', () async {
    final catalog = await RecordedClipCatalog.load(bundle: _Bundle(null));
    expect(catalog.isEmpty, isTrue);
  });

  // 2026-10-22: sözlük terimlerinin sentetik sesleri paketlendi (Anadil
  // Kurmancî TTS, MMS-1B ile geri okunarak denetlendi). Bekçi: dizindeki her
  // satır geçerli, dosyası diskte, metni sözlükte bir terim; kayıt sayısı
  // sessizce düşmesin (bir paketleme hatası bütün sesi kapatırdı).
  test('load: paketlenmiş dizin sözlük terimlerinin seslerini taşır', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString(RecordedClipCatalog.indexAsset);
    final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final catalog = RecordedClipCatalog.parse(raw);
    expect(catalog.length, rows.length, reason: 'geçersiz satır var');
    expect(catalog.length, greaterThanOrEqualTo(1000));
    final terms = {
      for (final e in LearnerLexicon.entries) kurmanciTextKey(e.termKu),
    };
    for (final r in rows) {
      final file = File('${RecordedClipCatalog.folder}${r['file']}');
      expect(file.existsSync(), isTrue, reason: '${r['file']} yok');
      expect(file.lengthSync(), greaterThan(1000), reason: '${r['file']}');
      expect(terms, contains(r['key']), reason: '${r['text']} sözlükte yok');
      expect(r['speaker'], contains('Anadil'));
    }
    expect(catalog.clipForText('Rojbaş'), isNotNull);
  });

  test('load: dizini asset paketinden okur', () async {
    final catalog = await RecordedClipCatalog.load(
      bundle: _Bundle(jsonEncode([row('Rojbaş')])),
    );
    expect(catalog.clipForText('Rojbaş'), isNotNull);
  });

  test('RecordedClip köken/lisans/konuşmacı olmadan kurulamaz', () {
    expect(
      () => RecordedClip(
        key: kurmanciTextKey('Rojbaş'),
        text: 'Rojbaş',
        file: 'a.m4a',
        speaker: '',
        license: 'CC0',
        provenance: 'x',
      ),
      throwsArgumentError,
    );
  });
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.index);
  final String? index;

  @override
  Future<ByteData> load(String key) async {
    if (index == null || key != RecordedClipCatalog.indexAsset) {
      throw FlutterError('asset yok: $key');
    }
    final bytes = utf8.encode(index!);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
