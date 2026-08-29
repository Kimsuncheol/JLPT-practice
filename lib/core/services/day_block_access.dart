import 'package:shared_preferences/shared_preferences.dart';

class DayBlockAccess {
  DayBlockAccess._();

  static const blockSize = 5;

  static int blockForDay(int day) => ((day - 1) ~/ blockSize) + 1;

  static int stageForDay(int day) => blockForDay(day);

  static int blockStartDay(int block) => (block - 1) * blockSize + 1;

  static int stageStartDay(int stage) => blockStartDay(stage);

  static int blockEndDay(int block) => block * blockSize;

  static int stageEndDay(int stage) => blockEndDay(stage);

  static bool requiresRewardedAd(int day) => day > 0 && day % blockSize == 0;

  static bool prerequisitesComplete(int day, Set<int> completedDays) {
    if (day <= 1) return true;
    for (var previousDay = 1; previousDay < day; previousDay++) {
      if (!completedDays.contains(previousDay)) return false;
    }
    return true;
  }

  static bool canStudy({
    required int day,
    required Set<int> completedDays,
    required Set<int> rewardedDays,
  }) {
    if (completedDays.contains(day)) return true;
    if (!prerequisitesComplete(day, completedDays)) return false;
    return !requiresRewardedAd(day) || rewardedDays.contains(day);
  }

  static Future<bool> isUnlocked(String level, int block) async {
    if (block <= 1) return true;
    final unlocked = await unlockedBlocks(level);
    return unlocked.contains(block);
  }

  static Future<Set<int>> unlockedBlocks(String level) async {
    final preferences = await SharedPreferences.getInstance();
    final raw =
        preferences.getStringList('unlockedDayBlocks_$level') ??
        const <String>[];
    return {1, ...raw.map(int.parse)};
  }

  static Future<void> unlock(String level, int block) async {
    if (block <= 1) return;
    final preferences = await SharedPreferences.getInstance();
    final key = 'unlockedDayBlocks_$level';
    final unlocked = <String>{
      ...(preferences.getStringList(key) ?? const <String>[]),
      block.toString(),
    };
    await preferences.setStringList(key, unlocked.toList());
  }

  static Future<Set<int>> rewardedDays(String level) async {
    final preferences = await SharedPreferences.getInstance();
    final raw =
        preferences.getStringList('rewardedStudyDays_$level') ??
        const <String>[];
    return raw.map(int.parse).toSet();
  }

  static Future<void> unlockRewardedDay(String level, int day) async {
    if (!requiresRewardedAd(day)) return;
    final preferences = await SharedPreferences.getInstance();
    final key = 'rewardedStudyDays_$level';
    final unlocked = <String>{
      ...(preferences.getStringList(key) ?? const <String>[]),
      day.toString(),
    };
    await preferences.setStringList(key, unlocked.toList());
  }

  static Future<void> clearRewardedDays() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where(
      (key) => key.startsWith('rewardedStudyDays_'),
    );
    await Future.wait(keys.map(preferences.remove));
  }

  static Future<Map<String, List<int>>> exportAccess() async {
    final preferences = await SharedPreferences.getInstance();
    final result = <String, List<int>>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith('unlockedDayBlocks_') &&
          !key.startsWith('rewardedStudyDays_')) {
        continue;
      }
      final values = preferences
          .getStringList(key)
          ?.map(int.tryParse)
          .whereType<int>()
          .toSet()
          .toList();
      if (values != null) result[key] = values..sort();
    }
    return result;
  }

  static Future<void> mergeAccess(Map<String, dynamic> cloud) async {
    final preferences = await SharedPreferences.getInstance();
    for (final entry in cloud.entries) {
      if (!entry.key.startsWith('unlockedDayBlocks_') &&
          !entry.key.startsWith('rewardedStudyDays_')) {
        continue;
      }
      final remote =
          (entry.value as List<dynamic>?)?.whereType<num>().map(
            (value) => value.toInt(),
          ) ??
          const Iterable<int>.empty();
      final local =
          preferences
              .getStringList(entry.key)
              ?.map(int.tryParse)
              .whereType<int>() ??
          const Iterable<int>.empty();
      final merged = {...local, ...remote}.map((value) => '$value').toList();
      await preferences.setStringList(entry.key, merged);
    }
  }
}
