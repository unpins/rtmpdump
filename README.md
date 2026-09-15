# rtmpdump

The [rtmpdump](https://rtmpdump.mplayerhq.hu/) RTMP streaming programs, as a single self-contained binary built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/rtmpdump/actions/workflows/rtmpdump.yml/badge.svg)](https://github.com/unpins/rtmpdump/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install rtmpdump`.

Download, serve and inspect RTMP streams.

## Usage

Run a program with [unpin](https://github.com/unpins/unpin):

```bash
unpin rtmpdump --unpin-program=rtmpdump -r rtmp://example.com/live/stream -o out.flv
unpin rtmpdump --unpin-program=rtmpgw -g 8080
```

Or install them and call each by name, which is usually what you want:

```bash
unpin install rtmpdump
rtmpdump -r rtmp://example.com/live/stream -o out.flv
```

`unpin install rtmpdump` creates the `rtmpdump` (download a stream), `rtmpgw` (HTTP gateway), `rtmpsrv` (logging server) and `rtmpsuck` (capturing proxy) commands.

## Man pages

`rtmpdump.1` and `rtmpgw.8` are embedded in the binary — read one with `unpin man rtmpdump rtmpgw`. `rtmpsrv` and `rtmpsuck` have no upstream man pages.

## Build locally

```bash
nix build github:unpins/rtmpdump
./result/bin/rtmp --unpin-program=rtmpdump --help
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/rtmpdump/releases) page has standalone binaries for manual download.

## Build notes

- **One binary, `rtmp`,** holds the four programs; `unpin install` creates a command for each.
- **Encrypted and TLS streams work:** `rtmpe://`, `rtmpte://`, `rtmps://`, and SWF verification (`--swfVfy`).
- **Windows:** a single `.exe`, no companion DLLs, with all four programs.
