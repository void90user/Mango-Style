mmsg get layout 2>/dev/null | awk '{printf "%s%s", (NR>1 ? " | " : ""), toupper($NF)} END{print ""}'
