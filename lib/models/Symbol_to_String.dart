import 'Formulars_and_Variabels.dart';

String symbol(VarKey k) {
  if (k.q == Quantity.velocity && k.role == Role.initial) return "v0";
  if (k.q == Quantity.velocity && k.role == Role.finalValue) return "v";
  if (k.q == Quantity.acceleration) return "a";
  if (k.q == Quantity.time) return "t";
  if (k.q == Quantity.displacement) return "s";
  if (k.q == Quantity.mass) return "m";
  if (k.q == Quantity.energy) {
    if (k.role == Role.finalValue) return "E_k";
    return "E";
  }
  return "${k.q.name}:${k.role.name}";
}

String unitText(Unit u) {
  switch (u) {
    case Unit.m:
      return "m";
    case Unit.s:
      return "s";
    case Unit.N:
      return "N";
    case Unit.kg:
      return "kg";
    case Unit.V:
      return "V";
    case Unit.A:
      return "A";
    case Unit.Ohm:
      return "Ω";
    case Unit.J:
      return "J";
    case Unit.W:
      return "W";
    case Unit.mps:
      return "m/s";
    case Unit.mps2:
      return "m/s²";
  }
}
