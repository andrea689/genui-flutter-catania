import 'package:bloc/bloc.dart';

import '../ai/llm_provider.dart';

/// The provider selected in the AppBar. Always starts with Gemini.
class LlmProviderCubit extends Cubit<LlmProvider> {
  LlmProviderCubit() : super(LlmProvider.gemini);

  void select(LlmProvider provider) => emit(provider);
}
