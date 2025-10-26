import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'Formulars_and_Variabels.dart';
import 'Symbol_to_String.dart';
import 'modelData.dart';

class QuizFormat {
  final int defaultDecimals;
  final Map<VarKey, int> perVarDecimals;

  const QuizFormat({this.defaultDecimals = 2, this.perVarDecimals = const {}});

  int d(VarKey k) => perVarDecimals[k] ?? defaultDecimals;
}

final kinEasyFormat = QuizFormat(
  defaultDecimals: 0,
  perVarDecimals: {a: 2, t: 1},
);

class Question {
  final String stem;
  final Map<VarKey, double> givens;
  final VarKey target;
  final double answer;
  final List<String> used;
  final List<double> choices;
  final QuizFormat format;

  const Question({
    required this.stem,
    required this.givens,
    required this.target,
    required this.answer,
    required this.used,
    required this.choices,
    required this.format,
  });
}

class QuestionEngine {
  final Domain dom;
  final QuizFormat fmt;
  final _r = Random();

  QuestionEngine(this.dom, this.fmt);

  double _sample(VarKey k) {
    final def = dom.vars[k];
    if (def == null) {
      throw StateError("Variable key $k not found in domain ${dom.id}");
    }
    final min = def.min;
    final max = def.max;
    return min + _r.nextDouble() * (max - min);
  }

  Question generate({required VarKey target, required Set<VarKey> givens}) {
    final f = dom.formulas.firstWhere(
      (fo) =>
          fo.solves.containsKey(target) &&
          fo.vars.difference({target}).every(givens.contains),
    );

    final m = <VarKey, double>{for (final g in givens) g: _sample(g)};

    // light guards:
    if (m[t]?.abs() case final x? when x < 0.2) m[t] = 1.0;

    final ans = f.solves[target]!(m);
    final choices = _choices(ans);

    final stem =
        "Gegeben: ${givens.map((k) {
          final d = fmt.d(k);
          final u = dom.vars[k]!.unit;
          return "${symbol(k)} = ${m[k]!.toStringAsFixed(d)} ${unitText(u)}";
        }).join(', ')}. Gesucht: ${symbol(target)}";

    return Question(
      stem: stem,
      givens: m,
      target: target,
      answer: ans,
      used: [f.id],
      choices: choices,
      format: fmt,
    );
  }

  List<double> _choices(double correct) {
    final s = <double>{correct};
    while (s.length < 4) {
      final jitter = 0.85 + _r.nextDouble() * 0.5;
      s.add(correct * jitter);
    }
    return s.toList()..shuffle(_r);
  }
}

final domainProvider = Provider<Domain>((_) => kinematics);
final formatProvider = StateProvider<QuizFormat>((_) => kinEasyFormat);
final engineProvider = Provider<QuestionEngine>((ref) {
  final dom = ref.watch(domainProvider);
  final fmt = ref.watch(formatProvider);
  return QuestionEngine(dom, fmt);
});
