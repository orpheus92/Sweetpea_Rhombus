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

@title{Generating and checking}

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
