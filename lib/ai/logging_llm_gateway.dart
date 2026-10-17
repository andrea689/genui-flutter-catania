import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'llm_gateway.dart';

/// If true, the model's raw response is printed to the console.
///
/// On by default in debug. To see it in a release build too (the published
/// site): `--dart-define=LOG_LLM=true`.
const bool kLogLlm = bool.fromEnvironment('LOG_LLM', defaultValue: kDebugMode);

/// Wraps an [LlmGateway] and prints the model's responses to the console.
///
/// Useful for comparing the real response with what the UI shows: if a card
/// doesn't appear, this tells you whether the model didn't send it or sent it
/// outside the schema.
///
/// A round's text is printed **in full, at the end of the round**: chunk by
/// chunk it would be unreadable, since JSON blocks arrive split mid-way. Tool
/// calls, on the other hand, are printed as soon as they arrive.
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
      // Even if the round is interrupted: the half-written JSON is exactly
      // what you need to see.
      if (text.isNotEmpty) _log('[LLM] testo del round $round:\n$text');
    }
  }
}
