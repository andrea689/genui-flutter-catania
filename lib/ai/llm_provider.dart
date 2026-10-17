/// Where the model's responses come from.
///
/// The choice only exists in debug: in release, i.e. on the published site,
/// [gemini] is always used.
enum LlmProvider {
  /// Gemini via Firebase AI Logic: the demo's real provider.
  gemini('Gemini'),

  /// The server on the same machine: the fallback if Gemini doesn't respond.
  local('Locale');

  const LlmProvider(this.label);

  /// The name shown in the AppBar menu.
  final String label;
}
