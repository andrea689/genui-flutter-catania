import 'llm_gateway.dart';

/// Runs a tool and returns the JSON payload to send back to the model.
typedef ToolHandler =
    Future<Map<String, Object?>> Function(Map<String, Object?> args);

/// The model kept asking for tools beyond the allowed limit.
class ToolLoopExhausted implements Exception {
  const ToolLoopExhausted(this.maxRounds);

  final int maxRounds;

  @override
  String toString() =>
      'ToolLoopExhausted: il modello ha chiesto tool per $maxRounds round '
      'senza produrre una risposta finale.';
}

/// Runs the function-calling round trip.
///
/// The model requests a function call, we run the tool, send the result back,
/// and the next round produces the A2UI chunks.
///
/// The key point, verified against the package: A2UI does **not** travel as a
/// function call but as JSON blocks inside the text stream (see
/// `PromptFragments.uiGenerationRestriction`). The two channels are
/// orthogonal, so function calling and A2UI streaming coexist without
/// conflicts.
class ToolLoop {
  const ToolLoop({
    required this.gateway,
    required this.tools,
    this.maxRounds = 4,
  });

  final LlmGateway gateway;

  /// The runnable handlers, keyed by name.
  final Map<String, ToolHandler> tools;

  /// Maximum number of rounds with function calls before giving up.
  final int maxRounds;

  /// Runs the loop until the model stops asking for tools.
  ///
  /// [onText] receives every text delta as soon as it arrives: it's the
  /// channel `A2uiTransportAdapter.addChunk` should be wired to.
  Future<void> run({
    required List<LlmMessage> history,
    required void Function(String text) onText,
  }) async {
    for (var round = 0; round < maxRounds; round++) {
      final calls = <LlmToolCall>[];

      await for (final event in gateway.streamTurn(history)) {
        switch (event) {
          case LlmTextDelta(:final text):
            onText(text);
          case LlmToolCallEvent(:final call):
            calls.add(call);
        }
      }

      // No tools requested: the round just streamed was the final answer,
      // A2UI included.
      if (calls.isEmpty) return;

      history
        ..add(LlmModelCalls(calls))
        ..add(LlmToolResults(await _executeAll(calls)));
    }
    throw ToolLoopExhausted(maxRounds);
  }

  Future<List<LlmToolResult>> _executeAll(List<LlmToolCall> calls) async {
    return Future.wait(calls.map(_executeOne));
  }

  Future<LlmToolResult> _executeOne(LlmToolCall call) async {
    final handler = tools[call.name];
    if (handler == null) {
      return LlmToolResult(
        name: call.name,
        id: call.id,
        payload: {'error': 'Tool sconosciuto: ${call.name}'},
      );
    }
    try {
      return LlmToolResult(
        name: call.name,
        id: call.id,
        payload: await handler(call.args),
      );
    } on Object catch (error) {
      // A tool that throws must not kill the conversation: the model
      // receives the error and can explain it to the user.
      return LlmToolResult(
        name: call.name,
        id: call.id,
        payload: {'error': error.toString()},
      );
    }
  }
}
