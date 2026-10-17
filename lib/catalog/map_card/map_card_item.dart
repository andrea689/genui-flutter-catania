import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../seismic_event_schema.dart';
import 'map_card.dart';

/// The adapter between the A2UI protocol and [MapCard].
final CatalogItem mapCardItem = CatalogItem(
  name: 'MapCard',
  dataSchema: S.object(
    description:
        'Gli epicentri su una mappa. Usala quando la domanda riguarda DOVE '
        'sono avvenute le scosse, o per dare il quadro di uno sciame.',
    properties: {
      'title': S.string(
        description: 'Titolo della card, es. "Sciame del 18 settembre".',
      ),
      'events': S.list(
        description: 'Gli eventi da mostrare sulla mappa.',
        items: seismicEventSchema,
      ),
    },
    required: ['events'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    return MapCard(
      title: data['title'] as String?,
      events: parseSeismicEvents(data['events']),
      // Same round trip as the tap on EventCard: the epicenter goes back into
      // the conversation as a new turn. Without this the map is inert, and
      // DEMO 3 on stage produces nothing.
      onEventTap: (event) => itemContext.dispatchEvent(
        UserActionEvent(
          name: 'map_epicenter_tapped',
          surfaceId: itemContext.surfaceId,
          sourceComponentId: itemContext.id,
          context: {'eventId': event.eventId, 'place': event.place},
        ),
      ),
    );
  },
);
