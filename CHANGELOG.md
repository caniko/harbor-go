# Changelog

## Unreleased

### Changed

- golangci-lint 2.14.0 (roborev's current pin) and Go 1.27.3; 2.13.1 cannot
  read the export data of Go 1.27.2 and later.

### Added

- Retain named-zone development shells through Harbor's shared core environment.
- Go 1.27 toolchains, matching module builders, gopls, and pinned golangci-lint
  2.13.1 for consumers including roborev.
- Composable CGO-capable development shells, a buildable Go template, and Go
  treefmt configuration.
- Native Linux and ARM64 macOS qualification for packages, race tests,
  generated embedded assets, and tool versions.
- Roborev packaging guidance for composing Bun assets with its Go executable.
