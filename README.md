# simplidigital-scanner

The crawling and security toolchain, as a pinned container image.

Deployed to the Docker LXC via a **Portainer Git-backed stack**. Full context lives in the vault: `SimpliDigital/_sop/Scanner LXC Setup.md`.

## What is in it

| Tool | Version | Job |
| --- | --- | --- |
| katana | v1.6.1 | Crawl |
| httpx | v1.10.0 | Status, titles, tech detection |
| nuclei | v3.11.0 | Misconfiguration checks, non-intrusive only |
| subfinder | v2.14.0 | Passive subdomain discovery |
| sslyze | 6.3.1 | TLS |
| checkdmarc | 5.17.3 | SPF, DKIM, DMARC, DNSSEC |

**Every version is pinned and was checked against the project's releases, not recalled.** The first draft of the Dockerfile was written from memory and all six were wrong, by as much as eight minor versions. A client report that says "nuclei 3.11.0 found this" has to still mean that in six months.

## The build toolchain is a pin too

Build stage is **`golang:1.26-alpine`**, and the version matters:

| Module | Requires |
| --- | --- |
| `httpx` v1.10.0 | **go 1.26** |
| `katana` v1.6.1 | go 1.25.7 |
| `nuclei` v3.11.0 | go 1.25.7 |
| `subfinder` v2.14.0 | go 1.24.0 |

**The first build used `golang:1.25-alpine` and failed.** Only `httpx` needs 1.26, and it was chained with the other three, so Docker reported a single opaque `exit code 1` for all four.

**Checked against each module's `go.mod` via the Go module proxy**, which is authoritative. GitHub release tags tell you the version; only `go.mod` tells you what it needs to compile. **Pinning the tools and not the toolchain is half a pin.**

Each tool now gets **its own `RUN`**, so a failure names the tool that broke and the passing layers cache.

## Deploy

Portainer → **Stacks** → **Add stack** → **Repository** → this repo's URL → **Deploy**.

Portainer builds the image and starts one long-lived container. Update by bumping a version in the `Dockerfile`, pushing, and hitting **Pull and redeploy**.

## Why a long-lived container

The tools are one-shot CLI commands, so a container that sleeps looks odd. It is deliberate.

**nuclei's template set is large and slow to fetch.** On the named volume it is downloaded once and survives restarts and rebuilds. A `docker run --rm` per scan would either re-download the set every time or bake stale templates into the image.

n8n runs commands against it:

```bash
docker exec simpli-scanner katana -u https://example.com -jc -silent
```

## Scope rules

**`nuclei-config.yaml` is baked into the image.** It excludes `intrusive`, `dast`, `fuzz`, `brute-force`, `sqli`, `rce`, `xss`, `ssrf`, `lfi` and `injection`, rate-limits to 20 requests a second, and sets an identifying User-Agent.

**These are in the file, not on the command line, on purpose.** A flag is typed by whoever runs the command, and one day it will not be. In the image, the constraint travels with the tool.

**The rule no config can enforce: never brute-force paths.** Guessing at `/.git/config`, `/.env` or `/backup.sql` is unauthorised-access-shaped conduct however passive it feels. Discovery is limited to `security.txt`, `robots.txt`, certificate transparency logs, and paths the site itself links to.

**No scan touches any client asset before a signed scope letter is filed.** Under the Computer Misuse Act 1990, "authorisation" is undefined and motive is not a defence.
