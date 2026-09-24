import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:genui/genui.dart' as genui;

import '../ai/etna_agent.dart';

part 'conversation_bloc.freezed.dart';

/// Un giro della chat: il messaggio dell'utente e la risposta del modello.
///
/// Della risposta il bloc tiene il testo in chiaro e gli **id** delle surface.
/// Solo gli id: lo stato dei widget resta nel `SurfaceController`.
@freezed
abstract class ChatTurn with _$ChatTurn {
  const factory ChatTurn({
    /// Quello che ha scritto l'utente. Null se il giro l'ha aperto un tap su
    /// una card, che arriva al modello senza passare dal bloc.
    String? userMessage,

    /// Il testo in chiaro del modello, senza i blocchi A2UI.
    @Default('') String text,

    /// Le surface composte in risposta a questo giro.
    @Default(<String>[]) List<String> surfaceIds,
  }) = _ChatTurn;
}

/// Cosa puo' succedere in una conversazione.
///
/// Il primo evento arriva dalla UI, gli altri dal package `genui`:
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

  /// Il modello ha finito di rispondere.
  const factory EtnaConversationEvent.replyCompleted() = ReplyCompleted;

  /// Qualcosa e' andato storto.
  const factory EtnaConversationEvent.failed(String message) =
      ConversationFailed;
}

/// Lo stato della conversazione.
///
/// Ogni variante porta la chat intera, giro per giro: cambiare stato non
/// cancella niente di quello che e' gia' a schermo.
@freezed
sealed class EtnaConversationState with _$EtnaConversationState {
  /// Niente e' ancora successo: la chat e' vuota.
  const factory EtnaConversationState.initial({
    @Default(<ChatTurn>[]) List<ChatTurn> turns,
  }) = ConversationInitial;

  /// In attesa del modello.
  const factory EtnaConversationState.thinking({
    required List<ChatTurn> turns,
  }) = ConversationThinking;

  /// Il modello ha risposto, o ha gia' composto almeno una surface.
  const factory EtnaConversationState.surfaces({
    required List<ChatTurn> turns,
  }) = ConversationSurfaces;

  /// Errore, con la chat fin qui ancora a schermo.
  const factory EtnaConversationState.error({
    required String message,
    required List<ChatTurn> turns,
  }) = ConversationErrorState;

  const EtnaConversationState._();

  /// Le surface attive, di tutti i giri.
  List<String> get activeSurfaceIds => [
    for (final turn in turns) ...turn.surfaceIds,
  ];

  /// Il testo in chiaro dell'ultimo giro.
  String get assistantText => turns.lastOrNull?.text ?? '';

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
    on<ReplyCompleted>(_onReplyCompleted);
    on<ConversationFailed>(_onFailed);

    _subscription = agent.conversation.events.listen(_onGenUiEvent);
    agent.conversation.state.addListener(_onGenUiState);
  }

  final EtnaAgent agent;
  late final StreamSubscription<genui.ConversationEvent> _subscription;

  /// L'ultimo `isWaiting` letto dallo stato della [genui.Conversation].
  bool _waiting = false;

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

  /// La fine di una risposta non e' un evento del package: si legge dal suo
  /// stato, quando `isWaiting` torna false.
  void _onGenUiState() {
    final waiting = agent.conversation.state.value.isWaiting;
    if (_waiting && !waiting) add(const EtnaConversationEvent.replyCompleted());
    _waiting = waiting;
  }

  Future<void> _onMessageSent(
    MessageSent event,
    Emitter<EtnaConversationState> emit,
  ) async {
    // Il messaggio entra in chat subito, prima che il modello risponda.
    emit(
      EtnaConversationState.thinking(
        turns: [
          ...state.turns,
          ChatTurn(userMessage: event.text),
        ],
      ),
    );
    // `sendRequest` inoltra a onSend, dove gira il tool loop. Gli eventi di
    // ritorno rientrano dal listener qui sopra.
    await agent.conversation.sendRequest(genui.ChatMessage.user(event.text));
  }

  void _onThinkingStarted(
    ThinkingStarted event,
    Emitter<EtnaConversationState> emit,
  ) {
    // Un messaggio scritto ha gia' aperto il suo giro in _onMessageSent. Se
    // non si sta aspettando, la richiesta e' partita da un tap su una card:
    // il giro nuovo non ha un messaggio dell'utente da mostrare.
    if (state.isThinking) return;
    emit(
      EtnaConversationState.thinking(turns: [...state.turns, const ChatTurn()]),
    );
  }

  void _onSurfaceAppeared(
    SurfaceAppeared event,
    Emitter<EtnaConversationState> emit,
  ) {
    if (state.activeSurfaceIds.contains(event.surfaceId)) return;
    emit(
      EtnaConversationState.surfaces(
        turns: _updateLastTurn(
          (turn) =>
              turn.copyWith(surfaceIds: [...turn.surfaceIds, event.surfaceId]),
        ),
      ),
    );
  }

  void _onSurfaceVanished(
    SurfaceVanished event,
    Emitter<EtnaConversationState> emit,
  ) {
    emit(
      state.copyWith(
        turns: [
          for (final turn in state.turns)
            turn.copyWith(
              surfaceIds: turn.surfaceIds
                  .where((id) => id != event.surfaceId)
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _onTextReceived(
    TextReceived event,
    Emitter<EtnaConversationState> emit,
  ) {
    // Il testo in chiaro arriva a chunk: va concatenato, non sostituito.
    emit(
      state.copyWith(
        turns: _updateLastTurn(
          (turn) => turn.copyWith(text: turn.text + event.text),
        ),
      ),
    );
  }

  void _onReplyCompleted(
    ReplyCompleted event,
    Emitter<EtnaConversationState> emit,
  ) {
    // Una risposta di solo testo non compone surface: senza questo lo
    // spinner resterebbe acceso.
    if (state.isThinking) {
      emit(EtnaConversationState.surfaces(turns: state.turns));
    }
  }

  void _onFailed(
    ConversationFailed event,
    Emitter<EtnaConversationState> emit,
  ) {
    emit(
      EtnaConversationState.error(message: event.message, turns: state.turns),
    );
  }

  /// I giri della chat, con l'ultimo aggiornato da [update].
  List<ChatTurn> _updateLastTurn(ChatTurn Function(ChatTurn turn) update) {
    final turns = [...state.turns];
    final last = turns.isEmpty ? const ChatTurn() : turns.removeLast();
    return [...turns, update(last)];
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    agent.conversation.state.removeListener(_onGenUiState);
    return super.close();
  }
}
