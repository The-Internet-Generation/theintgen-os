/**
 * theintgen-worker — Cloudflare Worker
 *
 * Routing logic for theintgen.com:
 *   Mobile  →  mobile/index.html  (TIG OS phone UI)
 *   Desktop →  desktop/index.html (TIG Ecosystem portal)
 *   Subsites→  fetched from GitHub (source of truth, 1h edge cache)
 *
 * Deploy:
 *   1. base64-encode mobile/index.html  →  replace OS_B64 below
 *   2. wrangler deploy  OR  cf-deploy.sh
 *
 * GitHub repos (The-Internet-Generation org):
 *   tigpods   → theintgen.com/tigpods
 *   tigital   → theintgen.com/tigital
 *   tiggigs   → theintgen.com/tiggigs
 *   tigom     → theintgen.com/tigom
 *   theintgen-web → desktop portal (deployed to theintgen-web.pages.dev)
 */

// ── Sources ────────────────────────────────────────────────────────────────
const DESKTOP = 'https://theintgen-web.pages.dev';
const GHRAW   = 'https://raw.githubusercontent.com/The-Internet-Generation';

// ── Inline assets (icons served at /icons/*) ───────────────────────────────
// Generated from shared/logos/ — replace with: base64 -i shared/logos/tigital.png
const TIGITAL_PNG = "…";   // shared/logos/tigital.png
const TIGPODS_PNG = "…";   // shared/logos/tigpods.png
const TIGOM_PNG   = "…";   // shared/logos/tigom.png

// ── TIG OS (mobile) ────────────────────────────────────────────────────────
// Generated from: base64 -i mobile/index.html
const OS_B64 = "…";        // mobile/index.html

// ── Helpers ────────────────────────────────────────────────────────────────
function htmlResponse(b64, cache = 300) {
  const binary = atob(b64);
  const bytes  = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Response(bytes, {
    headers: {
      'Content-Type':  'text/html;charset=utf-8',
      'Cache-Control': `public,max-age=${cache}`,
    },
  });
}

function pngResponse(b64) {
  const binary = atob(b64);
  const bytes  = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Response(bytes, { headers: { 'Content-Type': 'image/png' } });
}

function ghFetch(repo, path = '/index.html') {
  return fetch(`${GHRAW}/${repo}/main${path}`, { cf: { cacheTtl: 3600 } })
    .then(r => new Response(r.body, {
      status:  r.status,
      headers: {
        'Content-Type':  'text/html;charset=utf-8',
        'Cache-Control': 'public,max-age=3600',
      },
    }));
}

// ── Router ─────────────────────────────────────────────────────────────────
export default {
  async fetch(request) {
    const url    = new URL(request.url);
    const raw    = url.pathname;
    const p      = raw.replace(/\.html$/, '').replace(/\/+$/, '') || '/';
    const ua     = request.headers.get('User-Agent') || '';
    const mobile = /Mobile|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(ua);

    // ── Root ────────────────────────────────────────────────────────────────
    if (p === '/' || p === '') {
      return mobile
        ? htmlResponse(OS_B64, 60)           // TIG OS phone UI
        : fetch(DESKTOP + '/');              // Desktop portal
    }

    // ── Subsites (pulled from GitHub) ───────────────────────────────────────
    if (p === '/tigpods' || p.startsWith('/tigpods/')) return ghFetch('tigpods');
    if (p === '/tigital' || p.startsWith('/tigital/')) return ghFetch('tigital');
    if (p === '/tiggigs' || p.startsWith('/tiggigs/')) {
      const sub  = p.replace('/tiggigs', '') || '/index.html';
      const file = sub === '/' ? '/index.html' : sub;
      return ghFetch('tiggigs', file.endsWith('.html') ? file : '/index.html');
    }
    if (p === '/tigom' || p.startsWith('/tigom/')) return ghFetch('tigom');

    // ── App tile icons (inline) ─────────────────────────────────────────────
    if (raw === '/icons/tigital.png') return pngResponse(TIGITAL_PNG);
    if (raw === '/icons/tigpods.png') return pngResponse(TIGPODS_PNG);
    if (raw === '/icons/tigom.png')   return pngResponse(TIGOM_PNG);

    // ── Desktop: proxy all other paths to portal (assets, fonts, etc.) ──────
    if (!mobile) return fetch(DESKTOP + raw);

    // ── 404 ─────────────────────────────────────────────────────────────────
    return new Response('Not found', { status: 404 });
  },
};
