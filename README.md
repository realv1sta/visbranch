# visbranch

A pacman "repository" for Arch-based systems where the source of truth is
**PKGBUILDs**, not prebuilt `*.pkg.tar.zst` files.

Normally a custom repo serves binaries and pacman downloads them. visbranch
does the opposite: each package lives in `packages/<name>/PKGBUILD`, and a
small pacman shim builds it with `makepkg -si` the moment you ask pacman to
install it.

```console
$ pacman -S visbranch-test
visbranch: building visbranch-test from PKGBUILD
...
$ visbranch-test
test
```

## Why a shim?

pacman only understands binary repositories: it reads a `repo.db` and fetches
`.pkg.tar.*` files. It cannot run `makepkg` itself, so adding `[visbranch]` to
`/etc/pacman.conf` would not work. The shim at `/usr/local/bin/pacman` runs
before `/usr/bin/pacman` in `PATH` and is the "somehow":

| command | what happens |
| --- | --- |
| `pacman -S visbranch-test` | `makepkg -si` in `packages/visbranch-test` |
| `pacman -S visbranch-test firefox` | builds the first, real pacman installs the rest |
| `pacman -S firefox` | straight to real pacman |
| `pacman -Syu`, `-Ss`, `-R`, `-U`, ... | straight to real pacman |

Only `-S` (sync/install) is intercepted, and only when a target has a matching
`packages/<name>/PKGBUILD`. Anything the shim does not recognise is passed
through untouched to `/usr/bin/pacman`.

`makepkg` refuses to run as root, so when the shim is started with `sudo` it
re-runs the build as `$SUDO_USER`; the install step still goes through sudo.

## Layout

```
visbranch/
├── bin/pacman                  # the shim installed to /usr/local/bin/pacman
├── bin/visbranch               # helper: list / build / path / update
├── packages/
│   └── visbranch-test/
│       ├── PKGBUILD            # one directory per package
│       └── visbranch-test.sh   # installed as /usr/bin/visbranch-test
├── install.sh                  # install / --remove the shim
└── test.sh                     # prints "test"
```

## Install

```console
$ git clone https://github.com/realv1sta/visbranch
$ cd visbranch
$ sudo ./install.sh
```

The installer refuses to overwrite a `/usr/local/bin/pacman` it did not put
there, writes the checkout path to `/etc/visbranch.conf`, and prints a warning
if `/usr/local/bin` is not ahead of `/usr/bin` in `PATH`.

Then, as a normal user:

```console
$ pacman -S visbranch-test
$ visbranch-test
test
```

`sudo pacman -S visbranch-test` works too.

## Adding a package

```console
$ mkdir -p packages/foo
$ editor packages/foo/PKGBUILD
$ git add packages/foo/PKGBUILD
$ git commit -m "add foo" && git push
```

Then refresh the local checkout the shim reads from:

```console
$ visbranch update
$ visbranch list
$ pacman -S foo
```

Or build directly, without the shim:

```console
$ visbranch build foo
```

## Caveats

- This shadows pacman system-wide. That is invasive by design; back out with
  `sudo ./install.sh --remove`.
- Build leftovers (`src/`, `pkg/`, `*.pkg.tar.*`) are git-ignored. Never commit
  built packages — the PKGBUILD is the package.
- Query operations (`-Ss`, `-Si`) know nothing about unbuilt packages, because
  there is no repo database. Use `visbranch list`.
- `-Sw` (download only) has no meaning here and passes through to real pacman.
- Builds run with your user's `makepkg.conf`, so flags and `PKGDEST` apply as
  usual.
- Dependencies still come from your normal pacman repositories. If a dependency
  is itself PKGBUILD-backed, the shim handles the nested `pacman -S`.

## License

MIT — see [LICENSE](LICENSE).
