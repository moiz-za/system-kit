#!/usr/bin/env bash
#
# registry-parse.sh — shared THREADS.md parser library for System Kit.
#
# WHY THIS EXISTS: earlier scripts detected the registry's table format
# by counting pipe fields (NF >= 10 etc.). That is a landmine — any new
# column shifts every positional index and NF-based guesses silently
# read the WRONG columns (a heartbeat written into the Tree column, a
# scope read from the Mutexes column). This library resolves columns
# by HEADER NAME instead: the header row is read once, each consumer
# asks for the columns it needs by name, and absent columns resolve to
# a caller-provided default. Adding a column to the registry no longer
# requires touching any script.
#
# Header names across registry generations:
#   v2: Thread · Started · Tasks · Mutexes · Shared Files · Heartbeat · Status
#   v3: + Scope · Tree
#   v4: + Lane · Model
# "Scope" and "Shared Files" both resolve to the SCOPE column.
#
# Usage (source this file, then):
#   registry_read "$(cat docs/THREADS.md)"   # parse once (cached in vars)
#   registry_rows                            # newline list of data rows
#   registry_col <row> <Name> [default]      # trimmed value from a row
#   registry_format                          # 2 / 3 / 4 (0 unknown)
#   registry_col_row <row> <Name> <value>    # row with one column replaced
#
# library consumers: register-thread.sh, release-thread.sh,
# heartbeat.sh, check-scope-overlap.sh, check-stale.sh,
# validate-registry.sh

# True (0) when a row's pipe-field count matches the table header's —
# header-name resolution applies. Mismatched rows are resolved via
# registry_col_legacy (known historical layouts) by consumers that
# must not skip them (scope guards).
registry_row_matches_header() { # <row-line>
  local nf
  nf="$(printf '%s' "$1" | awk -F'|' '{print NF}')"
  [ "$nf" = "$REG_HEADER_NF" ]
}

# Universal column resolution: header-matching rows by header name;
# legacy rows by their own layout. Unknown layouts (a future column
# addition) still resolve STABLE positions — Thread ($2) and Status
# ($NF-1, the last cell) hold across every layout ever shipped — and
# return the default for anything else. This is the forward-compat
# guarantee: adding a column never breaks parsing.
registry_col_any() { # <row-line> <Name> [default]
  local row="$1" name="$2" default="${3:-}" v rc
  if registry_row_matches_header "$row"; then
    v="$(registry_col "$row" "$name" "$default")"
    printf '%s' "$v"
    return 0
  fi
  v="$(registry_col_legacy "$row" "$name")"
  rc=$?
  if [ $rc -ne 0 ]; then
    case "$name" in
      Thread) printf '%s' "$(printf '%s' "$row" | awk -F'|' '{v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}')" ;;
      Status)  printf '%s' "$(printf '%s' "$row" | awk -F'|' '{v=$(NF-1); gsub(/^[ \t]+|[ \t]+$/,"",v); print v}')" ;;
      *) printf '%s' "$default" ;;
    esac
    return 0
  fi
  printf '%s' "$v"
  return 0
}

registry_read() { # <entire file content>
  REG_CONTENT="$1"
  REG_HEADER=""
  REG_ROWS=""
  REG_HEADER_NF=""
  local in_active=0 in_table=0 line
  # read every line INCLUDING a final unterminated one (command
  # substitution strips the trailing newline, so plain `read` loops
  # would silently drop the last row)
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_active" = "1" ]; then
      case "$line" in
        "## "*) in_active=0; in_table=0 ;;
        "| Thread"*)
          REG_HEADER="$line"
          REG_HEADER_NF="$(printf '%s' "$line" | awk -F'|' '{print NF}')"
          in_table=1
          ;;
        "|"*"|"*)
          if [ "$in_table" = "1" ]; then
            case "$line" in
              "|"*---*")"|"|"*"---"*) ;; # separator row — skip
              *) REG_ROWS="${REG_ROWS}${line}"$'\n' ;;
            esac
          fi
          ;;
        "") ;;                         # blank line tolerated inside table
        *) in_table=0 ;;               # prose ends the table
      esac
    else
      case "$line" in
        "## Active Threads"*) in_active=1 ;;
      esac
    fi
  done < <(printf '%s' "$REG_CONTENT")
  _registry_map_header
}

# Resolve a column from a row of ANY KNOWN historical layout, without
# reference to the table header. Detects the row's own layout by cell
# count (awk NF = cells + 2, from the empty fields around the pipes):
#   v2 (7 cells, NF=9):  Thread2 Started3 Tasks4 Mutexes5 Scope6         HB8(NF-1... see below) Status
#   v3 (8 cells, NF=10): Thread2 Started3 Tasks4 Mutexes5 Scope6 Tree7   HB9  Status10
#   v4 (10 cells, NF=12):Thread2 Started3 Tasks4 Lane5 Mutexes6 Scope7 Tree8 Model9 HB11 Status12
# Stable positions per layout (verified: $NF is the trailing empty
# field, $1 the leading one, so Status = NF-... no: Status IS the last
# cell = NF-1; Heartbeat = NF-2).
# Returns 1 for unrecognized layouts (caller decides skip vs refuse).
registry_col_legacy() { # <row-line> <Name> -> echoes value; 0 found / 1 unknown layout
  local row="$1" name="$2"
  printf '%s' "$row" | awk -F'|' -v want="$name" '
    {
      nf = NF
      pos = 0
      if (nf == 9) {        # v2: 7 cells
        if      (want == "Thread")    pos = 2
        else if (want == "Started")   pos = 3
        else if (want == "Tasks")     pos = 4
        else if (want == "Mutexes")   pos = 5
        else if (want == "Scope")     pos = 6
        else if (want == "Heartbeat") pos = 8
        else if (want == "Status")    pos = 9
        else if (want == "Lane")      { print "CODE"; exit 0 }
        else if (want == "Tree")      { print "main"; exit 0 }
        else if (want == "Model")     { print "-"; exit 0 }
      } else if (nf == 10) { # v3: 8 cells
        if      (want == "Thread")    pos = 2
        else if (want == "Started")   pos = 3
        else if (want == "Tasks")     pos = 4
        else if (want == "Mutexes")   pos = 5
        else if (want == "Scope")     pos = 6
        else if (want == "Tree")      pos = 7
        else if (want == "Heartbeat") pos = 8
        else if (want == "Status")    pos = 9
        else if (want == "Lane")      { print "CODE"; exit 0 }
        else if (want == "Model")     { print "-"; exit 0 }
      } else if (nf == 12) { # v4: 10 cells
        if      (want == "Thread")    pos = 2
        else if (want == "Started")   pos = 3
        else if (want == "Tasks")     pos = 4
        else if (want == "Lane")      pos = 5
        else if (want == "Mutexes")   pos = 6
        else if (want == "Scope")     pos = 7
        else if (want == "Tree")      pos = 8
        else if (want == "Model")     pos = 9
        else if (want == "Heartbeat") pos = 10
        else if (want == "Status")    pos = 11
      }
      if (pos == 0) { exit 1 }
      v = $pos; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit 0
    }'
}

_registry_map_header() {
  REG_IDX_THREAD=""; REG_IDX_STARTED=""; REG_IDX_TASKS=""; REG_IDX_LANE=""
  REG_IDX_MUTEXES=""; REG_IDX_SCOPE=""; REG_IDX_TREE=""; REG_IDX_MODEL=""
  REG_IDX_HEARTBEAT=""; REG_IDX_STATUS=""
  [ -n "$REG_HEADER" ] || return 0
  local rest="$REG_HEADER|" i=1 field
  while [ "$rest" != "" ]; do
    field="${rest%%|*}"
    rest="${rest#*|}"
    field="${field#"${field%%[![:space:]]*}"}"   # ltrim
    field="${field%"${field##*[![:space:]]}"}"   # rtrim
    case "$field" in
      Thread)    REG_IDX_THREAD="$i" ;;
      Started)   REG_IDX_STARTED="$i" ;;
      Tasks)     REG_IDX_TASKS="$i" ;;
      Lane)      REG_IDX_LANE="$i" ;;
      Mutexes)   REG_IDX_MUTEXES="$i" ;;
      Scope|Shared\ Files) REG_IDX_SCOPE="$i" ;;
      Tree)      REG_IDX_TREE="$i" ;;
      Model)     REG_IDX_MODEL="$i" ;;
      Heartbeat) REG_IDX_HEARTBEAT="$i" ;;
      Status)    REG_IDX_STATUS="$i" ;;
    esac
    i=$((i + 1))
  done
  return 0
}

registry_rows() { # echoes the parsed data rows (one per line)
  printf '%s' "$REG_ROWS"
}

# Map a friendly column name to its index variable.
_registry_idx_for() { # <Name> -> echoes index ("" if column absent)
  case "$1" in
    Thread)    printf '%s' "${REG_IDX_THREAD:-}" ;;
    Started)   printf '%s' "${REG_IDX_STARTED:-}" ;;
    Tasks)     printf '%s' "${REG_IDX_TASKS:-}" ;;
    Lane)      printf '%s' "${REG_IDX_LANE:-}" ;;
    Mutexes)   printf '%s' "${REG_IDX_MUTEXES:-}" ;;
    Scope|Shared\ Files) printf '%s' "${REG_IDX_SCOPE:-}" ;;
    Tree)      printf '%s' "${REG_IDX_TREE:-}" ;;
    Model)     printf '%s' "${REG_IDX_MODEL:-}" ;;
    Heartbeat) printf '%s' "${REG_IDX_HEARTBEAT:-}" ;;
    Status)    printf '%s' "${REG_IDX_STATUS:-}" ;;
    *) printf '' ;;
  esac
}

registry_col() { # <row-line> <Name> [default] -> echoes trimmed value
  local row="$1" name="$2" default="${3:-}"
  local idx
  idx="$(_registry_idx_for "$name")"
  if [ -z "$idx" ]; then
    printf '%s' "$default"
    return 0
  fi
  printf '%s' "$row" | awk -F'|' -v n="$idx" '
    { v = $n; gsub(/^[ \t]+|[ \t]+$/, "", v); print v }' | head -1
}

# Replace one column's value in a row, preserving pipe structure.
# (Used by heartbeat to stamp rows without positional assumptions.)
registry_col_row() { # <row-line> <Name> <new-value> -> echoes new row
  local row="$1" name="$2" value="$3"
  local idx
  idx="$(_registry_idx_for "$name")"
  if [ -z "$idx" ]; then
    printf '%s' "$row"
    return 0
  fi
  printf '%s' "$row" | awk -F'|' -v n="$idx" -v val="$value" '
    BEGIN { OFS = "|" }
    { $n = " " val " "; print }'
}

registry_format() { # echoes 2 / 3 / 4 (0 = no recognizable header)
  [ -n "$REG_HEADER" ] || { echo 0; return; }
  case "$REG_HEADER" in
    *Lane*Model*) echo 4 ;;
    *Scope*Tree*) echo 3 ;;
    *Shared\ Files*) echo 2 ;;
    *) echo 0 ;;
  esac
}

# Canonical CURRENT column set — upgrade target for in-passing header
# upgrades when a claim lands on an older-format registry.
registry_v4_header() {
  echo "| Thread | Started | Tasks | Lane | Mutexes | Scope | Tree | Model | Heartbeat | Status |"
}

registry_v4_separator() {
  echo "|---|---|---|---|---|---|---|---|---|---|"
}
