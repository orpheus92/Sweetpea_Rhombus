#lang rhombus/scribble/manual
@// A documented binding must be imported into the document itself at label
@// phase, or `doc` reports "identifier to document has no for-label binding".
@// `docmodule` only declares which module a binding is documented as coming
@// from; it does not bring the name into scope.
@//
@// `rhombus open` has to be here too, not just this library's modules: the doc
@// entry forms resolve a binding's space (such as `rhombus/defn`) through
@// label-phase bindings, so without it even a correctly imported `factor` is
@// reported as having no for-label binding. Every library in the Rhombus
@// distribution that documents a macro opens `rhombus` this way.
@//
@// None of this library's 48 exported names collides with one of `rhombus`'s
@// own, so all three modules can be opened here. (`at_most` and `at_least` are
@// the near miss: Rhombus has `Real.at_most` and `Real.at_least`, which are
@// namespaced and so do not clash with the bare names exported here.)
@(import:
    meta_label:
      rhombus open
      lib("sweetpea-rhombus/sweetpea.rhm") open
      lib("sweetpea-rhombus/constraints.rhm") open
      lib("sweetpea-rhombus/synthesize.rhm") open)

@title{The notation}

@docmodule(~open, lib("sweetpea-rhombus/sweetpea.rhm"))

@doc(
  defn.macro 'factor $name: [$level, ...]'
  defn.macro 'factor $name($parent, ...) $shape: [$derived_level, ...]'
){

 Declares a factor and binds it to @rhombus(name), which also becomes a
 namespace holding each level's name --- so @rhombus(color.red) is a checked
 reference to a level of @rhombus(color). A level listed twice is rejected,
 since the crossing counts levels and a duplicate would quietly change how many
 trials a design has.

 In the first form each @rhombus(level) is a string, optionally followed by
 @rhombus(~weight) and an integer. A level of weight @italic{w} is combined
 @italic{w} times with each combination of the other crossed factors' levels,
 which is SweetPea's @tt{Level(name, weight=w)}.

 The second form declares a derived factor over the given parents, where
 @rhombus(shape) is any combination of @rhombus(~width), @rhombus(~stride) and
 @rhombus(~start). Each @rhombus(derived_level) is either a predicate over
 parent values or an @tt{else} level:

 @rhombusblock(
   derived con(a, b): a == b
   else plain
 )

 A predicate takes @rhombus(~width) values per parent, parent by parent in
 declaration order and oldest trial first, so at width 2 over two parents it
 takes four. The count is checked when the module is compiled.

}

@doc(
  defn.macro 'experiment $name:
                $clause
                ...'

  grammar clause
  | ~design: $factor_list
  | ~cross: $factor_list
  | ~within: $factor_or_list
  | ~within: $factor_or_list ~in_order
  | ~constraints: $constraint_list
  | ~min_trials: $int_expr
  | ~cover: $factor_list
  | ~require_complete_crossing: $bool_expr
){

 Declares an experiment and binds it to @rhombus(name). Only @rhombus(~design)
 and @rhombus(~cross) are required, and the clauses may be written in any
 order. An unrecognized clause does not compile, so @rhombus(~min_trial) for
 @rhombus(~min_trials) is caught rather than ignored.

 @rhombus(~design) is everything a trial carries and @rhombus(~cross) is what
 must be balanced; the design may be the wider of the two, and a factor in it
 but not the crossing varies freely. A factor crossed but absent from the
 design does not compile.

 @rhombus(~within) holds a factor constant across each instance of the inner
 design, which is SweetPea's @tt{Nest}. Given a list, a segment holds one
 combination of those factors constant, and the combinations rather than the
 individual levels are what gets crossed over the segments.
 @rhombus(~in_order) then takes them in declaration order, which is SweetPea's
 @tt{Sequential}.

 @rhombus(~min_trials) lengthens each segment; a segment always holds at least
 one full crossing, and the keyword can only ask for more. @rhombus(~cover) is
 SweetPea's @tt{CoverAllCombinations}. Both are keywords rather than
 constraints because both change how many trials exist, which is geometry
 rather than a condition on an assignment.

 @rhombus(~require_complete_crossing) defaults to true, as @tt{CrossBlock}
 does. Set it to false to drop the crossed combinations that cannot occur and
 cross what is left.

}

@doc(
  class Factor(name, levels, params, width, weights, stride, start)
  class Experiment(name, design, cross, constraints, within, in_order,
                   min_trials, cover, complete_crossing)
  class DerivedLevel(name, arity, predicate)
){

 What the declaration forms expand to. @rhombus(params) is empty for a basic
 factor and holds the parent factors for a derived one. An @tt{else} level is
 a @rhombus(DerivedLevel) with arity 0 and @rhombus(#false) for its predicate,
 which @rhombus(derivation) reads as "holds when none of the others does".

 Because a @rhombus(factor) declaration binds a namespace as well as a value,
 read a field through the class --- @rhombus(Factor.levels(color)) rather than
 @rhombus(color.levels).

}

@doc(
  fun level_value(l)
){

 The string value of a level, whether it is a plain string or a
 @rhombus(DerivedLevel).

}

