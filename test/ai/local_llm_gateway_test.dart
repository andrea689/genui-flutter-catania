import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/ai/local_llm_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake server that responds with [chunks], byte for byte as they arrive.
MockClient _server(
  List<List<int>> chunks, {
  int status = 200,
  void Function(http.BaseRequest request, String body)? onRequest,
}) => MockClient.streaming((request, bodyStream) async {
  onRequest?.call(request, await bodyStream.bytesToString());
  return http.StreamedResponse(Stream.fromIterable(chunks), status);
});

List<int> _bytes(String text) => utf8.encode(text);

Future<List<LlmEvent>> _events(LocalLlmGateway gateway) =>
    gateway.streamTurn(const [LlmUserText('ciao')]).toList();

void main() {
  group('LocalLlmGateway.toJson', () {
    test('traduce i tre messaggi della storia', () {
      expect(LocalLlmGateway.toJson(const LlmUserText('ciao')), {
        'type': 'user',
        'text': 'ciao',
      });
      expect(
        LocalLlmGateway.toJson(
          const LlmModelCalls([
            LlmToolCall(
              name: 'searchEarthquakes',
              args: {'daysBack': 7},
              id: 'c1',
            ),
          ]),
        ),
        {
          'type': 'calls',
          'calls': [
            {
              'name': 'searchEarthquakes',
              'args': {'daysBack': 7},
              'id': 'c1',
            },
          ],
        },
      );
      expect(
        LocalLlmGateway.toJson(
          const LlmToolResults([
            LlmToolResult(
              name: 'searchEarthquakes',
              payload: {'count': 0},
              id: 'c1',
            ),
          ]),
        ),
        {
          'type': 'results',
          'results': [
            {
              'name': 'searchEarthquakes',
              'payload': {'count': 0},
              'id': 'c1',
            },
          ],
        },
      );
    });

    test('senza id la chiave manca', () {
      expect(
        LocalLlmGateway.toJson(
          const LlmModelCalls([
            LlmToolCall(name: 'searchEarthquakes', args: {}),
          ]),
        ),
        {
          'type': 'calls',
          'calls': [
            {'name': 'searchEarthquakes', 'args': <String, Object?>{}},
          ],
        },
      );
    });
  });

  group('LocalLlmGateway.streamTurn', () {
    test('di default punta a localhost:8765', () {
      expect(LocalLlmGateway().baseUrl, Uri.parse('http://localhost:8765'));
    });

    test('manda la storia in POST su /turn', () async {
      late http.BaseRequest captured;
      late String body;
      final gateway = LocalLlmGateway(
        baseUrl: Uri.parse('http://localhost:8765'),
        client: _server(
          [],
          onRequest: (request, requestBody) {
            captured = request;
            body = requestBody;
          },
        ),
      );

      await _events(gateway);

      expect(captured.method, 'POST');
      expect(captured.url, Uri.parse('http://localhost:8765/turn'));
      expect(captured.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(body), {
        'history': [
          {'type': 'user', 'text': 'ciao'},
        ],
      });
    });

    test('manda system prompt e tool, come a un provider vero', () async {
      late String body;
      final gateway = LocalLlmGateway(
        client: _server([], onRequest: (_, requestBody) => body = requestBody),
        systemPrompt: 'Sei un test.',
        tools: const [
          {
            'name': 'searchEarthquakes',
            'description': 'Cerca i terremoti',
            'parameters': {'type': 'OBJECT'},
          },
        ],
      );

      await _events(gateway);

      expect(jsonDecode(body), {
        'system': 'Sei un test.',
        'tools': [
          {
            'name': 'searchEarthquakes',
            'description': 'Cerca i terremoti',
            'parameters': {'type': 'OBJECT'},
          },
        ],
        'history': [
          {'type': 'user', 'text': 'ciao'},
        ],
      });
    });

    test('una barra finale nell\'url non cambia l\'endpoint', () async {
      late Uri url;
      final gateway = LocalLlmGateway(
        baseUrl: Uri.parse('http://localhost:8765/'),
        client: _server([], onRequest: (request, _) => url = request.url),
      );

      await _events(gateway);

      expect(url, Uri.parse('http://localhost:8765/turn'));
    });

    test('una riga spezzata fra due chunk arriva intera', () async {
      final gateway = LocalLlmGateway(
        client: _server([
          _bytes('{"type":"text","te'),
          _bytes(
            'xt":"Ecco"}\n{"type":"tool_call","name":"searchEarthquakes",',
          ),
          _bytes('"args":{"daysBack":7},"id":"c1"}\n'),
        ]),
      );

      final events = await _events(gateway);

      expect(events, hasLength(2));
      expect((events[0] as LlmTextDelta).text, 'Ecco');
      final call = (events[1] as LlmToolCallEvent).call;
      expect(call.name, 'searchEarthquakes');
      expect(call.args, {'daysBack': 7});
      expect(call.id, 'c1');
    });

    test(
      'un carattere accentato spezzato fra due chunk resta intero',
      () async {
        final bytes = _bytes('{"type":"text","text":"Città"}\n');
        // "à" in UTF-8 is 0xC3 0xA0: cut between the two bytes.
        final cut = bytes.indexOf(0xC3) + 1;
        final gateway = LocalLlmGateway(
          client: _server([bytes.sublist(0, cut), bytes.sublist(cut)]),
        );

        final events = await _events(gateway);

        expect((events.single as LlmTextDelta).text, 'Città');
      },
    );

    test('l\'ultima riga senza a-capo non si perde', () async {
      final gateway = LocalLlmGateway(
        client: _server([_bytes('{"type":"text","text":"fine"}')]),
      );

      final events = await _events(gateway);

      expect((events.single as LlmTextDelta).text, 'fine');
    });

    test('righe vuote e type sconosciuti si ignorano', () async {
      final gateway = LocalLlmGateway(
        client: _server([
          _bytes('\n{"type":"thinking","text":"hmm"}\n\n'),
          _bytes('{"type":"text","text":"ok"}\n'),
        ]),
      );

      final events = await _events(gateway);

      expect((events.single as LlmTextDelta).text, 'ok');
    });

    test('una tool call senza id e con args null non esplode', () async {
      final gateway = LocalLlmGateway(
        client: _server([
          _bytes(
            '{"type":"tool_call","name":"searchEarthquakes","args":null}\n',
          ),
        ]),
      );

      final call = ((await _events(gateway)).single as LlmToolCallEvent).call;

      expect(call.name, 'searchEarthquakes');
      expect(call.id, isNull);
      expect(call.args, isEmpty);
    });

    test('uno stato diverso da 200 diventa LocalLlmException', () async {
      final gateway = LocalLlmGateway(
        client: _server([_bytes('boom')], status: 500),
      );

      await expectLater(
        _events(gateway),
        throwsA(
          isA<LocalLlmException>().having(
            (error) => error.message,
            'message',
            'Il provider locale ha risposto 500: boom',
          ),
        ),
      );
    });

    test('un server spento dice cosa fare', () async {
      final gateway = LocalLlmGateway(
        baseUrl: Uri.parse('http://localhost:8765'),
        client: MockClient(
          (_) async => throw http.ClientException('Connection refused'),
        ),
      );

      await expectLater(
        _events(gateway),
        throwsA(
          isA<LocalLlmException>().having(
            (error) => error.message,
            'message',
            'Provider locale non raggiungibile su http://localhost:8765: '
                'avvia il server',
          ),
        ),
      );
    });

    test('una riga non JSON diventa LocalLlmException', () async {
      final gateway = LocalLlmGateway(client: _server([_bytes('non json\n')]));

      await expectLater(
        _events(gateway),
        throwsA(
          isA<LocalLlmException>().having(
            (error) => error.message,
            'message',
            'Riga non valida dal provider locale: non json',
          ),
        ),
      );
    });
  });
}
