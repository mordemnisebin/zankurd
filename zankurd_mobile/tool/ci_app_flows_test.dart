// Aynı cihazsız akışlar; integration_test yolunun cihaz keşfini tetiklemez.
// Asıl dosya TestWidgetsFlutterBinding kullanır; test atlanmaz veya kopyalanmaz.
import '../integration_test/app_flows_test.dart' as flows;

void main() => flows.main();
