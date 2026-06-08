# rtmpdump

The [rtmpdump](https://rtmpdump.mplayerhq.hu/) RTMP streaming programs, as a single self-contained binary built natively for Linux, macOS, and Windows.

[![Build](https://github.com/unpins/rtmpdump/actions/workflows/rtmpdump.yml/badge.svg)](https://github.com/unpins/rtmpdump/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install rtmpdump`.

Download, serve and inspect RTMP streams.

## Usage

Run a program with [unpin](https://github.com/unpins/unpin):

```bash
unpin rtmpdump rtmpdump -r rtmp://example/live -o out.flv
unpin rtmpdump rtmpgw --help
```

`unpin install rtmpdump` also creates the commands `rtmpdump` (download a stream), `rtmpgw` (HTTP gateway), `rtmpsrv` (logging server) and `rtmpsuck` (capturing proxy):

```bash
unpin install rtmpdump
```

## Man pages

`rtmpdump.1` and `rtmpgw.8` are embedded in the binary — read with `unpin man rtmpdump`. `rtmpsrv` and `rtmpsuck` have no upstream man pages.

## Build locally

```bash
nix build github:unpins/rtmpdump
./result/bin/rtmp
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/rtmpdump/releases) page has standalone binaries for manual download.

## Build notes

- **Single multicall binary** — the four tools are post-linked into one `rtmp`; tool names are recreated as `argv[0]` shims on install.
- **Full crypto (OpenSSL)** — `rtmpe://` / `rtmpte://` (encrypted RTMP), `rtmps://` (RTMP over TLS) and SWF verification (`--swfVfy`) all work.
- **Windows:** `mingw` cross, single `.exe`, no companion DLLs. Ships all four tools.

The multicall link recipe is in [`multicall.nix`](./multicall.nix).
