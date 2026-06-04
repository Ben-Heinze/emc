{
  description = "Emacs with nix-community overlay";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    overlay.url = "github:nix-community/emacs-overlay";
  };
  outputs = { self, nixpkgs, overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        overlays = [ (import overlay) ];
      };
      iconFonts = [
        pkgs.all-the-icons
        pkgs.nerd-fonts.symbols-only
        pkgs.nerd-fonts.ubuntu-mono
      ];
      fontConfig = pkgs.makeFontsConf { fontDirectories = iconFonts; };
      emacsPackages = pkgs.emacsPackagesFor pkgs.emacs-unstable;
      emacs = emacsPackages.emacsWithPackages (epkgs: [
        epkgs.vterm
      ]);
      emacsWrapper = pkgs.writeShellScriptBin "emacs-wrapper" ''
        #!/bin/sh
        CACHE_DIR="$HOME/.local/share/emc/"
        mkdir -p "$CACHE_DIR"
        cp -ra ${toString ./.}/* "$CACHE_DIR/" 2>/dev/null || true
        chmod -R u+w "$CACHE_DIR"/*
        export PATH="${pkgs.cmake}/bin:$PATH"
        export PATH="${pkgs.gnumake}/bin:$PATH"
        export PATH="${pkgs.gcc}/bin:$PATH"
        export PATH="${pkgs.libtool}/bin:$PATH"
        export PATH="${pkgs.R}/bin:$PATH"
        export PATH="${pkgs.php}/bin:$PATH"
        export FONTCONFIG_FILE="${fontConfig}"
        cd "$CACHE_DIR"
        ${emacs}/bin/emacs --batch -l ./tangle-script.el
        exec ${emacs}/bin/emacs --init-dir "$CACHE_DIR" --chdir $HOME "$@"
      '';
    in
    {
      packages.${system}.default = emacs;
      apps.${system}.default = {
        type = "app";
        program = "${emacsWrapper}/bin/emacs-wrapper";
      };
      devShell = pkgs.mkShell {
        buildInputs = [

            emacs
            pkgs.libvterm
            pkgs.tree-sitter
            pkgs.cmake
            pkgs.gnumake
            pkgs.gcc
            pkgs.libtool
            pkgs.R
            pkgs.php
            pkgs.copilot-language-server
        ] ++ iconFonts;


      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.python3
        ];
      };




    };
}
