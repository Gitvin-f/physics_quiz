import 'Formulars_and_Variabels.dart';

const v0 = VarKey(Quantity.velocity, Role.initial);
const v1 = VarKey(Quantity.velocity, Role.finalValue);
const a  = VarKey(Quantity.acceleration, Role.atStart);
const t  = VarKey(Quantity.time, Role.delta);
const s  = VarKey(Quantity.displacement, Role.delta);

final kinematics = Domain(
  id: 'kin',
  title: 'Kinematik',
  vars: {
    v0: VarDef(v0, Unit.mps, min: 0, max: 30),
    v1: VarDef(v1, Unit.mps, min: 0, max: 60),
    a:  VarDef(a,  Unit.mps2, min: -10, max: 10),
    t:  VarDef(t,  Unit.s,    min: 0.5, max: 15),
    s:  VarDef(s,  Unit.m,    min: 5,   max: 300),
  },
  formulas: [
    FormulaDef(
      id: "v1 = v0 + a·t",
      vars: {v1, v0, a, t},
      solves: {
        v1: (m) => m[v0]! + m[a]!*m[t]!,
        a:  (m) => (m[v1]! - m[v0]!) / m[t]!,
        t:  (m) => (m[v1]! - m[v0]!) / m[a]!,
      },
    ),
    FormulaDef(
      id: "s = v0·t + 0.5·a·t²",
      vars: {s, v0, a, t},
      solves: {
        s: (m) => m[v0]!*m[t]! + 0.5*m[a]!*m[t]!*m[t]!,
      },
    ),
    // v1^2 = v0^2 + 2 a s
  ],
);
