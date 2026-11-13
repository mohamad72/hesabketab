import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/controller.dart';
import 'data/demo.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final demo =
      const bool.fromEnvironment('DEMO') ||
      Uri.base.queryParameters['demo'] == 'true';
  final controller = demo ? demoController() : FinanceController();
  String? error;
  if (!demo) {
    try {
      await controller.load();
    } catch (e) {
      error = e.toString();
    }
  }
  runApp(HesabApp(controller: controller, demo: demo, startupError: error));
}

class HesabApp extends StatelessWidget {
  final FinanceController controller;
  final bool demo;
  final String? startupError;
  const HesabApp({
    super.key,
    required this.controller,
    this.demo = false,
    this.startupError,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'حساب حضرات',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: startupError != null
        ? Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(startupError!),
              ),
            ),
          )
        : AppShell(controller: controller, demo: demo),
  );
}
