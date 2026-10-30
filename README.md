# Sweetpea_Rhombus

An implementation of SweetPea's experiment-design language in Rhombus.

## Overview

SweetPea is a domain-specific language for specifying counterbalanced
experimental designs. A design declares factors and their levels, states which
factors must be crossed, and adds constraints; SweetPea then produces trial
sequences that satisfy the specification.

This project reimplements that capability in Rhombus. A design is written as a
set of declarations in the host language, validated during compilation,
encoded as a Boolean satisfiability problem, solved by an external SAT solver,
and decoded back into trial sequences. No stage of the pipeline depends on the
Python implementation.

Validation occurs at expansion time and rejects three classes of
specification error before any code executes: references to undeclared
factors, derived levels whose arity contradicts their declaration, and factors
named in a crossing but absent from the design. Errors are reported even when
they occur in code paths that are never evaluated.

Constraints are declared once. A single declaration determines both the
clauses given to the solver and the predicate used to verify a finished
sequence, so the two representations cannot diverge. This property is the
central design commitment of the implementation and is discussed in
*Constraints: declared once, used twice* below.

**Status.** This is a research pilot intended to evaluate the approach, not a
tool for generating experiments used in studies. See *Limitations*.

---

# Installing

Three things: Racket, Rhombus, and a SAT solver. About ten minutes.

## 1. Racket 9.3 or later

Rhombus v1.0 needs a recent Racket. **Note that conda will not work** --
conda-forge's `racket` is stuck at 7.8, years too old.

**macOS.** `brew install --cask racket` is the obvious route but may fail
with a checksum mismatch, because Racket occasionally re-publishes an
installer without bumping the version and the Homebrew cask goes stale. If
that happens, install from the official download instead:

    cd ~/Downloads
    curl -LO https://mirror.racket-lang.org/installers/9.3/racket-9.3-aarch64-macosx-cs.dmg
    shasum -a 256 racket-9.3-aarch64-macosx-cs.dmg      # compare against the
                                                        # release page before
                                                        # continuing
    hdiutil attach racket-9.3-aarch64-macosx-cs.dmg
    cp -R "/Volumes/Racket v9.3/Racket v9.3" /Applications/
    hdiutil detach "/Volumes/Racket v9.3"
    echo 'export PATH="/Applications/Racket v9.3/bin:$PATH"' >> ~/.zshrc

Use `racket-9.3-x86_64-macosx-cs.dmg` on an Intel Mac.

**Linux.**

    curl -LO https://mirror.racket-lang.org/installers/9.3/racket-9.3-x86_64-linux-cs.sh
    sh racket-9.3-x86_64-linux-cs.sh

**Windows and other versions.** <https://download.racket-lang.org/>

Check it:

    racket --version        # Welcome to Racket v9.3 [cs].

## 2. Rhombus

    raco pkg install --auto rhombus

A few minutes, most of it building documentation. Check it:

    echo '#lang rhombus
    println("ok")' > /tmp/t.rhm && racket /tmp/t.rhm

## 3. A SAT solver

Needed only for `~strategy: #'iterate`, which is the default. The `#'random`
strategy runs without one.

    brew install cryptominisat      # macOS
    apt install cryptominisat       # Debian/Ubuntu

`minisat` and `picosat` also work. Any solver that reads DIMACS CNF and
replies with `s SATISFIABLE` / `v ...` will do -- pass its name or full path
as `~solver:`. SweetPea shells out to the same CryptoMiniSAT executable, so
if you already have SweetPea working you already have one.

Check it:

    printf 'p cnf 2 2\n1 -2 0\n2 0\n' > /tmp/t.cnf && cryptominisat5 /tmp/t.cnf

If a solver is missing, `synthesize_trials` says so by name rather than
producing nonsense.

## 4. Try it

    git clone https://github.com/orpheus92/Sweetpea_Rhombus.git
    cd Sweetpea_Rhombus
    racket examples/pilot.rhm

Expect three four-trial sequences. If that works, everything is installed.

---

# Using it

## The notation

    factor color:   ["red", "blue"]
    factor size:    ["small", "large"]
    factor session: ["s1", "s2", "s3"]

    factor congruency(color, word):          // a derived factor
      [derived con(a, b): a == b,
       derived inc(a, b): a != b]

    experiment plan:
      ~design: [color, size]                 // everything in a trial
      ~cross: [color, size]                  // what must be balanced
      ~within: [session, group] ~in_order    // repeat per combination
      ~min_trials: 30                        // SweetPea's MinimumTrials
      ~cover: [color, task]                  // CoverAllCombinations
      ~constraints: [no_repeats(color)]

Every clause but `~design` and `~cross` is optional, and they may be written
in any order. An unrecognized clause does not compile, so `~min_trial` for
`~min_trials` is caught rather than ignored (`tests/bad-clause.rhm`).

`~cover: [color, task]` is SweetPea's `CoverAllCombinations`: every
realizable combination of the listed factors must appear in some trial. A
factor outside the crossing is otherwise free, so nothing guarantees a
particular combination ever shows up. Coverage can lengthen the design --
one trial per combination at least, rounded up so the crossing still gets
whole passes -- which is why it is a keyword rather than a constraint, the
same reasoning as `~min_trials`. `cover_all_combinations([...])` is available
as a plain constraint when the design is already long enough.

A combination that cannot occur is not required. The case SweetPea's
documentation names is one contradicting a derived level's predicate, and
that is decided by calling the predicate, which is why this requirement sits
beside `derivation` rather than with the other constraints. A combination
ruled out for some other reason is still required, and the design then has
no solution; and the listed factors must be unweighted, as in SweetPea.
Not implemented: `optional`, the factors SweetPea gives up one at a time
when the design has no solution.

`~min_trials` lengthens the design: a segment always holds at least one
full crossing, and the keyword can only ask for more. The trials beyond one
crossing spread over the combinations -- each appears the floor or the
ceiling of the average, never more -- which is what the cardinality encoding
in `crossed` was already able to say. Under `~within` it lengthens each
segment, as SweetPea does when a `MinimumTrials` is pushed into a nested
block. It is a keyword and not a constraint because that is what it is in
SweetPea too: `MinimumTrials.apply` only sets a field on the block, and its
checker returns `True` unconditionally.

`~design` may be wider than `~cross`: a factor in the design but not the
crossing varies freely. `~within` is optional; it holds a factor constant
across each instance of the inner design, which is SweetPea's `Nest`.

`~within` takes one factor or a list of them. SweetPea's `Nest` takes an
outer *block*, not a factor, so the outer may cross several factors; with a
list, a segment holds one combination of them constant and the combinations
-- not the individual levels -- are what gets crossed over the segments. Two
sessions crossed with two groups gives four segments. `~in_order` then runs
through the combinations in the order the factors were declared.

A level may carry a weight, which is SweetPea's `Level(name, weight=w)`:

    factor color: ["red" ~weight 2, "blue"]

A level of weight `w` is combined `w` times with each combination of the
other crossed factors' levels. So the crossing takes the product of the
weight sums in trials -- `(2+1) x (1+1) = 6` above -- while the set of
distinct combinations is still the product of the level counts, and each
combination is entitled to the product of its own levels' weights. The
crossing already stated its requirement as a count between two bounds, so
weights cost it nothing. A derived level can be weighted the same way. A
weight on an uncrossed factor leaves the geometry alone, which is where this
stops short of SweetPea: there a weight also biases sampling, and here it
does not.

A `factor` declaration binds its level names as well, inside the factor's
own namespace, so a constraint can name a level rather than quote one:

    exclude(color, color.red)      checked when the module is compiled
    exclude(color, color.pink)     pink: identifier not provided by color
    exclude(color, "pink")         compiles; fails when the constraint runs

The last line is SweetPea's situation: `Exclude((color, "pink"))` is a
well-formed call that builds a perfectly good constraint about a level no
trial can have. `tests/bad-level.rhm` is the typo in a function that is
never called, and it does not compile. `examples/level_names.rhm` shows both
spellings side by side.

Two consequences worth knowing. A level listed twice is refused, since the
crossing counts levels and a duplicate would quietly change how many trials
a design has. And because `color` is now a namespace as well as a value,
`color.levels` no longer reads the Factor field -- use `Factor.levels(color)`.

## Derived factors

    factor congruency(color, word):
      [derived con(a, b): a == b,
       derived inc(a, b): a != b]

A derived factor's level in a trial is a function of its parents' levels in
that trial, so it is never a free choice. The requirement that says so is
SweetPea's `Derivation`, and like `consistent` and `crossed` it is applied
automatically -- it is part of what the design means, not something to write.

It is declared in `synthesize.rhm` rather than with the other constraints,
because it is the only requirement that needs to know what a derived level
is: it calls the predicate. By the time a geometry exists, every level has
been reduced to its value, so `constraints.rhm` contains no mention of
derived factors and every other constraint treats one as an ordinary factor.
That is why `no_repeats(congruency)` and `pin(0, congruency, congruency.con)`
need nothing special, and why a derived factor can be crossed:

    experiment plan:
      ~design: [color, word, congruency]
      ~cross: [color, congruency]

which is the Stroop design -- balance colour against congruency and let the
word follow. `examples/stroop.rhm` is Figure 2 of the proposal as a running
program; `tests/derived.rhm` checks the derived column against the predicate
on every sequence, and checks the two edges: levels whose predicates overlap
are refused, and a predicate that covers only some parent combinations
excludes the rest, which is how SweetPea excludes through a derived factor.

### Windows

    factor repetition(color) ~width 2:        // SweetPea's Transition
      [derived same(prev, now): prev == now,
       derived switch(prev, now): prev != now]

`~width w` means each predicate reads `w` consecutive trials of each parent,
oldest first and the parents in declaration order -- so at width 2 over
`(color, word)` the parameters are `(color_prev, color_now, word_prev,
word_now)`. Width 1 is SweetPea's `WithinTrial`, 2 is its `Transition`, and
any `w` is its `Window`. The arity is checked when the module is compiled,
so writing a transition predicate as if it took one value does not compile
(`tests/bad-window-arity.rhm`).

A window factor has no level for the first `w-1` trials of a segment, since
its window would reach back past the start. That is SweetPea's preamble, and
it shows up in four places: a trial inside it reads `#false` for that
factor, `consistent` requires that none of its levels be set there, `decode`
expects none, and if the factor is crossed the segment grows by the preamble
-- the crossing can only use trials where every crossed factor has a level.
So balancing colour against repetition over three colours is 6 + 1 = 7
trials.

### Strides, starts, chains and else

    factor alternating(color) ~width 2 ~stride 2:     // every other trial
      [derived same(prev, now): prev == now,
       derived diff(prev, now): prev != now]

    factor late(color) ~width 2 ~start 2:             // levels begin at 2
      [...]

`~stride s` gives the factor a level every `s` trials rather than every
trial, and `~start` overrides the trial its levels begin on. Together they
generalize the preamble from "the first `w-1` trials" into "these are the
trials it is scored on", which is one predicate -- `has_level` -- that
everything reading a trial now asks first. A strided factor cannot be
crossed, since it has no level in most trials, and cannot be read by another
factor, which is SweetPea's restriction too; a `~start` earlier than the
computed one is refused rather than left to the predicate to cope with,
which is where SweetPea leaves it.

    factor emphasis(color, word):
      [derived bold(c, w): c == "red" && w == "red",
       else plain]

`else` is SweetPea's `ElseLevel`: a level with no predicate of its own,
holding exactly when none of the others do.

A derived factor may derive from another:

    factor switched(congruency) ~width 2:
      [derived stay(prev, now): prev == now,
       derived flip(prev, now): prev != now]

The encoder needs nothing for this -- the parent's level variables exist
like any factor's and its own requirement ties them to its parents, so the
chain composes. What follows the chain is the preamble, computed through it
(own `width-1` plus the deepest parent's), and the order the sampler fills
the columns in, shallowest first so a child reads the value just computed.
SweetPea does the same with `Factor._get_depth` and a sort.

### Crossing a derived factor

Any of these may be crossed, because a derived factor's level variables are
ordinary variables and the crossing never learns where they came from:

    ~cross: [color, congruency]     a within-trial derived factor
    ~cross: [color, repetition]     a window factor (+ its preamble)
    ~cross: [color, switched]       a factor two deep
    ~cross: [congruency, switched]  two derived factors together

`tests/derived.rhm` covers all four. The exception is a strided factor, for
the reason above.

One difference from SweetPea. If a crossed combination cannot occur --
because it contradicts a derived level's predicate -- the design here has no
solution. SweetPea's `CrossBlock` behaves the same way by default, but takes
`require_complete_crossing=False` to drop the impossible combinations and
shrink the crossing, and there is no equivalent here yet. The realizability
test that `~cover` already performs is what such an option would need.

`examples/derived_chain.rhm` runs a chain, a stride and an `else` level
through one design and prints which factor is scored where.

## Generating trials

    synthesize_trials(plan, 3)                          # 3 sequences
    synthesize_trials(plan, 3, ~strategy: #'random)
    synthesize_trials(plan, 3, ~constraints: [pin(0, 0, 0)])
    synthesize_trials(plan, 3, ~solver: "minisat")
    check_sequence(plan, seq, ~constraints: [...])      # [] if sound
    count_sequences(plan)

## Constraints available

Applied to every design, with no need to write them:

    consistent()                 one level per factor per trial
    crossed()                    each combination gets its share of a
                                 segment: one each when the segment is one
                                 crossing, and floor/ceiling of the average
                                 when weights or ~min_trials make it longer
    derivation(f)                a derived factor follows its parents

Applied when the design calls for them:

    sustained(f)                 held constant across a segment  (~within)
    outer_crossed(fs)            each outer combination gets one segment
    sequential(fs)               the segments take them in order (~in_order)
    cover_all_combinations(fs)   every realizable combination appears
                                 (~cover)

Written by hand:

    exclude(f, level)            a level that never appears
    pin(i, f, level)             a level fixed to a trial, -1 is the last
    no_repeats(f)                no two adjacent trials share a level
    at_most_k_in_a_row(k, t)     AtMostKInARow, any k
    at_least_k_in_a_row(k, t)    AtLeastKInARow
    exactly_k_in_a_row(k, t)     ExactlyKInARow
    exactly_k_multiple_in_a_row(k, t)
                                 runs whose length is a multiple of k
    exactly_k(k, f, level)       exactly k trials carry this level
    latin_square([f, g])         LatinSquare, two factors
    within_each(c)               any constraint, inside each segment only

Constraints name factors and levels directly -- `no_repeats(color)`,
`exclude(size, "small")` -- so a design never mentions an index.

The three run-length constraints take a target `t` that is either a factor,
in which case the rule applies to every one of its levels, or a single
`[factor, level]` pair:

    at_most_k_in_a_row(1, color)            no colour twice running
    at_least_k_in_a_row(2, [color, "red"])  red, when it appears, appears twice

SweetPea's `AtMostKInARow` accepts the same two shapes.

`tests/all_constraints.rhm` puts every constraint above through the same
three-way check, on a flat design, a nested one and a nested one in order:
the sequences the solver returns under the constraint, the sequences the
checker accepts, and a count worked out by hand must all agree. The hand
count is what distinguishes this from a self-consistency test -- a
requirement that is wrong in the same way for both consumers would still be
caught.

`pin` takes a negative index as counting back from the end, and an index
outside the sequence gives a design with no solution rather than an error,
both as SweetPea documents.

Both consumers reach a constraint's requirements through one function,
`reqs_of`, which checks every atom against the geometry first. Declaring a
constraint once stops `cnf_of` and `holds_in` from disagreeing about what it
means, which was SweetPea's `Sequential` bug; it does not stop an atom from
naming a trial, factor or level the design does not have. Until `reqs_of`
checked, the two behaved differently when one did: `pin(99, color, "red")` on
a four-trial design had the solver allocate a variable for a trial that does
not exist and return every sequence, while the checker crashed indexing the
sequence. `tests/bad_constraints.rhm` holds that line, and separates it from
the case that is merely unsatisfiable -- `exactly_k(99, ...)` asks for more
than the design can give, which SweetPea reports as no sequences rather than
an error, and so does this.

`latin_square([item, order])` reads the sequence as rows of N trials. Every
row holds every level of both factors, the second factor follows the first by
an offset that is constant within a row, and consecutive rows take
consecutive offsets, with the starting offset left to the solver.

Which way the cycle turns is not in SweetPea's documentation, and the two
directions admit different sequences, so it was settled against SweetPea
itself: squares were passed to `sample_mismatch_experiment` with
`LatinSquare([a, b])` in play, and at N = 3 and N = 4, from either start, it
accepts offsets that step down by one per row and rejects offsets that step
up. The encoding here steps down. Agreement was then checked both ways --
five squares from this encoder were accepted by SweetPea, and four sequences
SweetPea generated are accepted here. Those four are recorded in
`tests/latin_square.rhm`, so the agreement is retested on every run without
SweetPea installed.

A row is what SweetPea's guide calls a participant: it sees one diagonal of
the crossing, so it sees every level of every factor without seeing every
combination, and the combinations are covered across participants.

The two factors need not have the same number of levels. The row is as long
as the longer factor -- SweetPea calls that the diagonal length -- and the
shorter one fills the row by repeating, so with four levels against two each
of the two takes half of every row and the diagonal is read modulo two. The
shorter count must divide the longer, or no row can hold each of its levels
equally often, and `latin_square` says so. Parity here was checked the same
way as the rotation direction: four 4-against-2 squares from this encoder
were accepted by SweetPea, and three of its own are accepted here and kept
as fixtures.

Two factors, though. SweetPea generalizes to more by giving every factor
except the longest its own rotation and stepping the vector of rotations
like an odometer, so the cycle is as long as the product of the other
factors' level counts. `latin_square` refuses three or more rather than
pretending.

`within_each` is the scope SweetPea gives by attaching a constraint list to
the inner block of a `Nest`:

    no_repeats(size)                no two adjacent trials, anywhere
    within_each(no_repeats(size))   ... except across a session boundary

It is a combinator rather than a kind of constraint. The wrapped constraint
is asked for its requirements against a geometry one segment long, and the
trial indices that come back are shifted into each segment in turn. So it
needs nothing from the constraint and works for every one of them --
`within_each(pin(0, color, color.red))` opens every session on red --
including constraints not written yet. Without a `~within` factor there is
one segment and it changes nothing.

`sequential` is no longer written as a constraint. Ordering the segments is a
property of the design, so it is stated there:

    ~within: session ~in_order

which is SweetPea's `Sequential`. The same split applies in principle to
`exclude` and `pin`: both attach to the design rather than relating trials to
one another, and both would read better as keywords. `no_repeats` is a
genuine constraint, since it constrains trials relative to each other.

## Not yet implemented

    CoverAllCombinations  the `optional` factors, which SweetPea gives up
                          one at a time when there is no solution
    Relax                 weakens a constraint when the design has no
                          solution, which is a search over k rather than a
                          declaration
    ContinuousConstraint  continuous factors are not in the encoding at all
    LatinSquare           three or more factors, which needs the odometer
                          over the rotations of all but the longest
    CrossBlock            require_complete_crossing=False, which drops the
                          combinations a derived predicate rules out instead
                          of leaving the design unsatisfiable

## Sampling strategies

`#'iterate` solves the CNF, adds a clause forbidding that answer, and solves
again. Distinct sequences, not uniformly sampled -- you get whichever the
solver prefers, and the same ones on every run. SweetPea's `IterateSATGen`.

`#'random` proposes a random ordering and keeps it only if the checker
accepts, which is rejection sampling -- SweetPea's `RandomGen`. It needs no
solver, samples with replacement, and respects whatever constraints are in
play.

What it proposes are the *basic* factors. A derived factor's value is
computed from its parents, with the same predicates the derivation
requirement uses, and left empty inside its preamble. Guessing it instead
would be rejected almost always, and for a window factor always, since a
guess fills a preamble trial that has to stay empty. SweetPea's `RandomGen`
does the same: it partitions the design, samples the basic factors, and
fills the derived ones in dependency order with the preamble as its own
range.

Where the crossing fixes a within-trial derived level, the free parents are
not left to chance either: they are drawn uniformly from among the
assignments that produce the level asked for. So the Stroop design, whose
crossing names a derived factor, samples at once rather than waiting for a
guess to come good.

Drawing uniformly from among them is what keeps the result uniform. Picking
the first parent that happens to fit would not: it would make some valid
sequences likelier than others. Every arrangement of the crossing holds the
same multiset of combinations, so the number of ways to complete it is the
product of the per-trial option counts and is the same for every
arrangement -- a uniform arrangement with a uniform completion of each trial
therefore gives every valid sequence the same chance.

A crossed factor whose window is wider than one trial is the exception,
since its options depend on trials already chosen. Those are left to
rejection, which is what SweetPea does with what it calls complex windows.
Rejection from a uniform proposal is still uniform; it is only slower.

Measured on a 2x2 design, 2400 draws over the 24 possible sequences:

    every draw valid:        #true
    distinct sequences seen: 24 of 24
    chi-square (df=23):      18.56
      p=.001 critical value: 49.73   <- what the test asserts
    #'iterate run twice -> identical
    #'random  run twice -> different

The test asserts at p=.001 rather than p=.05 deliberately: a chi-square test
at p=.05 rejects a *correct* sampler about one run in twenty, which would
make the suite flaky.

---

# Constraints: declared once, used twice

This is the part that makes it a language rather than a library.

A constraint says which *requirements* hold for a design. Every requirement
has one shape -- of these atoms, between `lo` and `hi` are true. Atoms are
literals, so `Not` is available:

    constraint pin(i, fi, li) ~given geom:
      [at_least(1, [Lev(i, fi, li)])]

    constraint sequential(fi) ~given geom:
      let n_seg = geom.n_trials / geom.seg_len
      let n = geom.counts[fi]
      for List (s in 0..n_seg):
        at_least(1, [Lev(s * geom.seg_len, fi, s mod n)])

From that one declaration, two things are derived by shared code:

    cnf_of(req, var_of)    clauses for the solver
    holds_in(req, is_set)  a check against a finished sequence

A constraint author writes neither. There is no second copy to keep in step,
so the encoder and the checker **cannot** disagree.

That matters because elsewhere they do. SweetPea writes every constraint
twice -- 13 constraints, 253 lines of encoder and 119 of checker -- with
nothing tying them together. One pair drifted: `Sequential`, where
`constraint.py:1232` divides the trial index by the segment length and
`:1487` does not. In the regime `n = 3` levels, `S = 2` trials per segment,
its `RandomGen` returns `s1, s3, s2` and reports success. That is still the
case on upstream master.

`tests/sequential_regime.rhm` runs exactly that design here:

    #'iterate (SAT):               ["s1","s1","s2","s2","s3","s3"]
    #'random (rejection sampling): ["s1","s1","s2","s2","s3","s3"]
    the sequence SweetPea returns, s1,s3,s2:
       checker says: ["sequential"]

Two strategies, two independent code paths, one declaration.

---

# Running everything

    racket examples/pilot.rhm             generate trials
    racket examples/strategies.rhm        the two sampling strategies
    racket examples/nesting.rhm           ~within
    racket examples/nested_outer.rhm      ~within with several factors
    racket examples/sequential.rhm        ordering inside a nest
    racket examples/design_keywords.rhm   ~in_order, and constraints by name
    racket examples/design_vs_cross.rhm   design wider than crossing
    racket examples/windows.rhm           no_repeats
    racket examples/cardinality.rhm       at_most_k_in_a_row, exactly_k
    racket examples/run_length.rhm        at_least/at_most/exactly k in a row
    racket examples/level_names.rhm       levels as names, not strings
    racket examples/within_each.rhm       a constraint scoped to a session
    racket examples/latin_square.rhm      Latin square counterbalancing
    racket examples/constraints_demo.rhm  constraints and the checker
    racket examples/inside_a_constraint.rhm  what a declaration produces
    racket examples/stroop.rhm            the notation, incl. derived factors
    racket examples/transition.rhm        a level that reads the previous trial
    racket examples/derived_chain.rhm     derived chains, strides, else levels

    bash tests/run-tests.sh               everything below, in one go
                                          (plus the bad-*.rhm designs, which
                                           must fail to compile)

    racket tests/agreement.rhm            encoder and checker agree
    racket tests/all_constraints.rhm      every constraint, against a hand count
    racket tests/bad_constraints.rhm      arguments that must be refused
    racket tests/scope.rhm                within_each, against a hand count
    racket tests/latin_square.rhm         Latin squares, incl. parity with SweetPea
    racket tests/derived.rhm              derived factors against their predicates
    racket tests/window.rhm               windows and the preamble, brute-forced
    racket tests/weights.rhm              weighted crossings, brute-forced
    racket tests/cover.rhm                ~cover, brute-forced
    racket tests/nest.rhm                 ~within with several factors
    racket tests/derived_shapes.rhm       derived chains, strides, else levels
    racket tests/min_trials.rhm           ~min_trials, against a hand count
    racket tests/sequential_regime.rhm    the design that broke SweetPea
    racket tests/counter_encoding.rhm     cardinality encoding vs. the solver
    racket tests/run_length.rhm           run lengths vs. brute force
    racket tests/uniformity.rhm           chi-square on #'random
    racket tests/verify.rhm               trial counts and distinctness
    tests/run-tests.sh                    designs that must FAIL to compile

---

# Limitations

Derived factors are parsed and statically checked but **not encoded** --
`synthesize_trials` rejects them, so the Stroop example cannot be
synthesized end to end. The `derived` sublanguage from the proposal's §2 is
not implemented, so derivation bodies are arbitrary Rhombus.

`MinimumTrials` is absent and does not fit the current design: it changes how
many trials exist rather than constraining an assignment, which belongs to a
separate phase. `Merge` in its full sense --
several crossings solved concurrently -- is not attempted.

CMSGen and UniGen are not available as strategies. Both are largely a matter
of invoking a different solver executable, but neither binary is in Homebrew
or the Racket catalog, so neither was testable here.

Everything runs at run time. The notation's checks happen at compile time;
the encoding does not.
