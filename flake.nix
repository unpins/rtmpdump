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
  # archives (nothing to engine-build). Windows (mingw, no engine → native
  # objects) still uses ./multicall.nix's make/objcopy fold.
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
      mk = pkgs: extra: import ./multicall.nix { lib = pkgs.lib // ulib; } extra;

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

      engine = "unpin-llvm";
      multicall = {
        programs = [
          { name = "rtmpdump"; }
          { name = "rtmpgw"; }
          { name = "rtmpsrv"; }
          { name = "rtmpsuck"; }
        ];
      };

      build = pkgs:
        let eng = engStdenv pkgs; in
        withCrypto (pkgs.pkgsStatic.rtmpdump.override { stdenv = eng; });

      # mingw cross. The tools force the C runtime static so the .exe carries
      # no libwinpthread-1 / libgcc_s DLLs; OpenSSL's static libs pull extra
      # Win32 syscall deps that multicall.nix appends (see there).
      windowsBuild = pkgs:
        let cross = ulib.mingwStaticCross pkgs; in
        mk pkgs {
          pkgs = cross;
          rtmpdump = withCrypto cross.rtmpdump;
          extraLinkFlags = "-static -static-libgcc";
        };
    };
}
