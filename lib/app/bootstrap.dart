import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// The reCAPTCHA Enterprise site key, injected at build time.
///
/// It's public by definition — it ends up in the JS bundle — but passing it
/// via `--dart-define` lets you rotate it without touching the code.
/// The empty default is harmless in debug, which falls back to the debug
/// provider.
const String kRecaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

/// If true, skips App Check activation entirely.
///
/// Useful for isolating problems: if the demo fails, this flag tells you in
/// one go whether App Check or the AI round trip is to blame.
/// **Never** in production: without App Check the key is exposed.
const bool kSkipAppCheck = bool.fromEnvironment('SKIP_APP_CHECK');

/// The App Check debug token, pinned at build time.
///
/// **Without it the token is regenerated on every launch**, and has to be
/// registered in the console again each time. The reason is that the debug
/// provider persists it in local storage tied to the installation:
///
/// - on **web** it's the browser storage, which is **per origin**. And
///   `flutter run -d chrome` picks a random port on every launch
///   (`localhost:56953`, then another), so every run is a new origin, finds
///   empty storage and generates a new token.
/// - on **macOS** it needs the Keychain, which isn't reachable without the
///   right entitlement: no persistence, a new token every time.
///
/// Pinning it here keeps the token the same: you register it **once** and
/// forget about it, on any port and after any reinstall.
/// It's not a secret — it only works for debug builds and only for tokens you
/// registered yourself — but there's no point committing it: pass it via
/// `--dart-define=APP_CHECK_DEBUG_TOKEN=...`.
const String kAppCheckDebugToken = String.fromEnvironment(
  'APP_CHECK_DEBUG_TOKEN',
  defaultValue: '',
);

/// Initializes Firebase and App Check.
///
/// **App Check becomes mandatory for Firebase AI Logic on November 2, 2026.**
/// With enforcement on, even the local app is blocked if the machine's debug
/// token isn't registered in the console: check it the evening before the
/// talk, not the morning of.
Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kSkipAppCheck) return;

  // Empty = let the provider generate one and print it to the console.
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

/// Picks the web provider.
///
/// **A release build must never fall back to the debug provider.**
/// It used to, and it shipped to production: CI built without a site key
/// (the repo variable wasn't set), the code picked the debug provider because
/// the key was empty, and the published site printed a debug token to the
/// console and then got a 403 on every call.
///
/// A configuration failure must be loud, not silent.
WebProvider _webProvider(String? debugToken) {
  if (kRecaptchaSiteKey.isNotEmpty) {
    // On web the only provider supported in production is reCAPTCHA
    // **Enterprise**, not v3.
    return ReCaptchaEnterpriseProvider(kRecaptchaSiteKey);
  }
  if (kDebugMode) {
    // Fine in development: it prints the token to the console, to register
    // once and then pin with --dart-define=APP_CHECK_DEBUG_TOKEN.
    return WebDebugProvider(debugToken: debugToken);
  }
  throw const AppCheckMisconfigured(
    'Build di release senza RECAPTCHA_SITE_KEY.\n\n'
    'App Check non può attivarsi e ogni chiamata a Gemini verrebbe '
    'rifiutata con 403.\n\n'
    'Per risolvere:\n'
    '1. crea una site key reCAPTCHA Enterprise per il dominio del sito\n'
    '2. registrala in Firebase Console -> App Check -> app web\n'
    '3. mettila nella repo variable RECAPTCHA_SITE_KEY\n'
    '   (Settings -> Secrets and variables -> Actions -> Variables)\n'
    '4. rilancia la GitHub Action',
  );
}

/// App Check can't be configured in this build.
///
/// Exists to show a readable message instead of a 403 in the console: people
/// opening the site from the talk's link shouldn't need DevTools to figure out
/// what's wrong.
class AppCheckMisconfigured implements Exception {
  const AppCheckMisconfigured(this.message);

  final String message;

  @override
  String toString() => 'AppCheckMisconfigured: $message';
}
