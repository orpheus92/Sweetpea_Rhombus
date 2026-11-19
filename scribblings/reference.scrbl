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

@title{Reference}

@local_table_of_contents()

@section{The notation}

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

@section{Constraints}

@docmodule(~open, lib("sweetpea-rhombus/constraints.rhm"))

This module knows nothing about derived factors. By the time a @rhombus(Geom)
exists every level has been reduced to its value, so every constraint here
treats a derived factor as an ordinary one.

@subsection{The requirement vocabulary}

@doc(
  class Lev(trial, factor, level)
  class Comb(trial, combo)
  class Not(atom)
  class All(atoms)
){

 Atoms. @rhombus(Lev) says that @rhombus(trial) carries @rhombus(level) of
 @rhombus(factor), and @rhombus(Comb) that @rhombus(trial) realizes a crossed
 combination; all the indices are into the geometry. Atoms are literals, so
 @rhombus(Not) is free.

 @rhombus(All) is the conjunction of several atoms usable @italic{as one atom}:
 Tseitin-encoded in both directions by the encoder, evaluated directly by the
 checker.

}

@doc(
  class Req(atoms, lo, hi)
  class Constraint(name, reqs)
){

 The only shape a requirement has: of @rhombus(atoms), between @rhombus(lo) and
 @rhombus(hi) are true. A @rhombus(Constraint) pairs the name the checker
 reports with a function from a @rhombus(Geom) to a list of @rhombus(Req).

}

@doc(
  class Geom(n_trials, factors, counts, combos, cross_idx, seg_len, sustain,
             preamble, stride)
){

 The shape of a design, with every level already reduced to a value.
 @rhombus(counts) is the level count per factor; @rhombus(combos) the crossed
 combinations that can occur, each a list of level indices parallel to
 @rhombus(cross_idx); @rhombus(seg_len) the trials per segment, equal to
 @rhombus(n_trials) without @rhombus(~within); @rhombus(sustain) the factors
 held constant across a segment; and @rhombus(preamble) and @rhombus(stride)
 say, per factor, the first trial of a segment it has a level on and how often
 after that.

}

@subsection{Building requirements}

@doc(
  fun exactly(n, atoms)
  fun at_most(n, atoms)
  fun at_least(n, atoms)
){

 @rhombus(Req(atoms, n, n)), @rhombus(Req(atoms, 0, n)) and
 @rhombus(Req(atoms, n, atoms.length())) respectively.

}

@doc(
  defn.macro 'constraint $name($arg, ...) ~given $g:
                $body'
){

 Declares a constraint. @rhombus(body) is evaluated with @rhombus(g) bound to
 the geometry and must produce a list of @rhombus(Req). Expands to a function
 returning a @rhombus(Constraint) whose name is the declared one.

}

@doc(
  fun has_level(geom :: Geom, fi :: Int, i :: Int) :: Boolean
){

 Whether factor @rhombus(fi) has a level on trial @rhombus(i) --- the one
 predicate everything reading a trial asks first. A trial is scored when, for
 @rhombus(k) the offset within its segment, @rhombus(k) is at or past that
 factor's preamble and @rhombus(k) less the preamble is a multiple of its
 stride.

}

@doc(
  fun index_of_factor(geom, f) :: Int
  fun index_of_level(geom, fi, lvl) :: Int
){

 The geometry index of a factor by name, and of a level, accepting either a
 string or a level object. Both raise an error when there is no such thing,
 rather than returning a sentinel that would later index out of range.

}

@subsection{The two consumers}

@doc(
  fun reqs_of(c :: Constraint, geom :: Geom) :: List
){

 The single entry point both consumers use. Calls the constraint and validates
 what comes back: every @rhombus(Lev) trial, factor and level index and every
 @rhombus(Comb) index must be in range, atom lists must be non-empty, and the
 bounds must be sane. An offending constraint fails by name rather than
 producing clauses the checker cannot read.

}

@doc(
  fun cnf_of(req :: Req, var_of, fresh :: Int)
  fun holds_in(req :: Req, is_set) :: Boolean
){

 The two derived views of one requirement. @rhombus(cnf_of) returns clauses as
 a list of lists of signed integers plus the next unused variable number, where
 @rhombus(var_of) maps an atom to a variable; bounds other than 0 and 1 use the
 Sinz (2005) sequential counter, which is why @rhombus(fresh) is threaded
 through. @rhombus(holds_in) answers whether the requirement holds of a
 finished sequence, where @rhombus(is_set) answers an atom.

 A constraint author writes neither.

}

@doc(
  fun within_each(c :: Constraint) :: Constraint
){

 Applies @rhombus(c) inside each segment only. The wrapped constraint is asked
 for its requirements against a geometry one segment long, and the trial
 indices that come back are shifted into each segment in turn --- so it needs
 nothing from the constraint and works for every one of them, including
 constraints not written yet.

}

@subsection{Applied automatically}

@doc(
  fun consistent() :: Constraint
  fun crossed() :: Constraint
){

 @rhombus(consistent) requires exactly one level of each factor in each trial
 it has a level on, and none in the trials it does not.

 @rhombus(crossed) gives each crossed combination its share of each segment and
 requires each trial to realize exactly one combination. A combination's share
 is the product of its levels' weights, scaled to the segment length and
 rounded both ways, so weights and @rhombus(~min_trials) need no separate
 machinery.

}

@subsection{Applied when the design calls for them}

@doc(
  fun sustained(f) :: Constraint
  fun outer_crossed(fs) :: Constraint
  fun sequential(fs) :: Constraint
){

 @rhombus(sustained) holds a factor constant across each segment, and
 @rhombus(outer_crossed) gives each combination of the outer factors exactly
 one segment; both are applied for @rhombus(~within). @rhombus(sequential)
 makes the segments take those combinations in declaration order, and is
 applied by @rhombus(~in_order).

}

@subsection{Written by hand}

@doc(
  fun exclude(f, lvl) :: Constraint
  fun pin(i, f, lvl) :: Constraint
){

 @rhombus(exclude) keeps a level out of every trial. @rhombus(pin) fixes one to
 trial @rhombus(i); a negative @rhombus(i) counts back from the end, and an
 @rhombus(i) outside the sequence yields an unsatisfiable requirement, so the
 design has no solution rather than raising an error --- both as SweetPea
 documents.

}

@doc(
  fun no_repeats(f) :: Constraint
  fun at_most_k_in_a_row(k, target) :: Constraint
  fun at_least_k_in_a_row(k, target) :: Constraint
  fun exactly_k_in_a_row(k, target) :: Constraint
  fun exactly_k_multiple_in_a_row(k, target) :: Constraint
){

 Run-length bounds, which are SweetPea's @tt{AtMostKInARow} and its siblings.
 @rhombus(target) is a factor, in which case the rule applies to each of its
 levels separately, or a @rhombus([factor, level]) pair.
 @rhombus(no_repeats) is @rhombus(at_most_k_in_a_row) with @rhombus(k) of 1,
 and @rhombus(exactly_k_multiple_in_a_row) admits runs of length @rhombus(k),
 twice @rhombus(k), three times @rhombus(k), and so on.

}

@doc(
  fun exactly_k(k, f, lvl) :: Constraint
){

 Exactly @rhombus(k) trials carry this level. Asking for more than the design
 can give is reported as no sequences rather than an error, as in SweetPea.

}

@doc(
  fun latin_square(fs) :: Constraint
){

 @rhombus(fs) is a two-element list. The sequence is read as rows as long as
 the factor with more levels; every row holds every level of both factors; the
 second factor follows the first by an offset constant within a row; and
 consecutive rows step that offset down by one. The shorter level count must
 divide the longer. Three or more factors are refused rather than approximated.

}

@section{Generating and checking}

@docmodule(~open, lib("sweetpea-rhombus/synthesize.rhm"))

@doc(
  fun synthesize_trials(exp :: Experiment,
                        count :: Int = 1,
                        ~constraints: extra :: List = [],
                        ~strategy: strategy :: Symbol = #'iterate,
                        ~solver: solver :: String = "cryptominisat5",
                        ~tmp: tmp :: String = "/tmp/sp_r.cnf") :: List
){

 Up to @rhombus(count) trial sequences for @rhombus(exp). Each sequence is a
 list of trials, and each trial a list of level values parallel to the
 experiment's design, with @rhombus(#false) where a factor has no level on that
 trial.

 The @rhombus(extra) constraints are added to those the experiment declares.
 @rhombus(strategy) is @rhombus(#'iterate) or @rhombus(#'random); anything else
 is an error that names the two. Returns fewer sequences than asked for,
 including none, when the design admits fewer.

}

@doc(
  fun check_sequence(exp :: Experiment, seq :: List,
                     ~constraints: extra :: List = []) :: List
  fun checker_for(geom :: Geom, seq :: List)
){

 @rhombus(check_sequence) returns the names of the constraints @rhombus(seq)
 violates, and the empty list if it violates none. It reads the same
 requirements the encoder reads, so it judges every column of a design however
 deep.

 @rhombus(checker_for) returns the @rhombus(is_set) predicate for a sequence
 that @rhombus(holds_in) wants, which lets a caller check one requirement on
 its own.

}

@doc(
  fun print_experiments(exp :: Experiment, trials :: List) :: Void
  fun print_trials(exp :: Experiment, seq :: List) :: Void
){

 A sequence read as a table rather than a list of lists, which is SweetPea's
 @tt{print_experiments} give or take the trial numbers. A factor with no value
 in a trial leaves its cell empty, and under @rhombus(~within) a blank line
 separates the segments.

}

@doc(
  fun geometry_of(exp :: Experiment) :: Geom
  fun count_sequences(exp :: Experiment) :: Int
  fun numbering(geom :: Geom)
){

 @rhombus(geometry_of) decides everything about the shape of a design before
 any encoding happens. It raises an error rather than guessing when a design
 does not make sense --- an empty crossing, a negative @rhombus(~min_trials), a
 strided factor in the crossing or read by another factor, a @rhombus(~start)
 earlier than the computed preamble, a weighted factor under @rhombus(~cover),
 or a crossing with no realizable combination left.

 @rhombus(count_sequences) is the factorial of the trial count: how many
 orderings exist before any requirement applies. A denominator for coverage
 figures, not a count of solutions.

 @rhombus(numbering) returns the atom-to-variable mapping and the variable
 count, and is exposed so that @tt{examples/inside_a_constraint.rhm} can show
 what a declaration produces.

}

@doc(
  fun derivation(f) :: Constraint
  fun cover_all_combinations(fs) :: Constraint
){

 The two requirements that must @italic{call} a derived level's predicate,
 which is why they live here rather than with the other constraints.

 @rhombus(derivation) ties a derived factor's level in each trial it is scored
 on to its parents' levels across the trials its window covers, handling
 @tt{else} levels and skipping trials where @rhombus(has_level) is false. It is
 applied automatically for every derived factor in a design.

 @rhombus(cover_all_combinations) requires every @italic{realizable}
 combination of @rhombus(fs) to appear in some trial. A combination
 contradicting a derived level's predicate is not realizable and so is not
 required; one ruled out for any other reason is still required, and the design
 then has no solution. It is applied by @rhombus(~cover), and is available by
 hand when the design is already long enough.

}
