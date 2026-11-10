import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/native_recovery_capacity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativeRecoveryCapacity.channelName);
  const probe = NativeRecoveryCapacity();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory destination;
  late String canonical;
  var calls = 0;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    destination = await Directory.systemTemp.createTemp('capacity-probe-');
    canonical = await destination.resolveSymbolicLinks();
    calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'availableBytes');
      expect(call.arguments, {'path': canonical});
      return {'path': canonical, 'availableBytes': 4096};
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    if (await destination.exists()) await destination.delete(recursive: true);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'uses canonical destination and native byte count on $platform',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        expect(await probe.availableBytes(destination), 4096);
        expect(calls, 1);
        expect(await destination.list().toList(), isEmpty);
      },
    );
  }

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.fuchsia,
  ]) {
    test('fails closed without channel call on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      expect(await probe.availableBytes(destination), isNull);
      expect(calls, 0);
    });
  }

  test(
    'rejects relative, missing, URI, NUL, file and final symlink paths',
    () async {
      final file = await File('${destination.path}/file').writeAsString('keep');
      final link = await Link(
        '${destination.path}/link',
      ).create(destination.path);
      for (final path in [
        '.',
        '${destination.path}/missing',
        destination.uri.toString(),
        '${destination.path}\u0000',
        file.path,
        link.path,
      ]) {
        expect(
          await probe.availableBytes(Directory(path)),
          isNull,
          reason: path,
        );
      }
      expect(calls, 0);
      expect(await file.readAsString(), 'keep');
    },
  );

  test('accepts zero and large 64-bit byte counts without coercion', () async {
    for (final bytes in [0, 0x7fffffffffffffff]) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'path': canonical, 'availableBytes': bytes},
      );
      expect(await probe.availableBytes(destination), bytes);
    }
  });

  test('rejects malformed responses and mismatched destination', () async {
    for (final response in <Object?>[
      null,
      123,
      <String, Object>{},
      {'path': '/another-volume', 'availableBytes': 4096},
      {'path': canonical, 'availableBytes': -1},
      {'path': canonical, 'availableBytes': '4096'},
      {'path': canonical, 'availableBytes': 4096.0},
      {'path': canonical, 'availableBytes': true},
      {'path': canonical},
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => response);
      expect(await probe.availableBytes(destination), isNull);
    }
  });

  test('missing plugin and platform errors fail closed', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await probe.availableBytes(destination), isNull);
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'capacity_unavailable');
    });
    expect(await probe.availableBytes(destination), isNull);
  });

  test('rejects destination removed during measurement', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      await destination.delete();
      return {'path': canonical, 'availableBytes': 4096};
    });
    expect(await probe.availableBytes(destination), isNull);
  });
}
