#lang rhombus/scribble/manual

@title{Sweetpea_Rhombus}

An implementation of SweetPea's experiment-design language in Rhombus.

@local_table_of_contents()

@section{Overview}

SweetPea is a domain-specific language for specifying counterbalanced
experimental designs. A design declares factors and their levels, states which
factors must be crossed, and adds constraints; SweetPea then produces trial
sequences that satisfy the specification.

This project reimplements that capability in Rhombus. A design is written as a
set of declarations in the host language, validated during compilation, encoded
as a Boolean satisfiability problem, solved by an external SAT solver, and
decoded back into trial sequences. No stage of the pipeline depends on the
Python implementation.

Validation happens at expansion time, and rejects several classes of
specification error before any code executes: references to undeclared factors,
levels that do not exist, derived predicates whose arity contradicts their
declaration, duplicate levels, and factors named in a crossing but absent from
the design. Errors are reported even when they occur in code paths that are
never evaluated.

Constraints are declared once. A single declaration determines both the clauses
given to the solver and the predicate used to verify a finished sequence, so
the two representations cannot diverge. That is the central design commitment
of the implementation, and the section below on declaring a constraint once
takes it up in detail.

@bold{Status.} This is a research pilot intended to evaluate the approach, not
a tool for generating experiments used in studies; the last section lists what
is missing.

@section{Installing}

Three things: Racket, Rhombus, and a SAT solver.

Racket 9.3 or later. Note that conda will not do --- conda-forge's Racket is
years out of date.

@verbatim{
  brew install --cask racket
  raco pkg install --auto rhombus
  brew install cryptominisat
}

On Linux, install Racket from the official installer script and use
@tt{apt install cryptominisat} for the solver.

The Homebrew cask occasionally fails with a checksum mismatch, because Racket
sometimes re-publishes an installer without bumping the version. Installing
from @tt{https://download.racket-lang.org/} works in that case.

The solver is needed only for the @rhombus(#'iterate) strategy, which is the
default; @rhombus(#'random) runs without one. Any solver that reads DIMACS CNF
and answers @tt{s SATISFIABLE} will do --- @tt{minisat} and @tt{picosat} both
work --- and is named with the @rhombus(~solver) argument. SweetPea shells out
to the same CryptoMiniSAT executable, so if SweetPea already runs, a solver is
already installed.

To install this library itself, from a checkout:

@verbatim{
  raco pkg install --auto
}

@section{Quick start}

@verbatim{
  racket examples/pilot.rhm
}

@verbatim{
  3 trial sequences found.

  Experiment 1:
      color  size
      -----  -----
  1   blue   large
  2   blue   small
  3   red    large
  4   red    small
}

If that runs, everything is installed.

@section{What a design looks like}

@rhombusblock(
  factor color: ["red", "blue", "green"]
  factor word:  ["red", "blue", "green"]

  // a derived factor: its level follows from its parents' levels
  factor congruency(color, word):
    [derived con(a, b): a == b,
     derived inc(a, b): a != b]

  experiment plan:
    ~design: [color, word, congruency]    // everything a trial carries
    ~cross: [color, congruency]           // what must be balanced
    ~min_trials: 12
    ~constraints: [no_repeats(congruency), at_most_k_in_a_row(2, color)]

  print_experiments(plan, synthesize_trials(plan, 3))
)

Because factors and levels are bindings rather than strings, a constraint names
a level instead of quoting one:

@rhombusblock(
  exclude(color, color.red)      // checked when the module is compiled
  exclude(color, color.pink)     // pink: identifier not provided by color
  exclude(color, "pink")         // compiles; fails when the constraint runs
)

The last line is SweetPea's situation: @tt{Exclude((color, "pink"))} is a
well-formed call that builds a perfectly good constraint about a level no trial
can have. The @tt{tests/bad-level.rhm} design puts that typo inside a function
that is never called, and it does not compile.

@section{Crossings}

@rhombus(~design) is everything a trial carries; @rhombus(~cross) is what must
be balanced. They are separate, and the design may be the wider of the two: a
factor in the design but not the crossing varies freely.

The crossing decides how long a design is --- one trial per combination of the
crossed factors' levels, so two colours against two sizes is four trials. A
combination's share is stated as a count between two bounds, which is what lets
weights, @rhombus(~min_trials) and coverage all fall out of the same
requirement rather than needing machinery of their own.

@italic{A crossing says nothing about order.} It says how often each
combination appears, and a solver is free to block them together --- left to
itself it does. The @tt{examples/stroop.rhm} design shows this: the crossing
alone, solved with @rhombus(#'iterate), puts the same colour in adjacent trials
nine times and repeats a whole trial three times. That satisfies the design. It
is not a sequence anyone would run. So a real design either says what it wants
of the order, with constraints, or draws uniformly from the valid sequences
instead of taking the first, which is what @rhombus(#'random) does.

@subsection{Weights}

@rhombusblock(
  factor color: ["red" ~weight 2, "blue"]
)

A level of weight @italic{w} is combined @italic{w} times with each combination
of the other crossed factors' levels, so the crossing takes the product of the
weight sums in trials --- @tt{(2+1) x (1+1) = 6} above --- while the set of
distinct combinations is still the product of the level counts, and each
combination is entitled to the product of its own levels' weights. Because the
crossing already stated its requirement as a count between two bounds, weights
cost the encoding nothing. A derived level can be weighted the same way.

Where this stops short of SweetPea: a weight on an @italic{uncrossed} factor
leaves the geometry alone. There a weight also biases sampling; here it does
not.

@subsection{Lengthening a design}

@rhombus(~min_trials) is SweetPea's @tt{MinimumTrials}. A segment always holds
at least one full crossing, and the keyword can only ask for more. The trials
beyond one crossing spread over the combinations --- each appears the floor or
the ceiling of the average, never more. Under @rhombus(~within) it lengthens
each segment, as SweetPea does when a @tt{MinimumTrials} is pushed into a
nested block.

@rhombus(~cover) is SweetPea's @tt{CoverAllCombinations}: every realizable
combination of the listed factors must appear in some trial. A factor outside
the crossing is otherwise free, so nothing guarantees a particular combination
ever shows up. Coverage can lengthen the design too --- one trial per
combination at least, rounded up so the crossing still gets whole passes.

A combination that cannot occur is not required. The case SweetPea's
documentation names is one contradicting a derived level's predicate, and that
is decided by calling the predicate, which is why that requirement lives beside
@rhombus(derivation) rather than with the other constraints. A combination
ruled out for any other reason is still required, and the design then has no
solution. The listed factors must be unweighted, as in SweetPea. Not
implemented: @tt{optional}, the factors SweetPea gives up one at a time when
the design has no solution.

Both are keywords rather than constraints because both change how many trials
exist, which is geometry and not a condition on an assignment --- and because
that is what they are in SweetPea, where @tt{MinimumTrials.apply} only sets a
field on the block and its checker returns true unconditionally.
@rhombus(cover_all_combinations) is available as a plain constraint when the
design is already long enough.

@subsection{Counting trials}

@rhombus(geometry_of) answers every question about the shape of a design before
any solving happens: @rhombus(n_trials) is how long it is, @rhombus(seg_len)
how long one segment is, @rhombus(combos) the crossed combinations that
survive, and @rhombus(preamble) and @rhombus(stride) say, per factor, where its
levels begin and how often they recur.

@section{Derived factors}

A derived factor's level in a trial is a function of its parents' levels, so it
is never a free choice. Four shapes beyond a plain within-trial predicate:

@itemlist(
  @item{@rhombus(~width) @italic{w} reads @italic{w} consecutive trials of each
        parent --- width 1 is SweetPea's @tt{WithinTrial}, 2 its
        @tt{Transition}, any @italic{w} its @tt{Window}. The factor then has no
        level for the first @italic{w}-1 trials of a segment, which is
        SweetPea's preamble.}
  @item{@rhombus(~stride) and @rhombus(~start) give a factor a level every
        @italic{s} trials rather than every trial, and say where its levels
        begin.}
  @item{@tt{else} is SweetPea's @tt{ElseLevel}: a level with no predicate of
        its own, holding exactly when none of the others does.}
  @item{A derived factor may derive from another, which composes without
        anything further in the encoder.}
)

A derived factor can be crossed, because its level variables are ordinary
variables and the crossing never learns where they came from. Crossing one
together with its parents asks for something contradictory, and
@rhombus(~require_complete_crossing) decides what happens then --- no solution,
which is SweetPea's default, or a crossing over the combinations that can
actually occur.

@section{Nesting}

@rhombus(~within) holds a factor constant across each instance of the inner
design, which is SweetPea's @tt{Nest}:

@rhombusblock(
  experiment plan:
    ~design: [color, size]
    ~cross: [color, size]
    ~within: session
)

The inner design is repeated once per level of @rhombus(session), and each
repetition is balanced on its own. Those repetitions are called
@deftech{segments} here, and @rhombus(seg_len) is how long one is.

@rhombus(~within) takes one factor or a list of them. SweetPea's @tt{Nest}
takes an outer @italic{block} rather than a factor, so the outer may cross
several factors; with a list, a segment holds one combination of them constant,
and the combinations --- not the individual levels --- are what gets crossed
over the segments. Two sessions crossed with two groups gives four segments.
An outer factor may not also appear in @rhombus(~design); that does not
compile.

@rhombus(~in_order) then takes the combinations in the order the factors were
declared, which is SweetPea's @tt{Sequential}. Ordering the segments is a
property of the design, so it is stated in the design rather than written as a
constraint --- which is also the decision that makes the bug described in
@secref("declared_once") unrepresentable here.

@subsection{Scoping a constraint to a segment}

@rhombus(within_each) is the scope SweetPea gives by attaching a constraint
list to the inner block of a @tt{Nest}:

@rhombusblock(
  no_repeats(size)                // no two adjacent trials, anywhere
  within_each(no_repeats(size))   // ... except across a session boundary
)

It is a combinator rather than a kind of constraint. The wrapped constraint is
asked for its requirements against a geometry one segment long, and the trial
indices that come back are shifted into each segment in turn. So it needs
nothing from the constraint and works for every one of them ---
@rhombus(within_each(pin(0, color, color.red))) opens every session on red ---
including constraints not written yet. Without a @rhombus(~within) factor there
is one segment and it changes nothing.

Under @rhombus(~within), @rhombus(print_trials) puts a blank line between the
segments, so a nested design reads as sessions rather than as one long block.

@section{Constraints}

Constraints name factors and levels directly --- @rhombus(no_repeats(color)),
@rhombus(exclude(size, size.small)) --- so a design never mentions an index.

Three are part of what a design @italic{means} and are never written by hand:
@rhombus(consistent) gives one level per factor per trial, @rhombus(crossed)
gives each combination its share of a segment, and @rhombus(derivation) ties a
derived factor to its parents. Four more are applied when the design calls for
them: @rhombus(sustained) and @rhombus(outer_crossed) for @rhombus(~within),
@rhombus(sequential) for @rhombus(~in_order), and
@rhombus(cover_all_combinations) for @rhombus(~cover).

The rest are written by hand:

@itemlist(
  @item{@rhombus(exclude(f, level)) --- a level that never appears.}
  @item{@rhombus(pin(i, f, level)) --- a level fixed to a trial. A negative
        index counts back from the end, and an index outside the sequence gives
        a design with no solution rather than an error, both as SweetPea
        documents.}
  @item{@rhombus(no_repeats(f)) --- no two adjacent trials share a level.}
  @item{@rhombus(at_most_k_in_a_row(k, t)), @rhombus(at_least_k_in_a_row(k, t))
        and @rhombus(exactly_k_in_a_row(k, t)) --- SweetPea's
        @tt{AtMostKInARow} and friends, for any @italic{k}.}
  @item{@rhombus(exactly_k_multiple_in_a_row(k, t)) --- runs whose length is a
        multiple of @italic{k}.}
  @item{@rhombus(exactly_k(k, f, level)) --- exactly @italic{k} trials carry
        this level.}
  @item{@rhombus(latin_square([f, g])) --- Latin square counterbalancing over
        two factors.}
  @item{@rhombus(within_each(c)) --- any constraint, inside each segment only.}
)

@subsection{Run-length targets}

The run-length constraints take a target that is either a factor, in which case
the rule applies to each of its levels separately, or a single
@rhombus([factor, level]) pair:

@rhombusblock(
  at_most_k_in_a_row(1, color)            // no colour twice running
  at_least_k_in_a_row(2, [color, "red"])  // red, when it appears, appears twice
)

SweetPea's @tt{AtMostKInARow} accepts the same two shapes. A @rhombus(Factor)
is not a @rhombus(List), so one @rhombus(match) separates them.

@subsection{Latin squares}

@rhombus(latin_square([item, order])) reads the sequence as rows of @italic{N}
trials. Every row holds every level of both factors, the second factor follows
the first by an offset that is constant within a row, and consecutive rows take
consecutive offsets, with the starting offset left to the solver. A row is what
SweetPea's guide calls a @italic{participant}: it sees one diagonal of the
crossing, so it sees every level of every factor without seeing every
combination, and the combinations are covered across participants.

Which way the cycle turns is not in SweetPea's documentation, and the two
directions admit different sequences, so it was settled against SweetPea
itself. Squares were passed to its @tt{sample_mismatch_experiment} with
@tt{LatinSquare([a, b])} in play, and at @italic{N} = 3 and @italic{N} = 4,
from either start, it accepts offsets that step @italic{down} by one per row
and rejects offsets that step up. The encoding here steps down. Agreement was
then checked both ways: five squares from this encoder were accepted by
SweetPea, and four sequences SweetPea generated are accepted here. Those four
are recorded in @tt{tests/latin_square.rhm}, so the agreement is retested on
every run without SweetPea installed.

The two factors need not have the same number of levels. The row is as long as
the longer factor --- SweetPea calls that the diagonal length --- and the
shorter one fills the row by repeating, so with four levels against two each
takes half of every row and the diagonal is read modulo two. The shorter count
must divide the longer, or no row can hold each of its levels equally often,
and @rhombus(latin_square) says so. Parity was checked the same way: four
4-against-2 squares from this encoder were accepted by SweetPea, and three of
its own are accepted here and kept as fixtures.

Two factors only. SweetPea generalizes to more by giving every factor except
the longest its own rotation and stepping the vector of rotations like an
odometer, so the cycle is as long as the product of the other factors' level
counts. @rhombus(latin_square) refuses three or more rather than pretending.

@subsection{Arguments that are checked}

Both consumers reach a constraint's requirements through one function,
@rhombus(reqs_of), which validates every atom against the geometry first.

Declaring a constraint once stops the encoder and the checker from disagreeing
about what a constraint @italic{means}. It does not stop an atom from naming a
trial, factor or level the design does not have, and until @rhombus(reqs_of)
checked, the two behaved differently when one did: @rhombus(pin(99, color, "red"))
on a four-trial design had the solver allocate a variable for a trial that does
not exist and return every sequence, while the checker crashed indexing the
sequence. @tt{tests/bad_constraints.rhm} holds that line, and separates it from
the case that is merely unsatisfiable --- @rhombus(exactly_k(99, ...)) asks for
more than the design can give, which SweetPea reports as no sequences rather
than an error, and so does this.

@subsection{Not implemented}

@itemlist(
  @item{@tt{CoverAllCombinations}' @tt{optional} factors, which SweetPea gives
        up one at a time when there is no solution.}
  @item{@tt{Relax}, which weakens a constraint when a design has no solution
        --- a search over @italic{k} rather than a declaration.}
  @item{@tt{ContinuousConstraint}: continuous factors are not in the encoding
        at all, and SweetPea keeps them out of its solver too.}
  @item{@tt{LatinSquare} over three or more factors.}
  @item{@tt{MultiCrossBlock}: more than one crossing over the same design.}
)

SweetPea's @tt{Relax}, its Latin-square release and coverage's @tt{optional}
form one concession ladder in its @tt{main.py} --- weaken, then release the
square, then drop optional factors --- cumulative and never taken back. None of
it is here.

@subsection{How they are tested}

@tt{tests/all_constraints.rhm} puts every constraint above through the same
three-way check, on a flat design, a nested one and a nested one in order: the
sequences the solver returns under the constraint, the sequences the checker
accepts, and a count worked out @italic{by hand} must all agree. The hand count
is what distinguishes this from a self-consistency test --- a requirement that
is wrong in the same way for both consumers would otherwise pass.

That is not hypothetical. On its first run the hand count disagreed with both
other columns for @rhombus(no_repeats(color)) together with
@rhombus(no_repeats(size)), and the hand count was the thing that was wrong:
both factors alternating gives the pair period 2, so a whole combination
repeats, and the answer is 0 rather than 4.

@section(~tag: "declared_once"){Declared once, used twice}

A constraint says which @italic{requirements} hold for a design. Every
requirement has one shape: of these atoms, between @rhombus(lo) and
@rhombus(hi) are true.

@rhombusblock(
  constraint pin(i, fi, li) ~given geom:
    [at_least(1, [Lev(i, fi, li)])]
)

From that one declaration, two things are derived by shared code:
@rhombus(cnf_of) produces clauses for the solver, and @rhombus(holds_in)
checks a finished sequence. A constraint author writes neither, so there is no
second copy to keep in step.

That matters because elsewhere the two do drift. SweetPea writes every
constraint twice --- 13 constraint classes carrying both an @tt{apply} and a
@tt{potential_sample_conforms}, around 250 lines of encoder against around 120
of checker --- with nothing tying them together. In
@tt{sweetpea/_internal/constraint.py} on upstream master, class @tt{Sequential}
computes the same quantity in two places and gets two answers:

@verbatim{
  apply()                      line 1466:  (i - preamble_size) // sustain_count
  potential_sample_conforms()  line 1487:  (i - preamble_size)
}

With three levels and two trials per segment, its @tt{RandomGen} returns
@tt{s1, s3, s2} and reports success. The @tt{tests/sequential_regime.rhm}
design runs exactly that case here: both strategies return a correct ordering,
and the checker rejects the sequence SweetPea accepts.

@section{Sampling strategies}

@rhombus(#'iterate) solves the CNF, adds a clause forbidding that answer, and
solves again. Distinct sequences, not uniformly sampled --- whichever the
solver prefers, and the same ones on every run. SweetPea's @tt{IterateSATGen}.

@rhombus(#'random) proposes a random ordering and keeps it only if the checker
accepts, which is rejection sampling --- SweetPea's @tt{RandomGen}. It needs no
solver and respects whatever constraints are in play. What it proposes are the
@italic{basic} factors; a derived factor's value is computed from its parents
and left empty inside its preamble, as SweetPea also does. Where the crossing
fixes a within-trial derived level, the free parents are drawn uniformly from
among the assignments that produce it, which is what keeps the result uniform
rather than merely valid.

Measured on a 2x2 design, 2400 draws over the 24 possible sequences: every draw
valid, all 24 seen, chi-square 18.56 on 23 degrees of freedom against a p=.001
critical value of 49.73. The test asserts at p=.001 rather than p=.05
deliberately, since a chi-square test at p=.05 rejects a correct sampler about
one run in twenty.

@section{Running everything}

@verbatim{
  bash tests/run-tests.sh
}

Three groups in one go: 18 test modules, 8 designs that must @italic{fail} to
compile, and a smoke run of all 20 examples.

Every test that matters compares against a hand count or a brute-force
enumeration rather than against the other consumer, because a requirement that
is wrong in the same way for both would otherwise pass. That is not
hypothetical: on its first run the hand count disagreed with both other columns
for a pair of @rhombus(no_repeats) constraints, and the hand count was the
thing that was wrong.

@section{Limitations}

The notation's checks happen at compile time; the encoding does not ---
everything from @rhombus(geometry_of) onward runs at run time.

Not implemented: the @tt{optional} factors of @tt{CoverAllCombinations};
@tt{Relax}, which searches over @italic{k} rather than declaring anything;
continuous factors, which SweetPea also keeps out of the solver;
@tt{LatinSquare} over three or more factors, which needs an odometer over the
rotations of all but the longest; and @tt{MultiCrossBlock}, more than one
crossing over the same design. @tt{Merge} in its full sense, several crossings
solved concurrently, is not attempted.

CMSGen and UniGen are not offered as strategies. Both are largely a matter of
invoking a different solver executable, but neither binary was available to
test against.

@include_section("reference.scrbl")
