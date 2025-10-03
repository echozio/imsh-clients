{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      argsFor = system: {
        inherit system;
        pkgs = nixpkgs.legacyPackages.${system};
      };
      forAllSystems = f: lib.genAttrs systems (system: f (argsFor system));
    in
    {
      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bash
              coreutils
              curl
              grimblast
              inotify-tools
              jq
              slurp
              wf-recorder
              wl-clipboard
            ];
          };
        }
      );

      packages = forAllSystems (
        { pkgs, system, ... }:
        {
          default = self.packages.${system}.imsh-clients;
          imsh-clients = pkgs.symlinkJoin {
            name = "imsh-clients";
            paths = with self.packages.${system}; [
              imsh-shot
              imsh-cast
              imsh-cast-monitor
            ];
          };
          imsh-shot = pkgs.callPackage ./imsh-shot { };
          imsh-cast = pkgs.callPackage ./imsh-cast { };
          imsh-cast-monitor = pkgs.callPackage ./imsh-cast-monitor { };
        }
      );

      homeManagerModules = {
        default = self.homeManagerModules.imsh-clients;
        imsh-clients = ./modules/home-manager.nix;
      };

      formatter = forAllSystems (
        { pkgs, ... }:
        pkgs.treefmt.withConfig {
          settings = {
            on-unmatched = "info";
            formatter.nixfmt = {
              command = lib.getExe pkgs.nixfmt-rfc-style;
              includes = [ "*.nix" ];
            };
          };
        }
      );
    };
}
