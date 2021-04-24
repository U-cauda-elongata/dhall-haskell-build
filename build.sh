#!/usr/bin/env bash

set -o errexit -o xtrace

main() {
    local target="${1}"
    shift
    local packages=( "${@}" )

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
        stack build "${packages[@]}" --verbose --system-ghc --no-install-ghc --copy-bins --local-bin-path=bin

    if [ "${#packages[@]}" -eq 0 ]; then
        packages=(
            dhall
            dhall-json
            dhall-bash
            dhall-lsp-server
            dhall-nix
            dhall-openapi
            dhall-yaml
            dhall-docs
        )
    fi

    for package in "${packages[@]}"; do
        local assets=
        case "${package}" in
        dhall)
            mkdir -p share/man/man1
            cp dhall-haskell/dhall/man/dhall.1 share/man/man1/
            assets=( bin/dhall share/man/man1/dhall.1 )
            ;;
        dhall-docs)
            mkdir -p share/man/man1
            cp dhall-haskell/dhall-docs/src/Dhall/data/man/dhall-docs.1 share/man/man1/
            assets=( bin/dhall-docs share/man/man1/dhall-docs.1 )
            ;;
        *)
            IFS=$'\n'
            # shellcheck disable=SC2207
            assets=( $(grep -iPo '(?<=^Executable\s).*' "dhall-haskell/${package}/${package}.cabal" | sed 's!^ *!bin/!') )
            ;;
        esac

        local version=
        version="$(grep -iPo '(?<=^Version: ).*' "dhall-haskell/${package}/${package}.cabal" | sed 's/^ *//g')"

        tar -jcvf "dist/${package}-${version}-${target}.tar.bz2" "${assets[@]}"
    done
}

main "${@}"
