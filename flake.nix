{
  description = "Reusable Go toolchains, module builds, and development shells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    harbor-meta = {
      url = "github:caniko/harbor-meta/trunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    harbor-meta,
    treefmt-nix,
    ...
  } @ outputArgs: let
    harborRoot =
      outputArgs.harborRoot or (harbor-meta.lib.standaloneRoot {
        core = harbor-meta;
        go = self;
      });
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    lib = import ./lib {inherit harbor-meta;};
    treefmt =
      forAllSystems (pkgs:
        treefmt-nix.lib.evalModule pkgs (import ./nix/treefmt.nix {inherit harbor-meta;}));
  in {
    inherit lib;
    treefmtModules.go = ./nix/treefmt/go.nix;
    templates.default = {
      path = ./templates/default;
      description = "Build and test a Go module with harbor-go";
    };
    packages = forAllSystems (pkgs: let
      toolchain = lib.mkGoToolchain {inherit pkgs;};
      template = harbor-meta.lib.templateTests.eval {
        flakeNix = ./templates/default/flake.nix;
        inputs = {
          harbor = harborRoot;
          inherit nixpkgs treefmt-nix;
        };
      };
    in {
      inherit (toolchain) go gopls;
      golangci-lint = toolchain.golangciLint;
      example = template.packages.${pkgs.stdenv.hostPlatform.system}.default;
      default = toolchain.go;
    });
    devShells = forAllSystems (pkgs: {
      default = lib.mkGoDevShell {
        inherit pkgs;
        packages = [self.formatter.${pkgs.stdenv.hostPlatform.system}];
      };
    });
    checks = forAllSystems (pkgs:
      (import ./checks {inherit pkgs self nixpkgs harbor-meta harborRoot;})
      // {formatting = treefmt.${pkgs.stdenv.hostPlatform.system}.config.build.check self;});
    formatter = builtins.mapAttrs (_: eval: eval.config.build.wrapper) treefmt;
  };
}
