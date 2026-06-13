{
  description = "Unofficial configuration tool for EGG XM2 and OP1 8k gaming mice";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      mkPackage =
        pkgs:
        let
          imguiSrc = pkgs.fetchFromGitHub {
            owner = "ocornut";
            repo = "imgui";
            rev = "aa23f3801b7414989093abf7388144bc4dfd221c";
            sha256 = "05q8jvlrj7z0b11plcjhq4yn7qdfbvw5h1lb8abbkswl6idrjrin";
          };
        in
        pkgs.stdenv.mkDerivation {
          pname = "egg-mouse-config";
          version = "unstable-2026-06-13";
          src = self;
          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
          ];

          buildInputs = with pkgs; [
            glfw
            libGL
            freetype
            hidapi
          ];

          postPatch = ''
            rm -rf imgui
            cp -r ${imguiSrc} imgui
            chmod -R u+w imgui
          '';

          # imgui's CMakeLists hardcodes /usr/include/freetype2; point it at nixpkgs.
          NIX_CFLAGS_COMPILE = "-I${pkgs.freetype.dev}/include/freetype2";
          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
          ];

          meta = with pkgs.lib; {
            description = "Unofficial configuration tool for EGG XM2 and OP1 8k gaming mice";
            homepage = "https://github.com/niansa/UnofficialEGGMouseConfig";
            license = licenses.gpl3Only;
            platforms = platforms.linux;
            mainProgram = "EGGMouseConfig";
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        eggMouseConfig = mkPackage pkgs;
      in
      {
        packages = {
          default = eggMouseConfig;
          egg-mouse-config = eggMouseConfig;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ eggMouseConfig ];
          packages = with pkgs; [ git ];
        };
      }
    )
    // {
      overlays.default = final: _: {
        egg-mouse-config = mkPackage final;
      };

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.egg-mouse-config;
        in
        {
          options.programs.egg-mouse-config = {
            enable = lib.mkEnableOption "the unofficial EGG mouse configuration tool";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = lib.literalExpression "egg-mouse-config.packages.\${system}.default";
              description = "The egg-mouse-config package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

            # Grant the locally logged-in user access to EGG mice (vendor 0x3367)
            # via systemd-logind's uaccess, so the GUI runs without root.
            services.udev.extraRules = ''
              SUBSYSTEM=="usb", ATTRS{idVendor}=="3367", MODE="0660", TAG+="uaccess"
              SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3367", MODE="0660", TAG+="uaccess"
            '';
          };
        };
    };
}
