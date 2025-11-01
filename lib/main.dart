import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'database/hive_setup.dart';
import 'providers/token_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/content_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await initHive();

  // Initialize providers
  final tokenProvider = TokenProvider();
  await tokenProvider.init();

  final deckProvider = DeckProvider();
  await deckProvider.init();

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(MyApp(
    tokenProvider: tokenProvider,
    deckProvider: deckProvider,
    settingsProvider: settingsProvider,
  ));
}

class MyApp extends StatefulWidget {
  final TokenProvider tokenProvider;
  final DeckProvider deckProvider;
  final SettingsProvider settingsProvider;

  const MyApp({
    super.key,
    required this.tokenProvider,
    required this.deckProvider,
    required this.settingsProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _disableScreenTimeout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  void _disableScreenTimeout() {
    // Keep screen awake during gameplay (matches SwiftUI behavior)
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Close Hive boxes on app pause/close
      widget.tokenProvider.dispose();
      widget.deckProvider.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.tokenProvider),
        ChangeNotifierProvider.value(value: widget.deckProvider),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
      ],
      child: MaterialApp(
        title: 'Doubling Season',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const ContentScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
