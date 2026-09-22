// Smoke check del giro reale: Gemini + function calling + streaming A2UI.
//
// Non e' un test automatico: fa UNA chiamata vera e stampa cosa succede.
// Da lanciare la sera prima del talk, quando App Check e' in enforcement:
//
//   fvm flutter run -d macos -t tool/verify_gemini.dart
//
// PRIMA di lanciarlo, una volta sola:
//   1. fvm dart run build_runner build      (i *.g.dart / *.freezed.dart non
//                                            sono nel repo: senza, non compila)
//   2. lancialo una volta e copia dal log la riga
//      "App Check debug token: '...'"
//   3. registra quel token in Firebase Console -> App Check -> l'app macOS/iOS
//      -> Gestisci token di debug
//   Il token cambia a ogni reinstallazione dell'app: verificalo LA SERA PRIMA.
//
// Per isolare App Check dal resto:
//   fvm flutter run -d macos -t tool/verify_gemini.dart \
//     --dart-define=SKIP_APP_CHECK=true
//   Se fallisce lo stesso con "App Check token is invalid", l'enforcement e'
//   attivo lato server e il token va registrato: non c'e' scorciatoia.
//
// Cosa deve stampare per dirsi sano:
//   - almeno un TOOL con searchEarthquakes e un conteggio di eventi > 0
//   - almeno una SURFACE con un componente fra EventCard/MapCard/
//     TimelineChart/ComparisonCard
//   - nessun ERROR

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_flutter_catania/ai/etna_agent.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/app/bootstrap.dart';
import 'package:genui_flutter_catania/catalog/etna_catalog.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';

const String _question = 'Dimmi della scossa piu forte dell ultima settimana';

/// Avvolge il gateway reale per stampare cosa passa nei due canali.
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

  final catalog = EtnaCatalog.asCatalog();
  final agent = EtnaAgent.custom(
    catalog: catalog,
    gateway: _LoggingGateway(EtnaAgent.buildFirebaseGateway(catalog: catalog)),
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
