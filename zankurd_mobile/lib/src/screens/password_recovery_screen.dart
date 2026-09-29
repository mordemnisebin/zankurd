import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/styled_input.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Kurtarma bağlantısıyla açılmış oturumda yeni parolayı alır.
///
/// `resetPasswordForEmail` yalnız bir bağlantı gönderiyordu; bağlantıya
/// dokunulduğunda Supabase normal bir oturum açıyor ve uygulama
/// kullanıcıyı doğrudan Home'a bırakıyordu. Parola hiç değişmediği için
/// "parolamı unuttum" hiçbir şeyi kurtarmıyor, yalnız bir kerelik giriş
/// yapıyordu (2026-08-06 denetimi).
///
/// Ekran bilerek bir ROTA DEĞİL, `AppShell`in build kapısıdır: itilmiş
/// bir rota olsaydı geri tuşu ya da web'de tarayıcı geri düğmesi
/// kurtarmayı sessizce atlayıp aynı duruma düşürürdü.
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _passwordFieldKey = GlobalKey<StyledInputFieldState>();
  final _confirmFieldKey = GlobalKey<StyledInputFieldState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final passwordOk = _passwordFieldKey.currentState?.validate() ?? false;
    final confirmOk = _confirmFieldKey.currentState?.validate() ?? false;
    if (!passwordOk || !confirmOk) return;

    setState(() => _saving = true);
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.t(K.newPasswordSaved);

    final ok = await authProvider.completePasswordRecovery(
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      // Bayrak düştüğü için `AppShell` bu kareden sonra normal akışa
      // geçer; ekranı elle kapatmak gerekmez.
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    }
  }

  Future<void> _cancel() async {
    // Vazgeçmek çıkış yapmaktır: parolası hâlâ eski olan bir oturumu
    // Home'a bırakmak, düzeltilmek istenen durumun aynısı olurdu.
    await context.read<AuthProvider>().cancelPasswordRecovery();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final error = authProvider.errorMessage;
    final t = SahneTokens.of(context);

    // 2026-09-29 Şahnê: giriş ekranıyla aynı marka anı — gece sahne
    // kartında logo işareti plakası, 28'lik başlık ve açıklama; altında
    // tek yüzey kartında iki parola alanı ve ekranın tek birincil eylemi.
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.page,
              vertical: SahneSpace.x6,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SahneStageCard(
                    padding: const EdgeInsets.fromLTRB(
                      SahneSpace.x4,
                      SahneSpace.x8,
                      SahneSpace.x4,
                      SahneSpace.x6,
                    ),
                    child: Builder(
                      builder: (context) {
                        final st = SahneTokens.of(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: AppLogo(width: 72, onBrandSurface: true),
                            ),
                            const SizedBox(height: SahneSpace.x4),
                            Semantics(
                              header: true,
                              child: Text(
                                context.t(K.newPasswordTitle),
                                textAlign: TextAlign.center,
                                style: SahneType.title.copyWith(color: st.tx),
                              ),
                            ),
                            const SizedBox(height: SahneSpace.x2),
                            Text(
                              context.t(K.newPasswordBody),
                              textAlign: TextAlign.center,
                              style: SahneType.body.copyWith(color: st.tx2),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  SahneSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StyledInputField(
                          key: _passwordFieldKey,
                          label: context.t(K.newPasswordLabel),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          prefixIcon: AppIcons.lock,
                          suffixIcon: _obscurePassword
                              ? AppIcons.eyeSlash
                              : AppIcons.eye,
                          suffixSemanticLabel: context.t(
                            _obscurePassword ? K.showPassword : K.hidePassword,
                          ),
                          onSuffixIconPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          hintText: context.t(K.passwordHintMin6),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.t(K.passwordRequired);
                            }
                            if (value.length < 6) {
                              return context.t(K.passwordMin6);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: SahneSpace.x4),
                        StyledInputField(
                          key: _confirmFieldKey,
                          label: context.t(K.confirmPassword),
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          prefixIcon: AppIcons.lock,
                          suffixIcon: _obscureConfirm
                              ? AppIcons.eyeSlash
                              : AppIcons.eye,
                          suffixSemanticLabel: context.t(
                            _obscureConfirm ? K.showPassword : K.hidePassword,
                          ),
                          onSuffixIconPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.t(K.confirmPasswordRequired);
                            }
                            if (value != _passwordController.text) {
                              return context.t(K.passwordsMismatch);
                            }
                            return null;
                          },
                        ),
                        if (error != null) ...[
                          const SizedBox(height: SahneSpace.x4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  AppIcons.triangleExclamation,
                                  size: 16,
                                  color: t.errTx,
                                ),
                              ),
                              const SizedBox(width: SahneSpace.x2),
                              Expanded(
                                child: Text(
                                  // Süresi geçmiş/kullanılmış bağlantı en
                                  // olası hata; sunucu metni Türkçe sabit
                                  // olduğu için burada anahtar defterinden
                                  // çevriliyor.
                                  context.translateAuthError(error),
                                  key: const ValueKey('recovery-error'),
                                  style: SahneType.captionStrong.copyWith(
                                    color: t.errTx,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: SahneSpace.x6),
                        SahneButton.primary(
                          label: context.t(K.newPasswordSave),
                          expand: true,
                          // Yükleme sürerken pasif (eski düğmenin dönen göstergesi yerine
                          // Şahnê'nin pasif hâli).
                          onPressed: _saving || authProvider.isLoading
                              ? null
                              : _submit,
                        ),
                        const SizedBox(height: SahneSpace.x2),
                        Center(
                          child: _TextAction(
                            label: context.t(K.recoveryCancel),
                            arrow: false,
                            onPressed: _saving ? null : _cancel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Metin bağlantısı ([SahneButton.text]) — 48'lik dokunma kutusunda.
///
/// Bileşen görselde 44'tür; uygulamanın erişilebilirlik kılavuzu testi
/// (Android) 48'in altını reddeder. [ZkBackButton] gibi: ekran okuyucu tek
/// bir 48'lik düğme görür, görsel boyut değişmez.
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onPressed,
    this.arrow = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Chevron (›) yalnız bir yere götüren bağlantıda; vazgeç / geç gibi
  /// kaçış bağlantılarında yok.
  final bool arrow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: SahneButton.text(
              label: label,
              arrow: arrow,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}
