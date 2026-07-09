import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/avatar_presets.dart';
import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../data/zankurd_repository.dart';
import '../game/avatar_frames.dart';
import '../l10n/lang.dart';
import '../models/avatar_identity.dart';
import '../models/mastery_level.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/player_avatar.dart';

/// Avatar/çerçeve/unvan düzenleyici. Kaydet ile repository'ye yazar ve
/// pop(true) döner; çağıran ekran görünümünü tazeler.
class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    required this.repository,
    this.imagePicker,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Testlerde sahte seçici enjekte etmek için.
  final ImagePicker? imagePicker;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  static const int _maxPhotoBytes = 2 * 1024 * 1024;

  AvatarIdentity _identity = const AvatarIdentity();
  Set<AvatarFrame> _unlocked = const {};
  List<String> _earnedTitles = const [];
  String _displayName = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final identity = await widget.repository.loadAvatarIdentity();
      final name = await widget.repository.getProfileName();
      final masteryStore = await MasteryStore.load();
      final achievementStore = await AchievementStore.load();

      final masteryByCategory = {
        for (final cat in widget.repository.categories)
          cat: masteryStore.correctCount(cat),
      };
      // Unvan adları dil ayarından bağımsız hep Kurmancî'dir (Xwendekar/
      // Pispor/Mamoste) — vitrine marka gibi yansır, çeviriye girmez.
      final titles = <String>[];
      for (final cat in widget.repository.categories) {
        final level = masteryStore.levelFor(cat);
        if (level != MasteryLevel.none) {
          titles.add('${level.titleKu} · $cat');
        }
      }

      if (!mounted) return;
      setState(() {
        _identity = identity;
        _displayName = name;
        _unlocked = unlockedFrames(
          unlockedBadgeCount: achievementStore.unlockedAchievements.length,
          masteryCorrectByCategory: masteryByCategory,
        );
        _earnedTitles = titles;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar editor load failed');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final ku = context.isKu;
    setState(() => _uploadingPhoto = true);
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        _showSnack(
          ku ? 'Wêne ji 2MB mezintir e.' : 'Fotoğraf 2MB sınırını aşıyor.',
        );
        return;
      }
      final contentType = file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final url = await widget.repository.uploadAvatarPhoto(
        Uint8List.fromList(bytes),
        contentType,
      );
      if (!mounted) return;
      setState(() => _identity = _identity.copyWith(photoUrl: url));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar photo upload failed');
      if (mounted) {
        _showSnack(
          context.isKu ? 'Barkirin bi ser neket.' : 'Yükleme başarısız oldu.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.updateAvatarIdentity(_identity);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar save failed');
      if (mounted) {
        setState(() => _saving = false);
        _showSnack(
          context.isKu ? 'Tomar nebû, dîsa biceribîne.' : 'Kaydedilemedi.',
        );
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Rûyê Min' : 'Avatarım')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGradientStart,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    Center(
                      child: PlayerAvatar(
                        key: const ValueKey('avatar-preview'),
                        radius: 52,
                        photoUrl: _identity.photoUrl,
                        iconId: _identity.iconId,
                        colorHex: _identity.colorHex,
                        frameId: _identity.frameId,
                        displayName: _displayName,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('avatar-pick-photo'),
                          onPressed: _uploadingPhoto ? null : _pickPhoto,
                          icon: _uploadingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: Text(ku ? 'Wêne bar bike' : 'Fotoğraf yükle'),
                        ),
                        if (_identity.photoUrl != null) ...[
                          const SizedBox(width: 10),
                          TextButton.icon(
                            key: const ValueKey('avatar-remove-photo'),
                            onPressed: () => setState(
                              () => _identity = _identity.copyWith(
                                clearPhoto: true,
                              ),
                            ),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(ku ? 'Rake' : 'Kaldır'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(ku ? 'Sembol' : 'Simge'),
                    AppPanel(
                      child: GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: [
                          for (final entry in avatarIcons.entries)
                            _IconCell(
                              key: ValueKey('avatar-icon-${entry.key}'),
                              icon: entry.value,
                              selected: _identity.iconId == entry.key,
                              color: colorFrom(
                                _identity.colorHex,
                                fallback: AppTheme.accent,
                              ),
                              onTap: () => setState(
                                () => _identity = _identity.copyWith(
                                  iconId: entry.key,
                                  clearPhoto: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionTitle(ku ? 'Reng' : 'Renk'),
                    AppPanel(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final hex in avatarColors)
                            GestureDetector(
                              key: ValueKey('avatar-color-$hex'),
                              onTap: () => setState(
                                () => _identity = _identity.copyWith(
                                  colorHex: hex,
                                ),
                              ),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorFrom(
                                    hex,
                                    fallback: AppTheme.accent,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _identity.colorHex == hex
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionTitle(ku ? 'Çarçove' : 'Çerçeve'),
                    AppPanel(
                      child: Column(
                        children: [
                          _FrameRow(
                            key: const ValueKey('avatar-frame-none'),
                            label: ku ? 'Bê çarçove' : 'Çerçevesiz',
                            color: AppTheme.textMuted,
                            locked: false,
                            selected: _identity.frameId == null,
                            requirement: null,
                            onTap: () => setState(
                              () => _identity = _identity.copyWith(
                                clearFrame: true,
                              ),
                            ),
                          ),
                          for (final frame in AvatarFrame.values)
                            _FrameRow(
                              key: ValueKey('avatar-frame-${frame.name}'),
                              label: switch (frame) {
                                AvatarFrame.bronze => ku ? 'Bronz' : 'Bronz',
                                AvatarFrame.silver => ku ? 'Zîv' : 'Gümüş',
                                AvatarFrame.gold => ku ? 'Zêr' : 'Altın',
                                AvatarFrame.mamoste => 'Mamoste',
                              },
                              color: frameColor(frame),
                              locked: !_unlocked.contains(frame),
                              selected: _identity.frameId == frame.name,
                              requirement: frameRequirementLabel(frame, ku),
                              onTap: () {
                                if (!_unlocked.contains(frame)) {
                                  _showSnack(
                                    '${ku ? 'Girtî' : 'Kilitli'} — '
                                    '${frameRequirementLabel(frame, ku)}',
                                  );
                                  return;
                                }
                                setState(
                                  () => _identity = _identity.copyWith(
                                    frameId: frame.name,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionTitle(ku ? 'Nav û Nîşan' : 'Unvan'),
                    AppPanel(
                      child: Column(
                        children: [
                          _TitleRow(
                            key: const ValueKey('avatar-title-none'),
                            label: ku ? 'Veşêre' : 'Gizle',
                            selected: _identity.showcaseTitle == null,
                            onTap: () => setState(
                              () => _identity = _identity.copyWith(
                                clearTitle: true,
                              ),
                            ),
                          ),
                          if (_earnedTitles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                ku
                                    ? 'Hîn nav û nîşan tune — bi lîstinê bidest bixe!'
                                    : 'Henüz unvan yok — oynayarak kazan!',
                                style: TextStyle(
                                  color: AppTheme.textMutedColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          for (final title in _earnedTitles)
                            _TitleRow(
                              key: ValueKey('avatar-title-$title'),
                              label: title,
                              selected: _identity.showcaseTitle == title,
                              onTap: () => setState(
                                () => _identity = _identity.copyWith(
                                  showcaseTitle: title,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('avatar-save'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(ku ? 'Tomar Bike' : 'Kaydet'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textPrimaryColor(context),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? color
              : AppTheme.surfaceColor(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white : AppTheme.borderColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : AppTheme.textMutedColor(context),
        ),
      ),
    );
  }
}

class _FrameRow extends StatelessWidget {
  const _FrameRow({
    required this.label,
    required this.color,
    required this.locked,
    required this.selected,
    required this.requirement,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool locked;
  final bool selected;
  final String? requirement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: locked
              ? Icon(
                  Icons.lock,
                  size: 14,
                  color: AppTheme.textMutedColor(context),
                )
              : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: locked
                ? AppTheme.textMutedColor(context)
                : AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: locked && requirement != null
            ? Text(requirement!, style: const TextStyle(fontSize: 11))
            : null,
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppTheme.correct)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          Icons.military_tech_outlined,
          color: selected ? AppTheme.gold : AppTheme.textMutedColor(context),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppTheme.correct)
            : null,
        onTap: onTap,
      ),
    );
  }
}
