import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/repositories/mock_test_repository.dart';

final mockTestRepositoryProvider = Provider(
  (ref) =>
      MockTestRepository(quizRepository: ref.read(quizRepositoryProvider)),
);
