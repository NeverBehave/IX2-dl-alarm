{ sources ? import ./nix/sources.nix }: # import the sources
with
{
  overlay = _: pkgs:
    {
      niv = (import sources.niv { }).niv;
    };
};
let
  pkgs = (import sources.nixpkgs) {
    overlays = [ overlay ];
    config.allowUnfree = true;
  };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    wget
    screen
    libarchive # bsdtar

    ubootTools
    unixtools.fdisk
    dtc

    nixUnstable

    niv
  ];

  shellHook = ''
    # Before run command
    echo 'Check readme for more details'
  '';
}