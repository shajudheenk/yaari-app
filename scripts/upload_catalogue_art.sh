#!/usr/bin/env bash
#
# Uploads the trade artwork to the public `catalogue` bucket.
#
# Storage writes need the service_role key, which must never be pasted into a
# chat, committed, or put in config.dart. Export it in your own shell instead:
#
#   export SUPABASE_SERVICE_KEY='...'        # Supabase dashboard -> Project Settings -> API
#   ./scripts/upload_catalogue_art.sh <folder-with-the-jpgs>
#
# The key is read from the environment and never printed.

set -euo pipefail

PROJECT_URL="${SUPABASE_URL:-https://capnsntuwdhxrxjfhrgr.supabase.co}"
SRC="${1:?usage: upload_catalogue_art.sh <folder containing *-tile.jpg and *-hero.jpg>}"

if [[ -z "${SUPABASE_SERVICE_KEY:-}" ]]; then
  echo "SUPABASE_SERVICE_KEY is not set." >&2
  echo "Get it from Supabase dashboard -> Project Settings -> API -> service_role," >&2
  echo "then: export SUPABASE_SERVICE_KEY='...'" >&2
  exit 1
fi

shopt -s nullglob
files=("$SRC"/*-tile.jpg "$SRC"/*-hero.jpg)
if (( ${#files[@]} == 0 )); then
  echo "No *-tile.jpg or *-hero.jpg found in $SRC" >&2
  exit 1
fi

fail=0
for f in "${files[@]}"; do
  name="trades/$(basename "$f")"
  # x-upsert lets the script be re-run after a bad crop without a delete first.
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$PROJECT_URL/storage/v1/object/catalogue/$name" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: image/jpeg" \
    -H "Cache-Control: max-age=31536000" \
    -H "x-upsert: true" \
    --data-binary "@$f")

  if [[ "$code" == "200" ]]; then
    printf '  uploaded  %s\n' "$name"
  else
    printf '  FAILED    %s (HTTP %s)\n' "$name" "$code"
    fail=1
  fi
done

echo
echo "Checking the files are publicly readable (no key sent):"
for f in "${files[@]}"; do
  name="trades/$(basename "$f")"
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    "$PROJECT_URL/storage/v1/object/public/catalogue/$name")
  printf '  %s  %s\n' "$code" "$name"
  [[ "$code" == "200" ]] || fail=1
done

exit $fail
