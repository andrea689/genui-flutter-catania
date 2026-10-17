import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/etna_agent.dart';
import 'package:genui_flutter_catania/ai/llm_provider.dart';
import 'package:genui_flutter_catania/ai/local_llm_gateway.dart';
import 'package:genui_flutter_catania/ai/logging_llm_gateway.dart';
import 'package:genui_flutter_catania/ai/response_mode.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('EtnaAgent.local monta il gateway locale sotto il log', () {
    final agent = EtnaAgent.local(
      repository: IngvRepository(
        client: MockClient((_) async => http.Response('', 204)),
      ),
    );
    addTearDown(agent.dispose);

    // In debug, and therefore in tests, the response is printed to the
    // console, same as with Gemini.
    final gateway = agent.loop.gateway;
    expect(gateway, isA<LoggingLlmGateway>());
    expect((gateway as LoggingLlmGateway).inner, isA<LocalLlmGateway>());
    // The tools are the real ones.
    expect(agent.loop.tools.keys, ['searchEarthquakes']);
  });

  test('EtnaAgent.local manda al server il prompt e i tool dell\'app', () {
    final agent = EtnaAgent.local(
      repository: IngvRepository(
        client: MockClient((_) async => http.Response('', 204)),
      ),
    );
    addTearDown(agent.dispose);

    final gateway =
        (agent.loop.gateway as LoggingLlmGateway).inner as LocalLlmGateway;
    // The catalog rules and genui's A2UI instructions, same as for Gemini.
    expect(
      gateway.systemPrompt,
      contains("Sei l'assistente sismico dell'Etna"),
    );
    expect(gateway.systemPrompt, contains('createSurface'));
    final tool = gateway.tools.single;
    expect(tool['name'], 'searchEarthquakes');
    final parameters = tool['parameters']! as Map<String, Object?>;
    expect((parameters['properties']! as Map<String, Object?>).keys, [
      'daysBack',
      'minMagnitude',
      'limit',
      'offsetDays',
    ]);
  });

  test('forProvider(local) costruisce l\'agente locale', () {
    final agent = EtnaAgent.forProvider(LlmProvider.local);
    addTearDown(agent.dispose);

    final gateway = agent.loop.gateway as LoggingLlmGateway;
    expect(gateway.inner, isA<LocalLlmGateway>());
  });

  test('EtnaAgent.local manda al server il prompt della modalità', () {
    final agent = EtnaAgent.local(
      repository: IngvRepository(
        client: MockClient((_) async => http.Response('', 204)),
      ),
      mode: ResponseMode.text,
    );
    addTearDown(agent.dispose);

    final gateway =
        (agent.loop.gateway as LoggingLlmGateway).inner as LocalLlmGateway;
    expect(gateway.systemPrompt, ResponseMode.text.systemPrompt);
    // Same tool in every mode: only the presentation changes.
    expect(gateway.tools.single['name'], 'searchEarthquakes');
  });

  test('forProvider passa la modalità all\'agente', () {
    final agent = EtnaAgent.forProvider(LlmProvider.local, ResponseMode.basic);
    addTearDown(agent.dispose);

    final gateway =
        (agent.loop.gateway as LoggingLlmGateway).inner as LocalLlmGateway;
    expect(gateway.systemPrompt, ResponseMode.basic.systemPrompt);
    expect(
      agent.catalog.items.map((item) => item.name),
      isNot(contains('EventCard')),
    );
  });

  test('le label del menu', () {
    expect(LlmProvider.values.map((provider) => provider.label), [
      'Gemini',
      'Locale',
    ]);
  });
}
