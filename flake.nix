{
    inputs = {
        nixpkgs.url= "github:nixos/nixpkgs/nixos-unstable";
        flake-utils.url = "github:numtide/flake-utils";
        rust-overlay.url = "github:oxalica/rust-overlay";
    };
  description = "A very basic flake";

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
      flake-utils.lib.eachDefaultSystem (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs { inherit system overlays; };
          rustVersion = pkgs.rust-bin.stable.latest.default;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustVersion;
            rustc = rustVersion;
          };
          myRustBuild = rustPlatform.buildRustPackage {
            pname =
              "burn_nix"; # make this what ever your cargo.toml package.name is
            version = "0.1.0";
            src = ./.; # the folder with the cargo.toml
            nativeBuildInputs = with pkgs; [pkg-config]; # just for the host building the package
            buildInputs = []; # packages needed by the consumer
            cargoLock.lockFile = ./Cargo.lock;
          };

          dockerImage = pkgs.dockerTools.buildImage {
            name = "rust-burn_nix";
            config = { Cmd = [ "${myRustBuild}/bin/burn_nix" ]; };
          };
        in {
            packages = {
                rustPackage = myRustBuild;
                docker = dockerImage;
            };
          defaultPackage = myRustBuild;
          devShell = pkgs.mkShell {
            buildInputs =
              [ (rustVersion.override { extensions = [ "rust-src" ]; }) ];
          };
        });
}
