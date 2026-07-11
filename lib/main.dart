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
import 'providers/rules_provider.dart';
import 'screens/content_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/error_screen.dart';
import 'services/iap_service.dart';
import 'services/token_update_service.dart';
import 'utils/token_update_prompt.dart';
import 'utils/whats_new_content.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  // Initialize IAP service (non-blocking of UI — errors are swallowed internally)
  await IAPService().initialize();

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
  late RulesProvider rulesProvider;
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
        _initRulesProvider(),
      ]);

      tokenProvider = results[0] as TokenProvider;
      deckProvider = results[1] as DeckProvider;
      settingsProvider = results[2] as SettingsProvider;
      trackerProvider = results[3] as TrackerProvider; // NEW - Widget Cards Feature
      toggleProvider = results[4] as ToggleProvider; // NEW - Widget Cards Feature
      rulesProvider = results[5] as RulesProvider;

      stopwatch.stop();
      debugPrint('═══ App Initialization Complete: ${stopwatch.elapsedMilliseconds}ms ═══');

      _providersReady = true;
      _checkReadyToTransition();

      // Run compaction in background AFTER app is ready
      _runBackgroundMaintenance();

      // Show data loss dialog if any boxes were wiped during boot
      _showDataLossDialogIfNeeded();

      // Show migration notification if multiplier was converted to rules
      _showMigrationNotificationIfNeeded();

      // Show What's New modal once per version upgrade
      _showWhatsNewIfNeeded();

      // Background check for a newer token database (24h throttled)
      _checkForTokenDatabaseUpdatesIfNeeded();
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

  Future<RulesProvider> _initRulesProvider() async {
    final stopwatch = Stopwatch()..start();
    final provider = RulesProvider();
    await provider.init();
    stopwatch.stop();
    debugPrint('RulesProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
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
            case 'tokenRules':
              lostItems.add('token rules');
              break;
            case 'customTokens':
              lostItems.add('custom tokens');
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

  /// Show a one-time SnackBar if the old multiplier mechanism was removed on
  /// upgrade. The old multiplier is NOT carried forward; this only informs
  /// users who had a non-default multiplier set.
  void _showMigrationNotificationIfNeeded() {
    if (!rulesProvider.needsMigrationNotification) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = _navigatorKey.currentContext;
        if (navContext == null) return;

        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(
            content: Text(
              'Your previous multiplier was removed. Set up token '
              'effects in the new rules calculator.',
            ),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );

        rulesProvider.clearMigrationNotification();
      });
    });
  }

  /// Show the What's New modal once per version on launch. Skipped if Hive
  /// boxes were wiped (data-loss dialog takes priority), if there's no entry
  /// for the current version in `whatsNewContent`, or if the user already
  /// dismissed this version.
  Future<void> _showWhatsNewIfNeeded() async {
    if (widget.wipedBoxes.isNotEmpty) {
      debugPrint("WhatsNew: skipped — wipedBoxes non-empty");
      return;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    if (!hasWhatsNewContent(version)) {
      debugPrint("WhatsNew: skipped — no content for v$version");
      return;
    }
    if (settingsProvider.lastDismissedWhatsNewVersion == version) {
      debugPrint("WhatsNew: skipped — already dismissed for v$version");
      return;
    }

    debugPrint("WhatsNew: scheduling modal for v$version");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final navContext = _navigatorKey.currentContext;
        if (navContext == null) {
          debugPrint(
              "WhatsNew: SKIPPED SILENTLY — navigator context null when callback fired");
          return;
        }
        debugPrint("WhatsNew: showing modal now");
        await showWhatsNewDialog(navContext);
        await settingsProvider.setLastDismissedWhatsNewVersion(version);
        debugPrint("WhatsNew: modal dismissed, recorded v$version");
      });
    });
  }

  /// Background check for a newer token database. Throttled to once per 24h
  /// via `tokenDbLastCheck` (which the check itself writes on success). If a
  /// newer version is available AND the user hasn't already tapped "Not now"
  /// on that specific version, we surface a modal that can perform the
  /// download inline.
  Future<void> _checkForTokenDatabaseUpdatesIfNeeded() async {
    if (widget.wipedBoxes.isNotEmpty) {
      debugPrint('TokenUpdate: skipped — wipedBoxes non-empty');
      return;
    }

    // Defer to the What's New modal — if it's going to fire this launch, bail
    // rather than stack two dialogs on top of each other. We haven't hit the
    // network or written `tokenDbLastCheck` yet, so this same check runs
    // fresh on the next launch (once What's New is dismissed).
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    final whatsNewWillFire = hasWhatsNewContent(appVersion) &&
        settingsProvider.lastDismissedWhatsNewVersion != appVersion;
    if (whatsNewWillFire) {
      debugPrint("TokenUpdate: skipped — What's New will fire this launch");
      return;
    }

    final lastCheck = settingsProvider.tokenDbLastCheck;
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < const Duration(hours: 24)) {
      final hrs =
          DateTime.now().difference(lastCheck).inHours;
      debugPrint(
          'TokenUpdate: skipped — last check was ${hrs}h ago (throttle: 24h)');
      return;
    }

    debugPrint('TokenUpdate: fetching remote manifest...');
    final result = await TokenUpdateService.checkForUpdate();
    debugPrint(
        'TokenUpdate: remote=${result.remoteVersion}, local=${result.currentVersion}, available=${result.available}, error=${result.error}');
    if (!result.available || result.remoteVersion == null) return;

    // Respect a previous "Not now" tap for this specific version.
    final dismissed = settingsProvider.tokenDbDismissedUpdateVersion;
    if (dismissed != null && dismissed == result.remoteVersion) {
      debugPrint(
          'TokenUpdate: skipped — user already dismissed v${result.remoteVersion}');
      return;
    }

    debugPrint('TokenUpdate: showing modal for v${result.remoteVersion}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final navContext = _navigatorKey.currentContext;
        if (navContext == null) return;

        final outcome = await showTokenUpdatePrompt(navContext, result);
        if (!navContext.mounted) return;

        switch (outcome) {
          case TokenUpdatePromptOutcome.updated:
            ScaffoldMessenger.of(navContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'Token database updated. Restart token search to see new tokens.',
                ),
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case TokenUpdatePromptOutcome.failed:
            ScaffoldMessenger.of(navContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'Token database update failed. Your existing tokens are unchanged.',
                ),
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case TokenUpdatePromptOutcome.dismissed:
            await settingsProvider
                .setTokenDbDismissedUpdateVersion(result.remoteVersion!);
            break;
        }
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
      rulesProvider.dispose();
    }
    IAPService().dispose();
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
        ChangeNotifierProvider.value(value: rulesProvider),
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
