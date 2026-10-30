#!/bin/bash
# The whole suite. Three kinds of check:
#
#   1. bad-*.rhm   must FAIL to compile; anything that compiles is a bug
#   2. the others  must run clean and report no failing case
#   3. examples/   must run at all (a smoke test), unless --no-examples
#
# Needs racket, rhombus and cryptominisat5 on PATH. From the repo root:
#   bash tests/run-tests.sh
cd "$(dirname "$0")"
fail=0

echo "== designs that must be rejected at compile time"
for f in bad-*.rhm; do
  if msg=$(raco make "$f" 2>&1); then
    echo "FAIL  $f compiled, but should have been rejected"
    fail=1
  else
    echo "ok    $f -> $(echo "$msg" | head -1)"
  fi
done

echo
echo "== tests"
for f in *.rhm; do
  case "$f" in bad-*) continue ;; esac
  out=$(racket "$f" 2>&1)
  status=$?
  # a reporting test prints FAIL, BAD or "NOT consistent" for a failing case
  if [ $status -ne 0 ] || echo "$out" | grep -qE "FAIL|BAD |NOT consistent"; then
    echo "FAIL  $f"
    echo "$out" | grep -E "FAIL|BAD |NOT consistent|rror" | head -5 | sed 's/^/        /'
    fail=1
  else
    echo "ok    $f"
  fi
done

if [ "$1" != "--no-examples" ]; then
  echo
  echo "== examples (smoke test: must run)"
  for f in ../examples/*.rhm; do
    if out=$(racket "$f" 2>&1); then
      echo "ok    $(basename "$f")"
    else
      echo "FAIL  $(basename "$f")"
      echo "$out" | tail -3 | sed 's/^/        /'
      fail=1
    fi
  done
fi

rm -rf compiled
echo
if [ $fail -eq 0 ]; then echo "everything passed"; else echo "FAILURES above"; fi
exit $fail
