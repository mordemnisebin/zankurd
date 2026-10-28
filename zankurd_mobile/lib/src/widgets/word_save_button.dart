import 'package:flutter/material.dart';

import '../data/local_progress_scope.dart';
import '../data/word_list_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import 'sahne/sahne.dart';

/// Sözlük maddesini kişisel kelime listesine ekleyen / çıkaran yer işareti.
///
/// Sözlük kartında ve kelime balonunda aynı düğmedir; durum
/// [WordListStore]dan gelir, bu yüzden biri değişince ötekisi de güncellenir.
/// Seçili durum Sahne'nin Öğren yeşili aç/kapa düğmesidir (Y6, 2026-10-29);
/// ekran okuyucu "Listeme ekle" / "Listemden çıkar" der ve seçili durumu
/// bildirir.
class WordSaveButton extends StatefulWidget {
  const WordSaveButton({required this.entryId, this.store, super.key});

  /// [LearnerLexiconEntry.id].
  final String entryId;

  /// Testlerde verilir; yoksa kullanıcının paylaşılan listesi.
  final WordListStore? store;

  @override
  State<WordSaveButton> createState() => _WordSaveButtonState();
}

class _WordSaveButtonState extends State<WordSaveButton> {
  WordListStore? _store;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  /// Düğme ilk kurulduğundaki mağaza kullanıcıya bağlıdır; hesap değişince
  /// eski kullanıcının listesine bağlı KALMASIN diye her çizimde kapsam
  /// anahtarı denetlenir ve değiştiyse mağaza yeniden yüklenir.
  bool _staleScope() =>
      widget.store == null &&
      _store != null &&
      _store!.physicalKey !=
          LocalProgressScope.physical(WordListStore.logicalKey);

  Future<void> _attach() async {
    try {
      final store = widget.store ?? await WordListStore.load();
      if (!mounted) return;
      _store?.removeListener(_changed);
      store.addListener(_changed);
      setState(() => _store = store);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_save_button');
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_staleScope()) {
      // Eski kullanıcının durumu bir kare bile gösterilmesin.
      _store?.removeListener(_changed);
      _store = null;
      _attach();
    }
    final store = _store;
    final saved = store?.contains(widget.entryId) ?? false;
    return SahneIconButton(
      key: ValueKey('word-save-${widget.entryId}'),
      icon: AppIcons.bookmark,
      selected: saved,
      // Y6: kaydedilince Öğren yeşili (altın = ödül); kayıtsız nötr çerçeve.
      selectedLearn: true,
      semanticLabel: context.t(saved ? K.wordsRemove : K.wordsAdd),
      onPressed: store == null
          ? null
          : () async {
              await store.toggle(widget.entryId);
            },
    );
  }
}
