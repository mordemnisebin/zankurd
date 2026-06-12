import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn(AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    LoadingOverlay.show(
      context,
      message: context.s('Tê têketin...', 'Giriş yapılıyor...'),
    );

    final success = await authProvider.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
      }
    }
  }

  Future<void> _signInWithGoogle(AuthProvider authProvider) async {
    LoadingOverlay.show(
      context,
      message: context.s(
        'Bi Google ve tê girêdan...',
        'Google ile bağlanılıyor...',
      ),
    );

    final success = await authProvider.signInWithGoogle();

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
      }
    }
  }

  Future<void> _signInAsGuest(AuthProvider authProvider) async {
    LoadingOverlay.show(
      context,
      message: context.s(
        'Wek mêvan tê têketin...',
        'Misafir olarak giriliyor...',
      ),
    );

    final success = await authProvider.signInAsGuest();

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
      }
    }
  }

  Future<void> _resetPassword(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Pêşî navnîşana e-peyamê ya derbasdar binivîse.',
              'Önce geçerli e-posta adresini yaz.',
            ),
          ),
        ),
      );
      return;
    }

    LoadingOverlay.show(
      context,
      message: context.s(
        'E-peyama vesazkirinê tê şandin...',
        'Sıfırlama e-postası gönderiliyor...',
      ),
    );

    final success = await authProvider.resetPassword(email);

    if (!mounted) return;
    LoadingOverlay.hide(context);

    final message = success
        ? context.s(
            'Girêdana vesazkirina şîfreyê ji e-peyama te re hat şandin.',
            'Parola sıfırlama bağlantısı e-postana gönderildi.',
          )
        : authProvider.errorMessage ??
              context.s(
                'Vesazkirina şîfreyê bi ser neket.',
                'Parola sıfırlama başarısız.',
              );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: _AuthScrollFrame(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.45),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'ZK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _LanguageChoiceCard(),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        context.s(
                          'Bi xêr hatî ZanKurdê',
                          'ZanKurd\'a Hoş Geldin',
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        context.s(
                          'Kurmancî hîn bibe û pêşbirkê bike',
                          'Kurmancî öğren ve yarışmaya katıl',
                        ),
                        style: const TextStyle(color: AppTheme.textSub),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: context.s(
                                'Navnîşana e-peyamê',
                                'E-posta adresi',
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            style: const TextStyle(color: AppTheme.textPrimary),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return context.s(
                                  'E-peyam pêwîst e',
                                  'E-posta gerekli',
                                );
                              }
                              if (!value.contains('@')) {
                                return context.s(
                                  'E-peyameke derbasdar binivîse',
                                  'Geçerli bir e-posta gir',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              hintText: context.s('Şîfre', 'Parola'),
                              prefixIcon: const Icon(
                                Icons.lock_outlined,
                                color: AppTheme.textMuted,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.textMuted,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                            style: const TextStyle(color: AppTheme.textPrimary),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return context.s(
                                  'Şîfre pêwîst e',
                                  'Parola gerekli',
                                );
                              }
                              if (value.length < 6) {
                                return context.s(
                                  'Şîfre divê herî kêm 6 tîp be',
                                  'Parola en az 6 karakter olmalı',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () => _resetPassword(authProvider),
                              child: Text(
                                context.s(
                                  'Şîfre ji bîr kir?',
                                  'Parolayı unuttun mu?',
                                ),
                                style: const TextStyle(color: AppTheme.textSub),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _GradientButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => _signIn(authProvider),
                            icon: Icons.login,
                            label: context.s('Têkeve', 'Giriş Yap'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            context.s('AN JÎ', 'VEYA'),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _signInWithGoogle(authProvider),
                        icon: const Text(
                          'G',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppTheme.gold,
                          ),
                        ),
                        label: Text(
                          context.s('Bi Google têkeve', 'Google ile giriş yap'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => _signInAsGuest(authProvider),
                        icon: const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: AppTheme.textSub,
                        ),
                        label: Text(
                          context.s(
                            'Wek mêvan bidomîne',
                            'Misafir olarak devam et',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.s('Hesabê te tune? ', 'Hesabın yok mu? '),
                          style: const TextStyle(color: AppTheme.textSub),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: Text(
                            context.s('Tomar bibe', 'Kaydol'),
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthScrollFrame extends StatelessWidget {
  const _AuthScrollFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 380 ? 16.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _LanguageChoiceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language, color: AppTheme.violet, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isKu ? 'Zimanê xwe hilbijêre' : 'Dilini seç',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isKu
                ? 'Dikarî paşê ji mîhengê biguherînî.'
                : 'Daha sonra ayarlardan değiştirebilirsin.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LangChip(
                  shortLabel: 'KU',
                  label: 'Kurmancî',
                  active: isKu,
                  onTap: () => context.langProvider.setLang('ku'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LangChip(
                  shortLabel: 'TR',
                  label: 'Türkçe',
                  active: !isKu,
                  onTap: () => context.langProvider.setLang('tr'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.shortLabel,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String shortLabel;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.surfaceHi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              shortLabel,
              style: TextStyle(
                color: active ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : AppTheme.textSub,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : AppTheme.accentGradient,
          color: onPressed == null ? AppTheme.surfaceHi : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
