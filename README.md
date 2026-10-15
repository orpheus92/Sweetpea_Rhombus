# Sweetpea_Rhombus — SweetPea experiment designs in Rhombus

## What this is, in plain terms

SweetPea generates trial sequences for behavioural experiments. You describe
your experiment -- the factors, their levels, how they cross -- and it works
out valid orderings of trials.

This project does the same job, written in Rhombus instead of Python.

You write the design in a notation that reads like the experiment itself.
Before anything runs, the design is checked: a misspelled factor name, a
derived level with the wrong number of parameters, or a factor you crossed
but forgot to declare will all stop the file from compiling. If the design is
sound, it is turned into a logic problem, handed to a SAT solver, and the
answer is turned back into trials.

**No Python is involved at any point.**

This is a research pilot, not a tool to run a study with. See *What is not
done* at the end.

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
      ~within: session                       // repeat the above per session
      ~constraints: [sequential(2)]

`~design` may be wider than `~cross`: a factor in the design but not the
crossing varies freely. `~within` is optional; it holds a factor constant
across each instance of the inner design, which is SweetPea's `Nest`.

## Generating trials

    synthesize_trials(plan, 3)                          # 3 sequences
    synthesize_trials(plan, 3, ~strategy: #'random)
    synthesize_trials(plan, 3, ~constraints: [pin(0, 0, 0)])
    synthesize_trials(plan, 3, ~solver: "minisat")
    check_sequence(plan, seq, ~constraints: [...])      # [] if sound
    count_sequences(plan)

## Constraints available

    consistent()        one level per factor per trial        (automatic)
    crossed()           each combination once per segment     (automatic)
    sustained(fi)       held constant across a segment        (automatic with ~within)
    outer_crossed(fi)   each segment gets a distinct level    (automatic with ~within)
    exclude(fi, li)     a level that never appears
    pin(i, fi, li)      a level fixed to a trial
    no_repeats(fi)      no two adjacent trials share a level  (AtMostKInARow, k=1)
    sequential(fi)      segments run in declaration order     (SweetPea's Sequential)

Factors are referred to by position in `~design`, counting the `~within`
factor last. Names would be friendlier and are an obvious next change.

## Sampling strategies

`#'iterate` solves the CNF, adds a clause forbidding that answer, and solves
again. Distinct sequences, not uniformly sampled -- you get whichever the
solver prefers, and the same ones on every run. SweetPea's `IterateSATGen`.

`#'random` proposes a random ordering and keeps it only if the checker
accepts, which is rejection sampling -- SweetPea's `RandomGen`. It needs no
solver, samples with replacement, and respects whatever constraints are in
play.

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
    racket examples/sequential.rhm        sequential inside a nest
    racket examples/design_vs_cross.rhm   design wider than crossing
    racket examples/windows.rhm           no_repeats
    racket examples/constraints_demo.rhm  constraints and the checker
    racket examples/inside_a_constraint.rhm  what a declaration produces
    racket examples/stroop.rhm            the notation, incl. derived factors

    racket tests/agreement.rhm            encoder and checker agree
    racket tests/sequential_regime.rhm    the design that broke SweetPea
    racket tests/uniformity.rhm           chi-square on #'random
    racket tests/verify.rhm               trial counts and distinctness
    tests/run-tests.sh                    designs that must FAIL to compile

---

# What is not done

Derived factors are parsed and statically checked but **not encoded** --
`synthesize_trials` rejects them, so the Stroop example cannot be
synthesized end to end. The `derived` sublanguage from the proposal's §2 is
not implemented, so derivation bodies are arbitrary Rhombus.

`MinimumTrials` is absent and does not fit the current design: it changes how
many trials exist rather than constraining an assignment, which belongs to a
separate phase. `AtMostKInARow` for k >= 2 needs a counter encoding in
`cnf_of`; `holds_in` already handles any k. `Merge` in its full sense --
several crossings solved concurrently -- is not attempted.

CMSGen and UniGen are not available as strategies. Both are largely a matter
of invoking a different solver executable, but neither binary is in Homebrew
or the Racket catalog, so neither was testable here.

Everything runs at run time. The notation's checks happen at compile time;
the encoding does not.
