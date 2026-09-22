# GenUI @ Flutter Catania — Design

**Talk:** 17 ottobre 2026 · Flutter Catania (meetup-group-poliomfw)
**Durata:** ~35 min di contenuto + Q&A (slot 30/45 min, 4 slide bonus per riempire i 45)
**Repo:** github.com/andrea689/genui-flutter-catania
**Pages:** https://andrea689.github.io/genui-flutter-catania/

---

## 1. Obiettivo del talk

Una sola tensione narrativa: **"l'AI sa la risposta ma te la sa solo scrivere"**, risolta dal vivo.

Il messaggio che il pubblico deve portarsi a casa, sopra ogni altro:

> La GenUI **non** è "l'AI genera codice Dart a runtime".
> È "l'AI compone widget da un catalogo che scrivi tu".

Il catalogo è contemporaneamente il vocabolario e la sandbox di sicurezza.

**Lingua:** italiano; termini tecnici, nomi API e snippet in inglese
(catalog, surface, transport restano tali — chi legge poi la doc ufficiale
non deve fare traduzione inversa).

---

## 2. Fatti verificati (2026-09-22)

Verificati in questa sessione, non assunti. **Da riverificare prima del talk.**

| Fatto | Valore | Impatto |
|---|---|---|
| Nome package | `genui` — **non** più `flutter_genui` | Metà dei tutorial online è obsoleta |
| Versione | `0.10.3`, alpha | API instabile, pinnare |
| Riscrittura | maggio 2026, su A2UI v0.9 | `ContentGenerator` **non esiste più** |
| Architettura | Engine / Transport / Facade | Struttura dell'Atto 2 |
| Piattaforme | Android, iOS, macOS, **web** | Il deploy web è possibile |
| API INGV | FDSN, aperta, **senza chiave** | Testata: risponde 200 |
| CORS INGV | `Access-Control-Allow-Origin: *` | Funziona da browser, niente proxy |
| Previewer | stabile da 3.35, auto-start da 3.38 | Momento live in VS Code |
| Previewer runtime | Flutter **Web**, no `dart:io`/plugin nativi | Forza widget puri |
| **App Check** | **obbligatorio dal 2 novembre 2026** | 16 giorni dopo il talk |
| App Check web | **solo** reCAPTCHA Enterprise | Non v3 |

### Citazioni da conservare (materiale per le slide)

> "None of the Firebase-related APIs use an API key as *authorization* for
> calling the API. The API key passed with the API call is only used for
> *identification* of the Firebase project or app."

> "Starting November 2, 2026, Firebase App Check enforcement will be
> *required* to use Firebase AI Logic."

---

## 3. Struttura delle slide (~30 + 4 bonus)

### Atto 0 — Aggancio (3 min)
1. Titolo · chi sei · Flutter Catania 17 ottobre 2026
2. **Il problema** — risposta testuale su una scossa all'Etna vs la stessa
   come card con mappa. Stessi dati, valore diverso.
3. **Cosa vedrai** — teaser 20s: stessa app, tre domande, tre UI

### Atto 1 — Il perché (6 min)
4. Tre modi di unire UI e AI: UI statica con contenuto generato / chat pura / **UI generativa**
5. Definizione: l'agente sceglie *anche la presentazione*, non solo il contenuto
6. **Slide anti-fraintendimento** — non genera codice, compone da un catalogo. *La slide più importante del talk.*
7. **A2UI** — protocollo aperto, v0.9, Google. `genui` ne è l'implementazione Flutter
8. Stato dell'arte onesto — alpha 0.10.3, riscritto a maggio 2026

### Atto 2 — Architettura (8 min)
9. I tre layer, con diagramma: **Engine** (`SurfaceController`) → **Transport** (`A2uiTransportAdapter`) → **Facade** (`Conversation`)
10. Cos'è una *surface* e come la renderizzi
11. `Catalog` / `CatalogItem` — il vocabolario concesso all'AI
12. Lo schema con `json_schema_builder`
13. Transport e streaming — `onSend` / `addChunk`
14. **Il giro completo** — sequence diagram: utente → prompt → tool INGV → stream A2UI → widget

### Atto 3 — Codice e demo (13 min)
15. Setup reale — `pubspec`, `flutterfire configure`, entitlements
16. Il dominio — INGV FDSN + modelli `freezed`
17. Il tool — function calling Gemini → repository INGV
18. Anatomia di una card — widget puro + `@Preview`
19. **🖥️ LIVE VS CODE** — il pannello con tutto il catalogo, light e dark
20. Da widget a `CatalogItem` — schema e adapter
21. Il system prompt — `PromptBuilder.chat`
22. **▶️ DEMO 1** — domanda semplice → una card
23. **▶️ DEMO 2** — domanda complessa → composizione multipla
24. **▶️ DEMO 3** — tap su card → nuovo turno

### Atto 4 — La realtà (5 min)
25. Cosa funziona e cosa fa male — latenza, non-determinismo, costo token
26. **Come testi una UI che non conosci a priori?** Golden test sui widget puri, test di schema sugli adapter
27. Il catalogo *è* la sandbox — l'AI non può renderizzare ciò che non le hai dato
28. **⚠️ App Check obbligatorio dal 2 novembre 2026** — detto il 17 ottobre è informazione che serve davvero
29. **Quando NON usarla** — checkout, form critici, flussi regolamentati

### Chiusura (2 min)
30. Tre takeaway + QR: repo, slide, doc ufficiale, spec A2UI

### Bonus (se lo slot è da 45 o arrivano domande)
- B1. **Integrazione con `flutter_bloc`** — la doc usa `setState`, la tua app no
- B2. AI che genera un JSON custom tuo vs A2UI
- B3. Multi-turn con memoria
- B4. Il deploy web nel dettaglio

---

## 4. La demo: "Etna Assistant"

Chat sull'attività sismica dell'Etna dove **la UI si compone da sola**.

```
"cosa è successo sull'Etna questa settimana?"  → MapCard + TimelineChart
"dimmi della scossa più forte"                 → EventCard dettagliata
"confronta con agosto"                         → ComparisonCard
```

Il punto del talk è che sono **tre presentazioni diverse dallo stesso
catalogo**, scelte dall'AI, senza una sola schermata hardcoded.

### Stack

| Pezzo | Scelta |
|---|---|
| Dati | INGV FDSN — aperta, senza chiave, CORS `*` |
| AI | Firebase AI → Gemini (verificare il nome modello disponibile) |
| Stato | `flutter_bloc` — `ConversationBloc` |
| Modelli | `freezed` + `json_serializable` |
| Widget | 4 `CatalogItem` custom sopra `BasicCatalogItems` |
| Mappa | `flutter_map` + tile OSM (fallback: `CustomPainter`) |
| Sicurezza | `firebase_app_check` — reCAPTCHA Enterprise su web, debug provider in dev |

### Flusso tecnico

```
utente digita
  → ConversationBloc
  → A2uiTransportAdapter.onSend
  → Gemini (con tool searchEarthquakes)
  → Gemini chiama il tool → EtnaRepository → INGV
  → risposta del tool torna a Gemini
  → Gemini emette A2UI in streaming → addChunk()
  → SurfaceController compone i widget dal catalogo
  → Surface renderizza
```

### Struttura: widget puro separato dall'adapter

Vincolo imposto dal previewer (gira su Flutter Web, niente Firebase) e
comunque buon design a prescindere:

```
lib/catalog/event_card/
  event_card.dart        ← widget PURO: EventCard({required SeismicEvent event})
                            + @Preview co-locate, dati finti
  event_card_item.dart   ← CatalogItem: schema JSON + parse → EventCard
```

Il widget non sa nulla di AI, JSON o Firebase.
L'adapter non sa nulla di pixel.

Tutte le preview usano `group: 'Catalogo Etna'` → un solo pannello VS Code
mostra l'intero vocabolario. `brightness` per light/dark senza rilanciare.

**Vincoli `@Preview`:** solo funzioni top-level, metodi statici, o costruttori
pubblici **senza argomenti obbligatori**. Per widget con parametri richiesti,
funzione wrapper senza parametri:

```dart
@Preview(name: 'EventCard — scossa forte', group: 'Catalogo Etna')
Widget eventCardStrong() => EventCard(event: _sampleStrongQuake);
```

---

## 5. Rischi dichiarati

### R1 — Function calling + streaming A2UI (ALTO)

`onSend` deve gestire un loop: se Gemini chiede il tool, eseguire INGV,
rimandare la risposta, **poi** streammare i chunk A2UI. Il package è in
alpha: potrebbe non comportarsi come da doc.

**Mitigazione:** l'agente demo valida **questo per primo**, come spike
isolato, prima di costruirci sopra bloc e i 4 widget.
**Fallback:** pre-caricare i dati INGV nel prompt — meno elegante, demo salva.

### R2 — App Check blocca la demo live (ALTO, sottovalutato)

Con enforcement attivo, **anche l'app in locale viene bloccata** senza
debug token registrato. Rischio concreto di 403 sul palco.

**Mitigazione:** registrare il debug token della macchina del talk e
verificare **la sera prima**, non la mattina.

### R3 — Chiave esposta sul web (MITIGATO)

Risolto da App Check, che è obbligatorio comunque dal 2 novembre.
La restrizione per referrer **non** è sufficiente: `Referer` è deciso dal client.

---

## 6. Deploy

```
andrea689.github.io/genui-flutter-catania/        → slide
andrea689.github.io/genui-flutter-catania/demo/   → app web
```

- `flutter build web --base-href "/genui-flutter-catania/demo/"`
- site key reCAPTCHA via `--dart-define` da *variable* del repo (pubblica per design, ma ruotabile senza toccare il codice)
- una sola GitHub Action: copia slide + build web + deploy unico
- `lib/firebase_options.dart` **è** committato: serve alla CI e, con App Check
  in enforcement, è sicuro secondo le linee guida Google. I file nativi
  (`google-services.json`, `GoogleService-Info.plist`) restano fuori: non
  servono alla CI e si rigenerano con `flutterfire configure`.

### Slide: scelta tecnica

reveal.js **vendorizzato in locale**, non da CDN — il wifi dei meetup è
quello che è, e le slide devono partire offline.

---

## 7. Azioni a carico di Andrea (console, non automatizzabili)

1. Creare una **site key reCAPTCHA Enterprise** per `andrea689.github.io`
2. Registrare l'app web in **App Check** con quella key
3. Attivare l'**enforcement su Firebase AI Logic**
4. Registrare il **debug token** della macchina del talk ← *verificare la sera prima*
5. Abilitare **GitHub Pages** sul repo con source = GitHub Actions
6. Creare la repo *variable* con la site key reCAPTCHA

Questi passi vanno anche nel README, per essere ripetibili.

---

## 8. Divisione del lavoro

| Chi | Cosa |
|---|---|
| Agente **demo** | App Flutter. Parte validando R1 come spike. |
| Agente **slide** | Deck reveal.js vendorizzato, tema, tutte le slide non-codice |
| Andrea (Claude) | `.gitignore` ✅, GitHub Action, README, spec |
| Passata finale | Il codice **vero** della demo entra nelle slide, così gli snippet non mentono |

---

## 9. Scoperte durante l'implementazione

Aggiornato 2026-09-22, dopo aver scritto la demo. Quanto segue **corregge**
le assunzioni delle sezioni precedenti: dove c'è conflitto, vale questa.

### R1 risolto: A2UI non viaggia come function call

Il rischio principale non esisteva, ma per un motivo che nessun tutorial dice.
`PromptBuilder.uiGenerationRestriction` (`prompt_builder.dart:63`):

> "Do not use tools or function calls for UI generation. Use JSON text blocks."

I due canali sono **ortogonali**: `response.functionCalls` porta le richieste
di dati, `response.text` porta l'A2UI. Il tool loop e la generazione della UI
convivono dentro `onSend` senza pestarsi i piedi, e `ToolLoop.run` inoltra
`onText` a **ogni** round, non solo all'ultimo.

Questo smentisce la descrizione "prima esaurisci i tool, poi streammi la UI".

### Due trappole non documentate nel package

1. **`flush()` è one-shot.** Chiude `_inputStream` (`a2ui_transport_adapter.dart:88-91`).
   Chiamarlo a fine turno rompe **tutti** i turni successivi. Da non usare in
   una chat multi-turno.
2. **Il parser trattiene il buffer all'infinito** se un turno finisce con una
   graffa o un fence spaiato, e il residuo sborda nel turno dopo.

Entrambe sono modi in cui la demo si romperebbe in modo inspiegabile dal vivo.

### App Check: l'enforcement è già attivo, non arriva il 2 novembre

Sul progetto `genui-flutter-catania` **ogni chiamata a Gemini è già rifiutata**
senza un debug token registrato — verificato con chiamate reali:
`403 PERMISSION_DENIED — App attestation failed`, e, saltando App Check lato
client, `Firebase App Check token is invalid` dal server di AI Logic.

Il 2 novembre 2026 resta la data in cui diventa obbligatorio **per tutti**.

### Correzioni all'API rispetto a quanto assunto

| Assunto | Reale |
|---|---|
| `Surface(host:, surfaceId:)` | `Surface(key:, surfaceContext:)` — il README su pub.dev è vecchio |
| `CoreCatalogItems` | `BasicCatalogItems`, via `asNoAssetCatalog()` |
| `widgetBuilder: (data, context)` | `widgetBuilder: (itemContext)` — un solo parametro |
| `CatalogItem.build()` | non esiste: `widgetBuilder` |
| `UiActionEvent` | `UserActionEvent`, via `itemContext.dispatchEvent(...)` |
| `Surface` ha una callback `onEvent` | **non ce l'ha**: l'interazione nasce dentro il `CatalogItem` |
| `PromptBuilder.chat(systemInstruction:)` | regole via `copyWith(systemPromptFragments: [...])` + `systemPromptJoined()` |

### Bug trovati dai golden test

Non artefatti di test, bug veri: `EventCard` usava `CrossAxisAlignment.stretch`
dentro una `Row` → vincoli infiniti in una `ListView`, **crash in app**.
Più badge e `_MiniStat` che sbordavano con metriche di font diverse.

### Numeri misurati

- Bundle web: ~42 MB su disco, **~10 MB di primo caricamento reale**
  (main.dart.js 3,5 MB + una variante canvaskit; il browser scarica solo la sua)
- Pipeline CI verificata su clone pulito: `pub get` → `build_runner` → `build web`
- 38 test verdi, `analyze` pulito, 14 `@Preview` nel gruppo "Catalogo Etna"

### Ancora non verificato

**Nessuno ha visto l'A2UI che Gemini produce davvero** — bloccato da App Check.
Restano da validare la qualità delle scelte di card e l'aderenza agli schemi.
È il primo test da fare appena il debug token è registrato.
