{
  config,
  lib,
  pkgs,
  local,
  ...
}:
let
  wallpaperDir = pkgs.callPackage ../assets/wallpaper.nix { };
  wallpaper = "${wallpaperDir}/mango-noctalia.png";
in
{
  users.users.${local.username} = {
    isNormalUser = true;
    description = local.fullName;
    uid = local.uid;
    group = local.group;
    extraGroups = local.extraGroups;
    shell = pkgs.bash;
    createHome = true;
  }
  // lib.optionalAttrs (local.hashedPassword != null) {
    hashedPassword = local.hashedPassword;
  };

  programs.mango = {
    enable = true;
    addLoginEntry = true;
  };

  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
  };

  services.xserver.enable = true;
  services.libinput.enable = true;
  services.displayManager.defaultSession = "mango";
  services.displayManager.autoLogin = lib.mkIf local.autologin {
    enable = true;
    user = local.username;
  };

  services.xserver.displayManager.lightdm = {
    enable = true;
    background = wallpaper;
    greeters.gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      cursorTheme = {
        name = "Bibata-Modern-Classic";
        package = pkgs.bibata-cursors;
        size = 24;
      };
      extraConfig = ''
        font-name = Inter 11
        indicators = ~host;~spacer;~clock;~spacer;~session;~language;~a11y;~power
        background-color = #11111b
      '';
    };
  };

  boot.loader = lib.mkMerge [
    (lib.mkIf (local.bootloader == "systemd-boot") {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    })
    (lib.mkIf (local.bootloader == "grub-efi") {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
      };
    })
    (lib.mkIf (local.bootloader == "grub-bios") {
      grub = {
        enable = true;
        device = local.grubDevice;
      };
    })
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = lib.mkIf local.nvidia {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = lib.mkIf local.nvidia [ "nvidia" ];

  security.rtkit.enable = true;
  security.polkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
  ];

  environment.systemPackages = with pkgs; [
    inter
    adw-gtk3
    papirus-icon-theme
    bibata-cursors
    brightnessctl
    wl-clipboard
    ntfs3g
    exfatprogs
    btrfs-progs
    xfsprogs
  ];
}
