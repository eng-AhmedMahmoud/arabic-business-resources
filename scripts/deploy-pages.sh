#!/usr/bin/env bash
# Production deploy to Cloudflare Pages: https://arabic-business-resources.pages.dev
# (the site left Vercel on 2026-11-15; arabic-business-resources.vercel.app now
# redirects here). There is no build: scripts/ci-local.sh stages the public files
# (everything tracked except dotfiles, scripts/ and Markdown) into a temp dir and
# checks them; that dir is uploaded, then the live URL is checked.
#   bash scripts/deploy-pages.sh
# Needs a wrangler login on the Cloudflare account that owns the project
# (`npx wrangler@4.156.0 whoami`).
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="arabic-business-resources"
URL="https://arabic-business-resources.pages.dev"
WRANGLER=(npx --yes wrangler@4.156.0)

if [ -n "$(git status --porcelain)" ]; then
  echo "deploy: working tree is dirty; commit or stash first" >&2
  exit 1
fi

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "${OUT_DIR:?}"' EXIT
bash scripts/ci-local.sh "$OUT_DIR"

"${WRANGLER[@]}" pages deploy "$OUT_DIR" --project-name "$PROJECT" --branch main \
  --commit-hash "$(git rev-parse HEAD)" --commit-message "$(git log -1 --format=%s)"

code="$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$URL/" || true)"
echo "deploy: $URL/ -> $code"
[ "$code" = 200 ]
