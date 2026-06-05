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
        export PATH="${pkgs.dmd}/bin:$PATH"
        export PATH="${pkgs.php}/bin:$PATH"
        export PATH="${pkgs.cargo}/bin:$PATH"
        export PATH="${pkgs.rustc}/bin:$PATH"
        export PATH="${pkgs.rust-script}/bin:$PATH"
        export FONTCONFIG_FILE="${fontConfig}"
        cd "$CACHE_DIR"
        ${emacs}/bin/emacs --batch -l ./tangle-script.el
        exec ${emacs}/bin/emacs --init-dir "$CACHE_DIR" --chdir $HOME "$@"
      '';
      dotnetSdk =
        if pkgs ? dotnet-sdk_10 then pkgs.dotnet-sdk_10
        else if pkgs ? dotnet-sdk then pkgs.dotnet-sdk
        else null;

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
            pkgs.dmd
            pkgs.php
            pkgs.copilot-language-server
        ] ++ iconFonts;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.dmd
          pkgs.crystal
          pkgs.gfortran
          pkgs.go
          pkgs.nodejs
          pkgs.python3
          pkgs.ruby
          pkgs.cargo
          pkgs.ocaml
          pkgs.tcl
          pkgs.guile
          pkgs.rustc
          pkgs.rust-script
          pkgs.lua
          pkgs.php
        ] ++ pkgs.lib.optionals (pkgs ? dotnet-sdk_10) [ pkgs.dotnet-sdk_10 ]
          ++ pkgs.lib.optionals (pkgs ? mono) [ pkgs.mono ]
          ++ pkgs.lib.optionals (pkgs ? dotnet-repl) [ pkgs.dotnet-repl ];
        shellHook = ''
            ${pkgs.lib.optionalString (dotnetSdk != null) ''
              export DOTNET_ROOT="${dotnetSdk}/share/dotnet"
              export DOTNET_ROOT_X64="$DOTNET_ROOT"
              export PATH="$DOTNET_ROOT''${PATH:+:}$PATH"
            ''}
        '';
      };
    };
}
