import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// La site key reCAPTCHA Enterprise, iniettata a build time.
///
/// E' pubblica per definizione — finisce nel bundle JS — ma passarla da
/// `--dart-define` permette di ruotarla senza toccare il codice.
/// Il default e' innocuo: senza key vera si ricade sul debug provider.
const String kRecaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

/// Se true, salta del tutto l'attivazione di App Check.
///
/// Serve a isolare i problemi: se la demo fallisce, questo flag dice in un
/// colpo solo se la colpa e' di App Check o del giro AI.
/// **Mai** in produzione: senza App Check la chiave e' esposta.
const bool kSkipAppCheck = bool.fromEnvironment('SKIP_APP_CHECK');

/// Il debug token di App Check, fissato a build time.
///
/// **Senza questo il token viene rigenerato a ogni avvio**, e va registrato di
/// nuovo in console ogni volta. Il motivo e' che il provider di debug lo
/// persiste in una memoria locale legata all'installazione:
///
/// - su **web** e' lo storage del browser, che e' **per origine**. E
///   `flutter run -d chrome` sceglie una porta a caso a ogni avvio
///   (`localhost:56953`, poi un'altra), quindi ogni run e' un'origine nuova,
///   trova lo storage vuoto e genera un token nuovo.
/// - su **macOS** serve il Keychain, che senza l'entitlement giusto non e'
///   raggiungibile: niente persistenza, token nuovo ogni volta.
///
/// Fissandolo qui il token e' sempre lo stesso: lo registri **una volta** e
/// non ci pensi piu', su qualunque porta e dopo qualunque reinstallazione.
/// Non e' un segreto — vale solo per le build di debug e solo per i token che
/// hai registrato tu — ma non ha senso committarlo: passalo da
/// `--dart-define=APP_CHECK_DEBUG_TOKEN=...`.
const String kAppCheckDebugToken = String.fromEnvironment(
  'APP_CHECK_DEBUG_TOKEN',
  defaultValue: '',
);

/// Inizializza Firebase e App Check.
///
/// **App Check diventa obbligatorio per Firebase AI Logic dal 2 novembre
/// 2026.** Con l'enforcement attivo anche l'app in locale viene bloccata se il
/// debug token della macchina non e' registrato in console: da verificare la
/// sera prima del talk, non la mattina.
Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kSkipAppCheck) return;

  // Vuoto = lascia che il provider ne generi uno e lo stampi in console.
  final debugToken = kAppCheckDebugToken.isEmpty ? null : kAppCheckDebugToken;

  await FirebaseAppCheck.instance.activate(
    providerWeb: _webProvider(debugToken),
    providerAndroid: kDebugMode
        ? AndroidDebugProvider(debugToken: debugToken)
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? AppleDebugProvider(debugToken: debugToken)
        : const AppleAppAttestProvider(),
  );
}

/// Sceglie il provider web.
///
/// **Una build di release non deve mai ricadere sul provider di debug.**
/// Ci ricadeva, ed e' andata in produzione: la CI buildava senza site key
/// (la repo variable non era impostata), il codice sceglieva il provider di
/// debug perche' la key era vuota, e il sito pubblicato stampava un debug
/// token in console per poi prendere 403 su ogni chiamata.
///
/// Un guasto di configurazione deve essere rumoroso, non silenzioso.
WebProvider _webProvider(String? debugToken) {
  if (kRecaptchaSiteKey.isNotEmpty) {
    // Su web l'unico provider supportato in produzione e' reCAPTCHA
    // **Enterprise**, non v3.
    return ReCaptchaEnterpriseProvider(kRecaptchaSiteKey);
  }
  if (kDebugMode) {
    // In sviluppo va bene: stampa il token in console, da registrare una
    // volta e poi fissare con --dart-define=APP_CHECK_DEBUG_TOKEN.
    return WebDebugProvider(debugToken: debugToken);
  }
  throw const AppCheckMisconfigured(
    'Build di release senza RECAPTCHA_SITE_KEY.\n\n'
    'App Check non puo attivarsi e ogni chiamata a Gemini verrebbe '
    'rifiutata con 403.\n\n'
    'Per risolvere:\n'
    '1. crea una site key reCAPTCHA Enterprise per il dominio del sito\n'
    '2. registrala in Firebase Console -> App Check -> app web\n'
    '3. mettila nella repo variable RECAPTCHA_SITE_KEY\n'
    '   (Settings -> Secrets and variables -> Actions -> Variables)\n'
    '4. rilancia la GitHub Action',
  );
}

/// App Check non e' configurabile in questa build.
///
/// Esiste per dare un messaggio leggibile invece di un 403 in console: chi
/// apre il sito dal link del talk non deve aprire i DevTools per capire.
class AppCheckMisconfigured implements Exception {
  const AppCheckMisconfigured(this.message);

  final String message;

  @override
  String toString() => 'AppCheckMisconfigured: $message';
}
