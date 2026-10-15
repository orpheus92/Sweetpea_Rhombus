# sp_r — writing SweetPea experiments in Rhombus

## What this is, in plain terms

SweetPea generates trial sequences for behavioural experiments. To use it, you
describe your experiment — the factors, their levels, how they cross — and
SweetPea works out valid orderings of trials.

Today you write that description as a Python program. This project is **a
different way of writing the same description**, and a checker that reads what
you wrote before anything runs.

Think of the difference between **writing a request as a free-form letter**
and **filling in a form**. The letter lets you say anything, in any order, and
nobody notices a problem until someone tries to act on it. The form knows which
fields exist, notices when you refer to something you never defined, and
refuses to be submitted until it makes sense.

What happens after submission is unchanged. The same SweetPea does the same
work, by the same method. We have not re-done the science, the solver, or the
trial generation — only how the experiment gets written down, and whether
mistakes are caught before or after you hit run.

**So it is not a new SweetPea.** It is a notation for SweetPea experiments,
with a proofreader attached.

### Why that matters

A mistyped factor name is the clearest case. In Python:

    color = Factor("color", ["red", "blue"])
    ...
    CrossBlock([color, word], [colour, word], [])

`colour` is a typo. Python cannot flag it as one, because the name of a factor
is just a piece of text that happens to be inside the quotes — nothing connects
`"color"` the text to `color` the variable. The program is perfectly valid; it
just describes a different experiment than you meant.

Written in this notation, `colour` is a name that was never defined, and the
file will not compile. You find out immediately, not after the run, and not by
noticing something odd in your data.

### Current state

The notation and the checking work. Actually producing trials does not — that
step still needs to hand the finished description back to Python SweetPea, and
that part is not built. So today this is a demonstration, not a tool anyone
should use to run a study.

---

## For the technically inclined

**This is not a rewrite of SweetPea.** It replaces the surface syntax only.
The experiment semantics, CNF encoding and SAT solving stay in the existing
Python library.

## How it fits together

SweetPea-py has three layers:

| layer | what it does | who owns it |
|---|---|---|
| 1. surface API | `Factor`, `DerivedLevel`, `CrossBlock`, constraints | **this project** |
| 2. block layer | SAT variable layout, CNF encoding, constraint checking | Python, unchanged |
| 3. solvers | CryptoMiniSat, UniGen, CMSGen, RandomGen | Python, unchanged |

Only layer 1 moves to Rhombus. Layers 2 and 3 are roughly 1,700 lines of
constraint code plus the solver backends; reimplementing those is months of
work and would create a second copy of the semantics to keep in sync. Keeping
Python as the engine means it stays the reference implementation.

The flow:

    your .rhm file
       |  COMPILE TIME - Rhombus macros expand `factor` / `experiment`
       |    * names resolve to bindings, not strings
       |    * derived-level arity checked against the factor's parameters
       |    * every factor in ~cross must appear in ~design
       v
    Factor / Experiment values
       |  RUN TIME  (not yet built)
       |    * serialise the design and hand it to Python SweetPea
       v
    trials come back

Today the compile-time half works. The handoff to Python is the next step.

## Why bother, if Python already works

Python has no static phase at all. `python -m py_compile` accepts a file whose
design is nonsense; the error only appears if execution reaches that line.
Compare:

    $ raco make tests/bad-name.rhm
    experiment plan: `colour` appears in ~cross but not in ~design

    $ python -m py_compile bad_design.py
    (success)
    $ python bad_design.py
    script finished normally; the bad CrossBlock was never evaluated

Both errors live inside a function that is never called. Rhombus rejects the
file; Python runs it happily.

The sharpest case is a misspelled factor name. In Python, `Factor("colour", ...)`
is a well-formed call that builds a perfectly good *different* factor — no check
can catch it, because the name is data. In Rhombus `factor color:` binds an
identifier, so a typo is a compile-time error.

## Layout

    sweetpea.rhm        the DSL: factor, experiment, derived
    examples/stroop.rhm Figure 2 of the proposal, as a running program
    tests/bad-*.rhm     designs that MUST fail to compile
    tests/run-tests.sh  runs them and checks each one is rejected
    info.rkt            Racket package metadata

## Running it

Needs Racket 9.3+ and Rhombus (`raco pkg install --auto rhombus`).

    racket examples/stroop.rhm
    tests/run-tests.sh

## Not yet covered

`Nest`, `Merge`, `Repeat`, `MultiCrossBlock`, `Transition` and windows > 1,
`ContinuousFactor`, weighted levels, every constraint except a placeholder
string, sampler selection, and the Python backend.

`Transition` is the notable omission: window-2 derivations are common in real
designs, and the `derived` form's parameterization story changes once a level
depends on the previous trial. That is a deferred design question, not just a
missing feature.
