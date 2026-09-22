import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:genui/genui.dart' as genui;

import '../ai/etna_agent.dart';

part 'conversation_bloc.freezed.dart';

/// Cosa puo' succedere in una conversazione.
///
/// I primi due eventi arrivano dalla UI, gli altri dal package `genui`:
/// il bloc e' il punto in cui i due mondi si incontrano.
@freezed
sealed class EtnaConversationEvent with _$EtnaConversationEvent {
  /// L'utente ha inviato un messaggio.
  const factory EtnaConversationEvent.messageSent(String text) = MessageSent;

  /// Il package ha iniziato ad aspettare il modello.
  const factory EtnaConversationEvent.thinkingStarted() = ThinkingStarted;

  /// Il modello ha composto una nuova surface.
  const factory EtnaConversationEvent.surfaceAppeared(String surfaceId) =
      SurfaceAppeared;

  /// Una surface e' stata rimossa.
  const factory EtnaConversationEvent.surfaceVanished(String surfaceId) =
      SurfaceVanished;

  /// E' arrivato testo in chiaro dal modello.
  const factory EtnaConversationEvent.textReceived(String text) = TextReceived;

  /// Qualcosa e' andato storto.
  const factory EtnaConversationEvent.failed(String message) =
      ConversationFailed;
}

/// Lo stato della conversazione.
@freezed
sealed class EtnaConversationState with _$EtnaConversationState {
  /// Niente e' ancora successo.
  const factory EtnaConversationState.initial() = ConversationInitial;

  /// In attesa del modello. Le surface gia' presenti restano a schermo.
  const factory EtnaConversationState.thinking({
    @Default(<String>[]) List<String> surfaceIds,
    @Default('') String text,
  }) = ConversationThinking;

  /// Il modello ha risposto: ci sono surface da renderizzare.
  const factory EtnaConversationState.surfaces({
    required List<String> surfaceIds,
    @Default('') String text,
  }) = ConversationSurfaces;

  /// Errore, con le surface gia' composte ancora a schermo.
  const factory EtnaConversationState.error({
    required String message,
    @Default(<String>[]) List<String> surfaceIds,
  }) = ConversationErrorState;

  const EtnaConversationState._();

  /// Le surface attive, qualunque sia lo stato.
  List<String> get activeSurfaceIds => switch (this) {
    ConversationInitial() => const [],
    ConversationThinking(:final surfaceIds) => surfaceIds,
    ConversationSurfaces(:final surfaceIds) => surfaceIds,
    ConversationErrorState(:final surfaceIds) => surfaceIds,
  };

  /// L'ultimo testo in chiaro del modello.
  String get assistantText => switch (this) {
    ConversationInitial() => '',
    ConversationThinking(:final text) => text,
    ConversationSurfaces(:final text) => text,
    ConversationErrorState() => '',
  };

  /// Se true, la UI mostra l'indicatore di attesa.
  bool get isThinking => this is ConversationThinking;
}

/// Possiede [Conversation] e [SurfaceController] e traduce i loro eventi in
/// stati.
///
/// La doc ufficiale fa tutto questo con `setState` in uno `StatefulWidget`.
/// Funziona, ma nasconde il punto: la GenUI e' uno stream di eventi come un
/// altro, e si integra in un'architettura vera senza trattamenti speciali.
class ConversationBloc
    extends Bloc<EtnaConversationEvent, EtnaConversationState> {
  ConversationBloc(this.agent) : super(const EtnaConversationState.initial()) {
    on<MessageSent>(_onMessageSent);
    on<ThinkingStarted>(_onThinkingStarted);
    on<SurfaceAppeared>(_onSurfaceAppeared);
    on<SurfaceVanished>(_onSurfaceVanished);
    on<TextReceived>(_onTextReceived);
    on<ConversationFailed>(_onFailed);

    _subscription = agent.conversation.events.listen(_onGenUiEvent);
  }

  final EtnaAgent agent;
  late final StreamSubscription<genui.ConversationEvent> _subscription;

  /// Il testo in chiaro si accumula a chunk: va concatenato, non sostituito.
  final StringBuffer _text = StringBuffer();

  /// Traduce gli eventi del package in eventi del bloc.
  void _onGenUiEvent(genui.ConversationEvent event) {
    switch (event) {
      case genui.ConversationWaiting():
        add(const EtnaConversationEvent.thinkingStarted());
      case genui.ConversationSurfaceAdded(:final surfaceId):
        add(EtnaConversationEvent.surfaceAppeared(surfaceId));
      case genui.ConversationSurfaceRemoved(:final surfaceId):
        add(EtnaConversationEvent.surfaceVanished(surfaceId));
      case genui.ConversationContentReceived(:final text):
        add(EtnaConversationEvent.textReceived(text));
      case genui.ConversationError(:final error):
        add(EtnaConversationEvent.failed(error.toString()));
      default:
        break;
    }
  }

  Future<void> _onMessageSent(
    MessageSent event,
    Emitter<EtnaConversationState> emit,
  ) async {
    _text.clear();
    emit(EtnaConversationState.thinking(surfaceIds: state.activeSurfaceIds));
    // `sendRequest` inoltra a onSend, dove gira il tool loop. Gli eventi di
    // ritorno rientrano dal listener qui sopra.
    await agent.conversation.sendRequest(genui.ChatMessage.user(event.text));
  }

  void _onThinkingStarted(
    ThinkingStarted event,
    Emitter<EtnaConversationState> emit,
  ) {
    emit(EtnaConversationState.thinking(surfaceIds: state.activeSurfaceIds));
  }

  void _onSurfaceAppeared(
    SurfaceAppeared event,
    Emitter<EtnaConversationState> emit,
  ) {
    if (state.activeSurfaceIds.contains(event.surfaceId)) return;
    emit(
      EtnaConversationState.surfaces(
        surfaceIds: [...state.activeSurfaceIds, event.surfaceId],
        text: _text.toString(),
      ),
    );
  }

  void _onSurfaceVanished(
    SurfaceVanished event,
    Emitter<EtnaConversationState> emit,
  ) {
    emit(
      EtnaConversationState.surfaces(
        surfaceIds: state.activeSurfaceIds
            .where((id) => id != event.surfaceId)
            .toList(),
        text: _text.toString(),
      ),
    );
  }

  void _onTextReceived(
    TextReceived event,
    Emitter<EtnaConversationState> emit,
  ) {
    _text.write(event.text);
    final text = _text.toString();
    emit(
      state.isThinking
          ? EtnaConversationState.thinking(
              surfaceIds: state.activeSurfaceIds,
              text: text,
            )
          : EtnaConversationState.surfaces(
              surfaceIds: state.activeSurfaceIds,
              text: text,
            ),
    );
  }

  void _onFailed(
    ConversationFailed event,
    Emitter<EtnaConversationState> emit,
  ) {
    emit(
      EtnaConversationState.error(
        message: event.message,
        surfaceIds: state.activeSurfaceIds,
      ),
    );
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
