{
  inputs,
  lib,
  pkgs,
  local,
  ...
}:
let
  wallpaperDir = pkgs.callPackage ../assets/wallpaper.nix { };
  noctalia = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  mangoBase = builtins.replaceStrings [ "@keyboardLayout@" ] [ local.keyboard ] (
    builtins.readFile ./mango.conf
  );
  mangoConfig =
    if local.keyboardVariant == ""
    then builtins.replaceStrings [ "xkb_rules_variant=@keyboardVariant@\n" ] [ "" ] mangoBase
    else builtins.replaceStrings [ "@keyboardVariant@" ] [ local.keyboardVariant ] mangoBase;
in
{
  imports = [
    inputs.mangowm.hmModules.mango
    inputs.noctalia.homeModules.default
  ];

  home.username = local.username;
  home.homeDirectory = "/home/${local.username}";
  home.stateVersion = local.stateVersion;

  xdg.enable = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "thunar.desktop" ];
      "x-scheme-handler/http" = [ "helium.desktop" ];
      "x-scheme-handler/https" = [ "helium.desktop" ];
      "text/html" = [ "helium.desktop" ];
      "x-scheme-handler/terminal" = [ "kitty.desktop" ];
    };
  };
  xdg.configFile."xdg-terminals.list".text = "kitty.desktop\n";
  xdg.configFile."gtk-3.0/bookmarks".text = lib.concatMapStrings (path: "file://${path}\n") (
    [ "/mnt" ] ++ local.mountPoints
  );

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  qt = {
    enable = true;
    platform = "wayland";
  };

  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = "12.0";
      confirm_os_window_close = 0;
      enable_audio_bell = "no";
      background_opacity = "0.94";
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      cursor = "#f5e0dc";
      selection_background = "#45475a";
      selection_foreground = "#cdd6f4";
      color0 = "#45475a";
      color1 = "#f38ba8";
      color2 = "#a6e3a1";
      color3 = "#f9e2af";
      color4 = "#89b4fa";
      color5 = "#f5c2e7";
      color6 = "#94e2d5";
      color7 = "#bac2de";
      color8 = "#585b70";
      color9 = "#f38ba8";
      color10 = "#a6e3a1";
      color11 = "#f9e2af";
      color12 = "#89b4fa";
      color13 = "#f5c2e7";
      color14 = "#94e2d5";
      color15 = "#a6adc8";
    };
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = false;
      settings = {
        shell = {
          font_family = "JetBrainsMono Nerd Font";
          polkit_agent = true;
          clipboard_enabled = true;
          settings_show_advanced = true;
          panel = {
            shadow = false;
            transparency_mode = "soft";
            launcher_placement = "floating";
            clipboard_placement = "floating";
          };
          launcher = {
            categories = true;
            show_icons = true;
            sort_by_usage = true;
            pinned = [
              "kitty"
              "helium"
              "thunar"
              "cursor"
              "steam"
              "vesktop"
              "lutris"
              "heroic"
            ];
          };
        };
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
        wallpaper = {
          enabled = true;
          fill_mode = "crop";
          directory = "${wallpaperDir}";
          default.path = "${wallpaperDir}/mango-noctalia.png";
        };
        dock = {
          enabled = false;
          shadow = false;
        };
      bar.main = {
        position = "top";
        thickness = 36;
        background_opacity = 0.92;
        radius = 16;
        margin_ends = 12;
        margin_edge = 8;
        padding = 10;
        widget_spacing = 6;
        shadow = false;
        reserve_space = true;
        capsule = true;
        start = [
          "launcher"
          "workspaces"
        ];
        center = [ "clock" ];
        end = [
          "media"
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "battery"
          "control-center"
          "session"
        ];
      };
    };
  };

  wayland.windowManager.mango = {
    enable = true;
    systemd.enable = true;
    extraConfig = mangoConfig;
    autostart_sh = ''
      ${noctalia}/bin/noctalia &
    '';
  };

  home.file."Pictures/Wallpapers/mango-noctalia.png".source = "${wallpaperDir}/mango-noctalia.png";
}
