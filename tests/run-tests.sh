#!/bin/bash
# Each file under tests/ must FAIL to compile. Anything that compiles is a bug.
cd "$(dirname "$0")"
fail=0
for f in bad-*.rhm; do
  if msg=$(raco make "$f" 2>&1); then
    echo "FAIL  $f compiled, but should have been rejected"
    fail=1
  else
    echo "ok    $f -> $(echo "$msg" | head -1)"
  fi
done
rm -rf compiled
exit $fail
