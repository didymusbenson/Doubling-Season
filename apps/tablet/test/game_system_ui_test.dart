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
    'desktop leaves system chrome alone',
    (tester) async {
      await tester.pumpWidget(const GameSystemUi(child: SizedBox()));
      await tester.pumpWidget(const SizedBox());
      expect(calls, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
