# Nix Flake for KrakenD
This repository is a Nix flake packaging the [KrakenD](https://www.krakend.io/) Gateway. The flake mirrors the binaries built officially by KrakendD and does not build them from source.

The flake outputs are documented in flake.nix but an overview:
TBD
<!-- - Default package and "app" is the latest released version -->
<!-- - packages.<version> for a tagged release -->
<!-- - packages.master for the latest nightly release -->
<!-- - packages.master-<date> for a nightly release -->
<!-- - overlays.default is an overlay that adds zigpkgs to be the packages exposed by this flake -->
<!-- - templates.compiler-dev to setup a development environment for Zig compiler development. -->

## How to use 

### Flake

In your `flake.nix` file:
```nix
{
  inputs.krakend.url = "github:aryuuu/krakend-flake";

  outputs = { self, krakend, ... }: {
    ...
  };
}
```

TBD

### Thanks

This repository is inspired by [mitchellh/zig-overlay](https://github.com/mitchellh/zig-overlay)

## TODOs
- [ ] set up simple flake to download a krakend binary from krakend-ce github release
- [ ] set up source file containing all the available versions of the release
- [ ] set go version to pair with each of the krakend release version for plugin development
