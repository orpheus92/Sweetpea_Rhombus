# sp_r — SweetPea experiment designs in Rhombus

## What this is, in plain terms

SweetPea generates trial sequences for behavioural experiments. You describe
your experiment — the factors, their levels, how they cross — and it works out
valid orderings of trials.

This project does the same job, written in Rhombus instead of Python.

You write the design in a notation that reads like the experiment itself.
Before anything runs, the design is checked: a misspelled factor name, a
derived level with the wrong number of parameters, or a factor you crossed but
forgot to declare will all stop the file from compiling. If the design is
sound, it is turned into a logic problem, handed to a SAT solver, and the
answer is turned back into trials.

**No Python is involved at any point.**

## What it looks like

    factor color: ["red", "blue"]
    factor size:  ["small", "large"]

    experiment plan:
      ~design: [color, size]
      ~cross: [color, size]

    let trials = synthesize_trials(plan, 3)

gives

    sequences found: 3
      [["red", "small"], ["blue", "large"], ["red", "large"], ["blue", "small"]]
      [["red", "large"], ["blue", "large"], ["blue", "small"], ["red", "small"]]
      [["red", "small"], ["blue", "large"], ["blue", "small"], ["red", "large"]]

Four trials, because two colours crossed with two sizes gives four
combinations and each must appear once. Three sequences, because that is what
was asked for; twenty-four exist in total, and asking for more than that
returns all twenty-four and stops.

## How it works

    your .rhm file
       |  COMPILE TIME — the notation expands and is checked
       |    * factor names are bindings, not strings, so typos cannot pass
       |    * derived levels must match their factor's parameters
       |    * every crossed factor must be declared in the design
       v
    Factor / Experiment values
       |  RUN TIME
       |    * boolean variables laid out, one per trial-factor-level
       |    * constraints written as clauses, saved as a CNF file
       v
    a SAT solver (an external program)
       |
       v
    the model is decoded back into trials

The solver is a separate executable that reads a CNF file and reports a
solution. SweetPea calls the very same program the very same way; nothing
about the Python implementation sat between the design and the solver.

## Requirements

Racket 9.3 or later, Rhombus, and a DIMACS SAT solver.

    raco pkg install --auto rhombus
    brew install cryptominisat      # or: brew install minisat

## Running it

    racket examples/pilot.rhm      # generate trials
    racket examples/strategies.rhm # the two sampling strategies side by side
    racket examples/stroop.rhm     # the notation, including derived factors
    racket tests/verify.rhm        # check the trials are actually valid
    racket tests/uniformity.rhm    # check #\'random really is uniform
    tests/run-tests.sh             # designs that must FAIL to compile

## Constraints: declared once, used twice

This is the part that makes it a language rather than a library.

A constraint says which *requirements* hold for a design. Every requirement
has one shape -- of this set of atoms, between `lo` and `hi` are true:

    constraint pin(i, fi, li) ~given geom:
      [at_least(1, [Lev(i, fi, li)])]

    constraint exclude(fi, li) ~given geom:
      let atoms: for List (i in 0..geom.n_trials): Lev(i, fi, li)
      [at_most(0, atoms)]

From that one declaration, two things are derived by shared code:

    cnf_of(req, var_of)    clauses for the solver
    holds_in(req, is_set)  a check against a finished sequence

A constraint author writes neither. There is no second copy to keep in step,
so the encoder and the checker **cannot** disagree.

That matters because they can and do elsewhere. SweetPea writes every
constraint twice -- 13 constraints, 253 lines of encoder and 119 of checker --
with nothing tying them together. One pair drifted: `Sequential`, where
`constraint.py:1232` divides by the segment length and `:1487` does not. The
result was `RandomGen` returning sessions in the wrong order and reporting
success. It is still that way on upstream master.

`tests/agreement.rhm` asserts the property SweetPea has no way to state:

    ok  every solver result passes the checker (24 sequences)
    ok  with pin(trial 0, color=red): solver obeys it and the checker agrees
    ok  #'random obeys the same constraint (50 draws)
    ok  a sequence starting with the wrong colour is rejected by pin
    ok  a sequence repeating one combination is rejected by crossed
    ok  excluding a level needed by the crossing yields 0 sequences

The third line is the sharpest: `#'random` finds sequences by rejection
sampling, using `holds_in`, while `#'iterate` finds them by solving clauses
from `cnf_of`. Two strategies, two code paths, one declaration. If the
declaration were wrong they would fail together; if the derivation were
wrong they would disagree.

## Sampling strategies

    synthesize_trials(plan, 3, ~strategy: #\'iterate)   # the default
    synthesize_trials(plan, 3, ~strategy: #\'random)
    synthesize_trials(plan, 3, ~constraints: [pin(0, 0, 0)])
    check_sequence(plan, seq, ~constraints: [pin(0, 0, 0)])  # [] if sound

`#\'iterate` solves the CNF, adds a clause forbidding that answer, and solves
again. The sequences are distinct but not uniformly sampled -- you get
whichever the solver prefers, and the same ones on every run. This is what
SweetPea calls `IterateSATGen`.

`#\'random` draws a uniformly random valid sequence directly, without a solver.
Within this pilot's scope -- plain factors, fully crossed, no other
constraints -- the valid sequences are exactly the orderings of the
combination list, so a random ordering is a uniform draw. It samples WITH
replacement, so two draws can coincide. This is SweetPea's `RandomGen`.

`count_sequences(plan)` reports how many valid sequences a design admits.
For a fully crossed design that is (number of combinations) factorial.

Measured on a 2x2 design, 2400 draws over the 24 possible sequences:

    every draw valid:        #true
    distinct sequences seen: 24 of 24
    chi-square (df=23):      18.56   (critical value at p=.05 is 35.17)
    verdict: consistent with uniform

    #\'iterate run twice -> identical
    #\'random  run twice -> different

CMSGen and UniGen are not implemented. Both are mostly a matter of invoking a
different solver executable -- SweetPea's own code is `unigen_exe = CMSGEN_EXE
if use_cmsgen else UNIGEN_EXE` plus a few flags -- so neither is deep work,
but neither binary was available to test against.

## Why the checking matters

A mistyped factor name is the clearest case. Writing a design as a Python
program, this is legal:

    color = Factor("color", ["red", "blue"])
    ...
    CrossBlock([color, word], [colour, word], [])

`colour` is a typo, but nothing can flag it: a factor's name is just text
inside quotes, with no connection to the variable. The program runs and
describes a different experiment than the one intended. Here, `colour` is a
name that was never defined, and the file will not compile.

More generally, a Python program has no stage at which a design is examined
without being run. An error in a branch that never executes is never reported.
Here the design is checked when the file is compiled, whether or not it runs.

## What is not done yet

Only plain factors are encoded, every design factor must be crossed, and the
crossing is the only constraint. `MinimumTrials`, `Exclude`, `AtMostKInARow`,
derived factors in the solver, `Nest`, `Merge` and weighted levels are not
encoded — the notation parses derived factors, but `synthesize_trials` rejects
them rather than quietly doing the wrong thing.

Uniform sampling works only because the pilot has no constraints beyond the
crossing. Once `Exclude` or `MinimumTrials` exist, the valid sequences are no
longer just the orderings of the combination list, and `#\'random` would have
to count solutions properly -- which is what SweetPea's `RandomGen` actually
does, and is real work.
