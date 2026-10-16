{
  lib,
  rustPlatform,
  pkg-config,
  cmake,
  makeWrapper,
  stdenv,
  libxkbcommon,
  wayland,
  vulkan-loader,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxcb,
}:

let
  version = (lib.importTOML ./Cargo.toml).workspace.package.version;
in
rustPlatform.buildRustPackage {
  pname = "terminal-rs";
  inherit version;

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;
  # The binary crate lives in app/ inside a virtual workspace manifest.
  buildAndTestSubdir = "app";

  nativeBuildInputs = [
    pkg-config
    cmake # aws-lc-sys builds its C sources with cmake
    makeWrapper
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libxkbcommon
    wayland
    vulkan-loader
    libGL
    libx11
    libxcursor
    libxi
    libxcb
  ];

  postInstall = ''
    mv $out/bin/terminal-rs $out/bin/.terminal-rs-unwrapped
    makeWrapper $out/bin/.terminal-rs-unwrapped $out/bin/terminal-rs \
      --run 'case "''${1:-}" in --version|-V) echo "terminal-rs ${version}"; exit 0;; --help|-h|-?) printf "%s\n" "terminal-rs ${version} — keyboard-driven market terminal" "" "usage: terminal-rs [--version] [--help]" "" "Launches the native GUI (eframe/wgpu). Environment:" "  TR_PROVIDER=sample    run on offline sample data" "  TR_DATA_DIR=<dir>     override the data directory" "  TR_SMOKE_SECS=<n>     render for N seconds, log frame stats and quit" "  TR_CONGRESS_REFRESH_MIN=0   disable congress refresh"; exit 0;; esac'
  '';

  # wgpu, xkbcommon-dl and wayland-backend dlopen() these libraries at
  # runtime. They are not NEEDED entries, so extend the ELF rpath so the
  # binary finds them on non-NixOS Linux too.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    rpath=$(patchelf --print-rpath "$out/bin/.terminal-rs-unwrapped")
    patchelf --set-rpath "$rpath:${
      lib.makeLibraryPath [
        libxkbcommon
        vulkan-loader
        wayland
        libGL
      ]
    }" "$out/bin/.terminal-rs-unwrapped"
  '';

  # The test suite needs a display/GPU and network access; the project's own
  # CI runs it on macOS runners and under Xvfb on Linux.
  doCheck = false;

  meta = {
    description = "Bloomberg-style trading terminal with GPU charts and congressional trade tracking";
    homepage = "https://github.com/levonk/terminal-rs";
    mainProgram = "terminal-rs";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
