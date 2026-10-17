import 'package:bloc/bloc.dart';

import '../ai/response_mode.dart';

/// The response mode selected in the AppBar. Starts with the Etna catalog.
class ResponseModeCubit extends Cubit<ResponseMode> {
  ResponseModeCubit() : super(ResponseMode.etna);

  void select(ResponseMode mode) => emit(mode);
}
