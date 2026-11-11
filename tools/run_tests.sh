#!/bin/bash
# Führt alle Tests aus und zählt Fehlerzeilen. Aufruf im Projektordner: tools/run_tests.sh [ordner-für-protokolle]
# Reihenfolge: alle Nacht-Tests, Lauftests, Daten, Rückfall-Prüfungen, Bildrate, 15-Tage-Durchlauf.
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-/tmp/homebound-tests}
mkdir -p "$OUT"
fail=0
run() { # name, argumente...
	local name=$1; shift
	local start; start=$(date +%s)
	timeout 3000 godot --headless --path . -- "$@" > "$OUT/$name.log" 2>&1
	local code=$?
	local errs; errs=$(grep -c -E 'SCRIPT ERROR|^ERROR: [^0-9]|^FEHLER' "$OUT/$name.log")
	echo "$name: Ende $code, Fehlerzeilen $errs, $(( $(date +%s) - start )) s"
	if [ "$code" != 0 ] || [ "$errs" != 0 ]; then fail=1; fi
}
godot --headless --path . --import > /dev/null 2>&1
for m in save mauler attack observe probe attack_locked events craft melee changes dread world research extras lab w17 camp places map supplies tablet lurk gear; do
	run "nt_$m" "--night-test=$m"
done
run walk --walk-test
run walk_lab --walk-test --lab
run walk_stream --walk-test --stream
run data --night-test=data
run regress --night-test=regress
run fps --night-test=fps
run playthrough --night-test=playthrough
echo "Protokolle: $OUT"
exit $fail
