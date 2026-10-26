import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../utils/app_route.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/story_catalog.dart';
import '../widgets/zk_back_button.dart';
import 'story_screen.dart';

/// Bütün günlük hikâyeler (2026-10-27). Öğrenme sayfası en çok dördünü
/// gösterir; buradan hepsi, kendi yerel ilerlemeleriyle açılır.
class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.storyCatalogTitle))),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('stories-screen'),
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x2,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          children: [
            StoryCatalog(
              isKu: context.isKu,
              showHeader: false,
              onOpen: (story, guide) => Navigator.of(context).push(
                AppRoute(
                  page: StoryScreen(story: story, guide: guide),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
