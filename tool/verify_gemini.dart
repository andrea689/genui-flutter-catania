// Smoke check of the real round trip: Gemini + function calling + A2UI
// streaming.
//
// It's not an automated test: it makes ONE real call and prints what happens.
// Run it the evening before the talk, when App Check is enforced:
//
//   fvm flutter run -d macos -t tool/verify_gemini.dart
//
// BEFORE running it, once:
//   1. fvm dart run build_runner build      (the *.g.dart / *.freezed.dart
//                                            files aren't in the repo: without
//                                            them it doesn't compile)
//   2. run it once and copy this line from the log:
//      "App Check debug token: '...'"
//   3. register that token in Firebase Console -> App Check -> the macOS/iOS
//      app -> Manage debug tokens
//   The token changes on every app reinstall: check it THE EVENING BEFORE.
//
// To isolate App Check from the rest:
//   fvm flutter run -d macos -t tool/verify_gemini.dart \
//     --dart-define=SKIP_APP_CHECK=true
//   If it still fails with "App Check token is invalid", enforcement is on
//   server-side and the token must be registered: there's no shortcut.
//
// What it must print to count as healthy:
//   - at least one TOOL with searchEarthquakes and an event count > 0
//   - at least one SURFACE with a component among EventCard/MapCard/
//     TimelineChart/ComparisonCard
//   - no ERROR

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_flutter_catania/ai/etna_agent.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/ai/response_mode.dart';
import 'package:genui_flutter_catania/app/bootstrap.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';

const String _question = 'Dimmi della scossa più forte dell\'ultima settimana';

/// Wraps the real gateway to print what flows through the two channels.
class _LoggingGateway implements LlmGateway {
  _LoggingGateway(this.inner);

  final LlmGateway inner;
  int round = 0;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    final current = ++round;
    stdout.writeln('--- ROUND $current (storico: ${history.length} messaggi)');
    await for (final event in inner.streamTurn(history)) {
      switch (event) {
        case LlmTextDelta(:final text):
          stdout.writeln(
            '  TEXT ${text.length} char: '
            '${text.replaceAll('\n', ' ').trim()}',
          );
        case LlmToolCallEvent(:final call):
          stdout.writeln('  TOOL ${call.name} args=${call.args}');
      }
      yield event;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  stdout.writeln('== Etna Assistant — verifica del giro reale ==');
  stdout.writeln('Modello: $kGeminiModel');

  try {
    await bootstrapFirebase();
    stdout.writeln('Firebase + App Check: OK');
  } on Object catch (error) {
    stdout.writeln('Firebase KO: $error');
    exit(1);
  }

  final agent = EtnaAgent.custom(
    catalog: ResponseMode.etna.catalog,
    gateway: _LoggingGateway(EtnaAgent.buildFirebaseGateway()),
    repository: IngvRepository(),
  );

  final surfaces = <String>[];
  final errors = <Object>[];
  agent.conversation.events.listen((event) {
    switch (event) {
      case genui.ConversationSurfaceAdded(:final surfaceId, :final definition):
        surfaces.add(surfaceId);
        final components = definition.components.values
            .map((c) => c.type)
            .join(', ');
        stdout.writeln('  SURFACE $surfaceId -> [$components]');
      case genui.ConversationError(:final error):
        errors.add(error);
        stdout.writeln('  ERROR $error');
      default:
        break;
    }
  });

  stdout.writeln('Domanda: "$_question"');
  final started = DateTime.now();

  try {
    await agent.conversation.sendRequest(genui.ChatMessage.user(_question));
  } on Object catch (error, stack) {
    stdout.writeln('ECCEZIONE: $error\n$stack');
  }

  await Future<void>.delayed(const Duration(seconds: 2));
  final elapsed = DateTime.now().difference(started);

  stdout.writeln('== Esito ==');
  stdout.writeln('Latenza: ${elapsed.inMilliseconds} ms');
  stdout.writeln('Surface create: ${surfaces.length}');
  stdout.writeln('Errori: ${errors.length}');
  stdout.writeln(
    surfaces.isNotEmpty && errors.isEmpty ? 'RISULTATO: OK' : 'RISULTATO: KO',
  );

  agent.dispose();
  exit(surfaces.isNotEmpty && errors.isEmpty ? 0 : 1);
}
