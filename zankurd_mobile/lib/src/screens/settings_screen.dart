import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.repository, super.key});

  final ZanKurdRepository repository;
  static const appVersion = '1.3.0+4';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Mîheng' : 'Ayarlar')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              // Language
              AppPanel(
                child: Row(
                  children: [
                    const Icon(Icons.language, color: AppTheme.violet),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ku ? 'Zimanê sepanê' : 'Uygulama dili',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _LangSwitch(),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // How to play
              _ExpandableSection(
                icon: Icons.help_outline_rounded,
                iconColor: AppTheme.correct,
                title: ku ? 'Çawa tê lîstin?' : 'Nasıl oynanır?',
                body: ku
                    ? '• Pêşbirka Bilez: tavilê 10 pirsan bibersivîne.\n'
                          '• Pêşbirka Rojê: her roj ji bo hemû lîstikvanan heman 10 pirs.\n'
                          '• Jûr Ava Bike: kodê bide hevalên xwe û bi hev re bilîzin.\n'
                          '• Kategorî û Ast: ji 6 kategoriyan û 5 astan hilbijêre.\n'
                          '• Joker 50/50: du bersivên şaş radike.\n'
                          '• Bersiva rast pûan û coin dide; rêza rast bonus zêde dike.'
                    : '• Hızlı Yarış: hemen 10 soru cevapla.\n'
                          '• Günün Yarışması: her gün tüm oyunculara aynı 10 soru.\n'
                          '• Oda Kur: kodu arkadaşlarına ver, birlikte yarışın.\n'
                          '• Kategori ve Seviye: 6 kategori, 5 seviye arasından seç.\n'
                          '• 50/50 jokeri iki yanlış cevabı eler.\n'
                          '• Doğru cevap puan ve coin kazandırır; seri bonusu artırır.',
              ),
              const SizedBox(height: 14),

              // Privacy
              _ExpandableSection(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppTheme.gold,
                title: ku ? 'Nepenî' : 'Gizlilik',
                body: ku
                    ? 'ZanKurd ev dane tomar dike: navê lîstikvan, '
                          'navnîşana e-peyamê (heke tomar bibî), pûan û statîstîkên '
                          'lîstikê, hejmara coinan û pirsên tomarkirî. Di xetayan de '
                          'tomarên teknîkî yên anonîm tên berhevkirin.\n\n'
                          'Daneyên te nayên firotin û ji bo reklamê bi kesên sêyemîn '
                          're nayên parvekirin. Navê te tenê di tabloya pêşderçûnê de '
                          'xuya dibe.\n\n'
                          'Ji bo jêbirina hesabê û hemû daneyan: '
                          'nisebinbawer47@gmail.com'
                    : 'ZanKurd şu verileri saklar: oyuncu adı, e-posta adresi '
                          '(kayıt olursan), oyun puanları ve istatistikleri, coin '
                          'bakiyesi ve kaydedilen sorular. Hatalarda anonim teknik '
                          'çökme kayıtları toplanır.\n\n'
                          'Verilerin satılmaz ve üçüncü taraflarla pazarlama amaçlı '
                          'paylaşılmaz. Adın yalnızca liderlik tablosunda görünür.\n\n'
                          'Hesabını ve tüm verilerini kalıcı sildirmek için: '
                          'nisebinbawer47@gmail.com',
              ),
              const SizedBox(height: 14),

              AppPanel(
                color: AppTheme.surface.withValues(alpha: 0.92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.wrong,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          ku ? 'Karên Hesabê' : 'Hesap İşlemleri',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ku
                          ? 'Ev kar nayên vegerandin.'
                          : 'Bu alandaki işlemler geri alınamaz.',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _deleting ? null : _confirmDeleteAccount,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.wrong.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.wrong.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            _deleting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.wrong,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_forever_outlined,
                                    color: AppTheme.wrong,
                                    size: 22,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ku ? 'Hesabê Min Jê Bibe' : 'Hesabımı Sil',
                                    style: const TextStyle(
                                      color: AppTheme.wrong,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ku
                                        ? 'Profîl, coin û pirsên tomarkirî tên jêbirin.'
                                        : 'Profil, coin ve kaydedilen soru verilerin silinir.',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // About
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'ZK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ZanKurd',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '${ku ? 'Guherto' : 'Sürüm'} ${SettingsScreen.appVersion}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ku
                          ? 'Sepana pêşbirkê ya Kurmancî — ziman, çand, dîrok, '
                                'edebiyat, cografya û muzîka Kurdî hîn bibe û pêşbirkê bike.'
                          : 'Kurmancî bilgi yarışması uygulaması — Kürt dili, kültürü, '
                                'tarihi, edebiyatı, coğrafyası ve müziğini öğren, yarış.',
                      style: const TextStyle(
                        color: AppTheme.textSub,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ku = context.isKu;
    final continueDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Text(
          ku ? 'Hesabê bi dawî jê bibî?' : 'Hesabı kalıcı olarak sil?',
        ),
        content: Text(
          ku
              ? 'Ev çalakî venagere. Profîl, coin, pirsên tomarkirî û daneyên kesane yên hesabê te tên jêbirin.'
              : 'Bu işlem geri alınamaz. Profil, coin, kaydedilen sorular ve hesabına bağlı kişisel veriler silinir.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ku ? 'Betal' : 'Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ku ? 'Berdewam Bike' : 'Devam Et'),
          ),
        ],
      ),
    );

    if (continueDelete != true || !mounted) return;
    final confirmed = await _showFinalDeleteConfirmation();
    if (confirmed != true || !mounted) return;
    await _deleteAccount();
  }

  Future<bool?> _showFinalDeleteConfirmation() {
    final controller = TextEditingController();
    final ku = context.isKu;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var canDelete = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: Text(ku ? 'Erêkirina dawî' : 'Son onay'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ku
                        ? 'Ji bo jêbirina hesabê "SIL" binivîse.'
                        : 'Hesabını silmek için "SIL" yaz.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('delete-confirm-field'),
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'SIL'),
                    onChanged: (value) {
                      setDialogState(() => canDelete = value.trim() == 'SIL');
                    },
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(ku ? 'Betal' : 'Vazgeç'),
                ),
                FilledButton(
                  onPressed: canDelete
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: Text(ku ? 'Bi Dawî Jê Bibe' : 'Kalıcı Olarak Sil'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      await widget.repository.deleteMyAccount();
      if (!mounted) return;
      await context.read<AuthProvider>().signOut();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'deleteAccount failed');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Hesab nehat jêbirin. Ji kerema xwe dîsa biceribîne.',
              'Hesap silinemedi. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    }
  }
}

class _LangSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHi,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangChip(
            label: 'KU',
            active: isKu,
            onTap: () => context.langProvider.setLang('ku'),
          ),
          _LangChip(
            label: 'TR',
            active: !isKu,
            onTap: () => context.langProvider.setLang('tr'),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            leading: Icon(icon, color: iconColor),
            iconColor: AppTheme.textSub,
            collapsedIconColor: AppTheme.textMuted,
            title: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  body,
                  style: const TextStyle(color: AppTheme.textSub, height: 1.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
