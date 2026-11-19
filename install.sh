#!/usr/bin/env bash
# Install (or remove) the visbranch pacman shim.
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
BINDIR=/usr/local/bin
CONF=/etc/visbranch.conf
MARKER='# visbranch pacman shim'

usage() {
    cat <<EOF
usage: sudo ./install.sh [--yes]     install the shim
       sudo ./install.sh --remove    remove it
EOF
}

warn_path() {
    case ":$PATH:" in
        *":$BINDIR:"*) ;;
        *) printf 'warning: %s is not in PATH; the shim may not be used\n' "$BINDIR" >&2 ;;
    esac
}

remove() {
    rm -f "$CONF" "$BINDIR/visbranch"
    if [[ -f $BINDIR/pacman ]] && grep -qF "$MARKER" "$BINDIR/pacman"; then
        rm -f "$BINDIR/pacman"
    elif [[ -e $BINDIR/pacman ]]; then
        printf 'warning: %s/pacman was not installed by visbranch; leaving it alone\n' "$BINDIR" >&2
    fi
    printf 'visbranch shim removed; /usr/bin/pacman is untouched\n'
}

case ${1:-} in
    -h | --help)
        usage
        exit 0
        ;;
    --remove)
        if (( EUID != 0 )); then
            printf 'run with sudo: sudo ./install.sh --remove\n' >&2
            exit 1
        fi
        remove
        exit 0
        ;;
    "" | --yes) ;;
    *)
        usage >&2
        exit 1
        ;;
esac

if (( EUID != 0 )); then
    printf 'run with sudo: sudo ./install.sh\n' >&2
    exit 1
fi

if [[ ! -x /usr/bin/pacman ]]; then
    printf '/usr/bin/pacman not found; is this an Arch-based system?\n' >&2
    exit 1
fi

if [[ -e $BINDIR/pacman ]] && ! grep -qF "$MARKER" "$BINDIR/pacman"; then
    printf 'refusing to overwrite %s/pacman: it was not installed by visbranch\n' "$BINDIR" >&2
    exit 1
fi

if [[ ${1:-} != --yes ]]; then
    cat <<EOF
This installs a pacman shim at $BINDIR/pacman that shadows /usr/bin/pacman.

  pacman -S <name>   builds packages/<name> with makepkg -si when a
                     PKGBUILD exists, otherwise behaves like real pacman.

Remove it again with: sudo ./install.sh --remove
EOF
    read -r -p 'Continue? [y/N] ' answer
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || exit 1
fi

install -Dm755 "$REPO_DIR/bin/pacman" "$BINDIR/pacman"
install -Dm755 "$REPO_DIR/bin/visbranch" "$BINDIR/visbranch"

# Remember where the checkout lives so the shim can find packages/.
printf 'VISBRANCH_DIR=%q\n' "$REPO_DIR" >"$CONF"
chmod 644 "$CONF"

printf 'installed %s/pacman and %s/visbranch\n' "$BINDIR" "$BINDIR"
printf 'package source: %s/packages\n' "$REPO_DIR"
printf 'try: pacman -S visbranch-test\n'
warn_path
