# Upstream rtmpdump builds four separate tool binaries — rtmpdump, rtmpgw,
# rtmpsrv and rtmpsuck. To honour the unpins one-pkg-one-bin rule we post-link
# them into a single multicall binary at $out/bin/rtmp; `lib.withAliases` then
# embeds the tool names as an UNPIN_META block so unpin's installer can
# recreate the argv[0] shims.
#
# rtmpdump is a plain hand-written Makefile (srt was CMake, librist meson), so
# the link mechanics differ:
#
#   * Each tool is a single translation unit (rtmpdump.c, rtmpgw.c, …) compiled
#     to <tool>.o at the source root; rtmpsrv/rtmpsuck/rtmpgw also pull a shared
#     thread.o. The tools share NO object beyond thread.o, so every per-tool
#     global beyond `main` that two tools both define clashes: sigIntHandler
#     (all four), controlServerThread / serverThread / startStreaming /
#     stopStreaming / doServe (the three servers), ServeInvoke / ServePacket /
#     rtmpServer (rtmpsrv+rtmpsuck), hex2bin / defaultRTMPRequest, … Each clash
#     has its def and refs in the same .o, so a per-tool `objcopy
#     --redefine-sym` stays self-consistent. We don't predict the set — the
#     iterative link below discovers it from the linker.
#
#   * The resolved link line comes from `make -n` for one tool (rtmpgw, which
#     carries thread.o + the full SLIBS group: pthread, librtmp, OpenSSL, zlib,
#     and the Win32 sysdlls on mingw), reusing the package's own makeFlags /
#     makeFlagsArray (CC, CROSS_COMPILE, CRYPTO, SYS) so it matches the build.
{ lib }:
{ pkgs, rtmpdump, name ? "rtmp", extraLinkFlags ? "" }:
let
  multicall = rtmpdump.overrideAttrs (old: {
    pname = "rtmpdump-multi";

    # Ship only the multicall binary — no lib/headers/man/debug.
    outputs = [ "out" ];
    separateDebugInfo = false;

    # OpenSSL's static libs reference Win32 crypto/socket APIs that the
    # Makefile's LIBS_mingw (-lws2_32 -lwinmm -lgdi32) doesn't cover. Append
    # the missing sysdlls at the end of the link (NIX_LDFLAGS lands last) so
    # both make's own tool link AND the multicall relink resolve
    # BCryptGenRandom / Crypt32 / advapi32 symbols.
    preBuild = (old.preBuild or "") + lib.optionalString pkgs.stdenv.hostPlatform.isWindows ''
      export NIX_LDFLAGS="''${NIX_LDFLAGS:-} -lcrypt32 -lbcrypt -lws2_32 -ladvapi32 -luser32"
    '';

    postBuild = (old.postBuild or "") + ''
      mkdir -p multicall

      # rtmpdump always builds all four tools; existence still gates in case a
      # platform ever drops one. rtmpdump first is fine, but rtmpgw is the link
      # template (it carries thread.o + the SLIBS superset), handled below.
      apps=()
      for a in rtmpdump rtmpgw rtmpsrv rtmpsuck; do
        [ -f "$a.o" ] && apps+=("$a")
      done
      [ ''${#apps[@]} -ge 1 ] || { echo "multicall: no rtmpdump tools built" >&2; exit 1; }
      printf '%s\n' "''${apps[@]}" > multicall/apps.list

      # Symbol prefix (Mach-O leads C symbols with '_'), read once from a main.
      if $NM --defined-only "''${apps[0]}.o" | awk '$3=="_main"{f=1} END{exit !f}'; then
        up=_
      else
        up=""
      fi

      # Rename each tool's main → <tool>_main so the dispatcher reaches them as
      # distinct entry points. The only clash known a priori; the rest come
      # from the linker in the iterative link below.
      for a in "''${apps[@]}"; do
        $OBJCOPY --redefine-sym "''${up}main=''${up}''${a}_main" "$a.o"
      done

      # Dispatcher (shared canonical generator — see nix-lib
      # lib.multicallDispatcherC). Reads multicall/apps.list (written above).
${lib.multicallDispatcherC { inherit name; }}
      $CC -O2 -c -o multicall/dispatcher.o multicall/dispatcher.c

      # Reuse the package's own resolved link line for rtmpgw (carries thread.o
      # + the full SLIBS group). Re-run make in dry-run mode with the SAME flags
      # the build used (makeFlags + makeFlagsArray carry CC, CROSS_COMPILE,
      # CRYPTO, SYS, SHARED) so the compiler, flags and lib order match exactly.
      # rtmpgw's executable is removed first so make prints the link recipe; the
      # librtmp FORCE sub-make and the (up-to-date) object compiles never match
      # `-o rtmpgw[.exe] ` (the link's output token, always followed by a space
      # then the first object — `-o rtmpgw.o` from a compile ends in `.o`).
      rm -f rtmpgw rtmpgw.exe
      line=$(make -n rtmpgw $makeFlags "''${makeFlagsArray[@]}" 2>/dev/null \
             | grep -E -- '-o +rtmpgw(\.exe)? ' | tail -1)
      [ -n "$line" ] || { echo "multicall: could not extract rtmpgw link line" >&2; exit 1; }

      pre="''${line%% -o *}"            # compiler + flags
      post="''${line#* -o }"           # "rtmpgw[.exe] rtmpgw.o thread.o <libs>"
      oldout="''${post%% *}"
      rest="''${post#"$oldout" }"      # objects + libs
      # Drop the template's objects (*.o); keep the lib group verbatim.
      libs=$(printf '%s\n' $rest | grep -v '\.o$' | tr '\n' ' ')
      # Full object set: every tool's .o + the shared thread.o + dispatcher.
      objs=""
      for a in "''${apps[@]}"; do objs="$objs $a.o"; done
      objs="$objs thread.o multicall/dispatcher.o"

      # Iterative link. Each failed attempt names the remaining *strong*
      # duplicates; rename those per-tool and relink. Pure C, so this typically
      # converges in one extra pass after `main`.
      converged=0
      for _ in $(seq 1 30); do
        if eval "$pre -o multicall/${name} $objs $libs $extraLinkFlags" 2>multicall/link.err; then
          converged=1; break
        fi
        cat multicall/link.err >&2
        sed -nE "s/.*multiple definition of [\`']([^']+)'.*/\1/p; s/.*duplicate symbol '([^']+)'.*/\1/p" \
          multicall/link.err | sort -u > multicall/clash.syms
        [ -s multicall/clash.syms ] || { echo "multicall: link failed without a duplicate-symbol diagnostic" >&2; exit 1; }
        while IFS= read -r sym; do
          hit=0
          for a in "''${apps[@]}"; do
            if $NM --defined-only "$a.o" | awk -v s="$sym" '$3==s{f=1} END{exit !f}'; then
              $OBJCOPY --redefine-sym "$sym=''${a}__''${sym#"$up"}" "$a.o"
              hit=1
            fi
          done
          [ "$hit" = 1 ] || { echo "multicall: clashing symbol '$sym' not defined by any tool object" >&2; exit 1; }
        done < multicall/clash.syms
      done
      [ "$converged" = 1 ] || { echo "multicall: link did not converge in 30 passes" >&2; exit 1; }

      # mingw gcc may auto-append .exe; normalize to the suffixless name
      # installPhase + withAliases expect (Windows postFixup re-adds .exe).
      [ -f multicall/${name} ] || mv multicall/${name}.exe multicall/${name}
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      install -m755 multicall/${name} "$out/bin/${name}"
      while IFS= read -r a; do
        [ -n "$a" ] && ln -s ${name} "$out/bin/$a"
      done < multicall/apps.list

      # Embed the two CLI man pages (committed roff at the source root).
      # rtmpsrv/rtmpsuck have no upstream man; librtmp.3 is library API doc,
      # not a CLI tool. withMan harvests $out/share/man for native/darwin;
      # the Windows build embeds the same two via flake.nix's winManRoot.
      [ -f rtmpdump.1 ] && install -Dm644 rtmpdump.1 "$out/share/man/man1/rtmpdump.1"
      [ -f rtmpgw.8 ]   && install -Dm644 rtmpgw.8   "$out/share/man/man8/rtmpgw.8"

      runHook postInstall
    '';
  });
  # withAliases harvests the tool symlinks, embeds them as UNPIN_META and
  # objcopies into `$out/bin/${name}` (its `primary`). On mingw the shipped
  # file must be `${name}.exe`; rename after the embed (symlinks are already
  # gone by then, so nothing dangles).
  aliased = lib.withAliases pkgs
    {
      primary = name;
      aliasesFromSymlinksIn = "bin";
    }
    multicall;
in
if pkgs.stdenv.hostPlatform.isWindows
then aliased.overrideAttrs (o: {
  postFixup = (o.postFixup or "") + ''
    [ -f "$out/bin/${name}" ] && mv "$out/bin/${name}" "$out/bin/${name}.exe"
  '';
})
else aliased
