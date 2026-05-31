# rtmpdump

Standalone build of the [rtmpdump](https://rtmpdump.mplayerhq.hu/) RTMP streaming toolkit.

[![Build](https://github.com/unpins/rtmpdump/actions/workflows/rtmpdump.yml/badge.svg)](https://github.com/unpins/rtmpdump/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) project — native single-binary builds with no third-party runtime dependencies.

Download, serve and inspect RTMP streams. Ships as one multicall binary that dispatches to the upstream tools:

- `rtmpdump` — download an RTMP/RTMPE/RTMPS stream to a file.
- `rtmpgw` — HTTP gateway that proxies RTMP streams over HTTP.
- `rtmpsrv` — minimal RTMP server that logs the parameters a client connects with.
- `rtmpsuck` — transparent proxy that captures streams passing through it.

Run a tool by name or via the dispatcher:

```bash
rtmpdump -r rtmp://example/live -o out.flv   # by name
rtmp dump -r rtmp://example/live -o out.flv   # via the rtmp dispatcher
```

## Installation

Install with [unpin](https://github.com/unpins/unpin):

```bash
unpin rtmpdump
```

Or run without installing:

```bash
unpin run rtmpdump -- rtmpdump --help
```

## Build locally

```bash
nix build github:unpins/rtmpdump
./result/bin/rtmp
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Man pages

`rtmpdump.1` and `rtmpgw.8` are embedded in the binary — read with `unpin man rtmpdump`. `rtmpsrv` and `rtmpsuck` have no upstream man pages.

## Manual download

The [Releases](https://github.com/unpins/rtmpdump/releases) page has standalone binaries for manual download.

## Build notes

- **Single multicall binary** — the four tools are post-linked into one `rtmp`; tool names are recreated as `argv[0]` shims on install.
- **Full crypto (OpenSSL)** — `rtmpe://` / `rtmpte://` (encrypted RTMP), `rtmps://` (RTMP over TLS) and SWF verification (`--swfVfy`) all work.
- **Windows:** `mingw` cross, single `.exe`, no companion DLLs. Ships all four tools.

The multicall link recipe is in [`multicall.nix`](./multicall.nix).
