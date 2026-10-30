{harbor-meta}: rec {
  timezone = harbor-meta.lib.timezone;
  mkGoToolchain = {
    pkgs,
    go ? pkgs.buildPackages.go_1_27,
    gopls ? null,
    golangciLint ? null,
  }: let
    buildGoModule = pkgs.buildGoModule.override {inherit go;};
  in {
    inherit go buildGoModule;
    gopls =
      if gopls != null
      then gopls
      else pkgs.gopls.override {buildGoLatestModule = buildGoModule;};
    golangciLint =
      if golangciLint != null
      then golangciLint
      else import ../nix/golangci-lint.nix {inherit pkgs buildGoModule;};
  };

  mkGoDevShellFragment = {
    pkgs,
    toolchain ? mkGoToolchain {inherit pkgs;},
    cgo ? true,
  }: {
    packages =
      [toolchain.go toolchain.gopls toolchain.golangciLint]
      ++ pkgs.lib.optionals cgo [pkgs.stdenv.cc pkgs.pkg-config];
    env = {
      GOTOOLCHAIN = "local";
      CGO_ENABLED =
        if cgo
        then "1"
        else "0";
    };
    shellHook = "";
  };

  mkGoDevShell = {
    pkgs,
    timeZone ? "UTC",
    toolchain ? mkGoToolchain {inherit pkgs;},
    cgo ? true,
    packages ? [],
    env ? {},
    extraShellHook ? "",
    mkShellArgs ? {},
  }:
    harbor-meta.lib.devShell.mkShell {
      inherit pkgs timeZone packages env extraShellHook mkShellArgs;
      fragments = [(mkGoDevShellFragment {inherit pkgs toolchain cgo;})];
    };

  # Build a pure-Go package for `target` with the native Go toolchain.
  #
  # A cross stdenv would build the Go compiler, cgo toolchain and linker for
  # the target, which cannot run on the build machine and is not substitutable.
  # Go can emit target binaries directly, so keep the build-platform toolchain
  # and switch GOOS/GOARCH instead. CGO is rejected because it needs a real
  # cross stdenv.
  mkGoCross = {
    pkgs,
    package,
    target,
    cgo ? false,
  }: let
    lib = pkgs.lib;
    targetPlatform =
      if builtins.isString target
      then lib.systems.elaborate target
      else target;
    targetGo =
      targetPlatform.go
      or (throw "harbor-go.mkGoCross: target ${toString target} has no Go platform metadata");
    targetSystem =
      targetPlatform.system
      or (throw "harbor-go.mkGoCross: target ${toString target} has no system");
    buildSystem = package.stdenv.buildPlatform.system;
    hostSystem = package.stdenv.hostPlatform.system;
  in
    if targetSystem == hostSystem
    then package
    else
      assert lib.assertMsg (buildSystem == hostSystem)
      "harbor-go.mkGoCross: ${package.name} is not a native build (build=${buildSystem}, host=${hostSystem}); pass a native package set instead of a cross stdenv";
      assert lib.assertMsg (!cgo)
      "harbor-go.mkGoCross: ${package.name} requests CGO_ENABLED=1; native-cross only supports pure-Go packages because cgo needs a real cross stdenv";
        package.overrideAttrs (old: {
          env =
            (old.env or {})
            // {
              GOOS = targetGo.GOOS;
              GOARCH = targetGo.GOARCH;
              CGO_ENABLED = "0";
            };
          doCheck = false;
          # buildGoModule only normalises $GOPATH/bin/$GOOS_$GOARCH when the
          # stdenv itself is cross. Native-cross keeps a native stdenv, so do it
          # here before installPhase copies $GOPATH/bin.
          postBuild =
            (old.postBuild or "")
            + ''
              gobin="$GOPATH/bin/${targetGo.GOOS}_${targetGo.GOARCH}"
              if [ -d "$gobin" ]; then
                mv "$gobin"/* "$GOPATH/bin/"
                rmdir "$gobin"
              fi
            '';
          passthru =
            (old.passthru or {})
            // {
              goNativeCross = {
                inherit targetSystem;
                inherit (targetGo) GOOS GOARCH;
              };
            };
        });

  mkGoPackage = {
    pkgs,
    toolchain ? mkGoToolchain {inherit pkgs;},
    target ? null,
    ...
  } @ args: let
    package = toolchain.buildGoModule (
      builtins.removeAttrs args ["pkgs" "toolchain" "target"]
      // {env = {GOTOOLCHAIN = "local";} // (args.env or {});}
    );
  in
    if target == null
    then package
    else
      mkGoCross {
        inherit pkgs package target;
        cgo = (args.env.CGO_ENABLED or "0") == "1";
      };
}
