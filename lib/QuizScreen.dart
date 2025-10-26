import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/Symbol_to_String.dart';
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
    // Example: solve v (v1) from {u, a, t}
    final nq = engine.generate(target: v1, givens: {v0, a, t});
    setState(() {
      _q = nq;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dom = ref.watch(domainProvider);
    final fmt = ref.watch(formatProvider);

    if (_q == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = _q!;
    final unit = unitText(dom.vars[q.target]!.unit);
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
}
