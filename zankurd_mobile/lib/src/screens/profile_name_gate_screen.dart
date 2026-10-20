import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/display_name_policy.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_logo.dart';
import '../widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class ProfileNameGateScreen extends StatefulWidget {
  const ProfileNameGateScreen({
    required this.repository,
    required this.onCompleted,
    this.initialName,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? initialName;
  final VoidCallback onCompleted;

  @override
  State<ProfileNameGateScreen> createState() => _ProfileNameGateScreenState();
}

class _ProfileNameGateScreenState extends State<ProfileNameGateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final initial = _isDefaultName(widget.initialName)
        ? ''
        : widget.initialName;
    _controller = TextEditingController(text: initial ?? '');
    if (_controller.text.isEmpty) {
      unawaited(_loadInitialName());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitialName() async {
    try {
      final name = await widget.repository.getProfileName();
      if (!mounted || _controller.text.isNotEmpty || _isDefaultName(name)) {
        return;
      }
      _controller.text = name.trim();
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'profile name gate prefill failed',
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final name = _controller.text.trim();
    // Klavye kapanmadan hata gösterilemez: `SnackBarBehavior.floating`
    // kutuyu ekranın altına koyar ve açık klavye tam orayı örter. Oyuncu
    // "Dest pê bike"ye basıyor, yazım sunucuya gitmiyor, hata mesajı
    // klavyenin arkasında doğup ölüyor — ekranda hiçbir şey olmuyor
    // (2026-07-31, sahibin iPhone ekran görüntüleri).
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      widget.onCompleted();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile name gate failed');
      if (!mounted) return;
      // Hata artık formun içinde, kalıcı olarak duruyor. Geçici bir
      // SnackBar burada yanlış araçtı: üç saniye sonra kaybolur ve geriye
      // açıklamasız bir tıkanma bırakır.
      setState(() {
        _saving = false;
        _saveError = context.t(K.nameGateSaveFailed);
      });
    }
  }

  static bool _isDefaultName(String? name) {
    final value = name?.trim();
    return value == null ||
        value.isEmpty ||
        value == 'ZanKurd Oyuncusu' ||
        value == 'ZanKurd Lîstikvan';
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // 2026-10-01 giriş iskeleti (bkz. [SahneEntryScaffold]): giriş ve kayıt
    // ekranıyla aynı yerleşim. Eskiden bu ekran tek başına durum çubuğunun
    // altına uzanan tam genişlikte bir gece bandıydı (başlık bandın içinde,
    // ortalı); "Şimdilik geç" kartın içinde birincil düğmenin altındaydı.
    // Şimdi: kahraman kart (logo), sola yaslı soru + açıklama, tek yüzey
    // kartında ad alanı; "Oyuna başla" alt perdede sabit, "Şimdilik geç"
    // karşılamadaki "Atla" ve seviye sınavındaki "Şimdilik geç" gibi
    // SAĞ ÜSTTE.
    //
    // 2026-07-27 canlı gezinti: bu ekran tanıtım turunun VE giriş
    // ekranının HEMEN ardından açılıyor; ikisi de zaten "ZanKurd'a Hoş
    // Geldin" başlığını anlatmıştı. Burada aynı karşılamayı üçüncü kez
    // göstermek yalnız oyalıyordu; asıl iş tek bir soru.
    return SahneEntryScaffold(
      skip: SahneButton.text(
        key: const ValueKey('name-gate-skip'),
        label: context.t(K.nameGateSkip),
        arrow: false,
        onPressed: _saving ? null : widget.onCompleted,
      ),
      hero: const SahneEntryHero(
        key: ValueKey('profile-name-gate-hero'),
        padding: EdgeInsets.fromLTRB(
          SahneSpace.x4,
          SahneSpace.x6,
          SahneSpace.x4,
          SahneSpace.x5,
        ),
        child: Center(child: AppLogo(width: 64)),
      ),
      title: context.t(K.nameGateQuestion),
      body: context.t(K.nameGateHelp),
      content: SahneSurfaceCard(
        key: const ValueKey('profile-name-gate-card'),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SahneField(
                key: const ValueKey('player-name-field'),
                controller: _controller,
                // Hata yalnız Form.validate() ile güncelleniyordu: geçerli
                // bir ad yazıldıktan sonra da uyarı ekranda kalıyordu
                // (2026-07-22 canlı UX denetimi).
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textCapitalization: TextCapitalization.words,
                hintText: context.t(K.nameGateHint),
                semanticLabel: context.t(K.nameGateHint),
                prefixIcon: AppIcons.user,
                validator: (value) {
                  // 2026-08-02: burada YALNIZ uzunluk kontrol ediliyordu.
                  // Ad, sohbet mesajından daha görünür bir UGC yüzeyi —
                  // liderlikte, odada ve eşleştirmede yabancılara
                  // gösteriliyor ve kalıcı.
                  final verdict = DisplayNamePolicy.review(value ?? '');
                  if (verdict == DisplayNameVerdict.allowed) return null;
                  return context.t(DisplayNamePolicy.messageKeyFor(verdict));
                },
              ),
              if (_saveError != null) ...[
                const SizedBox(height: SahneSpace.x4),
                DecoratedBox(
                  key: const ValueKey('name-gate-save-error'),
                  decoration: ShapeDecoration(
                    color: t.errTint,
                    shape: SahneShape.m,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(SahneSpace.x3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            AppIcons.triangleExclamation,
                            size: 20,
                            color: t.errTx,
                          ),
                        ),
                        const SizedBox(width: SahneSpace.x2),
                        Expanded(
                          child: Text(
                            _saveError!,
                            style: SahneType.body.copyWith(color: t.tx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      primary: SahneButton.primary(
        label: context.t(K.nameGateCta),
        expand: true,
        onPressed: _saving ? null : _save,
      ),
    );
  }
}
