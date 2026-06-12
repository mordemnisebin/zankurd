import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp(AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Divê tu mercên bikaranînê qebûl bikî',
              'Kullanım şartlarını kabul etmelisin',
            ),
          ),
        ),
      );
      return;
    }

    LoadingOverlay.show(
      context,
      message: context.s('Hesab tê afirandin...', 'Hesap oluşturuluyor...'),
    );

    final success = await authProvider.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );

    if (mounted) {
      LoadingOverlay.hide(context);

      if (success) {
        if (authProvider.needsEmailConfirmation) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.s(
                  'Hesab hat afirandin! Ji bo pejirandinê e-peyama xwe kontrol bike.',
                  'Hesap oluşturuldu! Doğrulamak için e-postanı kontrol et.',
                ),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        Navigator.of(context).pop();
      } else if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.s('Tomar bibe', 'Kaydol'))),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: _AuthScrollFrame(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.s('Hesabê xwe biafirîne', 'Hesabını oluştur'),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.s(
                          'Tevlî civata ZanKurdê bibe',
                          'ZanKurd topluluğuna katıl',
                        ),
                        style: const TextStyle(color: AppTheme.textSub),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: context.s('Navê te', 'Adın'),
                          prefixIcon: const Icon(
                            Icons.person_outlined,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.s('Nav pêwîst e', 'Ad gerekli');
                          }
                          if (value.length < 2) {
                            return context.s(
                              'Nav divê herî kêm 2 tîp be',
                              'Ad en az 2 karakter olmalı',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          hintText: context.s(
                            'Şîfreyê piştrast bike',
                            'Parolayı Onayla',
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outlined,
                            color: AppTheme.textMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.s(
                              'Piştrastkirina şîfreyê pêwîst e',
                              'Parola onayı gerekli',
                            );
                          }
                          if (value != _passwordController.text) {
                            return context.s(
                              'Şîfre li hev nakin',
                              'Parolalar eşleşmiyor',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            activeColor: AppTheme.accent,
                            onChanged: (value) {
                              setState(() => _agreeToTerms = value ?? false);
                            },
                          ),
                          Expanded(
                            child: Text(
                              context.s(
                                'Min mercên bikaranînê xwend û ez qebûl dikim',
                                'Kullanım şartlarını okudum ve kabul ediyorum',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSub,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: authProvider.isLoading
                                ? null
                                : AppTheme.accentGradient,
                            color: authProvider.isLoading
                                ? AppTheme.surfaceHi
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: authProvider.isLoading
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: authProvider.isLoading
                                  ? null
                                  : () => _signUp(authProvider),
                              borderRadius: BorderRadius.circular(14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.person_add_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    context.s(
                                      'Hesab Biafirîne',
                                      'Hesap Oluştur',
                                    ),
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
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.s(
                              'Hesabê te jixwe heye? ',
                              'Zaten hesabın var mı? ',
                            ),
                            style: const TextStyle(color: AppTheme.textSub),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text(
                              context.s('Têkeve', 'Giriş Yap'),
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
