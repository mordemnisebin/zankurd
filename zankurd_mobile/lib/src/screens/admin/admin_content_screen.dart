import 'package:flutter/material.dart';

import '../../utils/number_format.dart';

import '../../data/admin_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/admin.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/sahne/sahne.dart';
import '../../widgets/zk_back_button.dart';
import 'admin_widgets.dart';

/// Soru yönetimi (2.2): önerilen sorular (onayla / düzelt / reddet),
/// bildirilen sorular (düzelt / emekli et / bildirimi kapat) ve soru
/// öneren oyuncuların katkıları (ödüllendirme).
class AdminQuestionsScreen extends StatefulWidget {
  const AdminQuestionsScreen({super.key, required this.repository});

  final AdminRepository repository;

  /// Katkıcıya tek dokunuşla verilen jeton.
  static const int contributorReward = 100;

  @override
  State<AdminQuestionsScreen> createState() => _AdminQuestionsScreenState();
}

class _AdminQuestionsScreenState extends State<AdminQuestionsScreen> {
  int _tab = 0;

  AdminRepository get _repo => widget.repository;

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: context.t(K.adminQuestionsTitle),
      children: [
        SahneButton.secondary(
          key: const ValueKey('admin-new-question'),
          label: context.t(K.adminNewQuestion),
          icon: AppIcons.circlePlus,
          onPressed: () async {
            final added = await Navigator.of(context).push<bool>(
              AppRoute.to(AdminNewQuestionScreen(repository: _repo)),
            );
            if (added == true && context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.t(K.adminDone))));
            }
          },
        ),
        const SizedBox(height: SahneSpace.x4),
        SahneRail.fit(
          children: [
            SahneRailChip(
              key: const ValueKey('admin-tab-suggested'),
              label: context.t(K.adminTabSuggested),
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            SahneRailChip(
              key: const ValueKey('admin-tab-reported'),
              label: context.t(K.adminTabReported),
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
            SahneRailChip(
              key: const ValueKey('admin-tab-people'),
              label: context.t(K.adminTabPeople),
              selected: _tab == 2,
              onTap: () => setState(() => _tab = 2),
            ),
          ],
        ),
        const SizedBox(height: SahneSpace.x4),
        switch (_tab) {
          0 => _QuestionList(
            key: const ValueKey('admin-list-suggested'),
            repository: _repo,
            kind: AdminQuestionKind.suggestion,
          ),
          1 => _QuestionList(
            key: const ValueKey('admin-list-reported'),
            repository: _repo,
            kind: AdminQuestionKind.reported,
          ),
          _ => _ContributorList(
            key: const ValueKey('admin-list-people'),
            repository: _repo,
          ),
        },
      ],
    );
  }
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({
    super.key,
    required this.repository,
    required this.kind,
  });

  final AdminRepository repository;
  final AdminQuestionKind kind;

  @override
  Widget build(BuildContext context) {
    final suggestion = kind == AdminQuestionKind.suggestion;
    return AdminLoader<List<AdminQuestionItem>>(
      load: () => repository.loadQuestions(kind),
      builder: (context, items, reload) {
        if (items.isEmpty) {
          return AdminEmpty(
            context.t(
              suggestion ? K.adminEmptySuggested : K.adminEmptyReported,
            ),
          );
        }
        return Column(
          children: [
            for (final item in items) ...[
              _QuestionCard(
                item: item,
                actions: suggestion
                    ? _suggestionActions(context, item, reload)
                    : _reportedActions(context, item, reload),
              ),
              const SizedBox(height: SahneSpace.cardGap),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _suggestionActions(
    BuildContext context,
    AdminQuestionItem item,
    Future<void> Function() reload,
  ) => [
    SahneButton.secondary(
      key: ValueKey('admin-approve-${item.id}'),
      label: context.t(K.adminApprove),
      icon: AppIcons.check,
      onPressed: () => runAdminAction(
        context,
        () => repository.approveSuggestion(item.id),
        reload,
      ),
    ),
    SahneButton.secondary(
      key: ValueKey('admin-fix-${item.id}'),
      label: context.t(K.adminFix),
      icon: AppIcons.pen,
      onPressed: () async {
        final edit = await Navigator.of(context).push<AdminQuestionEdit>(
          AppRoute.to(AdminQuestionEditScreen(item: item)),
        );
        if (edit == null || !context.mounted) return;
        await runAdminAction(
          context,
          () => repository.approveSuggestion(item.id, edits: edit),
          reload,
        );
      },
    ),
    SahneButton.secondary(
      key: ValueKey('admin-reject-${item.id}'),
      label: context.t(K.adminReject),
      icon: AppIcons.xmark,
      onPressed: () async {
        final ok = await adminConfirm(
          context,
          body: context.t(K.adminConfirmReject),
          confirmLabel: context.t(K.adminReject),
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        await runAdminAction(
          context,
          () => repository.rejectSuggestion(item.id),
          reload,
        );
      },
    ),
  ];

  List<Widget> _reportedActions(
    BuildContext context,
    AdminQuestionItem item,
    Future<void> Function() reload,
  ) => [
    SahneButton.secondary(
      key: ValueKey('admin-fix-${item.id}'),
      label: context.t(K.adminFix),
      icon: AppIcons.pen,
      onPressed: () async {
        final edit = await Navigator.of(context).push<AdminQuestionEdit>(
          AppRoute.to(AdminQuestionEditScreen(item: item)),
        );
        if (edit == null || !context.mounted) return;
        await runAdminAction(
          context,
          () => repository.fixQuestion(item.id, edit),
          reload,
        );
      },
    ),
    SahneButton.secondary(
      key: ValueKey('admin-retire-${item.id}'),
      label: context.t(K.adminRetire),
      icon: AppIcons.eyeSlash,
      onPressed: () async {
        final ok = await adminConfirm(
          context,
          body: context.t(K.adminConfirmRetire),
          confirmLabel: context.t(K.adminRetire),
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        await runAdminAction(
          context,
          () => repository.retireQuestion(item.id),
          reload,
        );
      },
    ),
    SahneButton.secondary(
      key: ValueKey('admin-dismiss-${item.id}'),
      label: context.t(K.adminDismissReport),
      icon: AppIcons.circleCheck,
      onPressed: () => runAdminAction(
        context,
        () => repository.dismissQuestionReports(item.id),
        reload,
      ),
    ),
  ];
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item, required this.actions});

  final AdminQuestionItem item;
  final List<Widget> actions;

  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final suggestion = item.kind == AdminQuestionKind.suggestion;
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SahneBadge(label: item.category, tone: SahneBadgeTone.learn),
              if (suggestion && item.submitterName != null)
                Text(
                  context.t(K.adminSuggestedBy, {'name': item.submitterName!}),
                  style: SahneType.caption.copyWith(color: t.tx2),
                )
              else if (!suggestion)
                SahneBadge(
                  label: context.t(K.adminReportCount, {
                    'n': '${groupThousands(item.reportCount)}',
                  }),
                  tone: SahneBadgeTone.gold,
                ),
            ],
          ),
          const SizedBox(height: SahneSpace.x3),
          Text(item.prompt, style: SahneType.bodyStrong.copyWith(color: t.tx)),
          const SizedBox(height: SahneSpace.x2),
          for (var i = 0; i < item.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: SahneSpace.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: i == item.correctIndex
                        ? Icon(AppIcons.check, size: 16, color: t.okTx)
                        : Text(
                            _letters[i],
                            style: SahneType.caption.copyWith(color: t.tx3),
                          ),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(
                    child: Text(
                      item.options[i],
                      style:
                          (i == item.correctIndex
                                  ? SahneType.captionStrong
                                  : SahneType.caption)
                              .copyWith(
                                color: i == item.correctIndex ? t.okTx : t.tx2,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          if (!suggestion && item.reportReason != null) ...[
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.adminReportReason, {'reason': item.reportReason!}),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ],
          const SizedBox(height: SahneSpace.x3),
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            children: actions,
          ),
        ],
      ),
    );
  }
}

/// Soru düzeltme ekranı: metin, dört şık ve doğru şık. Kaydedilince
/// [AdminQuestionEdit] ile geri döner; sunucuya yazmayı çağıran yapar.
class AdminQuestionEditScreen extends StatefulWidget {
  const AdminQuestionEditScreen({super.key, required this.item});

  final AdminQuestionItem item;

  @override
  State<AdminQuestionEditScreen> createState() =>
      _AdminQuestionEditScreenState();
}

class _AdminQuestionEditScreenState extends State<AdminQuestionEditScreen> {
  late final TextEditingController _prompt = TextEditingController(
    text: widget.item.prompt,
  );
  late final List<TextEditingController> _options = [
    for (final option in widget.item.options)
      TextEditingController(text: option),
  ];
  late int _correct = widget.item.correctIndex;

  @override
  void dispose() {
    _prompt.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _prompt.text.trim().isNotEmpty &&
      _options.every((c) => c.text.trim().isNotEmpty);

  void _save() {
    if (!_valid) return;
    Navigator.pop(
      context,
      AdminQuestionEdit(
        prompt: _prompt.text.trim(),
        options: [for (final c in _options) c.text.trim()],
        correctIndex: _correct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    const letters = ['A', 'B', 'C', 'D'];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.adminFix))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x2,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          children: [
            SahneField(
              key: const ValueKey('admin-edit-prompt'),
              label: context.t(K.adminPromptLabel),
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            for (var i = 0; i < 4; i++) ...[
              const SizedBox(height: SahneSpace.x3),
              SahneField(
                key: ValueKey('admin-edit-option-$i'),
                label: context.t(K.adminOptionLabel, {'letter': letters[i]}),
                controller: _options[i],
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: SahneSpace.x4),
            Text(
              context.t(K.adminCorrectOption),
              style: SahneType.captionStrong.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x2),
            SahneRail.fit(
              children: [
                for (var i = 0; i < 4; i++)
                  SahneRailChip(
                    key: ValueKey('admin-edit-correct-$i'),
                    label: letters[i],
                    selected: _correct == i,
                    onTap: () => setState(() => _correct = i),
                  ),
              ],
            ),
            const SizedBox(height: SahneSpace.x6),
            SahneButton.primary(
              key: const ValueKey('admin-edit-save'),
              label: context.t(K.adminSaveFix),
              arrow: false,
              expand: true,
              onPressed: _valid ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorList extends StatelessWidget {
  const _ContributorList({super.key, required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return AdminLoader<List<AdminContributor>>(
      load: repository.loadContributors,
      builder: (context, people, reload) {
        if (people.isEmpty) {
          return AdminEmpty(context.t(K.adminEmptyPeople));
        }
        return Column(
          children: [
            for (final person in people) ...[
              SahneSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SahneAvatar(initial: person.name.characters.first),
                        const SizedBox(width: SahneSpace.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.name,
                                style: SahneType.bodyStrong.copyWith(
                                  color: t.tx,
                                ),
                              ),
                              Text(
                                context.t(K.adminContribSummary, {
                                  'n': '${person.suggested}',
                                  'm': '${person.approved}',
                                }),
                                style: SahneType.caption.copyWith(color: t.tx2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (person.rewardedCoins > 0) ...[
                      const SizedBox(height: SahneSpace.x2),
                      Text(
                        context.t(K.adminContribRewarded, {
                          'coins': '${groupThousands(person.rewardedCoins)}',
                        }),
                        style: SahneType.caption.copyWith(color: t.goldTx),
                      ),
                    ],
                    const SizedBox(height: SahneSpace.x3),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SahneButton.secondary(
                        key: ValueKey('admin-reward-${person.userId}'),
                        label: context.t(K.adminGiveCoins, {
                          'coins':
                              '${groupThousands(AdminQuestionsScreen.contributorReward)}',
                        }),
                        icon: AppIcons.coins,
                        onPressed: () async {
                          final ok = await adminConfirm(
                            context,
                            body: context.t(K.adminConfirmGrant, {
                              'name': person.name,
                              'coins':
                                  '${groupThousands(AdminQuestionsScreen.contributorReward)}',
                            }),
                          );
                          if (!ok || !context.mounted) return;
                          await runAdminAction(
                            context,
                            () => repository.rewardContributor(
                              person.userId,
                              coins: AdminQuestionsScreen.contributorReward,
                            ),
                            reload,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SahneSpace.cardGap),
            ],
          ],
        );
      },
    );
  }
}

/// Panelden yeni soru ekleme formu: kategori, metin, dört şık, doğru şık,
/// Kurmancî/Türkçe açıklama (en az biri). Sunucu (`admin_add_question`) yine
/// doğrular; buradaki denetim yalnız düğmeyi boşuna açmamak içindir. Soru
/// doğrudan onaylı girer (sahip kendisi yazar), bu yüzden kaydetmeden önce
/// onay sorulur.
class AdminNewQuestionScreen extends StatefulWidget {
  const AdminNewQuestionScreen({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminNewQuestionScreen> createState() => _AdminNewQuestionScreenState();
}

class _AdminNewQuestionScreenState extends State<AdminNewQuestionScreen> {
  final _prompt = TextEditingController();
  final _options = [for (var i = 0; i < 4; i++) TextEditingController()];
  final _explanationKu = TextEditingController();
  final _explanationTr = TextEditingController();
  String? _category;
  int _correct = 0;
  bool _saving = false;

  @override
  void dispose() {
    _prompt.dispose();
    for (final c in _options) {
      c.dispose();
    }
    _explanationKu.dispose();
    _explanationTr.dispose();
    super.dispose();
  }

  bool get _valid {
    final options = [for (final c in _options) c.text.trim().toLowerCase()];
    return _category != null &&
        _prompt.text.trim().isNotEmpty &&
        options.every((o) => o.isNotEmpty) &&
        options.toSet().length == 4 &&
        (_explanationKu.text.trim().isNotEmpty ||
            _explanationTr.text.trim().isNotEmpty);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    final ok = await adminConfirm(
      context,
      body: context.t(K.adminConfirmNewQuestion),
      confirmLabel: context.t(K.adminSaveNewQuestion),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final failed = context.t(K.adminFailed);
    setState(() => _saving = true);
    try {
      await widget.repository.addQuestion(
        AdminNewQuestion(
          category: _category!,
          prompt: _prompt.text.trim(),
          options: [for (final c in _options) c.text.trim()],
          correctIndex: _correct,
          explanationKu: _explanationKu.text.trim().isEmpty
              ? null
              : _explanationKu.text.trim(),
          explanationTr: _explanationTr.text.trim().isEmpty
              ? null
              : _explanationTr.text.trim(),
        ),
      );
      navigator.pop(true);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'admin add question failed');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    const letters = ['A', 'B', 'C', 'D'];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.adminNewQuestion))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x2,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          children: [
            Text(
              context.t(K.adminNewQuestionHint),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x4),
            Text(
              context.t(K.adminCategoryLabel),
              style: SahneType.captionStrong.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x2),
            AdminLoader<List<String>>(
              load: widget.repository.loadCategories,
              builder: (context, categories, _) => SahneRail.fit(
                children: [
                  for (final name in categories)
                    SahneRailChip(
                      key: ValueKey('admin-new-category-$name'),
                      label: name,
                      selected: _category == name,
                      onTap: () => setState(() => _category = name),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SahneSpace.x4),
            SahneField(
              key: const ValueKey('admin-new-prompt'),
              label: context.t(K.adminPromptLabel),
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            for (var i = 0; i < 4; i++) ...[
              const SizedBox(height: SahneSpace.x3),
              SahneField(
                key: ValueKey('admin-new-option-$i'),
                label: context.t(K.adminOptionLabel, {'letter': letters[i]}),
                controller: _options[i],
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: SahneSpace.x4),
            Text(
              context.t(K.adminCorrectOption),
              style: SahneType.captionStrong.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x2),
            SahneRail.fit(
              children: [
                for (var i = 0; i < 4; i++)
                  SahneRailChip(
                    key: ValueKey('admin-new-correct-$i'),
                    label: letters[i],
                    selected: _correct == i,
                    onTap: () => setState(() => _correct = i),
                  ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),
            SahneField(
              key: const ValueKey('admin-new-explanation-ku'),
              label: context.t(K.adminExplanationKuLabel),
              controller: _explanationKu,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SahneSpace.x3),
            SahneField(
              key: const ValueKey('admin-new-explanation-tr'),
              label: context.t(K.adminExplanationTrLabel),
              controller: _explanationTr,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SahneSpace.x6),
            SahneButton.primary(
              key: const ValueKey('admin-new-save'),
              label: context.t(K.adminSaveNewQuestion),
              arrow: false,
              expand: true,
              onPressed: _valid && !_saving ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
