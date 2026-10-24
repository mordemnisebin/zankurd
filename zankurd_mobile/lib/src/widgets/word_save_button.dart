import 'package:flutter/material.dart';

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
/// Seçili durum Sahne'nin altın tonlu aç/kapa düğmesidir (yeni renk yok);
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

  Future<void> _attach() async {
    try {
      final store = widget.store ?? await WordListStore.load();
      if (!mounted) return;
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
    final store = _store;
    final saved = store?.contains(widget.entryId) ?? false;
    return SahneIconButton(
      key: ValueKey('word-save-${widget.entryId}'),
      icon: AppIcons.bookmark,
      selected: saved,
      semanticLabel: context.t(saved ? K.wordsRemove : K.wordsAdd),
      onPressed: store == null
          ? null
          : () async {
              await store.toggle(widget.entryId);
            },
    );
  }
}
