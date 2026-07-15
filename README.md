# simplidigital-scanner

The crawling and security toolchain. **Official pre-built images, pinned. Nothing is compiled here.**

Deployed to the Docker LXC as a Portainer Git-backed stack. Full context: `SimpliDigital/_sop/Scanner LXC Setup.md` in the vault.

## What is in it

| Container | Image | Job |
| --- | --- | --- |
| `simpli-katana` | `projectdiscovery/katana:v1.6.1` | Crawl. **Ships chromium, so `-headless` renders JS** |
| `simpli-httpx` | `projectdiscovery/httpx:v1.10.0` | Status, titles, tech detection |
| `simpli-nuclei` | `projectdiscovery/nuclei:v3.11.0` | Misconfiguration checks, non-intrusive only |
| `simpli-subfinder` | `projectdiscovery/subfinder:v2.14.0` | Passive subdomain discovery |

## Why the custom Dockerfile was deleted

**It failed three deploys and it was the wrong idea.**

1. **We were compiling ProjectDiscovery's Go tools from source** to arrive at binaries they already publish, pre-built and tested, in their own Docker namespace. The build was pure liability.
2. **It had no browser.** katana needs Chrome for `-headless`, and **this client's site is JS-rendered**: a `curl` of their blog post reported *"no links to commercial pages"*, while the rendered DOM had **four links to `/book-appointment`**. **A crawler that cannot render JS would have put that error into a client report.** The official katana image ships chromium.
3. **The build broke on a version we never checked.** `httpx v1.10.0` declares `go 1.26`; our image was `golang:1.25-alpine`. Pinning the tools without pinning the toolchain is half a pin. (ProjectDiscovery's own Dockerfile builds on `golang:1.26.4-alpine`, which is how we confirmed it.)

**Versions stay pinned. Never `:latest`.** A report saying *"nuclei v3.11.0 found this"* has to still mean that in six months.

## Deploy

Portainer -> **Stacks** -> **Add stack** -> **Repository** -> this repo -> **Deploy**.

**If a deploy fails with an error quoting code that is not on `main`, Portainer is building a cached clone.** Delete the stack and re-add it; that forces a fresh fetch. **An error message quoting code that no longer exists means you are debugging the wrong version.**

Update path: bump a tag, push, **Pull and redeploy**.

## Usage

n8n execs against the long-lived containers:

```bash
docker exec simpli-katana katana -u https://example.com -headless -jc -silent
docker exec simpli-httpx  httpx -u https://example.com -title -status-code -tech-detect -json
docker exec simpli-nuclei nuclei -u https://example.com -j
```

**Use `-headless` on any JS-rendered site**, which is most client sites. Server HTML is not the asset.

## Scope rules

**`nuclei-config.yaml` is mounted into the container**, not passed as a flag. It excludes `intrusive`, `dast`, `fuzz`, `brute-force`, `sqli`, `rce`, `xss`, `ssrf`, `lfi` and `injection`, rate-limits to 20 requests a second, and sets an identifying User-Agent.

**A flag is typed by whoever runs the command, and one day it will not be.** In the container, the constraint travels with the tool.

**The rule no config can enforce: never brute-force paths.** Guessing at `/.git/config`, `/.env` or `/backup.sql` is unauthorised-access-shaped conduct however passive it feels. Discovery is limited to `security.txt`, `robots.txt`, certificate transparency logs, and paths the site itself links to.

**No scan touches any client asset before a signed scope letter is filed.** Under the Computer Misuse Act 1990, "authorisation" is undefined and motive is not a defence.

## Not here yet

`sslyze` and `checkdmarc` (TLS, SPF/DKIM/DMARC/DNSSEC) have no official image and need a small Python container. **Added when a workflow needs them, not before.** Security audits are gated and not on the critical path.
