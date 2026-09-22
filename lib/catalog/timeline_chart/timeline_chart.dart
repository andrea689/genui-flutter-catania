import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../domain/seismic_event.dart';
import '../etna_theme.dart';

/// La magnitudo nel tempo: una stanghetta per scossa, colorata per fascia.
///
/// Widget PURO, disegnato con [CustomPainter]: nessuna dipendenza da librerie
/// di grafici, quindi nulla che possa rompersi nel previewer o nella build web.
class TimelineChart extends StatelessWidget {
  const TimelineChart({super.key, required this.events, this.title});

  final List<SeismicEvent> events;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              sorted.isEmpty
                  ? 'Nessun evento nel periodo'
                  : '${sorted.length} eventi · '
                        '${formatEtnaDate(sorted.first.time)} – '
                        '${formatEtnaDate(sorted.last.time)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 170,
              child: sorted.isEmpty
                  ? const SizedBox.shrink()
                  : CustomPaint(
                      size: Size.infinite,
                      painter: _TimelinePainter(
                        events: sorted,
                        brightness: theme.brightness,
                        gridColor: theme.colorScheme.outlineVariant,
                        labelStyle:
                            theme.textTheme.labelSmall ??
                            const TextStyle(fontSize: 11),
                        labelColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.events,
    required this.brightness,
    required this.gridColor,
    required this.labelStyle,
    required this.labelColor,
  });

  final List<SeismicEvent> events;
  final Brightness brightness;
  final Color gridColor;
  final TextStyle labelStyle;
  final Color labelColor;

  static const double _leftGutter = 26;
  static const double _bottomGutter = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _leftGutter;
    final plotHeight = size.height - _bottomGutter;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final maxMagnitude = events
        .map((e) => e.magnitude)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, 8.0);
    // Arrotonda all'intero superiore, cosi' l'asse non taglia la punta.
    final axisMax = maxMagnitude.ceilToDouble();

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Griglia orizzontale + etichette di magnitudo.
    for (var step = 0; step <= axisMax.toInt(); step++) {
      final y = plotHeight - (step / axisMax) * plotHeight;
      canvas.drawLine(Offset(_leftGutter, y), Offset(size.width, y), gridPaint);
      _text(canvas, '$step', Offset(0, y - 7), align: TextAlign.right);
    }

    final firstMs = events.first.time.millisecondsSinceEpoch;
    final lastMs = events.last.time.millisecondsSinceEpoch;
    final span = (lastMs - firstMs).abs();

    for (final event in events) {
      final ratio = span == 0
          ? 0.5
          : (event.time.millisecondsSinceEpoch - firstMs) / span;
      // Margine interno, cosi' le stanghette agli estremi non toccano i bordi.
      final x = _leftGutter + 10 + ratio * (plotWidth - 20);
      final barHeight = (event.magnitude / axisMax) * plotHeight;
      final accent = event.severity.color(brightness);

      canvas.drawLine(
        Offset(x, plotHeight),
        Offset(x, plotHeight - barHeight),
        Paint()
          ..color = accent
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x, plotHeight - barHeight),
        4,
        Paint()..color = accent,
      );
    }

    // Etichette temporali: solo estremi, per non affollare l'asse.
    _text(
      canvas,
      formatEtnaDate(events.first.time),
      Offset(_leftGutter + 4, plotHeight + 6),
    );
    if (events.length > 1) {
      _text(
        canvas,
        formatEtnaDate(events.last.time),
        Offset(size.width - 44, plotHeight + 6),
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: labelStyle.copyWith(color: labelColor),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: 40);
    painter.paint(
      canvas,
      align == TextAlign.right
          ? Offset(offset.dx + (20 - painter.width), offset.dy)
          : offset,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) =>
      oldDelegate.events != events || oldDelegate.brightness != brightness;
}

// --- Preview -----------------------------------------------------------

final _week = <SeismicEvent>[
  for (final (index, magnitude) in const [
    1.4,
    2.1,
    1.8,
    4.3,
    3.1,
    2.4,
    1.9,
    2.8,
    1.2,
    3.6,
  ].indexed)
    SeismicEvent(
      eventId: 'demo-$index',
      time: DateTime.utc(2026, 9, 15).add(Duration(hours: index * 17)),
      magnitude: magnitude,
      magnitudeType: 'ML',
      place: 'Area etnea',
      latitude: 37.70 + index * 0.005,
      longitude: 15.00 + index * 0.004,
      depthKm: 3 + index.toDouble(),
    ),
];

@Preview(
  name: 'TimelineChart — settimana',
  group: 'Catalogo Etna',
  size: Size(460, 300),
)
Widget timelineChartWeek() =>
    TimelineChart(title: 'Magnitudo negli ultimi 7 giorni', events: _week);

@Preview(
  name: 'TimelineChart — settimana (dark)',
  group: 'Catalogo Etna',
  size: Size(460, 300),
  brightness: Brightness.dark,
)
Widget timelineChartWeekDark() =>
    TimelineChart(title: 'Magnitudo negli ultimi 7 giorni', events: _week);

@Preview(
  name: 'TimelineChart — evento singolo',
  group: 'Catalogo Etna',
  size: Size(460, 300),
)
Widget timelineChartSingle() =>
    TimelineChart(title: 'Un solo evento', events: [_week.first]);

@Preview(
  name: 'TimelineChart — vuoto',
  group: 'Catalogo Etna',
  size: Size(460, 300),
)
Widget timelineChartEmpty() =>
    const TimelineChart(title: 'Ultime 24 ore', events: <SeismicEvent>[]);
