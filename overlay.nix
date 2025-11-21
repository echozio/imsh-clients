self: super: {
  imsh-shot = self.callPackage ./imsh-shot { };
  imsh-cast = self.callPackage ./imsh-cast { };
  imsh-cast-monitor = self.callPackage ./imsh-cast-monitor { };

  # Remove when https://github.com/NixOS/nixpkgs/pull/463657
  # makes it to nixos-unstable
  wf-recorder = super.wf-recorder.overrideAttrs (prev: rec {
    version = "0.6.0";
    src = prev.src.override {
      rev = "v${version}";
      hash = "sha256-CY0pci2LNeQiojyeES5323tN3cYfS3m4pECK85fpn5I=";
    };
    patches = null;
  });
}
