{ pkgs, ... }:
{
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;
  hardware.steam-hardware.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  environment.systemPackages = with pkgs; [
    heroic
    lutris
    mangohud
    protonup-qt
    proton-ge-bin
    wineWowPackages.staging
    winetricks
    vulkan-tools
    steam-run
  ];
}
