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
import 'providers/tracker_provider.dart'; // NEW - Widget Cards Feature
import 'providers/toggle_provider.dart'; // NEW - Widget Cards Feature
import 'screens/content_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/error_screen.dart';

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

  // Initialize Hive with resilient error handling — this NEVER throws
  final hiveResult = await initHive();

  runApp(MyApp(wipedBoxes: hiveResult.wipedBoxes));
}

class MyApp extends StatefulWidget {
  final List<String> wipedBoxes;

  const MyApp({super.key, this.wipedBoxes = const []});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late TokenProvider tokenProvider;
  late DeckProvider deckProvider;
  late SettingsProvider settingsProvider;
  late TrackerProvider trackerProvider; // NEW - Widget Cards Feature
  late ToggleProvider toggleProvider; // NEW - Widget Cards Feature
  bool _isInitialized = false;
  bool _providersReady = false;
  bool _hasError = false;
  bool _dataLossDialogShown = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _disableScreenTimeout();
    _initializeProviders();
  }

  void _checkReadyToTransition() {
    if (_providersReady && !_isInitialized) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeProviders() async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('═══ App Initialization Started ═══');

      // Initialize all providers in parallel
      final results = await Future.wait([
        _initTokenProvider(),
        _initDeckProvider(),
        _initSettingsProvider(),
        _initTrackerProvider(), // NEW - Widget Cards Feature
        _initToggleProvider(), // NEW - Widget Cards Feature
      ]);

      tokenProvider = results[0] as TokenProvider;
      deckProvider = results[1] as DeckProvider;
      settingsProvider = results[2] as SettingsProvider;
      trackerProvider = results[3] as TrackerProvider; // NEW - Widget Cards Feature
      toggleProvider = results[4] as ToggleProvider; // NEW - Widget Cards Feature

      stopwatch.stop();
      debugPrint('═══ App Initialization Complete: ${stopwatch.elapsedMilliseconds}ms ═══');

      _providersReady = true;
      _checkReadyToTransition();

      // Run compaction in background AFTER app is ready
      _runBackgroundMaintenance();

      // Show data loss dialog if any boxes were wiped during boot
      _showDataLossDialogIfNeeded();
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

      // Show error screen to user instead of crashing
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<TokenProvider> _initTokenProvider() async {
    final stopwatch = Stopwatch()..start();
    final provider = TokenProvider();
    await provider.init();
    stopwatch.stop();
    debugPrint('TokenProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
    return provider;
  }

  Future<DeckProvider> _initDeckProvider() async {
    final stopwatch = Stopwatch()..start();
    final provider = DeckProvider();
    await provider.init();
    stopwatch.stop();
    debugPrint('DeckProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
    return provider;
  }

  Future<SettingsProvider> _initSettingsProvider() async {
    final stopwatch = Stopwatch()..start();
    final provider = SettingsProvider();
    await provider.init();
    stopwatch.stop();
    debugPrint('SettingsProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
    return provider;
  }

  Future<TrackerProvider> _initTrackerProvider() async {
    final stopwatch = Stopwatch()..start();
    final provider = TrackerProvider();
    await provider.init();
    stopwatch.stop();
    debugPrint('TrackerProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
    return provider;
  }

  Future<ToggleProvider> _initToggleProvider() async {
    final stopwatch = Stopwatch()..start();
    final provider = ToggleProvider();
    await provider.init();
    stopwatch.stop();
    debugPrint('ToggleProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
    return provider;
  }

  void _runBackgroundMaintenance() {
    // Run after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DatabaseMaintenanceService.compactIfNeeded().then((didCompact) {
        if (didCompact) {
          debugPrint('Background maintenance: Compaction completed');
        }
      }).catchError((e) {
        debugPrint('Background maintenance: Compaction failed - $e');
      });
    });
  }

  /// Show a one-time dialog if any Hive boxes were wiped during boot.
  /// Uses a GlobalKey on the ContentScreen's MaterialApp to access the navigator.
  void _showDataLossDialogIfNeeded() {
    if (_dataLossDialogShown || widget.wipedBoxes.isEmpty) return;
    _dataLossDialogShown = true;

    // Wait for the ContentScreen to be fully built and visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Need to wait one more frame to ensure MaterialApp's navigator is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = _navigatorKey.currentContext;
        if (navContext == null) return;

        // Build a human-readable description of what was lost
        final lostItems = <String>[];
        for (final boxName in widget.wipedBoxes) {
          switch (boxName) {
            case 'items':
              lostItems.add('tokens');
              break;
            case 'decks':
              lostItems.add('decks');
              break;
            case 'trackerWidgets':
            case 'toggleWidgets':
              if (!lostItems.contains('utilities')) {
                lostItems.add('utilities');
              }
              break;
            case 'artworkPreferences':
              lostItems.add('artwork preferences');
              break;
          }
        }

        final lostDescription = lostItems.join(', ');

        showDialog(
          context: navContext,
          builder: (context) => AlertDialog(
            title: const Text('Data Reset'),
            content: Text(
              'Some of your data couldn\'t be loaded and was reset. '
              'You may need to re-create any lost $lostDescription.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    });
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
      settingsProvider.dispose();
      trackerProvider.dispose(); // NEW - Widget Cards Feature
      toggleProvider.dispose(); // NEW - Widget Cards Feature
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

  ThemeMode _getThemeMode(SettingsProvider settings) {
    if (settings.useSystemTheme) {
      return ThemeMode.system;
    }
    return settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if initialization failed
    if (_hasError) {
      return MaterialApp(
        title: 'Tripling Season',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.grey,
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF181818),
            surfaceContainerHighest: const Color(0xFF37373C),
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF37373C),
          ),
          scaffoldBackgroundColor: const Color(0xFF181818),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const ErrorScreen(),
      );
    }

    // CRITICAL: MultiProvider must wrap MaterialApp so providers are available
    // to ALL routes, including those pushed via Navigator.push()
    if (!_isInitialized) {
      return MaterialApp(
        title: 'Tripling Season',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.grey,
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF181818), // Darker scaffold background
            surfaceContainerHighest: const Color(0xFF37373C), // Lighter card background
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF37373C), // Explicit card color override
          ),
          scaffoldBackgroundColor: const Color(0xFF181818),
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
        ChangeNotifierProvider.value(value: trackerProvider), // NEW - Widget Cards Feature
        ChangeNotifierProvider.value(value: toggleProvider), // NEW - Widget Cards Feature
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Doubling Procession',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.grey,
                brightness: Brightness.dark,
              ).copyWith(
                surface: const Color(0xFF181818), // Darker scaffold background
                surfaceContainerHighest: const Color(0xFF37373C), // Lighter card background
              ),
              cardTheme: const CardThemeData(
                color: Color(0xFF37373C), // Explicit card color override
              ),
              scaffoldBackgroundColor: const Color(0xFF181818),
              useMaterial3: true,
            ),
            themeMode: _getThemeMode(settings),
            debugShowCheckedModeBanner: false,
            home: const ContentScreen(),
          );
        },
      ),
    );
  }
}
