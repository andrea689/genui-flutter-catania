import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../seismic_event_schema.dart';
import 'event_card.dart';

/// L'adapter fra il protocollo A2UI e [EventCard].
///
/// Sa di JSON e di schemi. Non sa nulla di pixel: quelli stanno in
/// `event_card.dart`, che a sua volta non sa nulla di tutto questo.
final CatalogItem eventCardItem = CatalogItem(
  name: 'EventCard',
  dataSchema: S.object(
    description:
        'Il dettaglio di UNA singola scossa. Usala quando l utente chiede '
        'di un evento specifico, per esempio "la scossa piu forte".',
    properties: {'event': seismicEventSchema},
    required: ['event'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final event = parseSeismicEvent(data['event']! as Map<String, Object?>);

    return EventCard(
      event: event,
      // Il tap rientra nella conversazione: e' la DEMO 3 del talk.
      // L'evento risale al SurfaceController, che lo rimette in coda come
      // nuovo turno verso il modello.
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
