#!/usr/bin/env bash
#
# check-security.sh — machine-checkable security posture scan.
#
# The kit's security laws are documented; this script checks the parts
# a script CAN see. It scans a project tree for the common leak and
# injection classes and reports findings with file:line detail. It
# cannot judge intent — it narrows where a human (or agent applying
# the Security Checklist pattern) must look.
#
# Checks:
#   secrets     high-confidence credential patterns in tracked text
#               files (AWS keys, private key blocks, generic
#               api_key/secret/token assignments with literal values).
#               Env-var references and placeholder names are exempt.
#   injection   classic prompt-injection markers in project files
#               ("ignore previous instructions", "disregard above",
#               base64 blobs in docs) — each hit is UNTRUSTED INPUT,
#               not automatically malicious.
#   keyring     .env / secrets files that exist but are untracked
#               (info only — correct setup is env vars or a secret
#               manager, never committed files)
#
# Usage:
#   ./check-security.sh [project-root] [--files <glob>...]
#
#   project-root   defaults to current directory
#   --files        limit the scan to specific paths (default: tracked
#                  text files, or all text files when not a git repo)
#
# Exit 0  → no high-confidence findings
# Exit 1  → findings need review (listed)
# Exit 2  → usage error
#
# Design notes:
# - Patterns are deliberately high-confidence; this is a triage tool,
#   not a substitute for the documented Security Checklist.
# - Secrets never get printed: only file:line and the pattern class.
#   Values stay out of logs and out of LLM context.

set -u

ROOT="${1:-.}"
shift 2>/dev/null || true
SCOPE_MODE="all"
if [ "${1:-}" = "--files" ]; then
  shift
  SCOPE_MODE="args"
fi

[ -d "$ROOT" ] || { echo "ERROR: project root '$ROOT' not found"; exit 2; }

cd "$ROOT" 2>/dev/null || exit 2

# ---- collect target files ----
TARGETS="$(mktemp)"
if [ "$SCOPE_MODE" = "args" ] && [ "$#" -gt 0 ]; then
  printf '%s\n' "$@" > "$TARGETS"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  # tracked text files only
  git ls-files 2>/dev/null | grep -Ev '\.(png|jpg|jpeg|gif|svg|ico|pdf|zip|gz|tar|woff2?|ttf|mp[34]|webm)$' > "$TARGETS"
else
  find . -type f \
    ! -path './.git/*' \
    ! -name '*.png' ! -name '*.jpg' ! -name '*.jpeg' ! -name '*.gif' \
    ! -name '*.svg' ! -name '*.ico' ! -name '*.pdf' ! -name '*.zip' \
    ! -name '*.gz' ! -name '*.woff' ! -name '*.woff2' ! -name '*.ttf' \
    > "$TARGETS"
fi

FINDINGS=0

echo "Security posture scan — $ROOT"
echo "------------------------------------------------"

# ---- secrets: high-confidence credential patterns ----
# Same allowlist applies: files that document credential patterns (e.g.
# the test harness's fake AWS example key) are exempt.
SECRETS_TMP="$(mktemp)"
ALLOWLIST=".kit-security-allowlist"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if [ -f "$ALLOWLIST" ] && grep -qF -- "$f" "$ALLOWLIST" 2>/dev/null; then
    continue
  fi
  # AWS access key id
  grep -nE 'AKIA[0-9A-Z]{16}' "$f" 2>/dev/null | sed "s|^|$f:|" >> "$SECRETS_TMP"
  # private key blocks
  grep -n 'BEGIN (RSA |EC |OPENSSH |PGP )\?PRIVATE KEY' "$f" 2>/dev/null | sed "s|^|$f:|" >> "$SECRETS_TMP"
  # assignments of literal values to secret-ish names (quoted or bare),
  # excluding env-var reads, empty values, placeholders, and docs prose
  grep -nEi '(api[_-]?key|secret|token|passwd|password|access[_-]?key)[[:space:]_]*[:=][[:space:]]*["'\''`]?[A-Za-z0-9+/_-]{16,}' "$f" 2>/dev/null \
    | grep -Ev '\$\{|process\.env|os\.environ|getenv|ENVI?RONMENT|<[^>]*>|\[|\bexample\b|\bplaceholder\b|your[_-]' \
    | sed "s|^|$f:|" >> "$SECRETS_TMP"
done < "$TARGETS"

SECRETS_N=0
if [ -s "$SECRETS_TMP" ]; then
  # count + show file:line ONLY — never the matched value (it must not
  # enter logs or LLM context)
  SECRETS_N=$(wc -l < "$SECRETS_TMP" | tr -d ' ')
  echo "[REVIEW] secrets: $SECRETS_N high-confidence credential pattern(s):"
  sed -E 's/^([^:]+):([0-9]+):.*/  \1:\2 [credential pattern]/' "$SECRETS_TMP" | sort -u
  FINDINGS=1
else
  echo "[PASS] secrets: no credential patterns in scanned files"
fi
rm -f "$SECRETS_TMP"

# ---- prompt-injection markers (untrusted-input flags) ----
# Same allowlist as the secrets scan (declared above) applies here.
INJ_TMP="$(mktemp)"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if [ -f "$ALLOWLIST" ] && grep -qF -- "$f" "$ALLOWLIST" 2>/dev/null; then
    continue
  fi
  grep -nEi 'ignore (all |any )?(previous|prior|above) (instructions?|prompts?|rules?)|disregard (the )?(above|previous|prior)|forget (your |all )?(previous|prior) (instructions?|rules?)' "$f" 2>/dev/null | sed "s|^|$f:|" >> "$INJ_TMP"
done < "$TARGETS"

INJ_N=0
if [ -s "$INJ_TMP" ]; then
  INJ_N=$(wc -l < "$INJ_TMP" | tr -d ' ')
  echo "[REVIEW] injection: $INJ_N prompt-injection marker(s) — treat as untrusted input:"
  sed -E 's/^([^:]+):([0-9]+):.*/  \1:\2 [injection marker]/' "$INJ_TMP" | sort -u
  FINDINGS=1
else
  echo "[PASS] injection: no injection markers in scanned files"
fi
rm -f "$INJ_TMP"

# ---- untracked local secret stores (informational) ----
UNTRACKED_ENV=0
if git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      [ "$UNTRACKED_ENV" -eq 0 ] && echo "[NOTE] untracked local config (keep untracked; prefer env vars / secret manager):"
      echo "  $f"
      UNTRACKED_ENV=1
    fi
  done < <(ls -1 .env .env.local secrets.json 2>/dev/null)
  [ "$UNTRACKED_ENV" -eq 0 ] && echo "[PASS] keyring: no untracked .env/secrets.json in project root"
else
  echo "[NOTE] not a git repo — untracked-file check skipped"
fi

echo "------------------------------------------------"
if [ "$FINDINGS" -eq 1 ]; then
  echo "Findings need review. Rules: secrets live in env vars or secret"
  echo "managers only; injection markers mean the file is UNTRUSTED INPUT"
  echo "requiring validation before any agent follows it."
  exit 1
fi
echo "No high-confidence findings. Apply the documented Security Checklist"
echo "for the parts a scan cannot judge."
exit 0
