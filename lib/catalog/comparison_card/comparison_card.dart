import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// Il riassunto di un periodo, pronto per il confronto.
///
/// Non prende la lista di eventi ma numeri gia' aggregati: l'aggregazione e'
/// una decisione, e la decisione la prende l'AI scegliendo cosa mettere nella
/// card. Il widget si limita a disegnarla.
class PeriodSummary {
  const PeriodSummary({
    required this.label,
    required this.eventCount,
    required this.maxMagnitude,
    required this.averageMagnitude,
  });

  final String label;
  final int eventCount;
  final double maxMagnitude;
  final double averageMagnitude;
}

/// Confronto fra due periodi di attivita' sismica.
///
/// Widget PURO.
class ComparisonCard extends StatelessWidget {
  const ComparisonCard({
    super.key,
    required this.current,
    required this.previous,
    this.title,
  });

  final PeriodSummary current;
  final PeriodSummary previous;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _PeriodColumn(summary: previous)),
                Container(
                  width: 1,
                  height: 118,
                  color: theme.colorScheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _PeriodColumn(summary: current, emphasised: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Delta(current: current, previous: previous),
          ],
        ),
      ),
    );
  }
}

class _PeriodColumn extends StatelessWidget {
  const _PeriodColumn({required this.summary, this.emphasised = false});

  final PeriodSummary summary;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasised
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summary.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${summary.eventCount}',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          summary.eventCount == 1 ? 'evento' : 'eventi',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _MiniStat(
          label: 'Magnitudo max',
          value: summary.maxMagnitude.toStringAsFixed(1),
          color: color,
        ),
        const SizedBox(height: 6),
        _MiniStat(
          label: 'Media',
          value: summary.averageMagnitude.toStringAsFixed(2),
          color: color,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Flexible + ellipsis: la colonna e' stretta e le metriche dei font
        // cambiano fra previewer, test e dispositivo.
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.current, required this.previous});

  final PeriodSummary current;
  final PeriodSummary previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = current.eventCount - previous.eventCount;
    final increased = difference > 0;
    final unchanged = difference == 0;

    final color = unchanged
        ? theme.colorScheme.onSurfaceVariant
        : (increased ? const Color(0xFFD1495B) : const Color(0xFF2A9D8F));

    final percentage = previous.eventCount == 0
        ? null
        : (difference / previous.eventCount * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            unchanged
                ? Icons.trending_flat
                : (increased ? Icons.trending_up : Icons.trending_down),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              unchanged
                  ? 'Stesso numero di eventi'
                  : '${difference.abs()} eventi in '
                        '${increased ? 'piu' : 'meno'}'
                        '${percentage == null ? '' : ' (${percentage.abs()}%)'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Preview -----------------------------------------------------------

const _august = PeriodSummary(
  label: 'Agosto 2026',
  eventCount: 48,
  maxMagnitude: 3.2,
  averageMagnitude: 1.74,
);

const _september = PeriodSummary(
  label: 'Settembre 2026',
  eventCount: 71,
  maxMagnitude: 4.3,
  averageMagnitude: 2.08,
);

const _quiet = PeriodSummary(
  label: 'Questa settimana',
  eventCount: 12,
  maxMagnitude: 2.1,
  averageMagnitude: 1.42,
);

@Preview(
  name: 'ComparisonCard — attivita in aumento',
  group: 'Catalogo Etna',
  size: Size(460, 320),
)
Widget comparisonCardIncrease() => const ComparisonCard(
  title: 'Settembre rispetto ad agosto',
  previous: _august,
  current: _september,
);

@Preview(
  name: 'ComparisonCard — attivita in aumento (dark)',
  group: 'Catalogo Etna',
  size: Size(460, 320),
  brightness: Brightness.dark,
)
Widget comparisonCardIncreaseDark() => const ComparisonCard(
  title: 'Settembre rispetto ad agosto',
  previous: _august,
  current: _september,
);

@Preview(
  name: 'ComparisonCard — attivita in calo',
  group: 'Catalogo Etna',
  size: Size(460, 320),
)
Widget comparisonCardDecrease() => const ComparisonCard(
  title: 'Questa settimana rispetto ad agosto',
  previous: _august,
  current: _quiet,
);
