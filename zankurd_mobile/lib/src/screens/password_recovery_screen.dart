import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/styled_button.dart';
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

    return Scaffold(
      backgroundColor: AppTheme.bgOf(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(width: 120)),
                  const SizedBox(height: 24),
                  Text(
                    context.t(K.newPasswordTitle),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.t(K.newPasswordBody),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                  const SizedBox(height: 28),
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
                      setState(() => _obscurePassword = !_obscurePassword);
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
                  const SizedBox(height: 20),
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
                    const SizedBox(height: 16),
                    Text(
                      // Süresi geçmiş/kullanılmış bağlantı en olası hata;
                      // sunucu metni Türkçe sabit olduğu için burada
                      // anahtar defterinden çevriliyor.
                      context.translateAuthError(error),
                      key: const ValueKey('recovery-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.readableAccent(
                          context,
                          AppTheme.wrong,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  GeometricGradientButton(
                    label: context.t(K.newPasswordSave),
                    isLoading: _saving || authProvider.isLoading,
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _saving ? null : _cancel,
                    child: Text(
                      context.t(K.recoveryCancel),
                      style: TextStyle(color: AppTheme.textSubColor(context)),
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
