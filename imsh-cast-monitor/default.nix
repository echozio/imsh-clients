{
  writeShellApplication,

  coreutils,
  inotify-tools,
  jq,
  ...
}:
writeShellApplication {
  name = "imsh-cast-monitor";
  runtimeInputs = [
    coreutils
    inotify-tools
    jq
  ];
  bashOptions = [ ];
  text = builtins.readFile ./imsh-cast-monitor.sh;
}
