import 'package:flutter/widgets.dart';

bool get isFlutterTestEnvironment {
  // In Flutter widget tests, the binding is an instance of TestWidgetsFlutterBinding
  final bindingString = WidgetsBinding.instance.toString();
  return bindingString.contains('TestWidgetsFlutterBinding') || 
         WidgetsBinding.instance.runtimeType.toString().contains('Test');
}
