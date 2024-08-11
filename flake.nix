{
  description = "GBDK cross-platform dev kit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: with inputs; flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.default = with pkgs; stdenv.mkDerivation {
        pname = "gbdk";
        version = "4.3.0";
        src = ./.;
        nativeBuildInputs = [ sdcc ];
        propagatedNativeBuildInputs = [ sdcc ];
        env = {
          SDCCDIR = "${pkgs.sdcc}";
          # Don't copy SDCC binaries; we can just depend on 'em
          SDCC_BINS = "";
          # Do not install into /opt
          TARGETDIR = "${placeholder "out"}";
        };

        # OK, look, full disclosure, we're sort of butchering this, but
        # I want to get this working for defcon 32 badge hacking and I don't
        # really care

        buildPhase = ''
        runHook preBuild

        make gbdk-build
        mkdir -p $out

        mkdir -p build/bin
        cp ${pkgs.sdcc}/bin/* build/bin/
        cp -R ${pkgs.sdcc}/libexec build/libexec
        cp -R ${pkgs.sdcc}/share build/share
        make gbdk-install

        runHook postBuild
        '';

        installPhase = ''
        cp -R build/gbdk/* $out/
        cp -R build/* $out/
        runHook postInstall
        '';
      };
      devShells.default = with pkgs; mkShell {
        inputsFrom = [ self.packages.${system}.default ];
      };
    });
}
