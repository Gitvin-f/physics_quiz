enum Unit { m, s, mps, mps2, N, kg, V, A, Ohm, J, W }
enum Role { initial, finalValue, delta, atStart, atEnd }
enum Quantity { displacement, velocity, acceleration, time, mass, energy }

class VarDef {
  final VarKey key; final Unit unit;
  final double min, max; final int decimals;
  const VarDef(this.key, this.unit, {this.min=0, this.max=100, this.decimals=2});
}

class VarKey {
  final Quantity q;
  final Role role;     // e.g. initial vs final
  final String? tag;   // optional: e.g. “block A” for multi-body problems
  const VarKey(this.q, this.role, {this.tag});

  @override
  bool operator ==(Object o) =>
      o is VarKey && o.q == q && o.role == role && o.tag == tag;
  @override
  int get hashCode => Object.hash(q, role, tag);
  @override
  String toString() => '${q.name}:${role.name}${tag==null?"":":$tag"}';
}

typedef SolveFn = double Function(Map<VarKey, double> m);

class FormulaDef {
  final String id;
  final Set<VarKey> vars;                 // e.g. {"v","u","a","t"}
  final Map<VarKey, SolveFn> solves;      // rearranged solutions
  const FormulaDef({required this.id, required this.vars, required this.solves});
}

class Domain {
  final String id; final String title;
  final Map<VarKey, VarDef> vars;
  final List<FormulaDef> formulas;
  const Domain({required this.id, required this.title, required this.vars, required this.formulas});
}
