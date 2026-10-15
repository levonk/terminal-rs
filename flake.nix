{
  description = "Bloomberg-style trading terminal with GPU charts and congressional trade tracking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Pin x86_64-darwin to a stable release branch for older macOS Intel
    # compatibility. nixpkgs-unstable dropped x86_64-darwin in 26.11.
    nixpkgs-darwin-legacy.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Enables the non-flake `nix-build` path via default.nix.
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-darwin-legacy,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        if system == "x86_64-darwin" then
          import nixpkgs-darwin-legacy {
            inherit system;
            config.allowDeprecatedx86_64Darwin = true;
          }
        else
          nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (
        system:
        let
          terminal-rs = (pkgsFor system).callPackage ./package.nix { };
        in
        {
          inherit terminal-rs;
          default = terminal-rs;
          source = terminal-rs;
        }
      );

      apps = forAllSystems (system: {
        terminal-rs = {
          type = "app";
          program = "${self.packages.${system}.terminal-rs}/bin/terminal-rs";
          meta = self.packages.${system}.terminal-rs.meta;
        };
        default = self.apps.${system}.terminal-rs;
      });

      checks = forAllSystems (system: {
        build = self.packages.${system}.default;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.rustc
              pkgs.cargo
              pkgs.clippy
              pkgs.rustfmt
              pkgs.rust-analyzer
              pkgs.pkg-config
              pkgs.cmake # aws-lc-sys
              pkgs.sqlite # inspect the app's SQLite market-data cache
              pkgs.act # run GitHub Actions workflows locally
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.libxkbcommon
              pkgs.wayland
              pkgs.vulkan-loader
              pkgs.libGL
              pkgs.xorg.libX11
              pkgs.xorg.libXcursor
              pkgs.xorg.libXi
              pkgs.xorg.libxcb
            ];
          };
        }
      );

      overlays.default = final: prev: {
        terminal-rs = final.callPackage ./package.nix { };
      };
    };
}
