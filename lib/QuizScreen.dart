import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/Formulars_and_Variabels.dart';
import 'models/Symbol_to_String.dart';
import 'models/domain_graph.dart';
import 'models/modelData.dart';
import 'models/quizModel.dart';

class _SingleDomainConfig {
  final VarKey target;
  final Set<VarKey> givens;

  const _SingleDomainConfig({required this.target, required this.givens});
}

final Map<String, _SingleDomainConfig> _singleDomainConfigs = {
  kinematics.id: const _SingleDomainConfig(
    target: v1,
    givens: {v0, a, t},
  ),
  mechanicsEnergy.id: const _SingleDomainConfig(
    target: eKinetic,
    givens: {mBody, v1},
  ),
};

class PhysicsQuizScreen extends ConsumerStatefulWidget {
  const PhysicsQuizScreen({super.key});

  @override
  ConsumerState<PhysicsQuizScreen> createState() => _PhysicsQuizScreenState();
}

class _PhysicsQuizScreenState extends ConsumerState<PhysicsQuizScreen> {
  Question? _q;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _nextQuestion();
  }

  void _nextQuestion() {
    final engine = ref.read(engineProvider);
    final mode = ref.read(modeProvider);
    final registry = ref.read(registryProvider);
    var domainId = ref.read(selectedDomainProvider);

    late final Question nq;
    if (mode == QuizMode.singleDomain) {
      final configs = _singleDomainConfigs;
      var config = configs[domainId];
      if (config == null && configs.isNotEmpty) {
        final fallback = configs.entries.first;
        domainId = fallback.key;
        config = fallback.value;
        ref.read(selectedDomainProvider.notifier).state = domainId;
      }
      if (config == null) {
        throw StateError('Keine Domänenkonfiguration für Einzelaufgaben verfügbar');
      }
      nq = engine.singleDomain(
        domainId: domainId,
        target: config.target,
        givens: config.givens,
      );
    } else {
      nq = engine.transferTask(
        fromDomainId: kinematics.id,
        fromGivens: {v0, a, t},
        bridgeVar: v1,
        toDomainId: mechanicsEnergy.id,
        toGivens: {mBody},
        target: eKinetic,
        bridge: registry.bridgeFor(
          fromDomain: kinematics.id,
          fromVar: v1,
          toDomain: mechanicsEnergy.id,
          toVar: v1,
        ),
      );
    }
    setState(() {
      _q = nq;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = ref.watch(registryProvider);
    final fmt = ref.watch(formatProvider);
    final mode = ref.watch(modeProvider);
    final selectedDomainId = ref.watch(selectedDomainProvider);
    final domainConfigs = _singleDomainConfigs;
    final effectiveDomainId = domainConfigs.containsKey(selectedDomainId)
        ? selectedDomainId
        : (domainConfigs.keys.isNotEmpty ? domainConfigs.keys.first : selectedDomainId);
    final selectedDomainTitle = domainConfigs.containsKey(effectiveDomainId)
        ? registry.domain(effectiveDomainId).title
        : null;

    if (_q == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = _q!;
    final targetDef = registry.varDef(q.targetDomain, q.target);
    if (targetDef == null) {
      throw StateError('Zielvariable ${q.target} hat keine Domäne');
    }
    final unit = unitText(targetDef.unit);
    final d = fmt.d(q.target);
    final targetDomainTitle = registry.domain(q.targetDomain).title;
    final givensByDomain = <String, List<QuestionDatum>>{};
    for (final datum in q.givens) {
      givensByDomain.putIfAbsent(datum.domainId, () => []).add(datum);
    }
    final groupedGivens = givensByDomain.entries.toList();

    // Build formatted choices
    final choices = q.choices
        .map((c) => "${c.toStringAsFixed(d)} $unit")
        .toList();

    final isAnswered = _selectedIndex != null;
    final correctIndex = q.choices.indexOf(q.answer);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Physik-Quiz'),
        actions: [
          if (mode == QuizMode.singleDomain && domainConfigs.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Domäne wählen',
              initialValue: effectiveDomainId,
              onSelected: (value) {
                if (value != selectedDomainId) {
                  ref.read(selectedDomainProvider.notifier).state = value;
                  _nextQuestion();
                }
              },
              itemBuilder: (_) => [
                for (final entry in domainConfigs.entries)
                  PopupMenuItem(
                    value: entry.key,
                    child: Text(registry.domain(entry.key).title),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedDomainTitle != null)
                      Text(
                        selectedDomainTitle,
                        style: TextStyle(color: theme.colorScheme.onPrimary),
                      ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          PopupMenuButton<QuizMode>(
            tooltip: 'Aufgabentyp',
            initialValue: mode,
            onSelected: (value) {
              ref.read(modeProvider.notifier).state = value;
              _nextQuestion();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: QuizMode.singleDomain,
                child: Text('Eine Domäne'),
              ),
              PopupMenuItem(
                value: QuizMode.transfer,
                child: Text('Domänen-Transfer'),
              ),
            ],
          ),
          PopupMenuButton<int>(
            tooltip: 'Dezimalstellen',
            onSelected: (v) {
              ref.read(formatProvider.notifier).state =
                  QuizFormat(defaultDecimals: v, perVarDecimals: fmt.perVarDecimals);
              // Regenerate to apply new format
              _nextQuestion();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('0 Dezimalstellen')),
              PopupMenuItem(value: 1, child: Text('1 Dezimalstelle')),
              PopupMenuItem(value: 2, child: Text('2 Dezimalstellen')),
              PopupMenuItem(value: 3, child: Text('3 Dezimalstellen')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stem
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gesucht: ${symbol(q.target)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zieldomäne: $targetDomainTitle',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (q.stem.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        q.stem,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (groupedGivens.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Gegeben:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < groupedGivens.length; i++) ...[
                        Text(
                          registry.domain(groupedGivens[i].key).title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final datum in groupedGivens[i].value)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatGivenValue(datum, fmt, registry),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                          ],
                        ),
                        if (i < groupedGivens.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Options
            Expanded(
              child: GridView.builder(
                itemCount: choices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.1,
                ),
                itemBuilder: (_, i) {
                  final selected = _selectedIndex == i;
                  final isCorrectTile = isAnswered && i == correctIndex;

                  Color? bg;
                  Color? fg;
                  if (isAnswered) {
                    if (isCorrectTile) {
                      bg = theme.colorScheme.primaryContainer;
                      fg = theme.colorScheme.onPrimaryContainer;
                    } else if (selected) {
                      bg = theme.colorScheme.errorContainer;
                      fg = theme.colorScheme.onErrorContainer;
                    }
                  }

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bg, foregroundColor: fg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    onPressed: isAnswered ? null : () {
                      setState(() => _selectedIndex = i);
                      final ok = i == correctIndex;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? '✅ Richtig!' : '❌ Falsch')),
                      );
                      // Optionally: record stats via your statsProvider here
                    },
                    child: Text(choices[i], textAlign: TextAlign.center),
                  );
                },
              ),
            ),

            // Show correct numeric answer (formatted)
            if (isAnswered) ...[
              const SizedBox(height: 8),
              Text(
                "Richtig: ${q.answer.toStringAsFixed(d)} $unit  (${symbol(q.target)})",
                textAlign: TextAlign.center,
              ),
              if (q.bridgeDescription != null && q.bridgeDescription!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    q.bridgeDescription!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              for (final derived in q.derived)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _formatDatum(derived, fmt, registry),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            const SizedBox(height: 12),

            // Next button
            FilledButton.icon(
              onPressed: isAnswered ? _nextQuestion : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Weiter'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDatum(QuestionDatum datum, QuizFormat fmt, DomainRegistry registry) {
    final def = registry.varDef(datum.domainId, datum.key);
    final decimals = fmt.d(datum.key);
    final value = datum.value.toStringAsFixed(decimals);
    final unit = def != null ? unitText(def.unit) : '';
    final domainTitle = registry.domain(datum.domainId).title;
    final buffer = StringBuffer()
      ..write('$domainTitle: ${symbol(datum.key)} = $value');
    if (unit.isNotEmpty) {
      buffer.write(' $unit');
    }
    return buffer.toString();
  }

  String _formatGivenValue(
      QuestionDatum datum, QuizFormat fmt, DomainRegistry registry) {
    final def = registry.varDef(datum.domainId, datum.key);
    final decimals = fmt.d(datum.key);
    final value = datum.value.toStringAsFixed(decimals);
    final unit = def != null ? unitText(def.unit) : '';
    if (unit.isEmpty) {
      return '${symbol(datum.key)} = $value';
    }
    return '${symbol(datum.key)} = $value $unit';
  }
}
