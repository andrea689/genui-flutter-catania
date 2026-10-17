// Minimal abstraction over a streaming LLM with function calling.
//
// It exists for one reason only: to make the tool loop (tool call -> tool
// response -> A2UI stream) testable without touching the network or Firebase.
// The real implementations are `FirebaseLlmGateway` and `LocalLlmGateway`;
// tests use a fake.

/// A message in the conversation history with the model.
///
/// Deliberately SDK-agnostic: it doesn't depend on `firebase_ai`.
sealed class LlmMessage {
  const LlmMessage();
}

/// Text written by the user.
final class LlmUserText extends LlmMessage {
  const LlmUserText(this.text);

  final String text;
}

/// The model asked to run one or more functions.
final class LlmModelCalls extends LlmMessage {
  const LlmModelCalls(this.calls);

  final List<LlmToolCall> calls;
}

/// Tool results, to send back to the model.
final class LlmToolResults extends LlmMessage {
  const LlmToolResults(this.results);

  final List<LlmToolResult> results;
}

/// A function call request emitted by the model.
final class LlmToolCall {
  const LlmToolCall({
    required this.name,
    required this.args,
    this.id,
    this.raw,
  });

  final String name;
  final Map<String, Object?> args;
  final String? id;

  /// The provider's original object, to send back **as is**.
  ///
  /// Needed for Gemini 3 "thinking" models: the function call carries a
  /// `thought_signature` that must be preserved in the next round, otherwise
  /// the API complains and the model reasons worse.
  ///
  /// In `firebase_ai` 4.0.0 that signature is a **private field with no
  /// getter**, and the public `FunctionCall` constructor forces it to `null`:
  /// rebuilding the object loses it no matter what. The only way to keep it
  /// is not to rebuild it.
  ///
  /// It stays `Object?` on purpose: [ToolLoop] mustn't know what it holds, so
  /// tests keep running without `firebase_ai`.
  final Object? raw;
}

/// A tool's outcome, ready to go back to the model.
final class LlmToolResult {
  const LlmToolResult({required this.name, required this.payload, this.id});

  final String name;
  final Map<String, Object?> payload;
  final String? id;
}

/// A fragment emitted during a single model round.
sealed class LlmEvent {
  const LlmEvent();
}

/// A chunk of text. This is where A2UI travels: the protocol arrives as JSON
/// blocks inside the text stream, not as function calls.
final class LlmTextDelta extends LlmEvent {
  const LlmTextDelta(this.text);

  final String text;
}

/// The model requests a tool.
final class LlmToolCallEvent extends LlmEvent {
  const LlmToolCallEvent(this.call);

  final LlmToolCall call;
}

/// Source of model rounds. A single responsibility: given the history, stream
/// the events of ONE round.
abstract interface class LlmGateway {
  Stream<LlmEvent> streamTurn(List<LlmMessage> history);
}
