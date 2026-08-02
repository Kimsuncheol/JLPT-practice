import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

void main() {
  test('English and Korean strings are available', () {
    expect(const AppStrings('en')('startStudy'), 'Study new words');
    expect(const AppStrings('ko')('startStudy'), '새 단어 학습');
    expect(const AppStrings('en')('resumeLearning'), 'Resume learning');
    expect(const AppStrings('ko')('resumeLearning'), '이어서 학습');
  });

  test('unsupported string locale falls back to English', () {
    expect(const AppStrings('ja')('home'), 'Home');
  });
}
