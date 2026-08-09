#!/bin/bash
# Run all podman-dev checks (or a subset: ./run-checks.sh 00 50).
# Exit 0 iff every check script passes. STOP_ON_FAIL=1 aborts at first failure.

set -u
cd "$(dirname "$0")"

if [ "$#" -gt 0 ]; then
    scripts=()
    for prefix in "$@"; do
        for f in "$prefix"*.sh; do
            [ -e "$f" ] || { echo "no check matching '$prefix'"; exit 2; }
            scripts+=("$f")
        done
    done
else
    scripts=([0-9][0-9]-*.sh)
fi

total=0 failed=0
for s in "${scripts[@]}"; do
    total=$((total + 1))
    if bash "$s"; then
        echo "PASS  $s"
    else
        echo "FAIL  $s"
        failed=$((failed + 1))
        [ "${STOP_ON_FAIL:-0}" = "1" ] && break
    fi
    echo
done

echo "=================================="
echo "checks: $((total - failed))/$total passed"
[ "$failed" -eq 0 ]
