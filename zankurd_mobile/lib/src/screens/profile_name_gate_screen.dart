import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';

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

  @override
  void initState() {
    super.initState();
    final initial = _isDefaultName(widget.initialName)
        ? ''
        : widget.initialName;
    _controller = TextEditingController(text: initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final name = _controller.text.trim();
    setState(() => _saving = true);
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      widget.onCompleted();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile name gate failed');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Navê lîstikê nehat tomar kirin. Dîsa biceribîne.',
              'Oyuncu adı kaydedilemedi. Tekrar dene.',
            ),
          ),
        ),
      );
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
    final ku = context.isKu;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_esports_outlined,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        ku
                            ? 'Navê te di lîstikê de çi be?'
                            : 'Oyundaki adın ne olsun?',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 27,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ku
                            ? 'Ev nav di tabloya pêşderçûnê û jûrên serhêl de xuya dibe.'
                            : 'Bu ad liderlik tablosunda ve online odalarda görünecek.',
                        style: TextStyle(
                          color: AppTheme.textSubColor(context),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextFormField(
                        key: const ValueKey('player-name-field'),
                        controller: _controller,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        decoration: InputDecoration(
                          hintText: ku ? 'Mînak: Rojda' : 'Örn: Rojda',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.length < 2) {
                            return ku
                                ? 'Nav divê herî kêm 2 tîp be'
                                : 'Ad en az 2 karakter olmalı';
                          }
                          if (name.length > 24) {
                            return ku
                                ? 'Nav divê herî zêde 24 tîp be'
                                : 'Ad en fazla 24 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(ku ? 'Dest Pê Bike' : 'Oyuna Başla'),
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
    );
  }
}
