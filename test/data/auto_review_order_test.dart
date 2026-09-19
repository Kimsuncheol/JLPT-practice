import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';

void main() {
  test('offers every ordered combination of word, meanings and reading', () {
    expect(AutoReviewOrder.all, hasLength(6));
    expect(AutoReviewOrder.all.map((order) => order.id).toSet(), hasLength(6));
    for (final order in AutoReviewOrder.all) {
      expect(order.elements.toSet(), ReviewElement.values.toSet());
    }
    expect(AutoReviewOrder.all.first.id, 'word-meanings-reading');
    expect(AutoReviewOrder.all.first, AutoReviewOrder.defaultOrder);
  });

  test('round trips through its id and falls back to the default', () {
    for (final order in AutoReviewOrder.all) {
      expect(AutoReviewOrder.parse(order.id), order);
    }
    expect(AutoReviewOrder.parse('nonsense'), AutoReviewOrder.defaultOrder);
    expect(AutoReviewOrder.parse(null), AutoReviewOrder.defaultOrder);
  });
}
