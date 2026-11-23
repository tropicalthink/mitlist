import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mitlist/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every request and answers token registrations with a new id.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int _ids = 0;

  /// When set, POST responses wait for it.
  Completer<void>? holdPosts;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') {
      await holdPosts?.future;
      return ResponseBody.fromString(
        jsonEncode({'id': 'row-${++_ids}'}),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> get posts =>
      requests.where((r) => r.method == 'POST').toList();
  List<RequestOptions> get deletes =>
      requests.where((r) => r.method == 'DELETE').toList();
}

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;
  late StreamController<String> refreshes;
  late List<Object> tokenResults;
  String? accessToken;
  final waits = <Duration>[];

  PushTokenRegistrar build() => PushTokenRegistrar(
        platform: 'android',
        fetchToken: () async {
          final next = tokenResults.removeAt(0);
          if (next is Exception) throw next;
          return next as String;
        },
        tokenRefreshes: () => refreshes.stream,
        accessToken: () async => accessToken,
        wait: (d) async => waits.add(d),
        log: Logger(level: Level.off),
      );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = _RecordingAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    refreshes = StreamController<String>.broadcast();
    tokenResults = ['token-a'];
    accessToken = 'access-1';
    waits.clear();
  });

  tearDown(() => refreshes.close());

  test('registers the token at sign-in without any permission decision',
      () async {
    // The registrar has no permission input at all: starting it is enough.
    await build().start(dio);

    expect(adapter.posts, hasLength(1));
    final post = adapter.posts.single;
    expect(post.path, '/auth/device-tokens');
    expect(post.data, {'platform': 'android', 'token': 'token-a'});
    expect(post.headers['Authorization'], 'Bearer access-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PushTokenRegistrar.prefDeviceTokenId), 'row-1');
  });

  test('re-registers when the token is refreshed, once per token', () async {
    final registrar = build();
    await registrar.start(dio);

    refreshes.add('token-a'); // iOS replays the current token on launch
    await settle();
    expect(adapter.posts, hasLength(1));

    refreshes.add('token-b');
    await settle();
    expect(adapter.posts, hasLength(2));
    expect(
        adapter.posts.last.data, {'platform': 'android', 'token': 'token-b'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PushTokenRegistrar.prefDeviceTokenId), 'row-2');
  });

  test('waits for the iOS APNs token instead of giving up', () async {
    tokenResults = [
      FirebaseException(
          plugin: 'firebase_messaging', code: 'apns-token-not-set'),
      FirebaseException(
          plugin: 'firebase_messaging', code: 'apns-token-not-set'),
      'token-a',
    ];
    await build().start(dio);

    expect(waits, hasLength(2));
    expect(adapter.posts.single.data['token'], 'token-a');
  });

  test('a later permission grant does not register the same token twice',
      () async {
    tokenResults = ['token-a', 'token-a'];
    final registrar = build();
    await registrar.start(dio);
    await registrar.ensureRegistered(dio);
    expect(adapter.posts, hasLength(1));
  });

  test('sign-out removes the token and stops refreshes registering it',
      () async {
    final registrar = build();
    await registrar.start(dio);

    await registrar.stop();
    await PushTokenRegistrar.unregister(dio, log: Logger(level: Level.off));
    expect(adapter.deletes.single.path, '/auth/device-tokens/row-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PushTokenRegistrar.prefDeviceTokenId), isNull);

    refreshes.add('token-b');
    await settle();
    expect(adapter.posts, hasLength(1), reason: 'signed out');
  });

  test('the next account on the device registers the same token again',
      () async {
    tokenResults = ['token-a', 'token-a'];
    final registrar = build();
    await registrar.start(dio);
    await registrar.stop();
    await PushTokenRegistrar.unregister(dio, log: Logger(level: Level.off));

    accessToken = 'access-2';
    await registrar.start(dio);
    expect(adapter.posts, hasLength(2));
    expect(adapter.posts.last.headers['Authorization'], 'Bearer access-2');
    expect(adapter.posts.last.data['token'], 'token-a');
  });

  test('clears the legacy "already registered" marker on sign-out', () async {
    SharedPreferences.setMockInitialValues({
      PushTokenRegistrar.legacyPrefRegisteredToken: 'token-a',
      PushTokenRegistrar.prefDeviceTokenId: 'row-9',
    });
    await PushTokenRegistrar.unregister(dio, log: Logger(level: Level.off));
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString(PushTokenRegistrar.legacyPrefRegisteredToken), isNull);
    expect(adapter.deletes.single.path, '/auth/device-tokens/row-9');
  });

  test('does nothing while signed out', () async {
    accessToken = null;
    await build().start(dio);
    expect(adapter.requests, isEmpty);
  });

  test('a sign-out during registration stops it before it posts', () async {
    final gate = Completer<void>();
    final registrar = PushTokenRegistrar(
      platform: 'ios',
      fetchToken: () async => 'token-a',
      tokenRefreshes: () => refreshes.stream,
      accessToken: () async {
        await gate.future;
        return 'access-1';
      },
      log: Logger(level: Level.off),
    );
    final started = registrar.start(dio);
    await settle();
    await registrar.stop();
    gate.complete();
    await started;
    expect(adapter.posts, isEmpty);
  });

  test('a registration that lands after sign-out is taken back', () async {
    adapter.holdPosts = Completer<void>();
    final registrar = build();
    final started = registrar.start(dio);
    await settle();
    expect(adapter.posts, hasLength(1));

    await registrar.stop();
    await PushTokenRegistrar.unregister(dio, log: Logger(level: Level.off));
    expect(adapter.deletes, isEmpty, reason: 'no row id known yet');

    adapter.holdPosts!.complete();
    await started;
    expect(adapter.deletes.single.path, '/auth/device-tokens/row-1');
    expect(adapter.deletes.single.headers['Authorization'], 'Bearer access-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PushTokenRegistrar.prefDeviceTokenId), isNull);
  });
}
