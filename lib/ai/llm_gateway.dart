// Astrazione minima sopra un LLM streaming con function calling.
//
// Esiste per un motivo solo: rendere il loop di R1 (tool call -> risposta tool
// -> stream A2UI) testabile senza toccare la rete ne' Firebase.
// L'implementazione reale e' `FirebaseLlmGateway`; nei test si usa un fake.

/// Un messaggio nella storia della conversazione col modello.
///
/// Volutamente indipendente dall'SDK: non dipende da `firebase_ai`.
sealed class LlmMessage {
  const LlmMessage();
}

/// Testo scritto dall'utente.
final class LlmUserText extends LlmMessage {
  const LlmUserText(this.text);

  final String text;
}

/// Il modello ha chiesto di eseguire una o piu' funzioni.
final class LlmModelCalls extends LlmMessage {
  const LlmModelCalls(this.calls);

  final List<LlmToolCall> calls;
}

/// I risultati dei tool, da rimandare al modello.
final class LlmToolResults extends LlmMessage {
  const LlmToolResults(this.results);

  final List<LlmToolResult> results;
}

/// Una richiesta di function call emessa dal modello.
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

  /// L'oggetto originale del provider, da rimandare indietro **tale e quale**.
  ///
  /// Serve per i modelli "thinking" di Gemini 3: la function call porta con se'
  /// una `thought_signature` che va conservata nel giro successivo, altrimenti
  /// l'API protesta e il modello ragiona peggio.
  ///
  /// In `firebase_ai` 4.0.0 quella signature e' un campo **privato senza
  /// getter**, e il costruttore pubblico di `FunctionCall` la forza a `null`:
  /// ricostruire l'oggetto la perde comunque. L'unico modo di conservarla e'
  /// non ricostruirlo.
  ///
  /// Resta `Object?` di proposito: [ToolLoop] non deve sapere cosa contiene,
  /// cosi' i test continuano a girare senza `firebase_ai`.
  final Object? raw;
}

/// L'esito di un tool, pronto per tornare al modello.
final class LlmToolResult {
  const LlmToolResult({required this.name, required this.payload, this.id});

  final String name;
  final Map<String, Object?> payload;
  final String? id;
}

/// Un frammento emesso durante un singolo round del modello.
sealed class LlmEvent {
  const LlmEvent();
}

/// Un pezzo di testo. E' qui che viaggia l'A2UI: il protocollo arriva come
/// blocchi JSON dentro il flusso di testo, non come function call.
final class LlmTextDelta extends LlmEvent {
  const LlmTextDelta(this.text);

  final String text;
}

/// Il modello chiede un tool.
final class LlmToolCallEvent extends LlmEvent {
  const LlmToolCallEvent(this.call);

  final LlmToolCall call;
}

/// Sorgente di round del modello. Una sola responsabilita': dato lo storico,
/// streamare gli eventi di UN round.
abstract interface class LlmGateway {
  Stream<LlmEvent> streamTurn(List<LlmMessage> history);
}
