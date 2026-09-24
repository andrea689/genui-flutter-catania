import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/ai/logging_llm_gateway.dart';

class _FixedGateway implements LlmGateway {
  _FixedGateway(this.events, {this.error});

  final List<LlmEvent> events;
  final Object? error;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    for (final event in events) {
      yield event;
    }
    if (error case final error?) throw error;
  }
}

void main() {
  group('LoggingLlmGateway', () {
    test('lascia passare gli eventi tali e quali', () async {
      const events = [
        LlmToolCallEvent(
          LlmToolCall(name: 'searchEarthquakes', args: {'daysBack': 7}),
        ),
        LlmTextDelta('Ecco '),
        LlmTextDelta('la mappa.'),
      ];
      final gateway = LoggingLlmGateway(_FixedGateway(events), log: (_) {});

      expect(
        await gateway.streamTurn(const [LlmUserText('ciao')]).toList(),
        events,
      );
    });

    test('stampa il testo del round per intero, non a chunk', () async {
      final lines = <String>[];
      final gateway = LoggingLlmGateway(
        _FixedGateway(const [
          LlmTextDelta('```json\n{"version":"v0.9",'),
          LlmTextDelta('"createSurface":{"surfaceId":"s1"}}\n```'),
        ]),
        log: lines.add,
      );

      await gateway.streamTurn(const [LlmUserText('ciao')]).drain<void>();

      final text = lines.singleWhere((line) => line.contains('createSurface'));
      expect(
        text,
        endsWith(
          '```json\n{"version":"v0.9","createSurface":{"surfaceId":"s1"}}\n```',
        ),
      );
    });

    test('stampa le tool call con gli argomenti in JSON', () async {
      final lines = <String>[];
      final gateway = LoggingLlmGateway(
        _FixedGateway(const [
          LlmToolCallEvent(
            LlmToolCall(
              name: 'searchEarthquakes',
              args: {'daysBack': 7, 'minMagnitude': 3.0},
            ),
          ),
        ]),
        log: lines.add,
      );

      await gateway.streamTurn(const [LlmUserText('ciao')]).drain<void>();

      expect(
        lines,
        contains(
          contains('searchEarthquakes {"daysBack":7,"minMagnitude":3.0}'),
        ),
      );
    });

    test('se il round si interrompe stampa quello che era arrivato', () async {
      final lines = <String>[];
      final gateway = LoggingLlmGateway(
        _FixedGateway(const [
          LlmTextDelta('```json\n{"version":'),
        ], error: StateError('503 model is overloaded')),
        log: lines.add,
      );

      await expectLater(
        gateway.streamTurn(const [LlmUserText('ciao')]).drain<void>(),
        throwsStateError,
      );

      expect(lines, contains(endsWith('```json\n{"version":')));
      expect(lines, contains(contains('503 model is overloaded')));
    });
  });
}
