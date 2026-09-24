import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'llm_gateway.dart';

/// Se true, la risposta grezza del modello finisce in console.
///
/// Acceso di default in debug. Per vederla anche in una build di release (il
/// sito pubblicato): `--dart-define=LOG_LLM=true`.
const bool kLogLlm = bool.fromEnvironment('LOG_LLM', defaultValue: kDebugMode);

/// Avvolge un [LlmGateway] e stampa in console cosa risponde il modello.
///
/// Serve a confrontare la risposta vera con quello che la UI mostra: se una
/// card non compare, qui si vede se il modello non l'ha mandata o se l'ha
/// mandata fuori schema.
///
/// Il testo di un round si stampa **per intero, alla fine del round**: a
/// chunk sarebbe illeggibile, i blocchi JSON arrivano spezzati a meta'. Le
/// tool call invece si stampano appena arrivano.
class LoggingLlmGateway implements LlmGateway {
  LoggingLlmGateway(this.inner, {void Function(String line)? log})
    : _log = log ?? ((line) => debugPrint(line));

  final LlmGateway inner;
  final void Function(String line) _log;

  int _round = 0;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    final round = ++_round;
    final text = StringBuffer();
    _log('[LLM] round $round (storico: ${history.length} messaggi)');

    try {
      await for (final event in inner.streamTurn(history)) {
        switch (event) {
          case LlmTextDelta(text: final delta):
            text.write(delta);
          case LlmToolCallEvent(:final call):
            _log('[LLM] tool ${call.name} ${jsonEncode(call.args)}');
        }
        yield event;
      }
    } on Object catch (error) {
      _log('[LLM] round $round interrotto: $error');
      rethrow;
    } finally {
      // Anche se il round si interrompe: il JSON a meta' e' proprio quello
      // che serve vedere.
      if (text.isNotEmpty) _log('[LLM] testo del round $round:\n$text');
    }
  }
}
