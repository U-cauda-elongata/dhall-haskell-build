#!/usr/bin/env bash

set -o errexit -o xtrace

main() {
    local target="${1}"

    local platform=
    case "${target}" in
    aarch64-*)
        platform=linux/arm64/v8
        ;;
    arm-*)
        platform=linux/arm/v7
        ;;
    powerpc64le-*)
        platform=linux/ppc64le
        ;;
    s390x-*)
        platform=linux/s390x
        ;;
    x86-64-*)
        platform=linux/amd64
        ;;
    *)
        echo "Unknown target: ${target}"
        exit 1
        ;;
    esac

    cd "$(dirname "${0}")"
    mkdir -p .stack bin dist

    docker run --userns=host --user="${UID}":"$(id -g "${USER}")" --rm \
        --platform="${platform}" \
        --volume="$(pwd)/dhall-haskell":/build:Z \
        --volume="$(pwd)/bin":/build/bin:Z \
        --volume="$(pwd)/.stack":/.stack \
        --workdir=/build \
        ghcr.io/u-cauda-elongata/haskell:latest \
        stack build --verbose --system-ghc --no-install-ghc --copy-bins --local-bin-path=bin

    mkdir -p share/man/man1
    cp dhall-haskell/dhall/man/dhall.1 share/man/man1/
    cp dhall-haskell/dhall-docs/src/Dhall/data/man/dhall-docs.1 share/man/man1/

    get_cabal_version() {
        grep -iPo '(?<=^Version: ).*' "dhall-haskell/$1/$1.cabal" | sed 's/^ *//'
    }
    mk_release_name() {
        echo "dist/$1-$(get_cabal_version "$1")-$2.tar.bz2"
    }

    tar -jcvf "$(mk_release_name dhall "${target}")" bin/dhall share/man/man1/dhall.1
    tar -jcvf "$(mk_release_name dhall-json "${target}")" bin/dhall-to-json bin/dhall-to-yaml bin/json-to-dhall
    tar -jcvf "$(mk_release_name dhall-bash "${target}")" bin/dhall-to-bash
    tar -jcvf "$(mk_release_name dhall-lsp-server "${target}")" bin/dhall-lsp-server
    tar -jcvf "$(mk_release_name dhall-nix "${target}")" bin/dhall-to-nix
    tar -jcvf "$(mk_release_name dhall-openapi "${target}")" bin/openapi-to-dhall
    tar -jcvf "$(mk_release_name dhall-yaml "${target}")" bin/dhall-to-yaml-ng bin/yaml-to-dhall
    tar -jcvf "$(mk_release_name dhall-docs "${target}")" bin/dhall-docs share/man/man1/dhall-docs.1
}

main "${@}"
