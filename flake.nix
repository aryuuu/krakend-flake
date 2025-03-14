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
      
      # Helper function to determine the appropriate architecture mapping
      getSystemArch = system:
        let
          parts = builtins.split "-" system;
          arch = builtins.elemAt parts 0;
        in
          if arch == "x86_64" then "amd64"
          else if arch == "aarch64" then "arm64"
          else null;
          
      # Helper to get platform mapping
      getSystemPlatform = system:
        let
          parts = builtins.split "-" system;
          platform = builtins.elemAt parts 2;
        in
          if platform == "linux" then "generic-linux"
          else if platform == "darwin" then "darwin"
          else null;
      
      # Read the catalog file
      catalogFile = ./catalog.json;
      catalog = if builtins.pathExists catalogFile 
                then builtins.fromJSON (builtins.readFile catalogFile)
                else {};
      
      # Create a package for a specific version and system
      makeKrakendPackage = system: version:
        let
          pkgs = pkgsFor.${system};
          systemArch = getSystemArch system;
          systemPlatform = getSystemPlatform system;
          
          # Find the appropriate build for this system
          buildInfo = lib.findFirst 
            (build: build.arch == systemArch && build.platform == systemPlatform) 
            null 
            (catalog.versions.${version}.builds or []);
            
          # Get Go version associated with this KrakenD version
          goVersion = catalog.versions.${version}.goVersion or "1.21";
          
          # Function to get the appropriate Go package from nixpkgs
          getGo = goVer:
            if goVer == "1.19" then pkgs.go_1_19
            else if goVer == "1.20" then pkgs.go_1_20
            else if goVer == "1.21" then pkgs.go_1_21
            else if goVer == "1.22" then pkgs.go_1_22
            else pkgs.go;  # Default to latest
            
          goPkg = getGo goVersion;
        in
          if buildInfo == null then null else
          {
            package = pkgs.stdenv.mkDerivation {
              pname = "krakend";
              inherit version;
              
              src = pkgs.fetchurl {
                url = buildInfo.url;
                sha256 = buildInfo.sha256;
              };
              
              sourceRoot = ".";
              
              nativeBuildInputs = with pkgs; [
                autoPatchelfHook
              ];
              
              buildInputs = with pkgs; [
                stdenv.cc.cc.lib
              ];
              
              installPhase = ''
                mkdir -p $out/bin
                install -m755 -D usr/bin/krakend $out/bin/krakend
              '';
            };
            
            # Include the compatible Go version
            go = goPkg;
            
            # Add an overlay that adds a krakend development shell
            overlay = final: prev: {
              krakendDevEnv = final.mkShell {
                packages = [
                  final.go  # Use the compatible Go version
                  # final.gopls
                  # final.delve
                  # final.golangci-lint
                ];
                
                inputsFrom = [ self.packages.${system}.${version}.package ];
                
                shellHook = ''
                  export KRAKEND_VERSION="${version}"
                  export GO_VERSION="${goVersion}"
                  echo "KrakenD Plugin Development Environment"
                  echo "KrakenD version: $KRAKEND_VERSION"
                  echo "Go version: $GO_VERSION"
                '';
              };
            };
          };
    in
    {
      packages = eachSystem (system:
        let
          # Default to latest version in catalog
          latestVersion = lib.head (lib.sort lib.versionAtLeast (builtins.attrNames (catalog.versions or {})));
          
          # Generate a package for each version
          versionPackages = lib.mapAttrs 
            (version: _: makeKrakendPackage system version) 
            (catalog.versions or {});
            
          # Only include versions that have a build for this system
          filteredVersions = lib.filterAttrs (_: value: value != null) versionPackages;
          
          # Map the package attribute to make it the default attribute
          finalVersions = lib.mapAttrs 
            (version: value: value.package) 
            filteredVersions;
        in
          finalVersions // {
            default = if builtins.hasAttr latestVersion finalVersions
                      then finalVersions.${latestVersion}
                      else null;
          }
      );
      
      # Development shells for each KrakenD version with the correct Go version
      devShells = eachSystem (system:
        let
          shells = lib.mapAttrs 
            (version: value: 
              if value == null then null else
              let 
                pkgs = pkgsFor.${system}.extend value.overlay;
              in
              pkgs.krakendDevEnv
            ) 
            (lib.mapAttrs 
              (version: _: makeKrakendPackage system version) 
              (catalog.versions or {})
            );
          
          # Only include versions that have a build for this system
          filteredShells = lib.filterAttrs (_: value: value != null) shells;
          
          # Default to latest version
          latestVersion = lib.head (lib.sort lib.versionAtLeast (builtins.attrNames filteredShells));
        in
          filteredShells // {
            default = if builtins.hasAttr latestVersion filteredShells
                      then filteredShells.${latestVersion}
                      else null;
          }
      );
    };
}
