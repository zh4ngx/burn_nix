{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile
          ./rust-toolchain.toml;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;
        nativeBuildInputs = with pkgs; [
          rustToolchain
          pkg-config
          vulkan-loader
        ];
        buildInputs = with pkgs; [ ];
        commonArgs = { inherit src buildInputs nativeBuildInputs; };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        bin = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });
        dockerImage = pkgs.dockerTools.streamLayeredImage {
          name = "burn_nix";
          tag = "latest";
          contents = [ bin ];
          config = {
            Cmd = [ "${bin}/bin/burn_nix" ];
            Env = [ "LD_LIBRARY_PATH=${pkgs.vulkan-loader}/lib" ];
          };

        };
      in with pkgs; {
        packages = {
          inherit bin dockerImage;
          default = bin;
        };
        devShells.default = mkShell {
          inputsFrom = [ bin ];
          buildInputs = with pkgs; [ dive just ];
          LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib";
          RUST_BACKTRACE = 1;
        };
      });
}
