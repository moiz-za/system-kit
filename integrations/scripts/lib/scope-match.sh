#!/usr/bin/env bash
#
# scope-match.sh — shared scope-path matching library for System Kit.
#
# One matcher used by every scope consumer (register-thread.sh,
# check-scope-overlap.sh, pre-commit-scope-check.sh) so a scope is
# enforced identically at claim time, CI time, and commit time.
#
# Scope entry forms (space-separated list in the Scope column / identity
# file; comma also accepted as a separator):
#   src/api/          directory prefix — matches everything under it
#   src/api/tasks.ts  exact file
#   src/**/*.test.ts  glob: ** = any depth, * = one segment (fnmatch)
#   docs/guide/*.md   glob within one directory level
#
# Usage (source this file):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/scope-match.sh"
#   scope_list_contains_path <scope-list> <path>   # 0 if path inside
#
# Matching is prefix-safe: a directory scope matches all deeper paths;
# a glob is compiled to a fnmatch pattern once and tested per path.

# Expand one scope entry into a matchable regex-free fnmatch pattern.
# Bash case-statement globs natively support ** when extglob is on;
# we translate our documented syntax to case patterns instead:
#   **  -> *   (case patterns are already depth-free with pattern lists)
# Handled explicitly below with case + pathname segmentation.
scope_entry_matches_path() { # <scope-entry> <path> -> 0 if match
  local entry="$1" path="$2"
  [ -n "$entry" ] || return 1
  [ -n "$path" ] || return 1
  # exact file
  [ "$entry" = "$path" ] && return 0
  # directory prefix (entries ending in /)
  case "$entry" in
    */) case "$path" in "$entry"*) return 0 ;; esac ; return 1 ;;
  esac
  # glob entry (contains * or ?): translate to an ERE and match in awk.
  #   **  -> .*        (any chars, crosses directory separators)
  #   *   -> [^/]*     (one path segment)
  #   ?   -> [^/]      (one char, not a separator)
  # Everything else is regex-escaped. Anchored full-match.
  case "$entry" in
    *\** | *\?*)
      awk -v e="$entry" -v p="$path" 'BEGIN {
        re = ""
        i = 1
        n = length(e)
        while (i <= n) {
          c = substr(e, i, 1)
          two = substr(e, i, 2)
          if (two == "**") { re = re ".*"; i += 2; continue }
          if (c == "*")    { re = re "[^/]*"; i++; continue }
          if (c == "?")    { re = re "[^/]"; i++; continue }
          # escape ERE metacharacters
          if (c ~ /[\\.^$()|\[\]{}+]/) re = re "\\" c
          else re = re c
          i++
        }
        # ** between slashes may match zero segments: "src/**/*.ts" should
        # also hit "src/*.ts" — soften "**/" to "(/.*)?/" via alternative.
        gsub(/\.\*\//, "(.*/)?", re)
        exit(p ~ ("^" re "$") ? 0 : 1)
      }' && return 0 || return 1
      ;;
  esac
  # plain file entry that didn't equal path (prefix of a dir path?)
  case "$path" in "$entry"/*) return 0 ;; esac
  return 1
}

scope_list_contains_path() { # <space-or-comma-separated-list> <path>
  local list="$1" path="$2" entry
  [ -n "$list" ] || return 1
  [ -n "$path" ] || return 1
  # normalize commas to spaces; iterate with pathname expansion OFF so
  # glob scopes (src/**/*.ts) are handled as literals, not expanded
  # against the current directory
  local normalized="${list//,/ }"
  set -f
  for entry in $normalized; do
    set +f
    scope_entry_matches_path "$entry" "$path" && return 0
    set -f
  done
  set +f
  return 1
}

# Do two scope ENTRIES overlap? (used by claim/CI pairwise checks)
# Directory prefixes: containment. Globs: conservative — a glob overlaps
# any entry it can match (or that can match it), because a glob claims a
# wide, hard-to-enumerate area; blocking is always the safe answer.
scope_entry_overlaps_entry() { # <entry-a> <entry-b> -> 0 if overlap
  local a="$1" b="$2"
  [ -n "$a" ] || return 1
  [ -n "$b" ] || return 1
  # exact
  [ "$a" = "$b" ] && return 0
  # directory containment
  case "$a" in "$b"*) return 0 ;; esac
  case "$b" in "$a"*) return 0 ;; esac
  # glob on either side: match the other entry against the glob, and a
  # representative file inside it if the other is a directory
  local glob nonglob
  glob=""; nonglob=""
  case "$a" in
    *\** | *\?*) glob="$a"; nonglob="$b" ;;
  esac
  if [ -z "$glob" ]; then
    case "$b" in
      *\** | *\?*) glob="$b"; nonglob="$a" ;;
    esac
  fi
  if [ -n "$glob" ]; then
    scope_entry_matches_path "$glob" "$nonglob" && return 0
    case "$nonglob" in
      */) scope_entry_matches_path "$glob" "${nonglob}probe" && return 0 ;;
    esac
    # glob vs glob with different fixed prefixes can still intersect
    # (e.g. src/** and src/api/**) — prefix containment above covers the
    # common case; anything else with shared prefixes counts as overlap
    local pa="${a%%\**}" pb="${b%%\**}"
    [ -n "$pa" ] && [ -n "$pb" ] || return 1
    case "$pa" in "$pb"*) return 0 ;; esac
    case "$pb" in "$pa"*) return 0 ;; esac
    return 1
  fi
  return 1
}

scope_list_overlaps_entry() { # <list> <entry>
  local list="$1" entry="$2" e
  local normalized="${list//,/ }"
  set -f
  for e in $normalized; do
    set +f
    scope_entry_overlaps_entry "$e" "$entry" && { return 0; }
    set -f
  done
  set +f
  return 1
}

scope_list_overlaps_list() { # <list-a> <list-b>
  local a="$1" b="$2" ea eb
  local na="${a//,/ }" nb="${b//,/ }"
  set -f
  for ea in $na; do
    set +f
    if scope_list_overlaps_entry "$b" "$ea"; then set -f; return 0; fi
    set -f
  done
  set +f
  return 1
}
