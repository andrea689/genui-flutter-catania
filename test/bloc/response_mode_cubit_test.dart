import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/response_mode.dart';
import 'package:genui_flutter_catania/bloc/response_mode_cubit.dart';

void main() {
  test('parte dal catalogo Etna', () {
    final cubit = ResponseModeCubit();
    addTearDown(cubit.close);

    expect(cubit.state, ResponseMode.etna);
  });

  blocTest<ResponseModeCubit, ResponseMode>(
    'select cambia modalità',
    build: ResponseModeCubit.new,
    act: (cubit) => cubit.select(ResponseMode.text),
    expect: () => [ResponseMode.text],
  );
}
