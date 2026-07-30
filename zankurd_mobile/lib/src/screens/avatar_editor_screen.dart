import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/avatar_presets.dart';
import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../data/zankurd_repository.dart';
import '../game/avatar_frames.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/avatar_identity.dart';
import '../models/mastery_level.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/player_avatar.dart';
import '../widgets/screen_identity_header.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
      final hasGoldFrame = await widget.repository.hasPurchased(
        'avatar_frame_gold',
      );
      final hasVipBadge = await widget.repository.hasPurchased(
        'profile_badge_vip',
      );

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
          titles.add(
            '${level.titleKu} · ${CategoryNames.localized(cat, true)}',
          );
        }
      }
      if (hasVipBadge && !titles.contains('VIP')) titles.add('VIP');

      final frames = unlockedFrames(
        unlockedBadgeCount: achievementStore.unlockedAchievements.length,
        masteryCorrectByCategory: masteryByCategory,
      );
      if (hasGoldFrame) frames.add(AvatarFrame.gold);

      if (!mounted) return;
      setState(() {
        _identity = identity;
        _displayName = name;
        _unlocked = frames;
        _earnedTitles = titles;
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar editor load failed');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    // Fotoğraf seçimi asenkron: hata metinleri `context` async boşluğun
    // ötesine taşınmasın diye burada, senkron olarak çözülür.
    final tooLargeMessage = context.t(K.photoTooLarge);
    final uploadFailedMessage = context.t(K.uploadFailed);
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
        _showSnack(tooLargeMessage);
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
        _showSnack(uploadFailedMessage);
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
        _showSnack(context.t(K.saveFailed));
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
      appBar: AppBar(),
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  children: [
                    // Profil ailesi — mor kimlik.
                    ScreenIdentityHeader(
                      title: context.t(K.myAvatar),
                      subtitle: context.t(K.myAvatarSub),
                      accent: AppTheme.violet,
                      icon: AppIcons.faceSmile,
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                              : const Icon(AppIcons.images),
                          label: Text(context.t(K.uploadPhoto)),
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
                            icon: const Icon(AppIcons.xmark),
                            label: Text(context.t(K.removeAction)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(context.t(K.symbol)),
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
                    _SectionTitle(context.t(K.colorWord)),
                    AppPanel(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final hex in avatarColors)
                            ClipOval(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey('avatar-color-$hex'),
                                  onTap: () => setState(
                                    () => _identity = _identity.copyWith(
                                      colorHex: hex,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
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
                                        boxShadow: _identity.colorHex == hex
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionTitle(context.t(K.frame)),
                    AppPanel(
                      child: Column(
                        children: [
                          _FrameRow(
                            key: const ValueKey('avatar-frame-none'),
                            label: context.t(K.noFrame),
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
                                AvatarFrame.bronze => context.t(K.bronze),
                                AvatarFrame.silver => context.t(K.silver),
                                AvatarFrame.gold => context.t(K.gold),
                                AvatarFrame.mamoste => 'Mamoste',
                              },
                              color: frameColor(frame),
                              locked: !_unlocked.contains(frame),
                              selected: _identity.frameId == frame.name,
                              requirement: frameRequirementLabel(frame, ku),
                              onTap: () {
                                if (!_unlocked.contains(frame)) {
                                  _showSnack(
                                    '${context.t(K.locked)} — '
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
                    _SectionTitle(context.t(K.titleWord)),
                    AppPanel(
                      child: Column(
                        children: [
                          _TitleRow(
                            key: const ValueKey('avatar-title-none'),
                            label: context.t(K.hideAction),
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
                                context.t(K.noTitlesYet),
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
                          : const Icon(AppIcons.floppyDisk),
                      label: Text(context.t(K.save)),
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
                  AppIcons.lock,
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
            ? const Icon(AppIcons.circleCheck, color: AppTheme.correct)
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
          AppIcons.medal,
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
            ? const Icon(AppIcons.circleCheck, color: AppTheme.correct)
            : null,
        onTap: onTap,
      ),
    );
  }
}
