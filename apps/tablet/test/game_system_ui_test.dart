import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/game_system_ui.dart';

void main() {
  const android = MethodChannel('com.loosetie.triplingtable/system_ui');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(android, (call) async {
          calls.add(call);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(android, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'Android hides for table, restores on background and disposal',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const GameSystemUi(child: SizedBox()));
      expect(calls.single.method, 'setImmersive');
      expect(calls.single.arguments, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(calls.last.arguments, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.last.arguments, true);
      await tester.pumpWidget(const SizedBox());
      expect(calls.last.arguments, false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS requests immersive then restores both overlays',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const GameSystemUi(child: SizedBox()));
      expect(calls.single.method, 'SystemChrome.setEnabledSystemUIMode');
      expect(calls.single.arguments, 'SystemUiMode.immersiveSticky');
      await tester.pumpWidget(const SizedBox());
      expect(calls.last.method, 'SystemChrome.setEnabledSystemUIOverlays');
      expect(calls.last.arguments, [
        'SystemUiOverlay.top',
        'SystemUiOverlay.bottom',
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'keyboard dismissal reapplies after delay and exit cancels it',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const GameSystemUi(child: SizedBox()));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      final count = calls.length;
      await tester.pump(const Duration(milliseconds: 1000));
      expect(calls.length, count);
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls.length, count + 1);
      expect(calls.last.arguments, true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      final exitCount = calls.length;
      await tester.pump(const Duration(seconds: 2));
      expect(calls.length, exitCount);
      expect(calls.last.arguments, false);
      tester.view.resetViewInsets();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a table loaded in the background waits for resume',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpWidget(const GameSystemUi(child: SizedBox()));
      expect(calls, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.single.arguments, true);
      await tester.pumpWidget(const SizedBox());
      expect(calls.last.arguments, false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'missing native channel does not prevent table rendering',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(android, null);
      await tester.pumpWidget(
        const GameSystemUi(child: SizedBox(key: ValueKey('table'))),
      );
      expect(find.byKey(const ValueKey('table')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS fullscreen consumes only bottom safe area across keyboard and resume',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      const tableKey = ValueKey('table-surface');
      const insets = EdgeInsets.fromLTRB(44, 24, 12, 20);
      MediaQueryData? tableMedia;
      Widget shell({double keyboard = 0}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            padding: insets,
            viewPadding: insets,
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: GameSystemUi(
            child: Builder(
              builder: (context) {
                tableMedia = MediaQuery.of(context);
                return const SafeArea(child: SizedBox.expand(key: tableKey));
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(shell());
      final tableElement = tester.element(find.byKey(tableKey));
      expect(tableMedia!.padding, const EdgeInsets.fromLTRB(44, 24, 12, 0));
      expect(tableMedia!.viewPadding.bottom, 0);
      expect(tester.getBottomRight(find.byKey(tableKey)).dy, 600);
      expect(tester.getTopLeft(find.byKey(tableKey)), const Offset(44, 24));

      await tester.pumpWidget(shell(keyboard: 300));
      expect(tableMedia!.viewInsets.bottom, 300);
      expect(tableMedia!.viewPadding.bottom, 0);
      await tester.pumpWidget(shell());
      expect(tableMedia!.viewInsets.bottom, 0);
      expect(tester.getBottomRight(find.byKey(tableKey)).dy, 600);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(tableMedia!.padding, insets);
      expect(tableMedia!.viewPadding, insets);
      expect(tester.getBottomRight(find.byKey(tableKey)).dy, 580);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.getBottomRight(find.byKey(tableKey)).dy, 600);
      expect(tester.element(find.byKey(tableKey)), same(tableElement));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'other platforms preserve all platform-provided safe area insets',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      const media = MediaQueryData(
        padding: EdgeInsets.fromLTRB(44, 24, 12, 20),
        viewPadding: EdgeInsets.fromLTRB(44, 24, 12, 20),
      );
      MediaQueryData? actual;
      await tester.pumpWidget(
        MediaQuery(
          data: media,
          child: GameSystemUi(
            child: Builder(
              builder: (context) {
                actual = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(actual, media);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.linux,
    }),
  );

  testWidgets(
    'desktop leaves system chrome alone',
    (tester) async {
      await tester.pumpWidget(const GameSystemUi(child: SizedBox()));
      await tester.pumpWidget(const SizedBox());
      expect(calls, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
