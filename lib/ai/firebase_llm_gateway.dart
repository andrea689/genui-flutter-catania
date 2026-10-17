import 'package:firebase_ai/firebase_ai.dart';

import 'llm_gateway.dart';

/// The real [LlmGateway] implementation on top of Firebase AI Logic.
///
/// It does one thing only: translate the neutral types of `llm_gateway.dart`
/// into `firebase_ai` types and back. All the round-trip logic lives in
/// [ToolLoop], which therefore stays testable without a network.
class FirebaseLlmGateway implements LlmGateway {
  const FirebaseLlmGateway({required this.model, required this.tools});

  final GenerativeModel model;
  final List<Tool> tools;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    final stream = model.generateContentStream(
      history.map(toContent),
      tools: tools,
    );

    await for (final response in stream) {
      // The two channels are separate: text carries A2UI, function calls
      // carry data requests. They don't step on each other.
      final text = response.text;
      if (text != null && text.isNotEmpty) {
        yield LlmTextDelta(text);
      }
      for (final call in response.functionCalls) {
        yield LlmToolCallEvent(
          LlmToolCall(
            name: call.name,
            args: call.args,
            id: call.id,
            // The original Part, not a copy: it carries the
            // thought_signature, which is private and which the public
            // constructor would reset.
            raw: call,
          ),
        );
      }
    }
  }

  /// Translates a neutral message into a `firebase_ai` [Content].
  ///
  /// Visible for testing: it's the only place that knows which roles the
  /// model accepts, and getting them wrong only shows up against the real API.
  static Content toContent(LlmMessage message) => switch (message) {
    LlmUserText(:final text) => Content.text(text),
    // Function calls go back **exactly as they arrived**. Rebuilding them
    // with `FunctionCall(...)` would lose the thought_signature, which in
    // firebase_ai 4.0.0 is private and which that constructor resets:
    //   Function call is missing a thought_signature in functionCall parts.
    //   This is required for tools to work correctly.
    // The fallback rebuilds only when raw is missing (e.g. in tests with the
    // fake).
    LlmModelCalls(:final calls) => Content.model([
      for (final call in calls)
        if (call.raw case final FunctionCall original)
          original
        else
          FunctionCall(call.name, call.args, id: call.id),
    ]),
    // WARNING: Content.functionResponses() is deliberately NOT used here: in
    // firebase_ai 4.0.0 it hardcodes the 'function' role, which Gemini 3.x
    // rejects:
    //   Role 'function' is not supported. Please use a valid role:
    //   SYSTEM, SYSTEM_1, USER, ASSISTANT, DEVELOPER, CONTEXT, ...
    // The valid roles are 'user' and 'model': a tool response comes back as a
    // 'user' turn. The package helper hasn't caught up with the model.
    LlmToolResults(:final results) => Content('user', [
      for (final result in results)
        FunctionResponse(result.name, result.payload, id: result.id),
    ]),
  };
}
