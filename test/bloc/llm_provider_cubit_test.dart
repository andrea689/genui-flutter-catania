import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/llm_provider.dart';
import 'package:genui_flutter_catania/bloc/llm_provider_cubit.dart';

void main() {
  test('parte da Gemini', () {
    final cubit = LlmProviderCubit();
    addTearDown(cubit.close);

    expect(cubit.state, LlmProvider.gemini);
  });

  blocTest<LlmProviderCubit, LlmProvider>(
    'select cambia provider',
    build: LlmProviderCubit.new,
    act: (cubit) => cubit.select(LlmProvider.local),
    expect: () => [LlmProvider.local],
  );
}
