import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/services/cloud_sync_service.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'finishing a words day records activity once per calendar day',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          cloudSyncProvider.overrideWithValue(const _NoopCloudSyncService()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final controller = container.read(appControllerProvider.notifier);

      await controller.completeStudySession('N5', 1);
      var state = container.read(appControllerProvider).requireValue;
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 1);
      expect(state.completedStudyDays['N5'], contains(1));

      await controller.completeStudySession('N5', 2);
      state = container.read(appControllerProvider).requireValue;
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 1);
      expect(state.completedStudyDays['N5'], containsAll([1, 2]));

      final store = await LocalStore.create();
      expect(store.loadSettings('en').currentStreak, 1);
      expect(store.lastStudyDate, isNotNull);
    },
  );
}

class _NoopCloudSyncService extends CloudSyncService {
  const _NoopCloudSyncService();

  @override
  Future<CloudRestoreBundle> restore(AppState local) async =>
      CloudRestoreBundle(state: local, lastStudyDate: null);

  @override
  Future<void> syncAll(AppState state, {String? lastStudyDate}) async {}

  @override
  Future<void> syncLearningSummary(
    AppState state, {
    String? lastStudyDate,
  }) async {}
}
