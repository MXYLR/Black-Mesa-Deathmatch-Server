#!/bin/bash
# Compile every .sp in plugins/ with spcomp 1.11.0.6608
cd "$(dirname "$0")"
SPCOMP="/c/tmp/smx_analysis/dl/sm-win/addons/sourcemod/scripting/spcomp.exe"
mkdir -p out
pass=0; fail=0
cd plugins
for f in *.sp; do
    name=$(basename "$f" .sp)
    if "$SPCOMP" -i../include -o "../out/$name.smx" "$f" >"../out/$name.log" 2>&1; then
        pass=$((pass+1))
        echo "OK   $name"
    else
        fail=$((fail+1))
        echo "FAIL $name"
    fi
done
cd ..
echo "--- pass=$pass fail=$fail"
