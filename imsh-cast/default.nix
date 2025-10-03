{
  writeShellApplication,

  coreutils,
  curl,
  jq,
  slurp,
  wf-recorder,
  wl-clipboard,
  ...
}:
writeShellApplication {
  name = "imsh-cast";
  runtimeInputs = [
    coreutils
    curl
    jq
    slurp
    wf-recorder
    wl-clipboard
  ];
  bashOptions = [ ];
  excludeShellChecks = [ "SC2194" ];
  text = builtins.readFile ./imsh-cast.sh;
}
