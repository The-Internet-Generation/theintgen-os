# theintgen.com OS

The full codebase for everything running at theintgen.com.

---

## Folder Structure

```
theintgen.com OS/
├── mobile/          TIG OS — phone UI, loads on mobile devices
├── desktop/         TIG Ecosystem portal — loads on desktop/laptop
├── tigpods/         TigPods podcast site
├── tigital/         Tigital digital marketing site
├── tiggigs/         TigGigs job board (index, client, dashboard, team)
├── tigom/           TIGOM open mic site
├── shared/logos/    All brand logos and icons
└── worker/          Cloudflare Worker — routing layer
```

---

## How It Works

**theintgen.com** is served by a Cloudflare Worker that routes by device:

| Visitor | Gets |
|---------|------|
| Mobile | `mobile/index.html` — TIG OS phone UI |
| Desktop | `desktop/index.html` — TIG Ecosystem portal |
| `/tigpods` | `tigpods/index.html` — pulled from GitHub |
| `/tigital` | `tigital/index.html` — pulled from GitHub |
| `/tiggigs` | `tiggigs/index.html` — pulled from GitHub |
| `/tigom`   | `tigom/index.html` — pulled from GitHub |

---

## GitHub Repos (The-Internet-Generation org)

| Folder | GitHub Repo | Cloudflare |
|--------|-------------|------------|
| mobile + desktop | `The-Internet-Generation/theintgen-web` | `theintgen-web.pages.dev` |
| tigpods | `The-Internet-Generation/tigpods` | pulled by worker |
| tigital | `The-Internet-Generation/tigital` | pulled by worker |
| tiggigs | `The-Internet-Generation/tiggigs` | pulled by worker |

Subsite changes → push to GitHub → live within 1 hour (edge cache).

---

## Updating the Worker

1. Edit `mobile/index.html` or any subsite
2. To update the TIG OS on the worker: `base64 -i mobile/index.html` → replace `OS_B64` in `worker/worker.js`
3. Deploy: run `worker/deploy.sh` (needs CF API token)
