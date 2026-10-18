import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';
import '../models/room.dart';
import '../models/room_invite.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../utils/player_identity.dart';
import '../widgets/app_panel.dart';
import '../widgets/sahne/sahne.dart';

/// Oda lobisinden kabul edilmiş arkadaşları, kod girmeden davet eden sayfa.
///
/// Çoklu seçim; 8'den fazla arkadaşta arama kutusu çıkar. Odada olan ya da
/// zaten davet edilmiş arkadaş seçilemez ve nedeni satırda yazılır. Gönderim
/// başarılı olursa sayfa davet edilen kişi sayısıyla kapanır (çağıran
/// bildirimi gösterir); hata olursa sayfa açık kalır, sebep sayfada yazılır.
///
/// Dönüş: davet edilen kişi sayısı; vazgeçilirse `null`.
Future<int?> showRoomInviteFriendsSheet(
  BuildContext context,
  ZanKurdRepository repository,
  GameRoom room,
) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => RoomInviteFriendsSheet(repository: repository, room: room),
);

/// Arama kutusunun görünmeye başladığı arkadaş sayısı eşiği.
const roomInviteSearchThreshold = 8;

class RoomInviteFriendsSheet extends StatefulWidget {
  const RoomInviteFriendsSheet({
    required this.repository,
    required this.room,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;

  @override
  State<RoomInviteFriendsSheet> createState() => _RoomInviteFriendsSheetState();
}

class _RoomInviteFriendsSheetState extends State<RoomInviteFriendsSheet> {
  List<Friend>? _friends;
  Set<String> _invited = const {};
  bool _failed = false;
  bool _sending = false;
  String? _error;
  String _query = '';
  final Set<String> _selected = <String>{};

  Set<String> get _inRoom => {
    for (final p in widget.room.players)
      if (p.id != null && !p.left) p.id!,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final results = await Future.wait<Object>([
        widget.repository.loadFriends(),
        widget.repository.loadRoomInvitedIds(widget.room),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<Friend>;
        _invited = results[1] as Set<String>;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite sheet load');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final count = await widget.repository.inviteFriendsToRoom(
        widget.room,
        _selected.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(count);
    } on RoomInviteException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = context.t(switch (error.reason) {
          RoomInviteFailure.tooMany => K.roomInviteTooMany,
          RoomInviteFailure.full => K.roomFull,
          RoomInviteFailure.expired => K.roomNotFound,
          RoomInviteFailure.unknown => K.roomInviteFailed,
        });
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite send');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = context.t(K.roomInviteFailed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: SahneSpace.page,
        right: SahneSpace.page,
        bottom: SahneSpace.page + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AppPanel(
        child: Column(
          key: const ValueKey('room-invite-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.t(K.roomInviteSheetTitle),
                style: SahneType.headline.copyWith(color: t.tx),
              ),
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(
              context.t(K.roomInviteSheetSub),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x4),
            _body(context, t),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SahneTokens t) {
    if (_failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.challengeFriendsFailed),
            key: const ValueKey('room-invite-failed'),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
          SahneButton.secondary(
            label: context.t(K.retry),
            icon: AppIcons.arrowsRotate,
            expand: true,
            onPressed: () => unawaited(_load()),
          ),
        ],
      );
    }
    final friends = _friends;
    if (friends == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: SahneSpace.x4),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (friends.isEmpty) {
      return Text(
        context.t(K.roomInviteNoFriends),
        key: const ValueKey('room-invite-empty'),
        style: SahneType.body.copyWith(color: t.tx2),
      );
    }

    final inRoom = _inRoom;
    final needle = _query.trim().toLowerCase();
    final visible = [
      for (final f in friends)
        if (needle.isEmpty || f.friendName.toLowerCase().contains(needle)) f,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (friends.length > roomInviteSearchThreshold) ...[
          SahneField.search(
            key: const ValueKey('room-invite-search'),
            hintText: context.t(K.roomInviteSearchHint),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: SahneSpace.x3),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            child: SahneListGroup(
              children: [
                for (final friend in visible) _row(context, t, friend, inRoom),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: SahneSpace.x3),
          Text(
            _error!,
            key: const ValueKey('room-invite-error'),
            style: SahneType.caption.copyWith(color: t.errTx),
          ),
        ],
        const SizedBox(height: SahneSpace.x4),
        SahneButton.primary(
          key: const ValueKey('room-invite-send'),
          label: context.t(K.roomInviteSend, {'n': '${_selected.length}'}),
          icon: AppIcons.userPlus,
          arrow: false,
          expand: true,
          loading: _sending,
          onPressed: _selected.isEmpty || _sending ? null : _send,
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    SahneTokens t,
    Friend friend,
    Set<String> inRoom,
  ) {
    final id = friend.friendId;
    final here = inRoom.contains(id);
    final invited = !here && _invited.contains(id);
    final selected = _selected.contains(id);
    final name = context.playerDisplayName(friend.friendName);
    final note = here
        ? context.t(K.roomInviteAlreadyIn)
        : invited
        ? context.t(K.roomInviteAlreadyInvited)
        : null;
    final disabled = here;
    return SahneListRow.icon(
      key: ValueKey('room-invite-friend-$id'),
      icon: AppIcons.peopleGroup,
      role: SahneRole.race,
      title: name,
      subtitle: note,
      enabled: !disabled,
      trailing: selected
          ? Icon(AppIcons.circleCheck, color: t.roleText(SahneRole.race))
          : null,
      semanticLabel: note == null ? name : '$name. $note',
      onTap: disabled || _sending
          ? null
          : () => setState(() {
              if (!_selected.remove(id)) _selected.add(id);
            }),
    );
  }
}
