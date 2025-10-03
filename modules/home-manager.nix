{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.programs.imsh-clients;
in
{
  options.programs.imsh-clients = {
    enable = lib.mkEnableOption "imsh-clients";

    imsh-shot = {
      enable = lib.mkEnableOption "imsh-shot";
      package = lib.mkPackageOption pkgs "imsh-shot" { };
    };

    imsh-cast = {
      enable = lib.mkEnableOption "imsh-cast";
      package = lib.mkPackageOption pkgs "imsh-cast" { };
    };

    imsh-cast-monitor = {
      enable = lib.mkEnableOption "imsh-cast-monitor";
      package = lib.mkPackageOption pkgs "imsh-cast-monitor" { };

      waybar = {
        enable = lib.mkEnableOption "custom waybar module added to mainBar";

        module = lib.mkOption {
          type = lib.types.raw;
        };
      };
    };
  };

  config = {
    nixpkgs.overlays = lib.singleton (
      final: prev: {
        imsh-shot = final.callPackage ../imsh-shot { };
        imsh-cast = final.callPackage ../imsh-cast { };
        imsh-cast-monitor = final.callPackage ../imsh-cast-monitor { };
      }
    );

    programs.imsh-clients = {
      imsh-shot.enable = lib.mkDefault cfg.enable;
      imsh-cast.enable = lib.mkDefault cfg.enable;

      imsh-cast-monitor.waybar.module = {
        format = "{text}";
        exec = lib.getExe cfg.imsh-cast-monitor.package;
        return-type = "json";
        hide-empty-text = true;
      };
    };

    home.packages =
      (with cfg.imsh-shot; lib.optional enable package)
      ++ (with cfg.imsh-cast; lib.optional enable package)
      ++ (with cfg.imsh-cast-monitor; lib.optional enable package);

    programs.waybar = lib.mkIf cfg.imsh-cast-monitor.waybar.enable {
      settings.mainBar = {
        modules-center = lib.mkBefore [ "custom/imsh-cast-monitor" ];
        "custom/imsh-cast-monitor" = cfg.imsh-cast-monitor.waybar.module;
      };
      style = ''
        .imsh-cast-monitor.recording {
          color: #f00;
        }

        .imsh-cast-monitor.error {
          color: #ff0;
        }
      '';
    };
  };
}
