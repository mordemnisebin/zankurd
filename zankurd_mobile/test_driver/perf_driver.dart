// Performans sürücüsü: integration_test timeline'ını özet + JSON olarak
// output/performance/ altına yazar.
//
// Kullanım (gerçek cihaz, profile mode):
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/performance_test.dart \
//     --profile -d <device_id>

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data != null && data.containsKey('scroll_timeline')) {
        final timeline = Timeline.fromJson(
          data['scroll_timeline'] as Map<String, dynamic>,
        );
        final summary = TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(
          'scroll_timeline',
          destinationDirectory: 'output/performance',
          pretty: true,
          includeSummary: true,
        );
      }
    },
  );
}
