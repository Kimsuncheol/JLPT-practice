import 'package:shared_preferences/shared_preferences.dart';

class DayBlockAccess {
  DayBlockAccess._();

  static const blockSize = 5;

  static int blockForDay(int day) => ((day - 1) ~/ blockSize) + 1;

  static int blockStartDay(int block) => (block - 1) * blockSize + 1;

  static int blockEndDay(int block) => block * blockSize;

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
}
