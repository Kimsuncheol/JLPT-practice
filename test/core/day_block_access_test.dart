import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/day_block_access.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('groups study days into five-day stages', () {
    expect(DayBlockAccess.stageForDay(1), 1);
    expect(DayBlockAccess.stageForDay(5), 1);
    expect(DayBlockAccess.stageForDay(6), 2);
    expect(DayBlockAccess.stageStartDay(3), 11);
    expect(DayBlockAccess.stageEndDay(3), 15);
  });

  test('requires rewarded ads only on positive multiples of five', () {
    expect(DayBlockAccess.requiresRewardedAd(1), isFalse);
    expect(DayBlockAccess.requiresRewardedAd(4), isFalse);
    expect(DayBlockAccess.requiresRewardedAd(5), isTrue);
    expect(DayBlockAccess.requiresRewardedAd(10), isTrue);
  });

  test('requires every earlier day to be complete', () {
    expect(DayBlockAccess.prerequisitesComplete(1, {}), isTrue);
    expect(DayBlockAccess.prerequisitesComplete(3, {1}), isFalse);
    expect(DayBlockAccess.prerequisitesComplete(3, {1, 2}), isTrue);
  });

  test('combines progression and rewarded-ad access', () {
    expect(
      DayBlockAccess.canStudy(
        day: 4,
        completedDays: {1, 2, 3},
        rewardedDays: {},
      ),
      isTrue,
    );
    expect(
      DayBlockAccess.canStudy(
        day: 5,
        completedDays: {1, 2, 3, 4},
        rewardedDays: {},
      ),
      isFalse,
    );
    expect(
      DayBlockAccess.canStudy(
        day: 5,
        completedDays: {1, 2, 3, 4},
        rewardedDays: {5},
      ),
      isTrue,
    );
    expect(
      DayBlockAccess.canStudy(
        day: 6,
        completedDays: {1, 2, 3, 4},
        rewardedDays: {5},
      ),
      isFalse,
    );
  });

  test('persists rewarded day unlocks by JLPT level', () async {
    SharedPreferences.setMockInitialValues({});

    await DayBlockAccess.unlockRewardedDay('N5', 5);
    await DayBlockAccess.unlockRewardedDay('N5', 10);

    expect(await DayBlockAccess.rewardedDays('N5'), {5, 10});
    expect(await DayBlockAccess.rewardedDays('N4'), isEmpty);
  });
}
