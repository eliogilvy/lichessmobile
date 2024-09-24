import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/crashlytics.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/db/shared_preferences.dart';
import 'package:lichess_mobile/src/init.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/common/service/sound_service.dart';
import 'package:lichess_mobile/src/model/common/socket.dart';
import 'package:lichess_mobile/src/model/notifications/notification_service.dart';
import 'package:lichess_mobile/src/utils/connectivity.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import './fake_crashlytics.dart';
import './model/common/service/fake_sound_service.dart';
import 'model/common/fake_websocket_channel.dart';
import 'model/notifications/fake_notification_service.dart';
import 'utils/fake_connectivity_changes.dart';

class MockHttpClient extends Mock implements http.Client {}

const shouldLog = false;

/// Returns a [ProviderContainer] with a mocked [LichessClient] configured with
/// the given [mockClient].
Future<ProviderContainer> lichessClientContainer(MockClient mockClient) async {
  return makeContainer(
    overrides: [
      lichessClientProvider.overrideWith((ref) {
        return LichessClient(mockClient, ref);
      }),
    ],
  );
}

/// Returns a [ProviderContainer] with default mocks, ready for testing.
Future<ProviderContainer> makeContainer({
  List<Override>? overrides,
  AuthSessionState? userSession,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();

  FlutterSecureStorage.setMockInitialValues({
    kSRIStorageKey: 'test',
  });

  Logger.root.onRecord.listen((record) {
    if (shouldLog && record.level >= Level.FINE) {
      final time = DateFormat.Hms().format(record.time);
      debugPrint(
        '${record.level.name} at $time [${record.loggerName}] ${record.message}${record.error != null ? '\n${record.error}' : ''}',
      );
    }
  });

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWith((ref) async {
        final db =
            await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
        ref.onDispose(db.close);
        return db;
      }),
      webSocketChannelFactoryProvider.overrideWith((ref) {
        return FakeWebSocketChannelFactory(() => FakeWebSocketChannel());
      }),
      socketPoolProvider.overrideWith((ref) {
        final pool = SocketPool(ref);
        ref.onDispose(pool.dispose);
        return pool;
      }),
      lichessClientProvider.overrideWith((ref) {
        return LichessClient(MockHttpClient(), ref);
      }),
      connectivityChangesProvider.overrideWith(() {
        return FakeConnectivityChanges();
      }),
      defaultClientProvider.overrideWithValue(MockHttpClient()),
      crashlyticsProvider.overrideWithValue(FakeCrashlytics()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      soundServiceProvider.overrideWithValue(FakeSoundService()),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      cachedDataProvider.overrideWith((ref) {
        return CachedData(
          packageInfo: PackageInfo(
            appName: 'lichess_mobile_test',
            version: 'test',
            buildNumber: '0.0.0',
            packageName: 'lichess_mobile_test',
          ),
          deviceInfo: BaseDeviceInfo({
            'name': 'test',
            'model': 'test',
            'manufacturer': 'test',
            'systemName': 'test',
            'systemVersion': 'test',
            'identifierForVendor': 'test',
            'isPhysicalDevice': true,
          }),
          sharedPreferences: sharedPreferences,
          initialUserSession: userSession,
          sri: 'test',
          engineMaxMemoryInMb: 16,
        );
      }),
      ...overrides ?? [],
    ],
  );

  addTearDown(container.dispose);

  return container;
}
