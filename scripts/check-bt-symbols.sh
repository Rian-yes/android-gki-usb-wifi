#!/bin/sh
# Check whether symbols needed by external Bluetooth modules are exported
# by the running kernel via /proc/kallsyms.
#
# Usage (run as root on device):
#   su -c "sh scripts/check-bt-symbols.sh needed-symbols.txt"

SYMFILE="${1:-needed-symbols.txt}"

if [ ! -f "$SYMFILE" ]; then
  echo "Error: symbol file '$SYMFILE' not found." >&2
  exit 1
fi

if [ ! -r /proc/kallsyms ]; then
  echo "Error: /proc/kallsyms is not readable (run as root)." >&2
  exit 1
fi

# ponytail: single-pass awk over /proc/kallsyms is 100x faster than 100 greps
if command -v awk >/dev/null 2>&1; then
  awk '
  BEGIN { missing = 0; total = 0 }
  NR == FNR {
    sym = $1
    sub(/[ \t\r\n]+$/, "", sym)
    if (sym ~ /^#/ || sym == "") next
    # Ignore symbols exported by the shipped module set itself
    if (sym ~ /^btintel_/ || sym ~ /^btrtl_/ || sym ~ /^af_alg_/) next
    needed[sym] = 1
    total++
    next
  }
  {
    name = $3
    if (name ~ /^__ksymtab_/) {
      sub(/^__ksymtab_/, "", name)
      if (name in needed) {
        delete needed[name]
      }
    }
  }
  END {
    for (sym in needed) {
      print "MISSING " sym
      missing++
    }
    found = total - missing
    print "Summary: " found "/" total " symbols verified present, " missing " MISSING"
    if (missing > 0) exit 1
  }
  ' "$SYMFILE" /proc/kallsyms
else
  missing=0
  total=0
  while IFS= read -r sym || [ -n "$sym" ]; do
    sym=$(echo "$sym" | tr -d ' \t\r\n')
    case "$sym" in
      \#*|"") continue ;;
      btintel_*|btrtl_*|af_alg_*) continue ;;
    esac
    total=$((total + 1))
    if ! grep -q "__ksymtab_${sym}\$" /proc/kallsyms 2>/dev/null; then
      echo "MISSING $sym"
      missing=$((missing + 1))
    fi
  done < "$SYMFILE"
  echo "Summary: $((total - missing))/$total symbols verified present, $missing MISSING"
  [ "$missing" -eq 0 ] || exit 1
fi
