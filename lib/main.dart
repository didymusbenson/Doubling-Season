import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'database/hive_setup.dart';
import 'database/database_maintenance.dart';
import 'providers/token_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/content_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable immersive mode on Android (hides navigation buttons, keeps status bar)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );

  try {
    // Initialize Hive only - provider init happens in MyApp
    await initHive();

    runApp(const MyApp());
  } catch (e, stackTrace) {
    // CRITICAL: Log initialization errors (only in debug mode)
    if (kDebugMode) {
      print('════════════════════════════════════════════');
      print('FATAL ERROR during app initialization:');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('════════════════════════════════════════════');
    }
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late TokenProvider tokenProvider;
  late DeckProvider deckProvider;
  late SettingsProvider settingsProvider;
  bool _isInitialized = false;
  bool _providersReady = false;
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _disableScreenTimeout();
    _initializeProviders();
    _startMinimumDisplayTimer();
  }

  void _startMinimumDisplayTimer() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      _minTimeElapsed = true;
      _checkReadyToTransition();
    });
  }

  void _checkReadyToTransition() {
    if (_providersReady && _minTimeElapsed && !_isInitialized) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeProviders() async {
    try {
      // Initialize providers
      tokenProvider = TokenProvider();
      await tokenProvider.init();

      deckProvider = DeckProvider();
      await deckProvider.init();

      settingsProvider = SettingsProvider();
      await settingsProvider.init();

      // Perform database maintenance (compaction) if needed
      // This runs weekly to reclaim dead space from deleted tokens.
      // Safe to call on every startup - only compacts if interval has elapsed.
      // Non-blocking: errors don't affect app startup.
      await DatabaseMaintenanceService.compactIfNeeded();

      _providersReady = true;
      _checkReadyToTransition();
    } catch (e, stackTrace) {
      // Log provider initialization errors (only in debug mode)
      if (kDebugMode) {
        print('════════════════════════════════════════════');
        print('ERROR during provider initialization:');
        print('Error: $e');
        print('Stack trace:');
        print(stackTrace);
        print('════════════════════════════════════════════');
      }
      rethrow;
    }
  }

  void _skipSplash() {
    if (_providersReady && !_isInitialized) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    if (_isInitialized) {
      tokenProvider.dispose();
      deckProvider.dispose();
    }
    super.dispose();
  }

  void _disableScreenTimeout() {
    // Keep screen awake during gameplay (matches SwiftUI behavior)
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-initialize providers if they were disposed
      // Safety check: ensure tokenProvider exists before accessing its properties
      if (_isInitialized) {
        try {
          if (!tokenProvider.initialized) {
            _initializeProviders();
          }
        } catch (e) {
          // If provider is in invalid state, re-initialize
          _initializeProviders();
        }
      }
    }
    // Note: We no longer dispose on pause/detach because it causes issues
    // when returning to the app. Hive handles persistence automatically.
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: MultiProvider must wrap MaterialApp so providers are available
    // to ALL routes, including those pushed via Navigator.push()
    if (!_isInitialized) {
      return MaterialApp(
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
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          key: const ValueKey('splash'),
          onComplete: _skipSplash,
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: tokenProvider),
        ChangeNotifierProvider.value(value: deckProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
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
        debugShowCheckedModeBanner: false,
        home: const ContentScreen(),
      ),
    );
  }
}
