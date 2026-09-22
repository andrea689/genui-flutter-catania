import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../seismic_event_schema.dart';
import 'timeline_chart.dart';

/// L'adapter fra il protocollo A2UI e [TimelineChart].
final CatalogItem timelineChartItem = CatalogItem(
  name: 'TimelineChart',
  dataSchema: S.object(
    description:
        'L andamento della magnitudo nel tempo. Usala quando la domanda '
        'riguarda QUANDO sono avvenute le scosse, o l evoluzione di un '
        'periodo.',
    properties: {
      'title': S.string(description: 'Titolo della card.'),
      'events': S.list(
        description: 'Gli eventi da riportare sull asse temporale.',
        items: seismicEventSchema,
      ),
    },
    required: ['events'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    return TimelineChart(
      title: data['title'] as String?,
      events: parseSeismicEvents(data['events']),
    );
  },
);
