import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

Material _frameOf(WidgetTester tester, Finder field) => tester.widget<Material>(
  find.descendant(of: field, matching: find.byType(Material)).first,
);

/// Alanın pahlı çerçevesinin kenar çizgisi.
BorderSide _sideOf(WidgetTester tester, Finder field) =>
    (_frameOf(tester, field).shape! as BeveledRectangleBorder).side;

void main() {
  testWidgets('alan tema çerçevesini ikinci kez çizmez, çerçeve pahlıdır', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        SahneField(
          label: 'Navnîşana e-peyamê',
          controller: controller,
          prefixIcon: Icons.email_outlined,
        ),
      ),
    );

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration;
    expect(decoration?.border, InputBorder.none);
    expect(decoration?.enabledBorder, InputBorder.none);
    expect(decoration?.focusedBorder, InputBorder.none);
    expect(decoration?.disabledBorder, InputBorder.none);
    expect(decoration?.errorBorder, InputBorder.none);
    expect(decoration?.focusedErrorBorder, InputBorder.none);
    expect(decoration?.filled, isFalse);
    expect(
      _frameOf(tester, find.byType(SahneField)).shape,
      isA<BeveledRectangleBorder>(),
    );
  });

  testWidgets('odakta Agir halkası, hatada Şaş halkası ve metni', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    const t = SahneTokens.day;

    await tester.pumpWidget(
      _host(
        Form(
          key: formKey,
          child: SahneField(
            label: 'Ad',
            controller: controller,
            validator: (v) => (v ?? '').isEmpty ? 'Ad pêwîst e' : null,
          ),
        ),
      ),
    );

    final field = find.byType(SahneField);
    expect(_sideOf(tester, field).color, t.edge);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(_sideOf(tester, field).color, t.actTx);
    expect(_sideOf(tester, field).width, SahneRing.r2);

    // Form.validate() alanı da doğrular (eski StyledInputField yapmıyordu).
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Ad pêwîst e'), findsOneWidget);
    expect(_sideOf(tester, field).color, t.errTx);

    await tester.enterText(find.byType(TextField), 'Rojda');
    expect(formKey.currentState!.validate(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Ad pêwîst e'), findsNothing);
  });

  testWidgets('validate() denetleyiciye sonradan yazılan metni görür', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'x');
    addTearDown(controller.dispose);
    final key = GlobalKey<SahneFieldState>();

    await tester.pumpWidget(
      _host(
        SahneField(
          key: key,
          label: 'Ad',
          controller: controller,
          validator: (v) => (v ?? '').isEmpty ? 'boş' : null,
        ),
      ),
    );
    controller.clear();
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('boş'), findsOneWidget);
  });

  testWidgets('arama alanı: büyüteç + "ara" tuşu, etiket satırı yok', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      _host(
        SahneField.search(
          hintText: 'Bigere',
          onSubmitted: (v) => submitted = v,
        ),
      ),
    );
    expect(find.byIcon(AppIcons.magnifyingGlass), findsOneWidget);
    expect(find.text('Bigere'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).textInputAction,
      TextInputAction.search,
    );
    await tester.enterText(find.byType(TextField), 'dar');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, 'dar');
  });

  testWidgets('açılır liste: yer tutucu, seçim ve doğrulama', (tester) async {
    final formKey = GlobalKey<FormState>();
    String? picked;
    await tester.pumpWidget(
      _host(
        Form(
          key: formKey,
          child: SahneDropdownField<String>(
            label: 'Mijar',
            hintText: 'Mijarek hilbijêre',
            items: const [
              DropdownMenuItem(value: 'a', child: Text('Ziman')),
              DropdownMenuItem(value: 'b', child: Text('Dîrok')),
            ],
            onChanged: (v) => picked = v,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => v == null ? 'Mijar pêwîst e' : null,
          ),
        ),
      ),
    );
    expect(find.text('Mijarek hilbijêre'), findsOneWidget);
    // Yer tutucu metin alanlarıyla aynı stil: body + üçüncül metin.
    final hint = tester.widget<Text>(find.text('Mijarek hilbijêre'));
    expect(hint.style?.color, SahneTokens.day.tx3);
    expect(hint.style?.fontWeight, SahneType.body.fontWeight);

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Mijar pêwîst e'), findsOneWidget);

    await tester.tap(find.byType(SahneDropdownField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dîrok').last);
    await tester.pumpAndSettle();
    expect(picked, 'b');
    expect(find.text('Mijar pêwîst e'), findsNothing);
    expect(formKey.currentState!.validate(), isTrue);
  });
}
