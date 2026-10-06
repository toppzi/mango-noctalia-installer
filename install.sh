#!/usr/bin/env bash
# MangoWM + Noctalia installer for an already-installed minimal NixOS system.
# Run from the project directory:  sudo bash install.sh

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Run this with bash:  sudo bash install.sh"
  exit 1
fi

set -euo pipefail

MAUVE="#cba6f7"
TEXT="#cdd6f4"
SUB="#a6adc8"
PEACH="#fab387"
GREEN="#a6e3a1"
RED="#f38ba8"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP=""
REBUILT=false
TOTAL=6
STEP=0

die() {
  trap - ERR
  printf '\n%s\n' "$1" >&2
  exit 1
}

on_err() {
  local line=$1
  printf '\nThe installer stopped at line %s.\n' "$line" >&2
  if [[ "$REBUILT" == true ]]; then
    printf 'The desktop build already finished. A later step failed.\n' >&2
    printf 'Leave /etc/nixos as it is unless you want the previous system back.\n' >&2
  fi
  if [[ -n "$BACKUP" && -d "$BACKUP" ]]; then
    printf 'The previous /etc/nixos was copied to:\n  %s\n' "$BACKUP" >&2
    if [[ "$REBUILT" != true ]]; then
      printf 'Restore it with:\n  sudo rm -rf /etc/nixos && sudo mv %q /etc/nixos\n' "$BACKUP" >&2
    fi
  fi
}
trap 'on_err $LINENO' ERR

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo bash "$ROOT/install.sh" "$@"
fi

section() {
  STEP=$((STEP + 1))
  gum style --margin "1 0 0 0" --foreground "$PEACH" --bold "Step ${STEP} of ${TOTAL}    $1"
}

banner() {
  gum style \
    --border rounded \
    --border-foreground "$MAUVE" \
    --padding "1 4" \
    --margin "1 0" \
    --align center \
    "$(gum style --foreground "$MAUVE" --bold "MANGO   ·   NOCTALIA")" \
    "$(gum style --foreground "$SUB" "LightDM, games, and a bar that already knows the keys")"
}

nix_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "$value"
}

prompt() {
  local value
  value="$(gum input "$@")" || die "Cancelled."
  printf '%s' "$value"
}

need_nixos() {
  if [[ ! -f /etc/os-release ]] || ! grep -q '^ID=nixos$' /etc/os-release; then
    die "This installer only runs on NixOS. Install a minimal NixOS system first, boot it, then run this again."
  fi
  if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    die "No /etc/nixos/hardware-configuration.nix. Finish the normal NixOS install and boot into it before running this."
  fi
  if [[ ! -f "$ROOT/nix/flake.nix" ]]; then
    die "Can't find nix/flake.nix next to install.sh. Keep the project folder together."
  fi
}

fetch_tools() {
  if ! nix-instantiate --eval -E '<nixpkgs>' >/dev/null 2>&1; then
    die "The NixOS channel is missing. Run: nix-channel --add https://nixos.org/channels/nixos-unstable nixos && nix-channel --update"
  fi
  printf 'Preparing the installer interface…\n'
  local tools
  tools="$(nix-build --no-out-link -E '
    let pkgs = import <nixpkgs> {};
    in pkgs.buildEnv {
      name = "mango-installer-tools";
      paths = with pkgs; [ gum jq curl openssl pciutils ];
    }
  ')"
  export PATH="$tools/bin:$PATH"
}

ask_user() {
  local -a existing=()
  local name uid_field
  while IFS=: read -r name _ uid_field _; do
    if [[ "$uid_field" -ge 1000 && "$uid_field" -lt 65534 ]]; then
      existing+=("$name")
    fi
  done < /etc/passwd

  local choice
  if [[ ${#existing[@]} -eq 0 ]]; then
    choice="Create a new user"
  else
    choice="$(gum choose --header "Who should own this desktop?" "${existing[@]}" "Create a new user")" \
      || die "Cancelled."
  fi

  NEW_USER=false
  HASHED_PASSWORD="null"
  if [[ "$choice" == "Create a new user" ]]; then
    NEW_USER=true
    while true; do
      USERNAME="$(prompt --header "Username" --placeholder "alice")"
      if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        break
      fi
      gum style --foreground "$RED" "Use a short lowercase username. Letters, numbers, _ and - only."
    done
    FULL_NAME="$(prompt --header "Full name" --placeholder "Alice" --value "$USERNAME")"
    local pass pass2
    while true; do
      pass="$(gum input --password --header "Password for $USERNAME")" || die "Cancelled."
      pass2="$(gum input --password --header "Repeat the password")" || die "Cancelled."
      if [[ -n "$pass" && "$pass" == "$pass2" ]]; then
        break
      fi
      gum style --foreground "$RED" "The passwords were empty or did not match."
    done
    HASHED_PASSWORD="$(printf '%s' "$pass" | openssl passwd -6 -stdin)"
    unset pass pass2
    UID_VALUE=1000
    while getent passwd "$UID_VALUE" >/dev/null; do
      UID_VALUE=$((UID_VALUE + 1))
    done
    GROUP_NAME="users"
    GID_VALUE="$(getent group users | cut -d: -f3)"
    [[ -z "$GID_VALUE" ]] && GID_VALUE=100
    EXTRA_GROUPS=(wheel networkmanager video audio input render gamemode)
  else
    USERNAME="$choice"
    FULL_NAME="$(getent passwd "$USERNAME" | cut -d: -f5 | cut -d, -f1)"
    [[ -z "$FULL_NAME" ]] && FULL_NAME="$USERNAME"
    UID_VALUE="$(id -u "$USERNAME")"
    GID_VALUE="$(id -g "$USERNAME")"
    GROUP_NAME="$(id -gn "$USERNAME")"
    EXTRA_GROUPS=()
    local -A seen=()
    local group
    for group in wheel networkmanager video audio input render gamemode $(id -nG "$USERNAME"); do
      [[ "$group" == "$GROUP_NAME" ]] && continue
      [[ -n "${seen[$group]:-}" ]] && continue
      seen[$group]=1
      EXTRA_GROUPS+=("$group")
    done
  fi
}

ask_machine() {
  local current_host current_tz current_locale current_kb current_variant
  current_host="$(cat /etc/hostname 2>/dev/null || true)"
  [[ -z "$current_host" ]] && current_host="mango"
  HOSTNAME="$(prompt --header "Hostname" --value "$current_host")"
  if [[ ! "$HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
    die "Hostname '$HOSTNAME' is not valid."
  fi

  current_tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  [[ -z "$current_tz" ]] && current_tz="UTC"
  while true; do
    TIMEZONE="$(prompt --header "Timezone" --value "$current_tz")"
    if timedatectl list-timezones 2>/dev/null | grep -qx "$TIMEZONE"; then
      break
    fi
    gum style --foreground "$RED" "That timezone is not in the system list. Example: Europe/Stockholm"
  done

  current_locale="$(awk -F= '/^LANG=/{print $2}' /etc/locale.conf 2>/dev/null || true)"
  [[ -z "$current_locale" ]] && current_locale="en_US.UTF-8"
  LOCALE="$(prompt --header "Locale" --value "$current_locale")"

  current_kb="$(localectl status 2>/dev/null | awk -F: '/X11 Layout/ {gsub(/ /,"",$2); print $2}' || true)"
  [[ -z "$current_kb" ]] && current_kb="us"
  KEYBOARD="$(prompt --header "Keyboard layout" --value "$current_kb" --placeholder "us")"
  current_variant="$(localectl status 2>/dev/null | awk -F: '/X11 Variant/ {gsub(/ /,"",$2); print $2}' || true)"
  KEYBOARD_VARIANT="$(prompt --header "Keyboard variant" --value "$current_variant" --placeholder "empty, or dvorak / intl")"

  case "$(uname -m)" in
    x86_64) SYSTEM="x86_64-linux" ;;
    aarch64) SYSTEM="aarch64-linux" ;;
    *) die "This installer supports x86_64 and aarch64. This machine is $(uname -m)." ;;
  esac

  STATE_VERSION="$(sed -n 's/.*stateVersion = "\([^"]*\)".*/\1/p' /etc/nixos/configuration.nix | head -n 1 || true)"
  [[ -z "$STATE_VERSION" ]] && STATE_VERSION="25.11"

  OPENSSH=false
  if grep -Eq 'services\.openssh\.enable[[:space:]]*=[[:space:]]*true' /etc/nixos/configuration.nix; then
    OPENSSH=true
  fi
}

ask_bootloader() {
  local old=/etc/nixos/configuration.nix
  local detected="systemd-boot"
  local efi=false
  [[ -d /sys/firmware/efi ]] && efi=true
  if grep -q 'systemd-boot.enable = true' "$old"; then
    detected="systemd-boot"
  elif grep -q 'grub.enable = true' "$old"; then
    if grep -q 'efiSupport = true' "$old"; then
      detected="grub-efi"
    else
      detected="grub-bios"
    fi
  elif [[ "$efi" == false ]]; then
    detected="grub-bios"
  fi

  local selected="systemd-boot (UEFI)"
  case "$detected" in
    grub-efi) selected="GRUB (UEFI)" ;;
    grub-bios) selected="GRUB (BIOS)" ;;
  esac

  local pick
  pick="$(gum choose --header "Bootloader to keep" --selected "$selected" \
    "systemd-boot (UEFI)" "GRUB (UEFI)" "GRUB (BIOS)")" || die "Cancelled."
  case "$pick" in
    "systemd-boot (UEFI)") BOOTLOADER="systemd-boot" ;;
    "GRUB (UEFI)") BOOTLOADER="grub-efi" ;;
    "GRUB (BIOS)") BOOTLOADER="grub-bios" ;;
  esac

  if [[ "$efi" == false && "$BOOTLOADER" != "grub-bios" ]]; then
    die "This machine has no UEFI firmware. Choose GRUB (BIOS)."
  fi

  GRUB_DEVICE="/dev/sda"
  if [[ "$BOOTLOADER" == "grub-bios" ]]; then
    local parsed
    parsed="$(sed -n 's/.*device = "\([^"]*\)".*/\1/p' "$old" | head -n 1 || true)"
    if [[ -n "$parsed" && "$parsed" != "nodev" ]]; then
      GRUB_DEVICE="$parsed"
    fi
    GRUB_DEVICE="$(prompt --header "Disk GRUB should install to" --value "$GRUB_DEVICE")"
  fi
}

ask_nvidia() {
  NVIDIA=false
  if lspci -nn 2>/dev/null | grep -qi 'nvidia'; then
    if gum confirm --default=true "An NVIDIA GPU was found. Install the proprietary driver?"; then
      NVIDIA=true
    fi
  fi
}

ask_autologin() {
  AUTOLOGIN=false
  if gum confirm --default=false "Log in automatically as $USERNAME? LightDM stays installed either way."; then
    AUTOLOGIN=true
  fi
}

ask_boosteroid() {
  BOOSTEROID=false
  gum style --margin "1 0 0 0" --foreground "$SUB" \
    "Boosteroid publishes a .sh installer that expects apt or yum. NixOS has neither." \
    "If you say yes, the installer downloads that script, follows the portable archive it points at," \
    "and launches the client through steam-run so the libraries resolve."
  if gum confirm --default=false "Install Boosteroid?"; then
    BOOSTEROID=true
  fi
}

collect_drives() {
  DRIVE_JSON="$(lsblk -J -o PATH,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT,MOUNTPOINTS,TYPE | jq -c '
    def mounts:
      if (.mountpoints | type) == "array" then [.mountpoints[] | select(. != null and . != "")]
      elif (.mountpoint != null and .mountpoint != "") then [.mountpoint]
      else [] end;
    [ .. | objects
      | select(.type == "part" or .type == "crypt" or .type == "lvm" or (.type == "disk" and (.fstype // "") != ""))
      | select((.fstype // "") != "" and .fstype != "swap" and .fstype != "iso9660" and .fstype != "squashfs")
      | select((.uuid // "") != "")
      | select(mounts | all(. != "/" and (startswith("/boot") | not) and (startswith("/nix") | not) and . != "/home"))
      | {
          path, size, fstype, label: (.label // ""), uuid, type,
          mounted: (mounts | join(", "))
        }
    ] | unique_by(.uuid)
  ')"
}

sanitize_name() {
  local raw=$1 fallback=$2
  local name
  name="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$name" || "$name" == "." || "$name" == ".." ]]; then
    name="$(basename "$fallback")"
  fi
  printf '%s' "$name"
}

ask_drives() {
  MOUNT_LINES=()
  MOUNT_POINTS=()
  declare -A USED_NAMES=()
  local count
  count="$(jq 'length' <<<"$DRIVE_JSON")"
  if [[ "$count" -eq 0 ]]; then
    gum style --foreground "$SUB" "No extra filesystems showed up. The system disk stays as NixOS installed it."
    if gum confirm --default=false "Plug a drive in and scan again?"; then
      collect_drives
      ask_drives
    fi
    return
  fi

  gum style --foreground "$SUB" \
    "Each drive you accept is mounted at /mnt/<name> on every boot." \
    "NixOS writes that into /etc/fstab from the system config, so a later rebuild keeps it." \
    "A missing disk will not block startup."

  local i=0
  while [[ "$i" -lt "$count" ]]; do
    local path size fstype label uuid mounted title default_name name
    path="$(jq -r ".[$i].path" <<<"$DRIVE_JSON")"
    size="$(jq -r ".[$i].size" <<<"$DRIVE_JSON")"
    fstype="$(jq -r ".[$i].fstype" <<<"$DRIVE_JSON")"
    label="$(jq -r ".[$i].label" <<<"$DRIVE_JSON")"
    uuid="$(jq -r ".[$i].uuid" <<<"$DRIVE_JSON")"
    mounted="$(jq -r ".[$i].mounted" <<<"$DRIVE_JSON")"
    title="$path   $size   $fstype"
    [[ -n "$label" ]] && title="$title   \"$label\""
    [[ -n "$mounted" ]] && title="$title   mounted at $mounted"
    gum style --border rounded --border-foreground "$MAUVE" --padding "0 2" --margin "1 0 0 0" "$title"
    if gum confirm --default=false "Mount this on every boot?"; then
      default_name="$(sanitize_name "${label:-}" "$path")"
      while true; do
        name="$(prompt --header "Folder name under /mnt" --value "$default_name")"
        name="$(sanitize_name "$name" "$path")"
        if [[ -z "${USED_NAMES[$name]:-}" ]]; then
          break
        fi
        gum style --foreground "$RED" "/mnt/$name is already chosen. Pick another name."
        default_name="${name}-2"
      done
      USED_NAMES[$name]=1
      MOUNT_LINES+=("$path|$fstype|$uuid|$name")
      MOUNT_POINTS+=("/mnt/$name")
    fi
    i=$((i + 1))
  done
}

fstab_options_for() {
  local fstype=$1
  case "$fstype" in
    ntfs|ntfs3)
      printf '%s' "defaults,nofail,uid=${UID_VALUE},gid=${GID_VALUE},umask=022,windows_names,x-systemd.device-timeout=10s"
      ;;
    exfat|vfat|fat|fat32|msdos)
      printf '%s' "defaults,nofail,uid=${UID_VALUE},gid=${GID_VALUE},umask=022,x-systemd.device-timeout=10s"
      ;;
    *)
      printf '%s' "defaults,nofail,x-systemd.device-timeout=10s"
      ;;
  esac
}

nix_fs_type() {
  case "$1" in
    ntfs|ntfs3) printf '%s' "ntfs3" ;;
    fat|fat32|msdos) printf '%s' "vfat" ;;
    *) printf '%s' "$1" ;;
  esac
}

nix_options_for() {
  local fstype=$1
  case "$fstype" in
    ntfs|ntfs3|exfat|vfat|fat|fat32|msdos)
      printf '[ "defaults" "nofail" "uid=%s" "gid=%s" "umask=022"' "$UID_VALUE" "$GID_VALUE"
      if [[ "$fstype" == "ntfs" || "$fstype" == "ntfs3" ]]; then
        printf ' "windows_names"'
      fi
      printf ' "x-systemd.device-timeout=10s" ]'
      ;;
    *)
      printf '[ "defaults" "nofail" "x-systemd.device-timeout=10s" ]'
      ;;
  esac
}

write_mounts() {
  local dest=$1
  {
    printf '%s\n' "# Generated by the Mango + Noctalia installer."
    printf '%s\n' "# NixOS turns these fileSystems into /etc/fstab, so they mount on every boot."
    local line path fstype uuid name nix_type opts fstab_opts
    for line in "${MOUNT_LINES[@]}"; do
      [[ -z "$line" ]] && continue
      IFS='|' read -r path fstype uuid name <<<"$line"
      nix_type="$(nix_fs_type "$fstype")"
      fstab_opts="$(fstab_options_for "$fstype")"
      printf '# UUID=%s  /mnt/%s  %s  %s\n' "$uuid" "$name" "$nix_type" "$fstab_opts"
    done
    printf '%s\n' '{ }:'
    printf '%s\n' '{'
    for line in "${MOUNT_LINES[@]}"; do
      [[ -z "$line" ]] && continue
      IFS='|' read -r path fstype uuid name <<<"$line"
      nix_type="$(nix_fs_type "$fstype")"
      opts="$(nix_options_for "$fstype")"
      printf '  fileSystems."/mnt/%s" = {\n' "$name"
      printf '    device = "/dev/disk/by-uuid/%s";\n' "$uuid"
      printf '    fsType = "%s";\n' "$nix_type"
      printf '    options = %s;\n' "$opts"
      printf '  };\n'
    done
    printf '%s\n' '}'
  } > "$dest"
}

write_local() {
  local dest=$1
  local groups="["
  local group
  for group in "${EXTRA_GROUPS[@]}"; do
    groups+=" \"$(nix_escape "$group")\""
  done
  groups+=" ]"

  local mounts="["
  local point
  for point in "${MOUNT_POINTS[@]}"; do
    [[ -z "$point" ]] && continue
    mounts+=" \"$(nix_escape "$point")\""
  done
  mounts+=" ]"

  local hash_line="null"
  if [[ "$HASHED_PASSWORD" != "null" ]]; then
    hash_line="\"$(nix_escape "$HASHED_PASSWORD")\""
  fi

  {
    printf '%s\n' "# Generated by the Mango + Noctalia installer."
    printf '%s\n' "{"
    printf '  username = "%s";\n' "$(nix_escape "$USERNAME")"
    printf '  fullName = "%s";\n' "$(nix_escape "$FULL_NAME")"
    printf '  hostname = "%s";\n' "$(nix_escape "$HOSTNAME")"
    printf '  system = "%s";\n' "$SYSTEM"
    printf '  timezone = "%s";\n' "$(nix_escape "$TIMEZONE")"
    printf '  locale = "%s";\n' "$(nix_escape "$LOCALE")"
    printf '  keyboard = "%s";\n' "$(nix_escape "$KEYBOARD")"
    printf '  keyboardVariant = "%s";\n' "$(nix_escape "$KEYBOARD_VARIANT")"
    printf '  stateVersion = "%s";\n' "$(nix_escape "$STATE_VERSION")"
    printf '  bootloader = "%s";\n' "$BOOTLOADER"
    printf '  grubDevice = "%s";\n' "$(nix_escape "$GRUB_DEVICE")"
    printf '  uid = %s;\n' "$UID_VALUE"
    printf '  gid = %s;\n' "$GID_VALUE"
    printf '  group = "%s";\n' "$(nix_escape "$GROUP_NAME")"
    printf '  hashedPassword = %s;\n' "$hash_line"
    printf '  autologin = %s;\n' "$AUTOLOGIN"
    printf '  boosteroid = %s;\n' "$BOOSTEROID"
    printf '  nvidia = %s;\n' "$NVIDIA"
    printf '  openssh = %s;\n' "$OPENSSH"
    printf '  extraGroups = %s;\n' "$groups"
    printf '  mountPoints = %s;\n' "$mounts"
    printf '%s\n' "}"
  } > "$dest"
}

install_tree() {
  local stage
  stage="$(mktemp -d)"
  cp -a "$ROOT/nix/." "$stage/"
  cp -a /etc/nixos/hardware-configuration.nix "$stage/hardware-configuration.nix"
  write_local "$stage/local.nix"
  write_mounts "$stage/mounts.nix"
  BACKUP="/etc/nixos.backup-$(date +%Y%m%d-%H%M%S)"
  cp -a /etc/nixos "$BACKUP"
  find /etc/nixos -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "$stage/." /etc/nixos/
  rm -rf "$stage"
  chmod 644 /etc/nixos/local.nix
}

install_boosteroid_client() {
  local home dest tmp url found
  home="$(getent passwd "$USERNAME" | cut -d: -f6)"
  [[ -n "$home" && -d "$home" ]] || die "Home directory for $USERNAME does not exist yet, so Boosteroid was not copied."
  dest="$home/.local/share/BoosteroidGamesS.R.L"
  tmp="$(mktemp -d)"
  url="https://boosteroid.com/linux/installer/boosteroid_portable.tar"
  printf '\nDownloading the official Boosteroid installer script…\n'
  if curl -fL --retry 3 -o "$tmp/BoosteroidInstall.sh" "https://boosteroid.com/linux/installer/BoosteroidInstall.sh"; then
    found="$(grep -oE 'https://[^"'\''[:space:]]+boosteroid_portable\.tar' "$tmp/BoosteroidInstall.sh" | head -n 1 || true)"
    [[ -n "$found" ]] && url="$found"
    install -d -m 0755 "$dest"
    install -m 0644 "$tmp/BoosteroidInstall.sh" "$dest/BoosteroidInstall.sh"
    printf 'The .sh file is saved at %s\n' "$dest/BoosteroidInstall.sh"
    printf 'It is not executed: it installs packages with apt or yum, which NixOS does not have.\n'
  else
    printf 'The .sh file could not be downloaded. Continuing with the portable archive.\n'
  fi
  printf 'Downloading the Boosteroid client…\n'
  curl -fL --retry 3 --progress-bar -o "$tmp/boosteroid.tar" "$url"
  install -d -m 0755 "$dest"
  tar -xf "$tmp/boosteroid.tar" -C "$dest"
  find "$dest" -type f -name Boosteroid -exec chmod 0755 {} +
  local owner_group
  owner_group="$(id -gn "$USERNAME")"
  chown -R "$USERNAME:$owner_group" "$dest"
  rm -rf "$tmp"
  if ! find "$dest" -type f -name Boosteroid | grep -q .; then
    printf 'The archive extracted, but no Boosteroid binary was found under %s.\n' "$dest" >&2
    printf 'Launch will fail until that file is there. The desktop entry is still installed.\n' >&2
  fi
}

show_summary() {
  section "Review"
  local mounts="none"
  if [[ ${#MOUNT_POINTS[@]} -gt 0 ]]; then
    mounts="$(printf '%s\n' "${MOUNT_POINTS[@]}")"
  fi
  local boot_label="$BOOTLOADER"
  [[ "$BOOTLOADER" == "grub-bios" ]] && boot_label="grub-bios on $GRUB_DEVICE"
  gum style \
    --border rounded \
    --border-foreground "$MAUVE" \
    --padding "1 2" \
    --margin "1 0" \
    "$(gum style --foreground "$MAUVE" --bold "Ready to install")" \
    "" \
    "User          $USERNAME" \
    "Host          $HOSTNAME" \
    "System        $SYSTEM" \
    "Timezone      $TIMEZONE" \
    "Locale        $LOCALE" \
    "Keyboard      $KEYBOARD ${KEYBOARD_VARIANT}" \
    "Bootloader    $boot_label" \
    "NVIDIA        $NVIDIA" \
    "Autologin     $AUTOLOGIN" \
    "Boosteroid    $BOOSTEROID" \
    "OpenSSH       $OPENSSH  (kept from the current config)" \
    "" \
    "Mounts" \
    "$mounts" \
    "" \
    "This replaces /etc/nixos. hardware-configuration.nix and the NixOS state version stay." \
    "A backup is written first. Custom services in the old configuration.nix are not copied."
  gum confirm "Install MangoWM and Noctalia now?" || die "Cancelled. Nothing was changed."
}

rebuild() {
  section "Build"
  gum style --foreground "$SUB" \
    "The first build compiles Mango and downloads the rest of the desktop." \
    "That often takes a while. The log stays on this screen."
  export NIX_CONFIG=$'experimental-features = nix-command flakes\naccept-flake-config = true\nextra-substituters = https://noctalia.cachix.org\nextra-trusted-public-keys = noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=\n'
  nixos-rebuild switch --flake /etc/nixos#mango --show-trace
  REBUILT=true
}

main() {
  need_nixos
  fetch_tools
  clear || true
  banner
  gum style --foreground "$SUB" "This turns a minimal NixOS install into a MangoWM + Noctalia desktop."

  section "Account"
  ask_user

  section "Machine"
  ask_machine
  ask_bootloader
  ask_nvidia
  ask_autologin

  section "Drives"
  collect_drives
  ask_drives

  section "Boosteroid"
  ask_boosteroid

  show_summary
  install_tree
  rebuild
  if [[ "$BOOSTEROID" == true ]]; then
    install_boosteroid_client
  fi

  trap - ERR
  printf '\n'
  gum style \
    --border rounded \
    --border-foreground "$GREEN" \
    --padding "1 2" \
    --foreground "$TEXT" \
    "$(gum style --foreground "$GREEN" --bold "Desktop installed")" \
    "" \
    "Log in through LightDM and choose the Mango session." \
    "Super + Space opens the launcher. Super + F1 opens the key list." \
    "Flathub is added on the next boot once the network is up." \
    "" \
    "Backup of the old /etc/nixos:" \
    "$BACKUP"
  printf '\n'
  sed 's/^/  /' /etc/nixos/assets/keybinds.txt
  printf '\n'
  if gum confirm --default=true "Reboot into the new desktop now?"; then
    systemctl reboot
  fi
  gum style --foreground "$SUB" "Reboot when you are ready:  sudo systemctl reboot"
}

main "$@"
