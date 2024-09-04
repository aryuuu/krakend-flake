{
  description = "KrakenD Community Edition Binaries.";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    systems.url = "github:nix-systems/default";
  };
  outputs = { self, nixpkgs, systems, ... }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsFor = eachSystem (system:
        import nixpkgs {
          system = system;
        }
      );
    in
    {
      devShells = eachSystem (system: {
        default = pkgsFor.${system}.mkShell {
          packages = [
          ];
        };
      });
      packages = eachSystem (system: {
        default = pkgsFor.${system}.stdenv.mkDerivation rec {
          pname = "krakend";
          version = "2.7.0";
          arch = "x86_64-linux";
          
          src = pkgsFor.${system}.fetchurl {
            url = "https://github.com/krakend/krakend-ce/releases/download/v${version}/krakend_${version}_amd64_generic-linux.tar.gz";
            sha256 = "sha256-hMsiK9IyL1mMZg83Dp1sdY+oYFQ+eIkcnc2lzdEkFNQ=";
          };
          
          sourceRoot = ".";
          
          nativeBuildInputs = with pkgsFor.${system}; [
            autoPatchelfHook
          ];
          
          buildInputs = with pkgsFor.${system}; [
            stdenv.cc.cc.lib
          ];
          
          installPhase = ''
            mkdir -p $out/bin
            install -m755 -D usr/bin/krakend $out/bin/krakend
          '';
        };
      });
    };
}
