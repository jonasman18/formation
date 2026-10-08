import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/quiz_repository.dart';
import '../domain/quiz.dart';

final quizRepositoryProvider = Provider(
  (ref) => QuizRepository(ref.watch(supabaseClientProvider)),
);

final quizProvider = FutureProvider.autoDispose.family<Quiz, String>(
  (ref, quizId) => ref.watch(quizRepositoryProvider).fetchQuiz(quizId),
);
