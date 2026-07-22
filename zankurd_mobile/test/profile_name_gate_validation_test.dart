import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-22 canlı UX denetimi (P1-C): boş adla "Oyuna Başla"ya basınca
/// çıkan "Ad en az 2 karakter olmalı" uyarısı, geçerli bir ad yazıldıktan
/// sonra da ekranda kalıyordu — TextFormField varsayılan olarak yalnız
/// Form.validate() ile güncelleniyor.
void main() {
  testWidgets('geçerli ad yazılınca hata durumu temizlenir', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: MockZanKurdRepository(),
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('player-name-field'));
    expect(field, findsOneWidget);

    // Boş adla gönder → hata görünür.
    await tester.tap(find.text('Oyuna Başla'));
    await tester.pumpAndSettle();
    expect(find.text('Ad en az 2 karakter olmalı'), findsOneWidget);

    // Geçerli ad yaz → hata kendiliğinden kaybolmalı.
    await tester.enterText(field, 'Rojhat');
    await tester.pumpAndSettle();
    expect(
      find.text('Ad en az 2 karakter olmalı'),
      findsNothing,
      reason: 'girdi geçerli hale gelince hata temizlenmeli',
    );
  });
}
