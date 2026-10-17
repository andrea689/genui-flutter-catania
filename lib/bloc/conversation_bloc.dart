import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:genui/genui.dart' as genui;

import '../ai/etna_agent.dart';

part 'conversation_bloc.freezed.dart';

/// One chat turn: the user's message and the model's reply.
///
/// Of the reply, the bloc keeps the plain text and the surface **ids**.
/// Only the ids: widget state stays in the `SurfaceController`.
@freezed
abstract class ChatTurn with _$ChatTurn {
  const factory ChatTurn({
    /// What the user wrote. Null if the turn was started by a tap on a card,
    /// which reaches the model without going through the bloc.
    String? userMessage,

    /// The model's plain text, without the A2UI blocks.
    @Default('') String text,

    /// The surfaces composed in reply to this turn.
    @Default(<String>[]) List<String> surfaceIds,
  }) = _ChatTurn;
}

/// What can happen in a conversation.
///
/// The first event comes from the UI, the others from the `genui` package:
/// the bloc is where the two worlds meet.
@freezed
sealed class EtnaConversationEvent with _$EtnaConversationEvent {
  const factory EtnaConversationEvent.messageSent(String text) = MessageSent;

  /// The package started waiting for the model.
  const factory EtnaConversationEvent.thinkingStarted() = ThinkingStarted;

  /// The model composed a new surface.
  const factory EtnaConversationEvent.surfaceAppeared(String surfaceId) =
      SurfaceAppeared;

  const factory EtnaConversationEvent.surfaceVanished(String surfaceId) =
      SurfaceVanished;

  /// Plain text arrived from the model.
  const factory EtnaConversationEvent.textReceived(String text) = TextReceived;

  /// The model finished replying.
  const factory EtnaConversationEvent.replyCompleted() = ReplyCompleted;

  const factory EtnaConversationEvent.failed(String message) =
      ConversationFailed;
}

/// The conversation state.
///
/// Every variant carries the whole chat, turn by turn: changing state doesn't
/// erase anything already on screen.
@freezed
sealed class EtnaConversationState with _$EtnaConversationState {
  const factory EtnaConversationState.initial({
    @Default(<ChatTurn>[]) List<ChatTurn> turns,
  }) = ConversationInitial;

  /// Waiting for the model.
  const factory EtnaConversationState.thinking({
    required List<ChatTurn> turns,
  }) = ConversationThinking;

  /// The model has replied, or has already composed at least one surface.
  const factory EtnaConversationState.surfaces({
    required List<ChatTurn> turns,
  }) = ConversationSurfaces;

  /// An error, with the chat so far still on screen.
  const factory EtnaConversationState.error({
    required String message,
    required List<ChatTurn> turns,
  }) = ConversationErrorState;

  const EtnaConversationState._();

  /// The active surfaces, across all turns.
  List<String> get activeSurfaceIds => [
    for (final turn in turns) ...turn.surfaceIds,
  ];

  /// The plain text of the last turn.
  String get assistantText => turns.lastOrNull?.text ?? '';

  /// If true, the UI shows the waiting indicator.
  bool get isThinking => this is ConversationThinking;
}

/// Owns [Conversation] and [SurfaceController] and turns their events into
/// states.
///
/// The official docs do all this with `setState` in a `StatefulWidget`.
/// It works, but it hides the point: GenUI is a stream of events like any
/// other, and it fits into a real architecture with no special treatment.
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

  /// The last `isWaiting` read from the [genui.Conversation] state.
  bool _waiting = false;

  /// Translates the package's events into bloc events.
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

  /// The end of a reply isn't a package event: it's read from the package's
  /// state, when `isWaiting` goes back to false.
  void _onGenUiState() {
    final waiting = agent.conversation.state.value.isWaiting;
    if (_waiting && !waiting) add(const EtnaConversationEvent.replyCompleted());
    _waiting = waiting;
  }

  Future<void> _onMessageSent(
    MessageSent event,
    Emitter<EtnaConversationState> emit,
  ) async {
    // The message shows up in the chat right away, before the model replies.
    emit(
      EtnaConversationState.thinking(
        turns: [
          ...state.turns,
          ChatTurn(userMessage: event.text),
        ],
      ),
    );
    // `sendRequest` forwards to onSend, where the tool loop runs. The
    // resulting events come back through the listener above.
    await agent.conversation.sendRequest(genui.ChatMessage.user(event.text));
  }

  void _onThinkingStarted(
    ThinkingStarted event,
    Emitter<EtnaConversationState> emit,
  ) {
    // A typed message has already opened its turn in _onMessageSent. If we're
    // not waiting, the request came from a tap on a card: the new turn has no
    // user message to show.
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
    // Plain text arrives in chunks: it must be appended, not replaced.
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
    // A text-only reply composes no surface: without this the spinner would
    // stay on.
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

  /// The chat turns, with the last one updated by [update].
  List<ChatTurn> _updateLastTurn(ChatTurn Function(ChatTurn turn) update) {
    final turns = [...state.turns];
    final last = turns.isEmpty ? const ChatTurn() : turns.removeLast();
    return [...turns, update(last)];
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    agent.conversation.state.removeListener(_onGenUiState);
    // The bloc owns the agent: whoever recreates it, like the provider
    // switch, doesn't have to remember to release the old one. If a reply is
    // still in progress, the agent waits for it to finish.
    agent.disposeWhenIdle();
    return super.close();
  }
}
