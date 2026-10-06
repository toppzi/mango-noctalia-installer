{
  description = "Opinionated MangoWM + Noctalia desktop";

  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The cachix branch is the newest Noctalia commit that already has binaries.
    # Do not follow nixpkgs here: that changes the hash and misses the cache.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      mangowm,
      noctalia,
      helium,
      ...
    }:
    let
      local = import ./local.nix;
    in
    {
      nixosConfigurations.mango = nixpkgs.lib.nixosSystem {
        system = local.system;
        specialArgs = {
          inherit inputs local;
        };
        modules = [
          ./configuration.nix
        ];
      };
    };
}
