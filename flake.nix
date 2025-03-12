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
          platform = builtins.elemAt parts 2;
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
        in
          if buildInfo == null then null else
          pkgs.stdenv.mkDerivation {
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
        in
          filteredVersions // {
            default = if builtins.hasAttr latestVersion filteredVersions
                      then filteredVersions.${latestVersion}
                      else null;
          }
      );
    };
}
