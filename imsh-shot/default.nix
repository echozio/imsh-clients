{
  writeShellApplication,

  coreutils,
  curl,
  grimblast,
  jq,
  wl-clipboard,
  ...
}:
writeShellApplication {
  name = "imsh-shot";
  runtimeInputs = [
    coreutils
    curl
    grimblast
    jq
    wl-clipboard
  ];
  bashOptions = [ ];
  excludeShellChecks = [ "SC2194" ];
  text = builtins.readFile ./imsh-shot.sh;
}
