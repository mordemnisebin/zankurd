import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
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
    // Gece bandı durum çubuğunun altına uzanır; saat ve pil açık renkte
    // olmalı (bkz. `AppTheme.overlayOnDarkHeader`).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDarkHeader,
      child: Scaffold(
        backgroundColor: t.bg,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 860;

            return Column(
              children: [
                // 2026-07-23 M23: hero sabit flex (42-45%) alıyordu ama
                // içeriği çok daha az yer kaplıyor — alt kısmı boş kalıyordu.
                // Artık içerik kadar yer kaplıyor, kalan alan forma (Expanded)
                // gidiyor.
                //
                // 2026-09-27 canlı gezinti: bu ekran tanıtım turunun VE giriş
                // ekranının HEMEN ardından açılıyor; ikisi de zaten "ZanKurd'a
                // Hoş Geldin" başlığını ve ürünün ne sunduğunu anlatmıştı.
                // Burada aynı karşılamayı üçüncü kez göstermek yalnız
                // oyalıyordu; asıl iş tek bir soru ("Oyundaki adın ne olsun?").
                //
                // 2026-09-29 Şahnê: marka anı. Forest degrade şerit yerine
                // gece sahnesi bandı (her iki temada gece): logo işareti
                // plakada ve ekranın tek sorusu 28'lik başlık olarak bandın
                // içinde. Altında tek yüzey kartı: ad alanı + tek birincil.
                _NameGateHero(
                  compact: compact,
                  title: context.t(K.nameGateQuestion),
                  body: context.t(K.nameGateHelp),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    // Kart bandın hemen altında başlar (göz logodan soruya,
                    // sorudan alana iner) ve klavye açılınca yerinden
                    // zıplamaz (2026-09-27).
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        SahneSpace.page,
                        SahneSpace.x6,
                        SahneSpace.page,
                        SahneSpace.x6,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: SahneSurfaceCard(
                            key: const ValueKey('profile-name-gate-card'),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SahneField(
                                    key: const ValueKey('player-name-field'),
                                    controller: _controller,
                                    // Hata yalnız Form.validate() ile
                                    // güncelleniyordu: geçerli bir ad
                                    // yazıldıktan sonra da uyarı ekranda
                                    // kalıyordu (2026-07-22 canlı UX
                                    // denetimi).
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    hintText: context.t(K.nameGateHint),
                                    semanticLabel: context.t(K.nameGateHint),
                                    prefixIcon: AppIcons.user,
                                    validator: (value) {
                                      // 2026-08-02: burada YALNIZ
                                      // uzunluk kontrol ediliyordu.
                                      // Ad, sohbet mesajından daha
                                      // görünür bir UGC yüzeyi —
                                      // liderlikte, odada ve
                                      // eşleştirmede yabancılara
                                      // gösteriliyor ve kalıcı.
                                      final verdict = DisplayNamePolicy.review(
                                        value ?? '',
                                      );
                                      if (verdict ==
                                          DisplayNameVerdict.allowed) {
                                        return null;
                                      }
                                      return context.t(
                                        DisplayNamePolicy.messageKeyFor(
                                          verdict,
                                        ),
                                      );
                                    },
                                  ),
                                  if (_saveError != null) ...[
                                    const SizedBox(height: SahneSpace.x4),
                                    DecoratedBox(
                                      key: const ValueKey(
                                        'name-gate-save-error',
                                      ),
                                      decoration: ShapeDecoration(
                                        color: t.errTint,
                                        shape: SahneShape.m,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          SahneSpace.x3,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Icon(
                                                AppIcons.triangleExclamation,
                                                size: 20,
                                                color: t.errTx,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: SahneSpace.x2,
                                            ),
                                            Expanded(
                                              child: Text(
                                                _saveError!,
                                                style: SahneType.body.copyWith(
                                                  color: t.tx,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: SahneSpace.x5),
                                  SahneButton.primary(
                                    label: context.t(K.nameGateCta),
                                    expand: true,
                                    onPressed: _saving ? null : _save,
                                  ),
                                  const SizedBox(height: SahneSpace.x2),
                                  // 2026-07-23 UX: isim artık zorunlu değil;
                                  // kullanıcı varsayılan adla geçip sonra
                                  // profilden değiştirebilir.
                                  Center(
                                    child: SahneButton.text(
                                      label: context.t(K.nameGateSkip),
                                      arrow: false,
                                      onPressed: _saving
                                          ? null
                                          : widget.onCompleted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Gece sahnesi bandı: durum çubuğunun altına uzanır, alt köşeleri L pahlı.
/// Sahne kartının zemini (gece degradesi + öğrenme radyali) her iki temada
/// da gecedir; içindeki logo plakası ve metinler gece belirteçlerini alır.
/// Yüksekliği içerik kadardır — ekran boyuna göre esnemez.
class _NameGateHero extends StatelessWidget {
  const _NameGateHero({
    required this.compact,
    required this.title,
    required this.body,
  });

  final bool compact;
  final String title;
  final String body;

  static const _shape = BeveledRectangleBorder(
    borderRadius: BorderRadius.only(
      bottomLeft: Radius.circular(SahneShape.lValue),
      bottomRight: Radius.circular(SahneShape.lValue),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SahneStage(
      stage: AppTheme.stage,
      child: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return ClipPath(
            key: const ValueKey('profile-name-gate-hero'),
            clipper: const ShapeBorderClipper(shape: _shape),
            child: CustomPaint(
              key: const ValueKey('profile-name-gate-hero-surface'),
              painter: SahneStagePainter(
                race: false,
                glow: t.roleGlow(SahneRole.learn),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    SahneSpace.x6,
                    compact ? SahneSpace.x4 : SahneSpace.x8,
                    SahneSpace.x6,
                    compact ? SahneSpace.x5 : SahneSpace.x8,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: AppLogo(width: compact ? 56 : 72)),
                          SizedBox(
                            height: compact ? SahneSpace.x3 : SahneSpace.x4,
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: SahneType.title.copyWith(color: t.tx),
                            ),
                          ),
                          const SizedBox(height: SahneSpace.x1),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: SahneType.body.copyWith(color: t.tx2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
