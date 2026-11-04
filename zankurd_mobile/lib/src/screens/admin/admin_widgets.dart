import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/branded_loader.dart';
import '../../widgets/dialog_action_pair.dart';
import '../../widgets/sahne/sahne.dart';
import '../../widgets/zk_back_button.dart';

/// Yönetim ekranlarının ortak iskeleti: B iskeleti (başlık çubukta) +
/// kaydırılan sayfa. Görünüş `ImageCreditsScreen` ile aynı kalıptır.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x2,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Bir `Future`yi yükler; yüklenirken marka göstergesi, hatada yeniden dene.
///
/// [builder] üçüncü argüman olarak `reload` alır: bir işlem bitince liste
/// sunucudan yeniden okunur (yerel kopya tutulmaz — sunucu tek doğru).
class AdminLoader<T> extends StatefulWidget {
  const AdminLoader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function())
  builder;

  @override
  State<AdminLoader<T>> createState() => _AdminLoaderState<T>();
}

class _AdminLoaderState<T> extends State<AdminLoader<T>> {
  T? _data;
  Object? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loaded = true;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'admin load failed');
      if (!mounted) return;
      setState(() {
        _error = error;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: SahneSpace.x8),
        child: BrandedLoaderCenter(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SahneSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    context.t(K.adminLoadFailed),
                    style: SahneType.body.copyWith(color: t.errTx),
                  ),
                ),
              ],
            ),
            SahneButton.text(
              label: context.t(K.retry),
              arrow: false,
              onPressed: _reload,
            ),
          ],
        ),
      );
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/// Bir yönetim işlemini koşturur: başarıda "Kaydedildi", hatada "Yapılamadı"
/// bildirimi; ardından [reload]. Hata yutulmaz, rapora yazılır.
Future<void> runAdminAction(
  BuildContext context,
  Future<void> Function() action,
  Future<void> Function() reload,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final done = context.t(K.adminDone);
  final failed = context.t(K.adminFailed);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'admin action failed');
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
  await reload();
}

/// Onay penceresi. Yıkıcı olmayan işlemde de sorulur: yönetim işlemleri
/// denetim günlüğüne yazılır ve oyuncuyu etkiler.
Future<bool> adminConfirm(
  BuildContext context, {
  required String body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.t(K.adminConfirmTitle)),
      content: Text(body),
      actions: [
        DialogActionPair(
          cancel: OutlinedButton(
            key: const ValueKey('admin-confirm-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t(K.cancel)),
          ),
          confirm: FilledButton(
            key: const ValueKey('admin-confirm-ok'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel ?? context.t(K.adminConfirmApply)),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Ekranın üstündeki küçük açıklama satırı.
class AdminNote extends StatelessWidget {
  const AdminNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Text(text, style: SahneType.caption.copyWith(color: t.tx2));
  }
}

/// Boş durum metni.
class AdminEmpty extends StatelessWidget {
  const AdminEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SahneSpace.x6),
      child: Row(
        children: [
          Icon(AppIcons.circleCheck, size: 20, color: t.tx3),
          const SizedBox(width: SahneSpace.x2),
          Expanded(
            child: Text(text, style: SahneType.body.copyWith(color: t.tx2)),
          ),
        ],
      ),
    );
  }
}

/// `05.11 14:20` — dilden bağımsız kısa zaman.
String adminTime(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(at.day)}.${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
}
