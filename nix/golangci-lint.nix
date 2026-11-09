{
  pkgs,
  buildGoModule,
}: let
  version = "2.14.0";
in
  # Roborev refuses other versions (its .custom-gcl.yml); retain Nixpkgs'
  # packaging hooks. 2.13.1 cannot read Go >= 1.27.2 export data (version 5).
  (pkgs.golangci-lint.override {buildGo127Module = buildGoModule;}).overrideAttrs (old: {
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "golangci";
      repo = "golangci-lint";
      tag = "v${version}";
      hash = "sha256-HATA7JKHwEouM+8jYZbQrkX7p4gut4IpyTvcBexu/4o=";
    };
    vendorHash = "sha256-ekP/zDhYMpMG+tYAyYHNfLOCt/JkxrXUw1jHUEfsM8k=";
    ldflags = ["-s" "-w" "-X main.version=${version}" "-X main.commit=v${version}" "-X main.date=1970-01-01T00:00:00Z"];
    meta = old.meta // {changelog = "https://github.com/golangci/golangci-lint/blob/v${version}/CHANGELOG.md";};
  })
