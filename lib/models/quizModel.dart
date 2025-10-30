import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'Formulars_and_Variabels.dart';
import 'Symbol_to_String.dart';
import 'domain_graph.dart';
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

enum QuizMode { singleDomain, transfer }

class QuestionDatum {
  final VarKey key;
  final String domainId;
  final double value;

  const QuestionDatum({
    required this.key,
    required this.domainId,
    required this.value,
  });
}

class Question {
  final String stem;
  final List<QuestionDatum> givens;
  final VarKey target;
  final String targetDomain;
  final double answer;
  final List<String> used;
  final List<double> choices;
  final QuizFormat format;
  final Set<String> domainsInvolved;
  final List<QuestionDatum> derived;
  final String? bridgeDescription;

  Question({
    required this.stem,
    required this.givens,
    required this.target,
    required this.targetDomain,
    required this.answer,
    required this.used,
    required this.choices,
    required this.format,
    required this.domainsInvolved,
    this.derived = const [],
    this.bridgeDescription,
  });

  Iterable<QuestionDatum> byDomain(String domainId) sync* {
    for (final g in givens) {
      if (g.domainId == domainId) {
        yield g;
      }
    }
  }
}

class QuestionEngine {
  final DomainRegistry registry;
  final QuizFormat fmt;
  final _r = Random();

  QuestionEngine(this.registry, this.fmt);

  double _sample(String domainId, VarKey k) {
    final def = registry.varDef(domainId, k);
    if (def == null) {
      throw StateError('Variable key $k not found in domain $domainId');
    }
    final min = def.min;
    final max = def.max;
    final raw = min + _r.nextDouble() * (max - min);
    final scale = pow(10, def.decimals).toDouble();
    return (raw * scale).round() / scale;
  }

  FormulaDef _findFormula(Domain dom, VarKey target, Set<VarKey> givens) {
    return dom.formulas.firstWhere(
      (fo) => fo.solves.containsKey(target) &&
          fo.vars.difference({target}).every(givens.contains),
    );
  }

  Question singleDomain({
    required String domainId,
    required VarKey target,
    required Set<VarKey> givens,
  }) {
    final dom = registry.domain(domainId);
    final formula = _findFormula(dom, target, givens);
    final sampled = <VarKey, double>{for (final g in givens) g: _sample(domainId, g)};

    if (sampled[t]?.abs() case final x? when x < 0.2) sampled[t] = 1.0;

    final ans = formula.solves[target]!(sampled);
    final choices = _choices(ans);

    final givenList = [
      for (final g in givens)
        QuestionDatum(key: g, domainId: domainId, value: sampled[g]!),
    ];

    final stem =
        'Domäne ${dom.title}: Bestimme ${symbol(target)} mit den gegebenen Größen.';

    return Question(
      stem: stem,
      givens: givenList,
      target: target,
      targetDomain: domainId,
      answer: ans,
      used: [formula.id],
      choices: choices,
      format: fmt,
      domainsInvolved: {domainId},
    );
  }

  Question transferTask({
    required String fromDomainId,
    required Set<VarKey> fromGivens,
    required VarKey bridgeVar,
    required String toDomainId,
    required Set<VarKey> toGivens,
    required VarKey target,
    DomainBridge? bridge,
  }) {
    final domA = registry.domain(fromDomainId);
    final domB = registry.domain(toDomainId);
    final selectedBridge = bridge ??
        registry.bridgeFor(
          fromDomain: fromDomainId,
          fromVar: bridgeVar,
          toDomain: toDomainId,
          toVar: bridgeVar,
        ) ??
        DomainBridge(
          id: 'implicit-$fromDomainId-$toDomainId-${bridgeVar.hashCode}',
          description: 'Direkte Übertragung',
          fromDomain: fromDomainId,
          fromVar: bridgeVar,
          toDomain: toDomainId,
          toVar: bridgeVar,
        );

    final formulaA = _findFormula(domA, bridgeVar, fromGivens);
    final sampledA = <VarKey, double>{
      for (final g in fromGivens) g: _sample(fromDomainId, g)
    };
    final intermediate = formulaA.solves[bridgeVar]!(sampledA);
    final transferred = selectedBridge.forward(intermediate);

    final requiredForB = {...toGivens, selectedBridge.toVar};
    final formulaB = _findFormula(domB, target, requiredForB);
    final sampledB = <VarKey, double>{
      for (final g in toGivens) g: _sample(toDomainId, g)
    };
    sampledB[selectedBridge.toVar] = transferred;

    final answer = formulaB.solves[target]!(sampledB);
    final choices = _choices(answer);

    final givens = [
      for (final g in fromGivens)
        QuestionDatum(key: g, domainId: fromDomainId, value: sampledA[g]!),
      for (final g in toGivens)
        QuestionDatum(key: g, domainId: toDomainId, value: sampledB[g]!),
    ];

    final bridgeSteps = [
      QuestionDatum(key: selectedBridge.fromVar, domainId: fromDomainId, value: intermediate),
      if (selectedBridge.toVar != selectedBridge.fromVar)
        QuestionDatum(key: selectedBridge.toVar, domainId: toDomainId, value: transferred),
    ];

    final step1Text = fromGivens.isEmpty
        ? 'den gegebenen Größen'
        : fromGivens.map(symbol).join(', ');
    final step2Text = toGivens.isEmpty
        ? 'den gegebenen Größen'
        : toGivens.map(symbol).join(', ');

    final buffer = StringBuffer()
      ..writeln('Schritt 1 – ${domA.title}: Berechne ${symbol(bridgeVar)} aus $step1Text.')
      ..writeln(
          'Schritt 2 – ${domB.title}: Übertrage ${symbol(bridgeVar)} und verwende $step2Text, um ${symbol(target)} zu bestimmen.');
    if (selectedBridge.description.isNotEmpty) {
      buffer.writeln('Transferhinweis: ${selectedBridge.description}');
    }

    return Question(
      stem: buffer.toString().trim(),
      givens: givens,
      target: target,
      targetDomain: toDomainId,
      answer: answer,
      used: [formulaA.id, formulaB.id, selectedBridge.id],
      choices: choices,
      format: fmt,
      domainsInvolved: {fromDomainId, toDomainId},
      derived: bridgeSteps,
      bridgeDescription: selectedBridge.description,
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

final registryProvider = Provider<DomainRegistry>((_) => domainRegistry);
final formatProvider = StateProvider<QuizFormat>((_) => kinEasyFormat);
final modeProvider = StateProvider<QuizMode>((_) => QuizMode.singleDomain);
final selectedDomainProvider = StateProvider<String>((_) => kinematics.id);
final engineProvider = Provider<QuestionEngine>((ref) {
  final registry = ref.watch(registryProvider);
  final fmt = ref.watch(formatProvider);
  return QuestionEngine(registry, fmt);
});
