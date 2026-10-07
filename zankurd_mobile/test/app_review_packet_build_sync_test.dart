import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Yayınlanacak her build'in kendi App Review paketi olmalı.
///
/// ## Kusur
///
/// `docs/` altında build 14 ve build 15 için iki paket duruyordu; `pubspec`
/// ise 1.9.2+17'ye çıkmıştı. Yani kaynaktan üretilecek binary'nin reviewer
/// paketi yoktu ve `app_review_packet_test.dart` ile
/// `app_review_build15_packet_test.dart` bunu göremiyordu: ikisi de yalnız
/// kendi dokümanının **kendi içindeki** metni doğruluyor, dokümanın hangi
/// build'i anlattığını `pubspec` ile karşılaştırmıyordu (2026-08-16).
///
/// Sürüklenme sessiz olduğu için tehlikeli: paket App Store Connect'e
/// yapıştırıldığında "bu build 15'i anlatıyor" der, yüklenen binary 17
/// olur. Apple'ın Guideline 2.1 reddi zaten tam olarak paket ile binary'nin
/// örtüşmemesinden çıkmıştı.
///
/// ## Kural
///
/// Bekçi paketin *içeriğini* yargılamaz; yalnız `pubspec`teki build için
/// bir paket bulunmasını şart koşar. Build numarası her yükseltildiğinde
/// yeni paket üretilene kadar testler kırmızı kalır — sürüklenme artık
/// gönderim anında değil, build numarası değiştiği anda görünür.
void main() {
  test('pubspec\'teki build numarasının bir App Review paketi var', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(version, isNotNull, reason: 'pubspec.yaml\'da sürüm okunamadı.');

    final name = version!.group(1)!;
    final build = version.group(2)!;
    final expectedHeading = 'ZanKurd iOS $name ($build)';

    final packets = Directory('docs')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.uri.pathSegments.last.startsWith('app_review_packet_'),
        )
        .toList();

    final matching = packets
        .where((file) => file.readAsStringSync().contains(expectedHeading))
        .map((file) => file.uri.pathSegments.last)
        .toList();

    expect(
      matching,
      isNotEmpty,
      reason:
          '$name+$build için App Review paketi yok. `docs/` altında '
          '«$expectedHeading» başlığını taşıyan bir paket bekleniyor; '
          'bulunanlar: '
          '${packets.map((f) => f.uri.pathSegments.last).join(', ')}. '
          'Build numarası yükseltildiyse o build\'in paketi de üretilmeli.',
    );

    final packet = File('docs/${matching.first}').readAsStringSync();

    expect(
      packet,
      contains('Candidate build: $name ($build)'),
      reason:
          'Paketin güncel operasyonel bölümü pubspec\'teki aday build\'i '
          'değil eski bir build\'i anlatıyor olabilir.',
    );
    expect(
      packet,
      contains('Before uploading build $build'),
      reason: 'Upload öncesi gate metni güncel build numarasını taşımalı.',
    );
    expect(
      packet,
      contains('Upload the exact build $build'),
      reason: 'Upload talimatı güncel build numarasını taşımalı.',
    );
  });
}
