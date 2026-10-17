import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../seismic_event_schema.dart';
import 'event_card.dart';

/// The adapter between the A2UI protocol and [EventCard].
///
/// It knows about JSON and schemas. It knows nothing about pixels: those live
/// in `event_card.dart`, which in turn knows nothing about any of this.
final CatalogItem eventCardItem = CatalogItem(
  name: 'EventCard',
  dataSchema: S.object(
    description:
        'Il dettaglio di UNA singola scossa. Usala quando l\'utente chiede '
        'di un evento specifico, per esempio "la scossa più forte".',
    properties: {'event': seismicEventSchema},
    required: ['event'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final event = parseSeismicEvent(data['event']! as Map<String, Object?>);

    return EventCard(
      event: event,
      // The tap goes back into the conversation: it's DEMO 3 of the talk.
      // The event bubbles up to the SurfaceController, which queues it as a
      // new turn for the model.
      onTap: () => itemContext.dispatchEvent(
        UserActionEvent(
          name: 'event_card_tapped',
          surfaceId: itemContext.surfaceId,
          sourceComponentId: itemContext.id,
          context: {'eventId': event.eventId, 'place': event.place},
        ),
      ),
    );
  },
);
