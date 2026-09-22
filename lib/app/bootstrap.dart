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

/// Inizializza Firebase e App Check.
///
/// **App Check diventa obbligatorio per Firebase AI Logic dal 2 novembre
/// 2026.** Con l'enforcement attivo anche l'app in locale viene bloccata se il
/// debug token della macchina non e' registrato in console: da verificare la
/// sera prima del talk, non la mattina.
Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kSkipAppCheck) return;

  await FirebaseAppCheck.instance.activate(
    // Su web l'unico provider supportato in produzione e' reCAPTCHA
    // **Enterprise**, non v3. Senza site key si usa il debug provider, che
    // stampa il token in console: quello va registrato in Firebase.
    providerWeb: kRecaptchaSiteKey.isEmpty
        ? WebDebugProvider()
        : ReCaptchaEnterpriseProvider(kRecaptchaSiteKey),
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );
}
