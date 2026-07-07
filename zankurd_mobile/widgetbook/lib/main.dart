import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_card.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_button.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_section_header.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_metric_tile.dart';
import 'package:zankurd_mobile/core/widgets/zankurd_quiz_option.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        // ────────── Cards ──────────
        WidgetbookCategory(
          name: '🃏 Cards',
          children: [
            WidgetbookComponent(
              name: 'ZankurdCard',
              useCases: [
                WidgetbookUseCase(
                  name: 'Surface (default)',
                  builder: (context) => Center(
                    child: SizedBox(
                      width: 320,
                      child: ZankurdCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Surface Card',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text('Theme-aware surface, border, and shadow.',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Premium (gradient + glow)',
                  builder: (context) => Center(
                    child: SizedBox(
                      width: 320,
                      child: ZankurdCard(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFD81B60), Color(0xFFF4A261)],
                        ),
                        glowColor: const Color(0xFFD81B60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 28),
                            const SizedBox(height: 8),
                            const Text('Premium Card',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('Gradient background with glow shadow.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ZankurdSectionHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: ZankurdSectionHeader(title: 'Section Title'),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'With Subtitle + Action',
                  builder: (context) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: ZankurdSectionHeader(
                      title: 'Progress',
                      subtitle: 'Your weekly stats',
                      actionLabel: 'See All',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // ────────── Buttons ──────────
        WidgetbookCategory(
          name: '🔘 Buttons',
          children: [
            WidgetbookComponent(
              name: 'ZankurdButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Filled',
                  builder: (context) => const Center(
                    child: ZankurdButton(label: 'Destpê Bike', icon: Icons.play_arrow),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Outlined',
                  builder: (context) => const Center(
                    child: ZankurdButton(
                      label: 'Settings',
                      icon: Icons.settings_outlined,
                      variant: ZankurdButtonVariant.outlined,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Ghost',
                  builder: (context) => const Center(
                    child: ZankurdButton(
                      label: 'Cancel',
                      variant: ZankurdButtonVariant.ghost,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Expanded',
                  builder: (context) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ZankurdButton(
                      label: 'Full Width',
                      variant: ZankurdButtonVariant.filled,
                      expanded: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // ────────── Metrics ──────────
        WidgetbookCategory(
          name: '📊 Metrics',
          children: [
            WidgetbookComponent(
              name: 'ZankurdMetricTile',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default (Accent)',
                  builder: (context) => const Center(
                    child: ZankurdMetricTile(
                      icon: Icons.pie_chart,
                      value: '85%',
                      label: 'Accuracy',
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Gold (Reward)',
                  builder: (context) => const Center(
                    child: ZankurdMetricTile(
                      icon: Icons.stars_rounded,
                      value: '1,250',
                      label: 'Total Points',
                      color: Color(0xFFE9C46A),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Correct Green',
                  builder: (context) => const Center(
                    child: ZankurdMetricTile(
                      icon: Icons.check_circle,
                      value: '12/15',
                      label: 'Correct',
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // ────────── Quiz Option ──────────
        WidgetbookCategory(
          name: '❓ Quiz',
          children: [
            WidgetbookComponent(
              name: 'ZankurdQuizOption',
              useCases: [
                WidgetbookUseCase(
                  name: 'Neutral',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ZankurdQuizOption(
                      label: 'Kurmancî zimanekî Îranî ye.',
                      optionLetter: 'A',
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Selected',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ZankurdQuizOption(
                      label: 'Kurmancî li Bakurê Kurdistanê tê axaftin.',
                      optionLetter: 'B',
                      state: QuizOptionState.selected,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Correct',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ZankurdQuizOption(
                      label: 'Ehmedê Xanî helbestvanekî Kurd e.',
                      optionLetter: 'C',
                      state: QuizOptionState.correct,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Wrong',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ZankurdQuizOption(
                      label: 'Zimanê Kurdî tenê li Iraqê tê bikaranîn.',
                      optionLetter: 'D',
                      state: QuizOptionState.wrong,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
