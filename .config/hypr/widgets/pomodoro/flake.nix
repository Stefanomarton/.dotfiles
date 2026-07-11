{
  description = "Pomodoro timer widget for Hyprland using QuickShell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            quickshell
            qt6.qtbase
            qt6.qtdeclarative
          ];

          shellHook = ''
            echo "Pomodoro Widget Development Shell"
            echo "Run: quickshell -p ."
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "pomodoro-widget";
          version = "1.0.0";
          src = ./.;

          installPhase = ''
            mkdir -p $out/share/quickshell/pomodoro
            cp -r *.qml $out/share/quickshell/pomodoro/
            cp -r components $out/share/quickshell/pomodoro/ 2>/dev/null || true

            mkdir -p $out/bin
            cat > $out/bin/pomodoro-widget << EOF
            #!/usr/bin/env bash
            exec ${pkgs.quickshell}/bin/quickshell -p $out/share/quickshell/pomodoro "\$@"
            EOF
            chmod +x $out/bin/pomodoro-widget
          '';

          meta = {
            description = "Pomodoro timer overlay widget for Hyprland";
            mainProgram = "pomodoro-widget";
          };
        };
      }
    );
}
