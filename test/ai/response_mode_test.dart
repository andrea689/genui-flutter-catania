import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_flutter_catania/ai/response_mode.dart';
import 'package:genui_flutter_catania/catalog/etna_catalog.dart';

void main() {
  test('le label del menu', () {
    expect(ResponseMode.values.map((mode) => mode.label), [
      'Solo testo',
      'Catalogo base',
      'Catalogo Etna',
    ]);
  });

  test('solo testo: niente A2UI nel prompt, stesse regole sui dati', () {
    final prompt = ResponseMode.text.systemPrompt;

    expect(prompt, contains("Sei l'assistente sismico dell'Etna"));
    expect(prompt, contains('Chiama sempre searchEarthquakes'));
    expect(prompt, isNot(contains('createSurface')));
    expect(prompt, isNot(contains('EventCard')));
  });

  test('catalogo base: A2UI e componenti base, nessuna card Etna', () {
    final prompt = ResponseMode.basic.systemPrompt;

    expect(prompt, contains("Sei l'assistente sismico dell'Etna"));
    expect(prompt, contains('Chiama sempre searchEarthquakes'));
    expect(prompt, contains('createSurface'));
    expect(prompt, contains('Card'));
    expect(prompt, isNot(contains('EventCard')));
    expect(
      ResponseMode.basic.catalog.items.map((item) => item.name),
      isNot(contains('EventCard')),
    );
  });

  test('catalogo Etna: lo stesso prompt di prima, byte per byte', () {
    expect(
      ResponseMode.etna.systemPrompt,
      PromptBuilder.chat(catalog: EtnaCatalog.asCatalog()).systemPromptJoined(),
    );
    expect(
      ResponseMode.etna.catalog.items.map((item) => item.name),
      containsAll(['EventCard', 'MapCard', 'TimelineChart', 'ComparisonCard']),
    );
  });
}
