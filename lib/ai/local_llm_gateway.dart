import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_gateway.dart';

/// Where the local provider listens. Host and port only: the endpoint is
/// `/turn`.
///
/// To change it: `--dart-define=LOCAL_LLM_URL=http://192.168.1.10:8765`.
const String kLocalLlmUrl = String.fromEnvironment(
  'LOCAL_LLM_URL',
  defaultValue: 'http://localhost:8765',
);

/// The local provider didn't respond as expected.
///
/// The message says what to do: it ends up in the error snackbar, in front of
/// whoever is presenting.
class LocalLlmException implements Exception {
  const LocalLlmException(this.message);

  final String message;

  @override
  String toString() => 'LocalLlmException: $message';
}

/// An [LlmGateway] that talks to a server on the same machine.
///
/// It's the demo's fallback: if Gemini doesn't respond, switch to it from the
/// AppBar. The protocol is deliberately minimal (see
/// `docs/superpowers/specs/2026-09-25-provider-locale-design.md`):
///
/// - `POST /turn` with the history as JSON, the system prompt and the tools;
/// - the response is NDJSON, one event per line, read as it arrives.
///
/// The system prompt and tools are sent on every round, as with Gemini: the
/// fake server ignores them, a real model behind the server needs them.
class LocalLlmGateway implements LlmGateway {
  LocalLlmGateway({
    Uri? baseUrl,
    this._client,
    this.systemPrompt,
    this.tools = const [],
  }) : baseUrl = baseUrl ?? Uri.parse(kLocalLlmUrl);

  final Uri baseUrl;

  /// The app's system prompt. If null, the key is left out of the request.
  final String? systemPrompt;

  /// The tool declarations, as produced by `FunctionDeclaration.toJson`.
  ///
  /// Maps rather than SDK types: the gateway doesn't depend on `firebase_ai`.
  final List<Map<String, Object?>> tools;

  /// Injected in tests. If null, one is created per round and closed at the
  /// end, so the gateway has no lifecycle to manage.
  final http.Client? _client;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    final client = _client ?? http.Client();
    try {
      final request = http.Request('POST', baseUrl.resolve('/turn'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          if (systemPrompt != null) 'system': systemPrompt,
          if (tools.isNotEmpty) 'tools': tools,
          'history': history.map(toJson).toList(),
        });

      final http.StreamedResponse response;
      try {
        response = await client.send(request);
      } on http.ClientException {
        throw LocalLlmException(
          'Provider locale non raggiungibile su $baseUrl: avvia il server',
        );
      }

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw LocalLlmException(
          'Il provider locale ha risposto ${response.statusCode}: $body',
        );
      }

      // utf8.decoder stitches together characters split across two chunks,
      // LineSplitter does the same for lines, including a final one with no
      // trailing newline.
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final event = parseLine(line);
        if (event != null) yield event;
      }
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Translates a neutral message into the protocol's JSON.
  ///
  /// Visible for testing, like `FirebaseLlmGateway.toContent`.
  static Map<String, Object?> toJson(LlmMessage message) => switch (message) {
    LlmUserText(:final text) => {'type': 'user', 'text': text},
    LlmModelCalls(:final calls) => {
      'type': 'calls',
      'calls': [
        for (final call in calls)
          {
            'name': call.name,
            'args': call.args,
            if (call.id != null) 'id': call.id,
          },
      ],
    },
    LlmToolResults(:final results) => {
      'type': 'results',
      'results': [
        for (final result in results)
          {
            'name': result.name,
            'payload': result.payload,
            if (result.id != null) 'id': result.id,
          },
      ],
    },
  };

  /// Translates an NDJSON line into an event. Null for unknown `type`s.
  ///
  /// Lenient where it can be: it's a debug protocol, and an odd line must not
  /// break the demo. A line that isn't JSON, however, means a broken server,
  /// and that has to be reported.
  static LlmEvent? parseLine(String line) {
    final Object? json;
    try {
      json = jsonDecode(line);
    } on FormatException {
      throw LocalLlmException('Riga non valida dal provider locale: $line');
    }
    if (json is! Map<String, Object?>) {
      throw LocalLlmException('Riga non valida dal provider locale: $line');
    }

    return switch (json['type']) {
      'text' => LlmTextDelta('${json['text'] ?? ''}'),
      'tool_call' => LlmToolCallEvent(
        LlmToolCall(
          name: '${json['name']}',
          args: switch (json['args']) {
            final Map<String, Object?> args => args,
            _ => const {},
          },
          id: switch (json['id']) {
            final String id => id,
            _ => null,
          },
        ),
      ),
      _ => null,
    };
  }
}
