{
  description = "Standalone build of the rtmpdump RTMP streaming toolkit";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # rtmpdump ships four CLI tools (rtmpdump / rtmpgw / rtmpsrv / rtmpsuck).
  # We post-link them into a single multicall `rtmp` binary — see
  # ./multicall.nix for the link mechanics.
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

      # Standalone variant: keep CRYPTO=OPENSSL (the package default) but stop
      # the librtmp.so build — pkgsStatic / mingw-static toolchains can't link
      # a shared object (`crtbeginT.o R_X86_64_32 against __TMC_END__`). The
      # `all` target then reduces to librtmp.a + the four tools.
      withCrypto = drv: drv.overrideAttrs (oa: {
        makeFlags = (oa.makeFlags or [ ]) ++ [ "SHARED=no" ];
      });
    in
    ulib.mkStandaloneFlake {
      inherit self;
      name = "rtmp";

      build = pkgs:
        let sp = pkgs.pkgsStatic; in
        mk pkgs { pkgs = sp; rtmpdump = withCrypto sp.rtmpdump; };

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
