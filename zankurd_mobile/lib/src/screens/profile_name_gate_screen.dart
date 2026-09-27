import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../services/display_name_policy.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_logo.dart';
import '../widgets/styled_button.dart';
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
    return Scaffold(
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
              // Hoş Geldin" başlığını ve ürünün ne sunduğunu (görev, arkadaş,
              // seri) anlatmıştı. Burada aynı karşılamayı ve aynı üç maddeyi
              // üçüncü kez göstermek bilgi vermiyor, yalnız oyalıyordu; asıl
              // iş tek bir soru ("Oyundaki adın ne olsun?") ve o soru zaten
              // aşağıdaki kartta. Hero artık yalnız küçük bir marka şeridi.
              ClipRRect(
                key: const ValueKey('profile-name-gate-hero'),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.card),
                  bottomRight: Radius.circular(AppRadius.card),
                ),
                child: Container(
                  key: const ValueKey('profile-name-gate-hero-surface'),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.identityHeaderGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: compact ? AppSpacing.md : AppSpacing.lg,
                      ),
                      child: Center(
                        child: AppLogo(
                          width: compact ? 64 : 72,
                          onBrandSurface: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.backgroundGradient(context),
                  ),
                  child: SafeArea(
                    top: false,
                    // 2026-07-23 M23 devamı: kart kalan alanda ortalanıyordu;
                    // o zaman hero ekranın üçte birini kaplıyordu.
                    //
                    // 2026-09-27: hero yalnız logo şeridine inince ortalanan
                    // kart ekranın ortasında yüzdü — üstünde ve altında
                    // ~400px boşluk kaldı, ekran yarım yüklenmiş gibi
                    // görünüyordu. Kart artık şeridin hemen altında başlar
                    // (göz logodan soruya iner) ve klavye açılınca yerinden
                    // zıplamaz.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.xl,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Container(
                            key: const ValueKey('profile-name-gate-card'),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor(context).withValues(
                                alpha: AppTheme.isLight(context) ? 0.92 : 0.55,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: AppTheme.borderColor(
                                  context,
                                ).withValues(alpha: 0.45),
                              ),
                              boxShadow: AppTheme.softShadow(context),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 22,
                                        margin: const EdgeInsets.only(
                                          right: AppSpacing.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppTheme.accent,
                                              AppTheme.primaryGradientEnd,
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          context.t(K.nameGateQuestion),
                                          style: AppTypography.heading2
                                              .copyWith(
                                                color:
                                                    AppTheme.textPrimaryColor(
                                                      context,
                                                    ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    context.t(K.nameGateHelp),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppTheme.textMutedColor(context),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  TextFormField(
                                    key: const ValueKey('player-name-field'),
                                    controller: _controller,
                                    // Hata yalnız Form.validate() ile
                                    // güncelleniyordu: geçerli bir ad yazıldıktan
                                    // sonra da kırmızı kenarlık ve "en az 2
                                    // karakter" uyarısı ekranda kalıyordu
                                    // (2026-07-22 canlı UX denetimi).
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppTheme.textPrimaryColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: context.t(K.nameGateHint),
                                      prefixIcon: Icon(
                                        AppIcons.user,
                                        color: AppTheme.textMutedColor(context),
                                      ),
                                    ),
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
                                    const SizedBox(height: AppSpacing.md),
                                    Container(
                                      key: const ValueKey(
                                        'name-gate-save-error',
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.wrong.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: AppTheme.wrong.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            AppIcons.triangleExclamation,
                                            size: 20,
                                            color: AppColors.readableAccent(
                                              context,
                                              AppTheme.wrong,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _saveError!,
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textPrimaryColor(
                                                          context,
                                                        ),
                                                    height: 1.45,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.lg),
                                  GeometricGradientButton(
                                    label: context.t(K.nameGateCta),
                                    icon: AppIcons.arrowRight,
                                    isLoading: _saving,
                                    onPressed: _saving ? null : _save,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  // 2026-07-23 UX: isim artık zorunlu değil;
                                  // kullanıcı varsayılan adla geçip sonra
                                  // profilden değiştirebilir (giriş sürtünmesi ↓).
                                  TextButton(
                                    onPressed: _saving
                                        ? null
                                        : widget.onCompleted,
                                    child: Text(
                                      context.t(K.nameGateSkip),
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppTheme.textMutedColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
