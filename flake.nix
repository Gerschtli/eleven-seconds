{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forEachSystem = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ];

      nodejsFor = system: nixpkgs.legacyPackages.${system}.nodejs_24;
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            nodejs = nodejsFor system;
          in
          {
            default = pkgs.mkShell {
              packages = [
                nodejs
                pkgs.pnpm
              ];
            };
          });

      checks = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            nodejs = nodejsFor system;

            inherit (pkgs.lib) getExe versions;

            checker = name: description: package: versionCommand: pkgs.runCommand "check-${name}-version" { } ''
              version_nix="${package.version}"
              version_non_nix="$(${versionCommand})"

              echo "compare versions for ${description}"
              echo "version_nix:     $version_nix"
              echo "version_non_nix: $version_non_nix"

              [[ "$version_nix" == "$version_non_nix" ]]
              touch $out
            '';
          in
          {
            node = checker
              "node"
              "node major version in package.json"
              { version = versions.major nodejs.version; }
              ''
                ${getExe pkgs.jq} --raw-output '.engines.node' ${./package.json} \
                  | ${getExe pkgs.gnused} -e 's,\.x$,,'
              '';

            pnpm = checker "pnpm" "pnpm version in package.json" pkgs.pnpm ''
              ${getExe pkgs.jq} --raw-output '.packageManager' ${./package.json} \
                | ${getExe pkgs.gnused} -e 's,^pnpm@,,'
            '';
          });
    };
}
