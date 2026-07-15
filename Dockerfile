# SimpliDigital scanner toolchain.
#
# Every version below was CHECKED against the project's releases on 15 July 2026,
# not recalled. The first draft of this file was written from memory and all six
# versions were wrong, by as much as eight minor releases. Check, then pin.
#
# Runtime is debian-slim, not alpine, on purpose: sslyze ships sdist-only and its
# C dependency nassl needs a wheel. nassl publishes both manylinux and musllinux,
# so alpine would work, but manylinux is the better-supported path and 200MB of
# image is irrelevant on a 16GB disk.

# golang:1.26, NOT 1.25. Checked against each module's go.mod via the Go module
# proxy rather than guessed:
#   httpx     v1.10.0  requires  go 1.26    <- 1.25 fails here, and did
#   katana    v1.6.1   requires  go 1.25.7
#   nuclei    v3.11.0  requires  go 1.25.7
#   subfinder v2.14.0  requires  go 1.24.0
# Pinning the tool versions is not enough: the TOOLCHAIN version is a pin too,
# and it is the one the first build died on.
FROM golang:1.26-alpine AS build
RUN apk add --no-cache git

# CGO off so the binaries are static and run on the debian runtime below.
ENV CGO_ENABLED=0

# One RUN per tool, cheapest first. A single chained RUN reports one opaque
# "exit code 1" for all four and discards the layer on any failure, which is
# exactly how the first build wasted everyone's time.
RUN go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@v2.14.0
RUN go install github.com/projectdiscovery/katana/cmd/katana@v1.6.1
RUN go install github.com/projectdiscovery/httpx/cmd/httpx@v1.10.0
RUN go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@v3.11.0

FROM python:3.13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /go/bin/katana /go/bin/httpx /go/bin/nuclei /go/bin/subfinder /usr/local/bin/

RUN pip install --no-cache-dir \
      sslyze==6.3.1 \
      checkdmarc==5.17.3

# The scope guardrails travel with the image. See nuclei-config.yaml for why.
RUN mkdir -p /root/.config/nuclei
COPY nuclei-config.yaml /root/.config/nuclei/config.yaml

# Templates live on a named volume so they survive a rebuild and are fetched once.
ENV NUCLEI_TEMPLATES_DIR=/opt/nuclei-templates
VOLUME ["/opt/nuclei-templates"]

# Non-root. Nothing here needs privilege: every tool makes ordinary outbound
# HTTP and DNS requests.
RUN useradd -m -u 10001 scanner \
 && mkdir -p /opt/nuclei-templates \
 && chown -R scanner:scanner /opt/nuclei-templates \
 && cp -r /root/.config /home/scanner/.config \
 && chown -R scanner:scanner /home/scanner/.config
USER scanner
WORKDIR /home/scanner

CMD ["sleep", "infinity"]
