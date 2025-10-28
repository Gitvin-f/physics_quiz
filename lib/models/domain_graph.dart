import 'Formulars_and_Variabels.dart';

typedef TransferFn = double Function(double value);

double _identity(double v) => v;

class DomainBridge {
  final String id;
  final String description;
  final String fromDomain;
  final VarKey fromVar;
  final String toDomain;
  final VarKey toVar;
  final TransferFn forward;
  final TransferFn backward;

  const DomainBridge({
    required this.id,
    required this.description,
    required this.fromDomain,
    required this.fromVar,
    required this.toDomain,
    required this.toVar,
    TransferFn? forward,
    TransferFn? backward,
  })  : forward = forward ?? _identity,
        backward = backward ?? _identity;
}

class DomainRegistry {
  final Map<String, Domain> domains;
  final List<DomainBridge> bridges;

  const DomainRegistry({required this.domains, this.bridges = const []});

  Domain domain(String id) {
    final dom = domains[id];
    if (dom == null) {
      throw StateError('Domain with id $id not found');
    }
    return dom;
  }

  VarDef? varDef(String domainId, VarKey key) {
    return domains[domainId]?.vars[key];
  }

  Iterable<String> domainsContaining(VarKey key) sync* {
    for (final entry in domains.entries) {
      if (entry.value.vars.containsKey(key)) {
        yield entry.key;
      }
    }
  }

  DomainBridge? bridgeFor({
    required String fromDomain,
    required VarKey fromVar,
    required String toDomain,
    required VarKey toVar,
  }) {
    for (final b in bridges) {
      if (b.fromDomain == fromDomain &&
          b.fromVar == fromVar &&
          b.toDomain == toDomain &&
          b.toVar == toVar) {
        return b;
      }
    }
    return null;
  }
}
