import 'Formulars_and_Variabels.dart';

String symbol(VarKey k) {
  if (k.q == Quantity.velocity && k.role == Role.initial) return "v0";
  if (k.q == Quantity.velocity && k.role == Role.finalValue) return "v";
  if (k.q == Quantity.acceleration) return "a";
  if (k.q == Quantity.time) return "t";
  if (k.q == Quantity.displacement) return "s";
  return "${k.q.name}:${k.role.name}";
}

String unitText(Unit u) {
  switch (u) {
    case Unit.m:
      return "m";
    case Unit.s:
      return "s";
    case Unit.N:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.kg:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.V:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.A:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.Ohm:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.J:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.W:
      // TODO: Handle this case.
      throw UnimplementedError();
    case Unit.mps:
      return "m/s";
    case Unit.mps2:
      return "m/s²";
  }
}
