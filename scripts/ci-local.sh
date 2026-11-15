#!/usr/bin/env bash
# The merge gate (this repo is not on Jenkins). The site is plain static HTML
# with no build: this stages the public files into an output dir exactly as
# scripts/deploy-pages.sh uploads them, then checks the staged HTML:
#   - every local href/src resolves to a staged file,
#   - every absolute link to the site's own host (canonical, og:image) does too,
#   - each page has a <title>, and nothing points at *.vercel.app.
#   bash scripts/ci-local.sh [out-dir]   (default: a temp dir, removed on exit)
set -euo pipefail
cd "$(dirname "$0")/.."

SITE="https://arabic-business-resources.pages.dev"

if [ $# -ge 1 ]; then
  OUT="$1"; mkdir -p "$OUT"
else
  OUT="$(mktemp -d)"; trap 'rm -rf "${OUT:?}"' EXIT
fi

# Public files = every tracked file except dotfiles, scripts/ and Markdown.
count=0
while IFS= read -r f; do
  mkdir -p "$OUT/$(dirname "$f")"
  cp "$f" "$OUT/$f"
  count=$((count + 1))
done < <(git ls-files | grep -vE '^(\.|scripts/)|\.md$')
echo "ci-local: staged $count files into $OUT"

fail=0
check() { # <html> <ref> <path relative to the page or root>
  local target="$3"
  case "$target" in
    /*) target="$OUT$target" ;;
    *) target="$OUT/$(dirname "$1")/$target" ;;
  esac
  case "$target" in */) target="${target}index.html" ;; esac
  if [ ! -e "$target" ]; then echo "ci-local: $1 -> $2 is missing" >&2; fail=1; fi
}

pages=0
while IFS= read -r html; do
  pages=$((pages + 1))
  grep -q '<title>' "$OUT/$html" || { echo "ci-local: $html has no <title>" >&2; fail=1; }
  while IFS= read -r ref; do
    check "$html" "$ref" "${ref%%[?#]*}"
  done < <(grep -oE '(href|src)="[^"]*"' "$OUT/$html" | sed -E 's/^(href|src)="//; s/"$//' \
    | grep -vE '^(https?:|mailto:|tel:|#|data:|javascript:|//)' || true)
  while IFS= read -r ref; do
    path="${ref#"$SITE"}"; path="${path%%[?#]*}"
    check "$html" "$ref" "${path:-/}"
  done < <(grep -oE "${SITE//./\\.}[^\"' <)]*" "$OUT/$html" || true)
done < <(cd "$OUT" && find . -name '*.html' | sed 's#^\./##')

if grep -rnE 'vercel\.app' --include='*.html' "$OUT"; then
  echo "ci-local: a Vercel URL is left in the site" >&2; fail=1
fi

[ "$fail" = 0 ] || { echo "ci-local: FAILED" >&2; exit 1; }
echo "ci-local: $pages page(s) checked, all local links resolve"
echo "ci-local: all steps passed"
