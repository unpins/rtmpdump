{
  description = "the rtmpdump RTMP streaming toolkit as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # rtmpdump ships four CLI tools (rtmpdump / rtmpgw / rtmpsrv / rtmpsuck)
  # folded into one argv[0]-dispatching `rtmp` binary.
  #
  # Native (Linux/darwin): build under the unpin-llvm engine (all objects LLVM
  # bitcode) and let mkStandaloneFlake's bitcode self-fold pack the four tools
  # into one binary. rtmpdump's only real deps are OpenSSL + zlib, which stay
  # ordinary pkgsStatic `.a`s — the self-fold links them as external native
  # archives (nothing to engine-build). Windows takes the same route through
  # the mingw engine adapter.
  #
  # Crypto: full CRYPTO=OPENSSL (upstream default), so rtmpe:// / rtmpte:// /
  # rtmps:// and SWF verification all work. This is the documented exception
  # to the mbedtls-over-OpenSSL policy (docs/crypto-backend.md): rtmpdump
  # only offers OpenSSL / GnuTLS / PolarSSL, and its PolarSSL path is the
  # obsolete 1.x API (no drop-in to nixpkgs' mbedtls 3.x), so OpenSSL is the
  # only working full-feature option. ffmpeg sidesteps this entirely — it
  # drops --enable-librtmp and uses native rtmp via its own mbedtls.
  outputs = { self, unpins-lib }:
    let
      ulib = unpins-lib.lib;

      # Pure C, lto + link capture so the self-fold can relink the four tools.
      engStdenv = pkgs:
        let sp = pkgs.pkgsStatic; in
        ulib.unpinAdapterStdenv {
          inherit pkgs;
          target = sp.stdenv.hostPlatform.config;
          native = pkgs.stdenv.buildPlatform.system == pkgs.stdenv.hostPlatform.system;
          cxx = false;
          lto = true;
          captureLinks = true;
        };

      # Keep CRYPTO=OPENSSL (the package default) but stop the librtmp.so build —
      # pkgsStatic / mingw-static toolchains can't link a shared object
      # (`crtbeginT.o R_X86_64_32 against __TMC_END__`). The `all` target then
      # reduces to librtmp.a + the four tools.
      withCrypto = drv: drv.overrideAttrs (oa: {
        makeFlags = (oa.makeFlags or [ ]) ++ [ "SHARED=no" ];
      });

      # Man set: rtmpdump.1 + rtmpgw.8 (the only two CLI man pages upstream
      # ships — rtmpsrv/rtmpsuck have none). The stock derivation installs both
      # into $out/share/man, so mkStandaloneFlake's withMan harvests them on
      # every target (windows harvests its OWN man — same source, no graft).
    in
    ulib.mkStandaloneFlake {
      inherit self;
      dnsFallback = true; # resolves hostnames; opt into the Android DNS fallback
      name = "rtmp";
      smoke = [ "--unpin-program=rtmpdump" "--help" ];
      smokePattern = "^RTMPDump v[0-9]+\\.[0-9]+";

      engine = "unpin-llvm";
      multicall = {
        windows = true;
        # rtmpsrv and rtmpsuck are servers: they print a banner and start
        # listening, so `--help` never returns (measured: 338 MB of output in
        # 20 s). `noHelp` keeps them announced and in the dispatch table while
        # telling the CI sweep not to run them.
        programs = [
          { name = "rtmpdump"; }
          { name = "rtmpgw"; }
          # rtmpdump installs three pages — rtmpdump.1, rtmpgw.1 and the
          # librtmp.3 library page — and none for the two servers, which get
          # neither a page nor a --help that returns.
          { name = "rtmpsrv"; noHelp = true; noMan = true; }
          { name = "rtmpsuck"; noHelp = true; noMan = true; }
        ];
      };

      build = pkgs:
        let eng = engStdenv pkgs; in
        withCrypto (pkgs.pkgsStatic.rtmpdump.override { stdenv = eng; });

      # mingw cross.
      windowsBuild = pkgs:
        let
          # OPENSSLDIR/ENGINESDIR/MODULESDIR default to openssl's own $out, so
          # the .exe carried live references to `openssl-...-w64-mingw32` and
          # its `-etc`. The retarget is set-wide ONLY in the engine's native
          # scope (nix-lib/native-overlay/openssl.nix) -- the mingw and cosmo
          # scopes have none, so each consumer has to do it. C:/ssl is what the
          # standalone `openssl` package already uses for its own mingw build.
          cross = (ulib.mingwStaticCross pkgs).extend (final: prev: {
            openssl = prev.openssl.overrideAttrs (ulib.retargetOpenssl "C:/ssl");
          });
        in
        (withCrypto cross.rtmpdump).overrideAttrs (old: {
          # OpenSSL's static libs reference Win32 crypto/socket APIs the
          # Makefile's LIBS_mingw (-lws2_32 -lwinmm -lgdi32) doesn't cover.
          # NIX_LDFLAGS lands last, so appending them here resolves
          # BCryptGenRandom / Crypt32 / advapi32 for each tool's own link — the
          # links the engine captures.
          preBuild = (old.preBuild or "") + ''
            export NIX_LDFLAGS="''${NIX_LDFLAGS:-} -lcrypt32 -lbcrypt -lws2_32 -ladvapi32 -luser32"
          '';
        });
    };
}
