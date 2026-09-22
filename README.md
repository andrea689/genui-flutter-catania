# GenUI con Flutter — Etna Assistant

Slide e demo del talk **"GenUI: quando l'AI disegna la UI"**, presentato al
meetup [Flutter Catania](https://www.meetup.com/meetup-group-poliomfw/) del
**17 ottobre 2026**.

📊 **[Slide](https://andrea689.github.io/genui-flutter-catania/)** ·
🚀 **[Demo live](https://andrea689.github.io/genui-flutter-catania/demo/)**

---

## Di cosa si tratta

La **Generative UI** non è "l'AI che genera codice Dart a runtime".
È **l'AI che compone widget da un catalogo che scrivi tu**.

Tu definisci il vocabolario — un insieme di widget con i loro schemi — e
l'agente decide *quali* usare e *come* comporli in base alla conversazione.
Il catalogo è contemporaneamente il vocabolario e la sandbox di sicurezza:
l'AI non può renderizzare ciò che non le hai dato.

**Etna Assistant** è la demo: chiedi dell'attività sismica dell'Etna e la UI
si compone da sola, usando dati reali dell'[INGV](https://www.ingv.it/).

```
"cosa è successo sull'Etna questa settimana?"  → MapCard + TimelineChart
"dimmi della scossa più forte"                 → EventCard dettagliata
"confronta con agosto"                         → ComparisonCard
```

Tre presentazioni diverse dallo stesso catalogo, scelte dall'AI.
Nessuna schermata hardcoded.

## Stack

| Pezzo | Scelta |
|---|---|
| GenUI | [`genui`](https://pub.dev/packages/genui) — implementazione Flutter del protocollo aperto [A2UI](https://flutter.dev/blog/new-updates-to-a2ui-and-flutters-genui-package) |
| AI | Firebase AI Logic → Gemini `3.5-flash` |
| Dati | [INGV FDSN](https://webservices.ingv.it/) — API aperta, senza chiave |
| Stato | `flutter_bloc` |
| Modelli | `freezed` + `json_serializable` |
| Sicurezza | `firebase_app_check` |

> ⚠️ Il package `genui` è in **alpha** e l'API cambia spesso. È stato
> riscritto a maggio 2026 sopra A2UI v0.9: `ContentGenerator` non esiste più.
> Molti tutorial in circolazione sono già obsoleti.

---

## Setup

### Requisiti

- Flutter **3.44.8** (il repo usa [fvm](https://fvm.app/): `fvm install`)
- Un progetto Firebase con la **Gemini API abilitata**

### 1. Dipendenze e codice generato

I file generati (`*.g.dart`, `*.freezed.dart`) non sono nel repo:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Firebase

Il progetto è già configurato e `lib/firebase_options.dart` è committato.
Per rigenerarlo sul tuo progetto Firebase:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=genui-flutter-catania
```

I file di servizio nativi (`google-services.json`, `GoogleService-Info.plist`)
**non** sono nel repo: li rigenera `flutterfire configure`.

<details>
<summary>Perché <code>firebase_options.dart</code> è committato ma i file nativi no</summary>

Secondo le [linee guida Google](https://firebase.google.com/docs/projects/api-keys),
le API key ristrette ai servizi Firebase **non sono segreti**:

> "None of the Firebase-related APIs use an API key as *authorization* for
> calling the API. The API key passed with the API call is only used for
> *identification* of the Firebase project or app."

La protezione vera è **App Check**, non la segretezza della chiave.
`firebase_options.dart` serve alla CI per buildare la versione web, quindi
sta nel repo. I file nativi non servono alla CI e restano fuori: meno
superficie esposta, zero costo.
</details>

### 3. App Check — obbligatorio, e già attivo

> 🚨 **Su questo progetto l'enforcement è già attivo.** Finché non registri un
> debug token, **nessuna chiamata a Gemini passa** — nemmeno in locale.
> Verificato con chiamate reali: `403 PERMISSION_DENIED — App attestation failed`.

Dal **2 novembre 2026** App Check diventa comunque obbligatorio per chiunque
usi Firebase AI Logic, quindi non è una particolarità di questo repo.

Non basta restringere la chiave per dominio: l'header `Referer` lo decide il
client, e `curl` può dichiarare quello che vuole. La restrizione ferma un
*altro sito*, non uno script. Ci sono resoconti pubblici di bollette da
migliaia di euro generate in una notte da chiavi Firebase esposte e usate
contro Gemini.

#### Sbloccare lo sviluppo in locale

```bash
flutter run -d macos -t tool/verify_gemini.dart
```

Stampa nei log `App Check debug token: '...'`. Copialo e registralo in
**Firebase Console → App Check → [la tua app] → Gestisci token di debug**.

Rilancia: deve stampare `RISULTATO: OK` con almeno un `TOOL searchEarthquakes`
e una `SURFACE`. Questo script è anche lo smoke test del giro completo.

#### ⚠️ Fissa il token, o te ne ritrovi uno nuovo a ogni avvio

Se non lo fissi, **il token cambia a ogni run** e devi registrarlo di nuovo
ogni volta. Non è un bug: il provider di debug lo salva in una memoria locale
legata all'installazione, e quella memoria sparisce di continuo.

- **Web** — lo storage del browser è **per origine**, e `flutter run -d chrome`
  sceglie una porta a caso ogni volta (`localhost:56953`, poi un'altra). Ogni
  run è un'origine nuova → storage vuoto → token nuovo.
- **macOS** — serve il Keychain, e senza l'entitlement giusto
  ([vedi sotto](#-macos-serve-anche-il-keychain)) non è raggiungibile: niente
  persistenza, token nuovo ogni volta.

La soluzione è passarlo tu. Prendi **un** token dai log, registralo in console,
e poi usa sempre quello:

```bash
flutter run --dart-define=APP_CHECK_DEBUG_TOKEN=<il-tuo-token>
```

Così vale su qualunque porta, dopo qualunque reinstallazione, su tutte le
piattaforme. Registri una volta e non ci pensi più.

> Non è un segreto — vale solo per le build di debug e solo per i token che hai
> registrato tu — ma non committarlo: tienilo nel `--dart-define`.
>
> Se preferisci non passarlo, l'alternativa **solo per il web** è fissare la
> porta: `flutter run -d chrome --web-port=5000`. Stessa origine ogni volta,
> quindi lo storage sopravvive.

**Se devi fare una demo dal vivo, verificalo la sera prima** — non la mattina.

#### 🍎 macOS: il token va sotto l'app **iOS**, non sotto quella web

La Firebase Console non ha un tipo di app "macOS": puoi creare solo **web, iOS
e Android**. Non è una dimenticanza — **macOS usa la registrazione dell'app
Apple**, cioè quella iOS.

La prova sta in `lib/firebase_options.dart`, dove macOS e iOS hanno lo **stesso
`appId`**:

```dart
static const FirebaseOptions ios = FirebaseOptions(
  appId: '1:513967163990:ios:e8f734cc39e8ddbeb409f7', // <-- stesso
);
static const FirebaseOptions macos = FirebaseOptions(
  appId: '1:513967163990:ios:e8f734cc39e8ddbeb409f7', // <-- appId
);
```

Quindi il debug token stampato da `flutter run -d macos` va registrato sotto
**l'app iOS**. Registrarlo sotto l'app web non ha effetto: sono due
registrazioni diverse, e App Check verifica il token contro quella dell'app che
sta chiamando.

Sul lato Dart non serve fare niente: `providerApple` copre sia iOS sia macOS
(vedi `lib/app/bootstrap.dart`).

#### 🔑 macOS: serve anche il Keychain

```
[firebase_app_check/code-unsupported] The operation couldn't be completed.
Keychain access error.
```

App Check conserva l'ID di installazione nel Keychain, e su macOS l'app
sandboxata non ci arriva senza un entitlement esplicito. I file
`macos/Runner/*.entitlements` contengono già:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.example.genuiFlutterCatania</string>
</array>
```

**Ma da solo non basta.** `$(AppIdentifierPrefix)` si risolve solo se il target
è firmato con un **Development Team**, e questo progetto è firmato ad-hoc
(`CODE_SIGN_IDENTITY = "-"`, nessun team). Serve un passaggio in Xcode:

1. apri `macos/Runner.xcworkspace`
2. target **Runner** → **Signing & Capabilities**
3. scegli un **Team** (basta un Apple ID gratuito)
4. verifica che ci sia la capability **Keychain Sharing**

> Su iOS non serve niente di tutto questo: il problema è solo del sandbox macOS.

#### Se hai fretta: fai la demo sul web

Il web non ha né il problema del Keychain né quello della firma, e per un talk
è anche più comodo da proiettare. Se macOS fa storie, **non è una battaglia che
devi vincere**:

```bash
flutter run -d chrome --dart-define=RECAPTCHA_SITE_KEY=...
```

#### Per il deploy web (una volta sola)

1. **Google Cloud Console** → crea una site key **reCAPTCHA Enterprise** per
   il dominio `andrea689.github.io`
   *(per il web è l'unico provider supportato — reCAPTCHA v3 non va bene)*
2. **Firebase Console** → App Check → registra l'app web con quella site key
3. Metti la site key in `RECAPTCHA_SITE_KEY`, come **variable** o come
   **secret** — la Action accetta entrambi (vedi [Deploy](#deploy))

---

## Eseguire

```bash
flutter run                              # mobile / desktop
flutter run -d chrome \
  --dart-define=RECAPTCHA_SITE_KEY=...   # web (serve la site key)
```

In caso di guasto sul palco, `--dart-define=SKIP_APP_CHECK=true` salta
l'inizializzazione di App Check per isolare il problema. **Non è una via
d'uscita**: il server di Firebase AI Logic rifiuta comunque la richiesta.
Serve solo a capire *dove* si rompe, mai in produzione.

### Il modello

Default: **`gemini-3.5-flash`** — stabile da maggio 2026, garantito fino ad
almeno maggio 2027.

Non è prudenza per inerzia. `gemini-3.8-flash` sarebbe il default raccomandato
da Firebase AI Logic e segue meglio le istruzioni (che per la UI generativa
conta: è ciò che tiene i widget dentro lo schema), ma è GA dal 2 settembre 2026
e si sta prendendo tutto il carico: in prova rispondeva **saturo**.

Un 503 *"model is overloaded"* durante una demo dal vivo non si ripara. Per il
palco vince la capacità disponibile, non il benchmark.

```bash
flutter run --dart-define=GEMINI_MODEL=gemini-3.8-flash   # se vuoi riprovarlo
```

> ⚠️ **Non usare `gemini-2.5-flash`**: si spegne il **16 ottobre 2026**.
> Tutti i modelli 2.5 chiudono nell'ottobre 2026. `gemini-3.5-flash` è
> garantito fino ad almeno maggio 2027 ed è l'alternativa prudente.

## Widget Previewer

Il catalogo è ispezionabile senza lanciare l'app: ogni widget ha delle
`@Preview` con dati finti, tutte nel gruppo **"Catalogo Etna"**.

- **VS Code / Android Studio**: pannello *Flutter Widget Preview* (parte da solo)
- **CLI**: `flutter widget-preview start`

Questo è anche il motivo per cui ogni voce del catalogo è divisa in due:

```
lib/catalog/event_card/
  event_card.dart        ← widget PURO + @Preview — non sa nulla di AI o JSON
  event_card_item.dart   ← CatalogItem: schema + parse JSON → widget
```

Il previewer gira su Flutter Web e non ha accesso a `dart:io` né ai plugin
nativi, quindi **non può inizializzare Firebase**. Separare il widget puro
dall'adapter lo rende previewabile — ed è comunque il modo giusto di
scriverli: il widget si golden-testa, l'adapter si testa sullo schema.

---

## Deploy

Ogni push su `main` pubblica su GitHub Pages tramite
[`.github/workflows/pages.yml`](.github/workflows/pages.yml):

```
andrea689.github.io/genui-flutter-catania/        → slide
andrea689.github.io/genui-flutter-catania/demo/   → app web
```

Se la build della demo fallisce, **le slide vengono pubblicate lo stesso** —
il giorno del talk contano quelle.

Per attivarlo sul repo:

1. **Settings → Pages** → Source: **GitHub Actions**
2. **Settings → Secrets and variables → Actions** → crea
   `RECAPTCHA_SITE_KEY` con la site key reCAPTCHA Enterprise

   Va bene sia come **variable** sia come **secret**: la Action legge
   `vars.RECAPTCHA_SITE_KEY || secrets.RECAPTCHA_SITE_KEY`.

   > La site key **è pubblica per design** — finisce nel bundle JS e chiunque
   > può leggerla dal sito — quindi non è un segreto e una *variable* è il
   > posto più onesto. Come *secret* funziona lo stesso, con un piccolo
   > svantaggio: GitHub maschera i secret nei log, quindi se un giorno devi
   > capire con che valore è stata fatta una build, vedi `***`.

   Se manca, la build di release **non parte** e mostra una schermata che
   spiega cosa fare: senza App Check ogni chiamata a Gemini prenderebbe 403.

## Slide

Sono in [`slides/`](slides/), fatte con reveal.js **vendorizzato in locale**:
niente CDN, partono anche senza rete. Il wifi dei meetup è quello che è.

```bash
open slides/index.html      # oppure servile: python3 -m http.server -d slides
```

- `S` → speaker notes · `Esc` → panoramica · `?print-pdf` in coda all'URL → export PDF

---

## Struttura

```
lib/
  catalog/          widget del catalogo, ognuno diviso in widget puro + adapter
  data/             repository INGV e modelli freezed
  conversation/     ConversationBloc e stati
slides/             deck reveal.js
docs/superpowers/   spec di design del talk
.github/workflows/  deploy su GitHub Pages
```

## Link

- [GenUI SDK per Flutter](https://docs.flutter.dev/ai/genui) — doc ufficiale
- [Package `genui`](https://pub.dev/packages/genui)
- [A2UI](https://flutter.dev/blog/new-updates-to-a2ui-and-flutters-genui-package) — il protocollo
- [App Check per Firebase AI Logic](https://firebase.google.com/docs/ai-logic/app-check)
- [Flutter Widget Previewer](https://docs.flutter.dev/tools/widget-previewer)
- [API INGV](https://webservices.ingv.it/)

## Licenza

MIT — vedi [LICENSE](LICENSE).
