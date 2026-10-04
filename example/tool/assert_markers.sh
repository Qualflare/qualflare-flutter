#!/usr/bin/env bash
# Usage: assert_markers.sh RESULTS.json [native]
# Fails unless the Dart JSON reporter results hold markers of every kind on the
# right tests. With "native", also requires the native screenshot to have
# produced attachment chunks and the whole run to hold no warning.
set -euo pipefail
file=${1:?results file}
native=${2:-}

# Every test's markers, parsed, keyed by test name.
read -r -d '' defs <<'JQ' || true
def prefix: "##qualflare[v1] ";
(map(select(.type=="testStart") | {key: (.test.id|tostring), value: .test.name}) | from_entries) as $names
| (map(select(.type=="testDone") | {key: (.testID|tostring), value: .result}) | from_entries) as $results
| def markers($n): [.[] | select(.type=="print" and $names[.testID|tostring]==$n)
    | .message | select(startswith(prefix)) | ltrimstr(prefix) | fromjson];
JQ

# jq -s: slurp, so -e judges the whole file rather than its last line.
jq -s -e "$defs"'
  markers("pays for the cart") as $m
  | ($m | map(.k) | unique) as $kinds
  | (["label","link","tag","priority","step+","step-","att"] - $kinds | length == 0)
  and ($m | any(.k=="link" and .type=="issue"))
  and ($m | any(.k=="step+" and .parent != null))
  and ($m | any(.k=="att" and .name=="order.json" and .type=="application/json"))
  and ($m | any(.k=="att" and .name=="confirmed.png" and .type=="image/png"))
  and ((.[] | select(.type=="testStart" and .test.name=="pays for the cart") | .test.id | tostring) as $id
       | $results[$id] == "success")
' "$file" >/dev/null || { echo "pays for the cart: a marker kind is missing or the test did not pass" >&2; exit 1; }

jq -s -e "$defs"'
  (markers("shows a receipt (fails on purpose)") | any(.k=="att" and .name=="failure.png"))
  and ((.[] | select(.type=="testStart" and .test.name=="shows a receipt (fails on purpose)") | .test.id | tostring) as $id
       | $results[$id] != "success")
' "$file" >/dev/null || { echo "the failing test has no failure screenshot or did not fail" >&2; exit 1; }

jq -s -e "$defs"'
  (markers("recovers on the second attempt") | any(.k=="att" and .name=="failure.png"))
  and ((.[] | select(.type=="testStart" and .test.name=="recovers on the second attempt") | .test.id | tostring) as $id
       | $results[$id] == "success")
' "$file" >/dev/null || { echo "the retried test did not fail once with a screenshot then pass" >&2; exit 1; }

if [ "$native" = native ]; then
  jq -s -e "$defs"'
    markers("captures the native screen") as $m
    | ($m | any(.k=="att" and .name=="native.png" and .type=="image/png" and .n >= 1))
    and (map(select(.type=="print") | .message | select(startswith(prefix+"{\"k\":\"warn\""))) | length == 0)
  ' "$file" >/dev/null || { echo "the native screenshot did not produce att chunks, or a warn marker was recorded" >&2; exit 1; }
fi
echo "markers ok: $file"
