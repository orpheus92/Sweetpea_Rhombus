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

@title{Constraints}

@docmodule(~open, lib("sweetpea-rhombus/constraints.rhm"))

This module knows nothing about derived factors. By the time a @rhombus(Geom)
exists every level has been reduced to its value, so every constraint here
treats a derived factor as an ordinary one.

@section{The requirement vocabulary}

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

@section{Building requirements}

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

@section{The two consumers}

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

@section{Applied automatically}

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

@section{Applied when the design calls for them}

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

@section{Written by hand}

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

