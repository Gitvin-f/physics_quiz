import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/Symbol_to_String.dart';
import 'models/domain_graph.dart';
import 'models/modelData.dart';
import 'models/quizModel.dart';

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

    late final Question nq;
    if (mode == QuizMode.singleDomain) {
      nq = engine.singleDomain(
        domainId: kinematics.id,
        target: v1,
        givens: {v0, a, t},
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
                child: Text(
                  q.stem,
                  style: theme.textTheme.titleMedium,
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
}
