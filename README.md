# MangoWM + Noctalia

An installer for a minimal NixOS system. It sets up MangoWM, Noctalia, and LightDM, then installs a small set of daily apps and can mount extra disks on every boot.

Run it on the installed system, not from the NixOS ISO.

## Install

1. Install NixOS the normal way and choose a minimal system. Boot into it.
2. Copy this folder onto that machine.
3. From the folder, run:

```bash
sudo bash install.sh
```

The installer asks for the account, keyboard, bootloader, extra drives, and whether to install Boosteroid. It keeps `hardware-configuration.nix` and the current NixOS state version, and it saves the old `/etc/nixos` next to a timestamped backup before replacing it.

The first build compiles Mango and downloads the rest. Reboot when it finishes, then pick the Mango session in LightDM.

## What you get

- MangoWM, with Noctalia started by the compositor
- LightDM with a dark GTK greeter
- Kitty, Helium, Cursor, Thunar, Vesktop
- Steam (with 32-bit graphics, GameMode, Gamescope, MangoHud, and GE-Proton), Lutris, and Heroic
- Flatpak, with Flathub added on the next boot
- PipeWire, NetworkManager, Bluetooth, and a Catppuccin-tinted Noctalia bar

Super is the Windows key. Super+Space opens the launcher. Super+F1 opens the full key list, which is also at `/etc/mango-noctalia/KEYBINDS.txt`.

## Disks

The installer lists filesystems that are not `/`, `/boot`, `/nix`, or `/home`. For each one you accept, it asks for a folder name and mounts it at `/mnt/<name>`.

NixOS does not keep a hand-written `/etc/fstab`. The answers are saved in `/etc/nixos/mounts.nix`, and NixOS generates `/etc/fstab` from that file, so the disks come back on every boot. A disk that is unplugged will not stop startup.

## Boosteroid

The official [BoosteroidInstall.sh](https://boosteroid.com/linux/installer/BoosteroidInstall.sh) installs its dependencies with apt or yum. NixOS has neither, so the installer downloads that script, reads the portable archive it points at, and extracts the client to `~/.local/share/BoosteroidGamesS.R.L`. A `boosteroid` command and a desktop entry launch it through `steam-run`. The client is forced onto X11 (`xcb`) because the Wayland build has been unstable; `BOOSTEROID_PLATFORM=wayland boosteroid` tries native Wayland.

## Afterward

Change the system in `/etc/nixos`, then run:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#mango
```

Noctalia settings changed in the settings window are stored in `~/.local/state/noctalia/settings.toml` and override the file managed by Nix.
