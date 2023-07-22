{ pkgs ? import <nixpkgs> {}
}:

let
  inherit (pkgs)
    lib
    curl
  ;

  flashrom = pkgs.callPackage (
    { stdenv
    , lib
    , fetchgit
    , pkg-config
    , meson
    , ninja
    , cmocka
    , libftdi1
    , libusb1
    , pciutils
    }:

    stdenv.mkDerivation rec {
      pname = "flashrom-cros";
      version = "R110-15278.B";

      src = fetchgit {
        url = "https://chromium.googlesource.com/chromiumos/third_party/flashrom";
        rev = "bc6a1b933141acd74951f4992b7fcb9d8b060e12";
        hash = "sha256-GsUuASmLkEXPU9d2eyBpoXTo33MvQQ6trGvTiIJeNv0=";
      };

      nativeBuildInputs = [
        pkg-config meson ninja
      ] ++ checkInputs;

      buildInputs = [
        libftdi1 libusb1 pciutils
      ];

      checkInputs = [
        cmocka
      ];
    }
  ) {};

  scripts = pkgs.callPackage (
    { stdenv
    , fetchFromGitHub
    , coreutils
    , flashrom
    }:
    stdenv.mkDerivation {
      pname = "mrchromebox-firmware-utility-scripts";
      version = "4.20.1";
      src = fetchFromGitHub {
        owner = "MrChromebox";
        repo = "scripts";
        rev = "c65756062eeeda59ca2e2dce12740cb73c73d655";
        hash = "sha256-JguI7JEUgjReNreMGyWm8COTUBM15gYe12TauYwxSUA=";
      };
      patchPhase = ''
        sed -i -e 's;\s*flashromcmd=.*/flashrom\s*$;true;' functions.sh
        sed -i -e 's;\s*cbfstoolcmd=.*/cbfstool\s*$;true;' functions.sh
        sed -i -e 's;\s*gbbutilitycmd=.*/gbb_utility\s*$;true;' functions.sh

        for f in *.sh; do
        substituteInPlace functions.sh \
          --replace 'flashromcmd=""' 'flashromcmd="${flashrom}/bin/flashrom"' \
          --replace 'cbfstoolcmd=""' 'cbfstoolcmd="${coreutils}/bin/true"' \
          --replace 'gbbutilitycmd=""' 'gbbutilitycmd="${coreutils}/bin/true"' \
          --replace '/tmp' '"$TMPDIR"'
        done
      '';
      dontBuild = true;
      installPhase = ''
        mv -v "$PWD" "$out"
      '';
    }
  ) {
    inherit flashrom;
  };

  wrapper = pkgs.writeShellScript "mrchromebox-firmware-util" ''
    PATH="${lib.makeBinPath (with pkgs; [
      dmidecode
    ])}:$PATH"

    echo ""
    echo ""
    echo "DO NOT report bugs with MrChromebox when using this script."
    echo "**I will get angry!**"
    echo ""
    echo ""

    TMPDIR="$(mktemp 'mrchromebox-firmware-utility.XXXXXXXXXX')"
    mkdir -p "$TMPDIR"

    CURL="${curl}/bin/curl"

    pushd "${scripts}"
    source ./sources.sh  
    source ./firmware.sh 
    source ./functions.sh
    popd

    prelim_setup || exit 1
    menu_fwupdate
  '';
in
  wrapper
