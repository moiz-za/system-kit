#!/usr/bin/env bash
#
# validate-deploy-handoff.sh — machine-checkable Deploy Handoff validation.
#
# The refusal rule, automated: a DEPLOY-lane thread (or CI) runs this
# against a filed handoff BEFORE executing anything. A handoff is
# complete when every required section is present and filled — no
# placeholder markers, no "gate green" claimed without numbers.
#
# Two modes:
#   FULL (default)     — the routine 10-item form; everything required
#   EMERGENCY          --emergency: the minimal incident set (version,
#                        evidence, what-changed, rollback); the rest
#                        follows within 24h per the emergency path
#
# Works with BOTH project vocabularies (universal kit — git and non-git):
#   git projects    : version identity = commit sha + how remote-verified
#   non-git projects: version identity = release artifact reference
#                     (timestamp + BUILDLOG entry, or archive checksum)
#   The validator does not care WHICH — it checks the items are
#   PRESENT and FILLED, not their vocabulary.
#
# Usage:
#   ./validate-deploy-handoff.sh <handoff.md> [--emergency]
#
# Exit 0  → handoff complete — safe to execute
# Exit 1  → REFUSED — incomplete (missing sections listed). Deploy
#           thread: post a one-line refusal, notify the owner, nothing
#           deploys until the CODE thread completes the handoff.
# Exit 2  → usage / input error

set -u

usage() {
  cat <<EOF
Usage: $0 <handoff.md> [--emergency]
  --emergency   validate the minimal incident set instead of the full form
EOF
}

[ "$#" -ge 1 ] || { usage; exit 2; }
FILE="$1"; shift || true
MODE="full"
[ "${1:-}" = "--emergency" ] && MODE="emergency"
[ -f "$FILE" ] || { echo "ERROR: handoff file not found at '$FILE'"; exit 2; }

CONTENT="$(cat "$FILE")"

FAIL=0
missing() { echo "MISSING/UNFILLED: $1"; FAIL=1; }

# Extract the body of a numbered item: the remainder of the heading
# line after the label, plus everything up to the next numbered
# heading. Handles both shapes: "2. TARGET: staging" (value inline)
# and multi-line bodies.
section_body() { # <label-regex> -> echoes the item's body text
  printf '%s' "$CONTENT" | awk -v pat="$1" '
    BEGIN { IGNORECASE = 1 }
    !in_item && $0 ~ pat {
      in_item = 1
      # remainder of the heading line after the label match
      idx = index($0, ":")
      if (idx > 0) print substr($0, idx + 1)
      else if ($0 ~ /[a-z]/) print $0
      next
    }
    in_item && /^[0-9]+\. / { exit }
    in_item { print }'
}

section_filled() { # <label-regex> -> 0 when filled
  local body
  body="$(section_body "$1")"
  # strip placeholders and emptiness; filled = at least one real line
  printf '%s' "$body" | awk '
    {
      line = $0
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (line == "" || line ~ /^-+$/) next
      if (line ~ /⟨[^⟩]*⟩/) next
      if (line ~ /^<[^>]*>$/) next
      if (tolower(line) ~ /\[fill\]/) next
      if (line ~ /TODO/) next
      print "FILLED"; exit
    }' | grep -q FILLED
}

# EMERGENCY mode: the minimal incident set only — version (1),
# what changed (3), rollback (8), gate evidence (9). Target/DB/env/
# build/smoke/urgency are waived DURING the incident; the full form
# follows within 24h.
if [ "$MODE" = "emergency" ]; then
  if printf '%s' "$CONTENT" | grep -qiE 'PINNED (SHA|VERSION|ARTIFACT)'; then
    section_filled 'PINNED (SHA|VERSION|ARTIFACT)' || missing "item 1 — pinned version/sha/artifact"
    printf '%s' "$CONTENT" | grep -qiE 'VERIFIED HOW|verified.*(remote|ref|checksum|api|log)' \
      || missing "item 1 — how the pinned version was VERIFIED"
  else
    missing "item 1 — pinned version/sha/artifact"
  fi
  section_filled 'WHAT CHANGED' || missing "item 3 — what changed (one line)"
  section_filled 'ROLLBACK'      || missing "item 8 — rollback"
  section_filled 'GATE EVIDENCE' || missing "item 9 — gate evidence"
  printf '%s' "$CONTENT" | grep -qE '[0-9]+ */ *[0-9]+|[0-9]+ (passed|tests|assertions)|✓' \
    || missing "item 9 — gate evidence must carry NUMBERS"

  echo "------------------------------------------------"
  if [ "$FAIL" -eq 1 ]; then
    echo "REFUSED — even the emergency minimal set is incomplete."
    exit 1
  fi
  echo "OK — minimal EMERGENCY handoff complete. The full form follows"
  echo "within 24h after the incident is resolved."
  exit 0
fi

# ---- FULL mode: all ten items ----
echo "Deploy Handoff validation — $FILE (mode: $MODE)"
echo "------------------------------------------------"

# Item 1: version identity — the contract. No version = no deploy.
# Accepts both vocabularies (git sha / non-git release artifact).
if printf '%s' "$CONTENT" | grep -qiE 'PINNED (SHA|VERSION|ARTIFACT)'; then
  if ! section_filled 'PINNED (SHA|VERSION|ARTIFACT)'; then
    missing "item 1 — pinned version/sha/artifact (present but unfilled)"
  fi
  # verification discipline: "pushed" must state HOW verified
  if ! printf '%s' "$CONTENT" | grep -qiE 'VERIFIED HOW|verified.*(remote|ref|checksum|api|log)'; then
    missing "item 1 — how the pinned version was VERIFIED (not assumed)"
  fi
else
  missing "item 1 — pinned version/sha/artifact (git: full commit sha; non-git: release artifact reference)"
fi

# Item 2: target
if ! section_filled 'TARGET'; then
  missing "item 2 — target environment"
fi

# Item 3: what changed — written for zero shared context
if ! section_filled 'WHAT CHANGED'; then
  missing "item 3 — what changed (plain English, for a stranger)"
fi

# Item 4+5: DB + env prerequisites (explicit "none" is a valid fill)
if ! printf '%s' "$CONTENT" | grep -qiE 'DB PREREQUISIT'; then
  missing "item 4 — DB prerequisites (or explicit 'none')"
elif ! section_filled 'DB PREREQUISIT' && ! printf '%s' "$CONTENT" | grep -qiE '(DB PREREQUISIT[a-z]*[^a-z]*none|no db changes)'; then
  missing "item 4 — DB prerequisites (unfilled)"
fi
if ! printf '%s' "$CONTENT" | grep -qiE 'ENV.?( /|/)? ?SECRETS|SECRETS CHANGES'; then
  missing "item 5 — env/secrets changes (or explicit 'none')"
elif ! section_filled 'ENV.?( /|/)? ?SECRETS|SECRETS CHANGES' && ! printf '%s' "$CONTENT" | grep -qiE '(ENV[^0-9]*none|no env changes)'; then
  missing "item 5 — env/secrets changes (unfilled)"
fi

# Item 7: smoke list — must exist with at least one concrete check
if ! section_filled 'SMOKE LIST'; then
  missing "item 7 — smoke list (specific checks, not 'check the site')"
elif ! printf '%s' "$CONTENT" | grep -qiE 'rendered|content|behavior|route|login|grep|expected'; then
  missing "item 7 — smoke list must name CONCRETE checks (routes/behaviors/rendered content, not generic)"
fi

# Item 8: rollback — prior-good version + steps
if ! section_filled 'ROLLBACK'; then
  missing "item 8 — rollback (prior-good version + concrete steps)"
fi

# Item 9: gate evidence — numbers required, "green" alone is refused
if ! section_filled 'GATE EVIDENCE'; then
  missing "item 9 — gate evidence"
elif ! printf '%s' "$CONTENT" | grep -qE '[0-9]+ */ *[0-9]+|[0-9]+ (passed|tests|assertions)|✓'; then
  missing "item 9 — gate evidence must carry NUMBERS (counts/results), not 'green'"
fi

# Full-mode extras
if [ "$MODE" = "full" ]; then
  if ! section_filled 'BUILD.?/CACHE|BUILD/CACHE'; then
    missing "item 6 — build/cache steps beyond the standard ceremony (or 'none')"
  fi
  if ! section_filled 'URGENCY'; then
    missing "item 10 — urgency (routine / owner-requested / emergency)"
  fi
fi

echo "------------------------------------------------"
if [ "$FAIL" -eq 1 ]; then
  echo "REFUSED — handoff incomplete. Per the refusal rule: nothing deploys"
  echo "until the CODE thread completes this handoff. Post a one-line"
  echo "refusal in the queue entry and notify the owner."
  exit 1
fi
if [ "$MODE" = "emergency" ]; then
  echo "OK — minimal EMERGENCY handoff complete. The full form follows"
  echo "within 24h after the incident is resolved."
else
  echo "OK — handoff complete. Safe to execute per the queue ceremony."
fi
exit 0
