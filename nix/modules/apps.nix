{
  lib,
  pkgs,
  local,
  ...
}:
let
  boosteroid = pkgs.writeShellScriptBin "boosteroid" ''
    set -euo pipefail
    export QT_QPA_PLATFORM="''${BOOSTEROID_PLATFORM:-xcb}"
    roots=(
      "$HOME/.local/share/BoosteroidGamesS.R.L"
      "$HOME/.local/share/BoosteroidGamesS.R.L."
    )
    for root in "''${roots[@]}"; do
      [[ -d "$root" ]] || continue
      bin=$(find "$root" -type f -name Boosteroid -perm -u+x -print -quit || true)
      if [[ -n "$bin" ]]; then
        exec ${pkgs.steam-run}/bin/steam-run "$bin" "$@"
      fi
    done
    echo "Boosteroid is not in ~/.local/share/BoosteroidGamesS.R.L yet." >&2
    echo "Re-run the desktop installer and accept the Boosteroid step." >&2
    exit 1
  '';
in
{
  programs.helium = {
    enable = true;
    flags = [
      "--ozone-platform-hint=auto"
      "--enable-features=WaylandWindowDecorations"
    ];
  };

  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  services.flatpak.enable = true;
  systemd.services.flatpak-flathub = {
    description = "Add the Flathub remote";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      for _ in 1 2 3 4 5 6; do
        if flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
          exit 0
        fi
        sleep 5
      done
      echo "Flathub was not added. When the network is up, run:"
      echo "  flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
      exit 0
    '';
    serviceConfig.Type = "oneshot";
  };

  programs.nix-ld.enable = true;

  environment.systemPackages =
    with pkgs;
    [
      kitty
      code-cursor-fhs
      vesktop
      file-roller
      curl
      wget
      git
      unzip
    ]
    ++ lib.optional local.boosteroid boosteroid
    ++ lib.optional local.boosteroid (
      pkgs.makeDesktopItem {
        name = "boosteroid";
        desktopName = "Boosteroid";
        comment = "Cloud gaming, wrapped for NixOS";
        exec = "boosteroid";
        terminal = false;
        categories = [ "Game" ];
      }
    );
}
