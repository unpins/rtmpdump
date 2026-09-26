# Changelog

## [Unreleased]

### Added

- On Linux, hostnames now resolve on a machine whose DNS resolver is missing or
  unreachable — Android, or a container with no `/etc/resolv.conf` — once you
  point unpins at a name server. Before, every lookup failed there and the
  download never started.

### Changed

- A program inside the binary is selected with `--unpin-program=<name>`:
  `rtmp --unpin-program=rtmpgw -g 8080`. The positional form
  (`rtmp rtmpgw …`) is gone. The installed `rtmpdump`, `rtmpgw`, `rtmpsrv` and
  `rtmpsuck` commands are unaffected.

- The build downloads a real stream before the binary ships: a short FLV is
  served over RTMP on loopback, `rtmpdump` fetches it, and the saved video
  frames must match the source. It runs on every target the build host can
  execute. The check before this only ran `--help`.

- Built by the same compiler as the rest of the catalog. The Linux x86_64
  binary shrank from 6.3 MB to 5.9 MB; behaviour is unchanged.
