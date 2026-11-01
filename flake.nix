{
  description = "Nix packaging of the Omarchy kernel (linux-omarchy)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    omarchy-pkgs = {
      url = "github:omacom/omarchy-pkgs";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      omarchy-pkgs,
    }:
    let
      # Omarchy only ships an x86_64 kernel config.
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          kernel = pkgs.callPackage ./kernel.nix { inherit omarchy-pkgs; };
        in
        {
          inherit kernel;
          linux-omarchy = kernel;
          default = kernel;
        }
      );
    };
}
