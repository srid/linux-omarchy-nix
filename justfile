default:
    @just --list

# Bump the omarchy-pkgs input and rewrite sources.nix to match its PKGBUILD
# (kernel version + kernel.org tarball hash). Patches and config are read from
# the input at build time, so nothing else needs touching.
update:
    ./update.sh

# Build the kernel.
build:
    nix build .#linux-omarchy -L

# What is pinned, and what the input's PKGBUILD says.
status:
    #!/usr/bin/env bash
    set -euo pipefail
    src=$(nix eval --raw --impure --expr 'let f = builtins.getFlake (toString ./.); in f.inputs.omarchy-pkgs.outPath')
    echo "omarchy-pkgs rev:  $(jq -r '.nodes."omarchy-pkgs".locked.rev' flake.lock | cut -c1-12)"
    echo "input pkgver:      $(sed -n 's/^pkgver=//p' "$src/pkgbuilds/linux-omarchy/PKGBUILD" | head -1)"
    echo "pinned in sources: $(sed -n 's/.*version = "\(.*\)";/\1/p' sources.nix)"
