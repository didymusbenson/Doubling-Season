import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'state/table_controller.dart';
import 'services/table_support_service.dart';
import 'ui/table_screen.dart';
import 'ui/table_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TriplingTableApp());
}

class TriplingTableApp extends StatefulWidget {
  const TriplingTableApp({super.key});
  @override
  State<TriplingTableApp> createState() => _TriplingTableAppState();
}

class _TriplingTableAppState extends State<TriplingTableApp>
    with WidgetsBindingObserver {
  final controller = TableController();
  bool ready = false;
  String? startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      startupError = null;
    });
    try {
      await controller.initialize();
      if (!controller.ready) {
        throw StateError(controller.error ?? 'Could not open the saved game.');
      }
      if (!mounted) return;
      setState(() {
        ready = true;
      });
      unawaited(WakelockPlus.enable().catchError((Object _) {}));
      unawaited(TableSupportService.instance.initialize());
    } catch (e) {
      if (mounted) {
        setState(() {
          startupError = e.toString();
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      controller.settleHistoryGroup();
      unawaited(controller.flush());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'Tripling Table',
      // Tooltips are never part of table interaction, including overlay routes.
      // Controls supply their own names, values and actions to accessibility.
      builder: (context, child) => TooltipVisibility(
        visible: false,
        child: child ?? const SizedBox.shrink(),
      ),
      debugShowCheckedModeBanner: false,
      theme: tableTheme(Brightness.light),
      darkTheme: tableTheme(Brightness.dark),
      themeMode: !ready
          ? ThemeMode.dark
          : switch (controller.state.settings['theme']) {
              'light' => ThemeMode.light,
              'system' => ThemeMode.system,
              _ => ThemeMode.dark,
            },
      home: ready
          ? TableScreen(controller: controller)
          : Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.spa_outlined, size: 56),
                        const SizedBox(height: 20),
                        const Text(
                          'Tripling Table',
                          style: TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 12),
                        if (startupError == null) ...[
                          const Text('Opening your table…'),
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                        ] else ...[
                          const Text(
                            'Your saved table could not be opened. Your data has been preserved.',
                          ),
                          const SizedBox(height: 12),
                          SelectableText(startupError!),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}
