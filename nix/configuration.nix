{
  inputs,
  lib,
  pkgs,
  local,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./mounts.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.mangowm.nixosModules.mango
    inputs.noctalia.nixosModules.default
    inputs.helium.nixosModules.default
    ./modules/desktop.nix
    ./modules/apps.nix
    ./modules/gaming.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      "@wheel"
    ];
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  networking.hostName = local.hostname;
  networking.networkmanager.enable = true;
  # hardware-configuration.nix often enables dhcpcd per interface. NetworkManager replaces it.
  networking.dhcpcd.enable = lib.mkForce false;
  networking.useNetworkd = lib.mkForce false;
  networking.useDHCP = lib.mkForce false;
  networking.interfaces = lib.mkForce { };

  time.timeZone = local.timezone;
  i18n.defaultLocale = local.locale;
  console.useXkbConfig = true;
  services.xserver.xkb.layout = local.keyboard;
  services.xserver.xkb.variant = local.keyboardVariant;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    TERMINAL = "kitty";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  environment.etc."mango-noctalia/KEYBINDS.txt".source = ./assets/keybinds.txt;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "pre-mango";
    extraSpecialArgs = {
      inherit inputs local;
    };
    users.${local.username} = import ./home/home.nix;
  };

  hardware.enableRedistributableFirmware = lib.mkDefault true;

  services.openssh.enable = local.openssh;

  system.stateVersion = local.stateVersion;
}
