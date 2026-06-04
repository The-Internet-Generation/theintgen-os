#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  theintgen.com OS — Deploy Script
#  Deploys each part of the OS to its Cloudflare target.
#
#  Usage:
#    ./deploy.sh all         — deploy everything
#    ./deploy.sh mobile      — deploy mobile/ → tig-os.pages.dev
#    ./deploy.sh desktop     — deploy desktop/ → theintgen-web.pages.dev
#    ./deploy.sh worker      — deploy worker.js → theintgen-worker
#    ./deploy.sh tigpods     — deploy tigpods/ repo (push to GitHub, CF pulls)
# ─────────────────────────────────────────────────────────────────
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CF_TOKEN="${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN before running}"
CF_ACCOUNT="${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID before running}"

# Node / wrangler (uses downloaded binary if system node not found)
NODE_BIN="/tmp/node-v22.14.0-darwin-arm64/bin"
export PATH="$NODE_BIN:$PATH"
WRANGLER="/tmp/wrangler-v3/bin/wrangler"

deploy_pages() {
  local dir="$1" project="$2"
  echo "▶ Deploying $dir/ → $project.pages.dev"
  CLOUDFLARE_API_TOKEN="$CF_TOKEN" \
  CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT" \
    "$WRANGLER" pages deploy "$ROOT/$dir" \
      --project-name="$project" \
      --branch=main
  echo "  ✓ $project.pages.dev updated"
}

deploy_worker() {
  echo "▶ Deploying worker → theintgen-worker"
  # Rebuild OS_B64 from mobile/index.html
  python3 -c "
import base64, re
with open('$ROOT/mobile/index.html', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()
with open('$ROOT/worker/worker.js', 'r') as f:
    src = f.read()
src = re.sub(r'(const OS_B64 = \")[^\"]*(\";)', r'\g<1>' + b64 + r'\g<2>', src)
with open('/tmp/theintgen-worker-deploy.js', 'w') as f:
    f.write(src)
print('  OS_B64 updated from mobile/index.html')
"
  python3 << 'PYEOF'
import urllib.request, urllib.error

import os
CF_TOKEN   = os.environ["CLOUDFLARE_API_TOKEN"]
CF_ACCOUNT = os.environ["CLOUDFLARE_ACCOUNT_ID"]

with open('/tmp/theintgen-worker-deploy.js', 'rb') as f:
    worker_js = f.read()

BOUNDARY = b"tig0worker0deploy"
body = (
    b"--" + BOUNDARY + b"\r\n"
    b'Content-Disposition: form-data; name="metadata"\r\n'
    b"Content-Type: application/json\r\n\r\n"
    b'{"main_module":"worker.js","compatibility_date":"2024-01-01"}\r\n'
    b"--" + BOUNDARY + b"\r\n"
    b'Content-Disposition: form-data; name="worker.js"; filename="worker.js"\r\n'
    b"Content-Type: application/javascript+module\r\n\r\n" +
    worker_js + b"\r\n"
    b"--" + BOUNDARY + b"--\r\n"
)

req = urllib.request.Request(
    f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT}/workers/scripts/theintgen-worker",
    data=body, method="PUT",
    headers={
        "Authorization": f"Bearer {CF_TOKEN}",
        "Content-Type": f"multipart/form-data; boundary={BOUNDARY.decode()}"
    }
)
try:
    with urllib.request.urlopen(req) as r:
        import json
        d = json.loads(r.read())
        print(f"  ✓ theintgen-worker deployed (success={d.get('success')})")
except urllib.error.HTTPError as e:
    print(f"  ✗ Worker error {e.code}: {e.read().decode()[:300]}")
PYEOF
}

TARGET="${1:-all}"

case "$TARGET" in
  mobile)  deploy_pages mobile tig-os ;;
  desktop) deploy_pages desktop theintgen-web ;;
  worker)  deploy_worker ;;
  all)
    deploy_pages mobile tig-os
    deploy_pages desktop theintgen-web
    deploy_worker
    echo ""
    echo "✅ All deployments complete."
    echo "   tig-os.pages.dev      → mobile TIG OS"
    echo "   theintgen-web.pages.dev → desktop portal"
    echo "   theintgen-worker       → routing layer"
    ;;
  *)
    echo "Usage: ./deploy.sh [all|mobile|desktop|worker]"
    exit 1
    ;;
esac
