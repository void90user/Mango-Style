#!/usr/bin/env bash

export MANGO_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/mango-*.sock 2>/dev/null | head -1)

mmsg get all-monitors 2>/dev/null \
  | grep -o '"layout_symbol":"[^"]*"' \
  | grep -o '"[^"]*"$' \
  | tr -d '"' \
  | tr '[:lower:]' '[:upper:]' \
  | paste -sd '|' \
  | sed 's/|/ | /g'
