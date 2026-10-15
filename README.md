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

    racket examples/pilot.rhm     # generate trials
    racket tests/verify.rhm       # check the trials are actually valid
    racket examples/stroop.rhm    # the notation, including derived factors
    tests/run-tests.sh            # designs that must FAIL to compile

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

Sampling is not uniform. Repeated calls add clauses forbidding the sequences
already found and take whatever the solver returns next, which enumerates
valid sequences but does not sample them evenly. SweetPea's `RandomGen` and
`UniGen` exist precisely for that, and neither is implemented here. Uniformity
matters for real experiments; this is a gap, not a design choice.
