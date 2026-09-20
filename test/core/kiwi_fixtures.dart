import 'package:jlpt_practice/core/services/meaning_mask_service.dart';

/// Morpheme analyses captured from the Kiwi engine (kiwipiepy, same model
/// family as flutter_kiwi_nlp's bundled CONG model), so the matching logic
/// can be tested without the native library.
const kiwiFixtures = <String, List<Morpheme>>{
  '일하다': [
    Morpheme(form: '일', tag: 'NNG', start: 0, length: 1),
    Morpheme(form: '하', tag: 'XSV', start: 1, length: 1),
    Morpheme(form: '다', tag: 'EC', start: 2, length: 1),
  ],
  '근무하다': [
    Morpheme(form: '근무', tag: 'NNG', start: 0, length: 2),
    Morpheme(form: '하', tag: 'XSV', start: 2, length: 1),
    Morpheme(form: '다', tag: 'EC', start: 3, length: 1),
  ],
  '공부하다': [
    Morpheme(form: '공부', tag: 'NNG', start: 0, length: 2),
    Morpheme(form: '하', tag: 'XSV', start: 2, length: 1),
    Morpheme(form: '다', tag: 'EF', start: 3, length: 1),
  ],
  '듣다': [
    Morpheme(form: '듣', tag: 'VV-I', start: 0, length: 1),
    Morpheme(form: '다', tag: 'EF', start: 1, length: 1),
  ],
  '먹다': [
    Morpheme(form: '먹', tag: 'VV', start: 0, length: 1),
    Morpheme(form: '다', tag: 'EF', start: 1, length: 1),
  ],
  '장래에 의사로 일할 생각입니다.': [
    Morpheme(form: '장래', tag: 'NNG', start: 0, length: 2),
    Morpheme(form: '에', tag: 'JKB', start: 2, length: 1),
    Morpheme(form: '의사', tag: 'NNG', start: 4, length: 2),
    Morpheme(form: '로', tag: 'JKB', start: 6, length: 1),
    Morpheme(form: '일', tag: 'NNG', start: 8, length: 1),
    Morpheme(form: '하', tag: 'XSV', start: 9, length: 1),
    Morpheme(form: 'ᆯ', tag: 'ETM', start: 9, length: 1),
    Morpheme(form: '생각', tag: 'NNG', start: 11, length: 2),
    Morpheme(form: '이', tag: 'VCP', start: 13, length: 1),
    Morpheme(form: 'ᆸ니다', tag: 'EF', start: 13, length: 3),
    Morpheme(form: '.', tag: 'SF', start: 16, length: 1),
  ],
  '어제 도서관에서 공부했어요.': [
    Morpheme(form: '어제', tag: 'MAG', start: 0, length: 2),
    Morpheme(form: '도서관', tag: 'NNG', start: 3, length: 3),
    Morpheme(form: '에서', tag: 'JKB', start: 6, length: 2),
    Morpheme(form: '공부', tag: 'NNG', start: 9, length: 2),
    Morpheme(form: '하', tag: 'XSV', start: 11, length: 1),
    Morpheme(form: '었', tag: 'EP', start: 11, length: 1),
    Morpheme(form: '어요', tag: 'EF', start: 12, length: 2),
    Morpheme(form: '.', tag: 'SF', start: 14, length: 1),
  ],
  '그는 은행에서 근무하고 있어요.': [
    Morpheme(form: '그', tag: 'NP', start: 0, length: 1),
    Morpheme(form: '는', tag: 'JX', start: 1, length: 1),
    Morpheme(form: '은행', tag: 'NNG', start: 3, length: 2),
    Morpheme(form: '에서', tag: 'JKB', start: 5, length: 2),
    Morpheme(form: '근무', tag: 'NNG', start: 8, length: 2),
    Morpheme(form: '하', tag: 'XSV', start: 10, length: 1),
    Morpheme(form: '고', tag: 'EC', start: 11, length: 1),
    Morpheme(form: '있', tag: 'VX', start: 13, length: 1),
    Morpheme(form: '어요', tag: 'EF', start: 14, length: 2),
    Morpheme(form: '.', tag: 'SF', start: 16, length: 1),
  ],
  '음악을 들었어요.': [
    Morpheme(form: '음악', tag: 'NNG', start: 0, length: 2),
    Morpheme(form: '을', tag: 'JKO', start: 2, length: 1),
    Morpheme(form: '듣', tag: 'VV-I', start: 4, length: 1),
    Morpheme(form: '었', tag: 'EP', start: 5, length: 1),
    Morpheme(form: '어요', tag: 'EF', start: 6, length: 2),
    Morpheme(form: '.', tag: 'SF', start: 8, length: 1),
  ],
  '밥을 먹었어요.': [
    Morpheme(form: '밥', tag: 'NNG', start: 0, length: 1),
    Morpheme(form: '을', tag: 'JKO', start: 1, length: 1),
    Morpheme(form: '먹', tag: 'VV', start: 3, length: 1),
    Morpheme(form: '었', tag: 'EP', start: 4, length: 1),
    Morpheme(form: '어요', tag: 'EF', start: 5, length: 2),
    Morpheme(form: '.', tag: 'SF', start: 7, length: 1),
  ],
  '일요일에는 일이 많아요.': [
    Morpheme(form: '일요일', tag: 'NNG', start: 0, length: 3),
    Morpheme(form: '에', tag: 'JKB', start: 3, length: 1),
    Morpheme(form: '는', tag: 'JX', start: 4, length: 1),
    Morpheme(form: '일', tag: 'NNG', start: 6, length: 1),
    Morpheme(form: '이', tag: 'JKS', start: 7, length: 1),
    Morpheme(form: '많', tag: 'VA', start: 9, length: 1),
    Morpheme(form: '어요', tag: 'EF', start: 10, length: 2),
    Morpheme(form: '.', tag: 'SF', start: 12, length: 1),
  ],
};
