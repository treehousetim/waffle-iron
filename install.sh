#!/bin/bash
#
# install.sh — installs `iron`, the command that adds Waffle Iron modules to a
# Waffle app:
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/treehousetim/waffle-iron/main/install.sh)"
#
# Or download it, read it, then run it:
#
#   curl -fsSLO https://raw.githubusercontent.com/treehousetim/waffle-iron/main/install.sh
#   less install.sh && bash install.sh
#
# Options:
#   --to <dir>   install into <dir> instead of ~/.local/bin
#   --yes        do not ask (needed when there is no terminal)
#   -h, --help   this help
#
# `iron` holds no logic of its own. From anywhere inside a Waffle app it finds
# the app's root and runs that app's ./tools/module.sh with the same arguments,
# so `iron use short-links` is `./tools/module.sh use short-links`. Every check
# a module goes through lives there, versioned and tested with the app.
#
# This script needs no sudo and refuses to run as root, never overwrites an
# `iron` it did not write, and never edits a shell profile. Everything below
# is inside main(), called on the last line, so a download cut off partway
# runs nothing.
#
# Runs on macOS (its stock bash 3.2) and Linux, and on Windows inside WSL2.
# The numbers cite the failure list in tests/install-test.sh.

set -euo pipefail

# The line that marks an `iron` as one this script wrote, so it may replace it.
IRON_MARKER='# installed-by: waffle-iron install.sh'

# The half-written launcher, removed by the EXIT trap if the install fails.
IRON_TMP=''

die()  { printf 'error: %s\n' "$1" >&2; exit 1; }
say()  { printf '%s\n' "$1"; }

usage() {
    cat <<'USAGE'
Installs iron, the command that adds Waffle Iron modules to a Waffle app.

Usage: install.sh [--to <dir>] [--yes]

  --to <dir>   install into <dir> instead of ~/.local/bin
  --yes        do not ask (needed when there is no terminal)
  -h, --help   this help
USAGE
}

# The launcher, written verbatim (quoted heredoc: nothing in it is expanded here).
launcher() {
    cat <<'IRON'
#!/bin/bash
#
# iron — run this Waffle app's module command from anywhere inside the app.
#
#   iron use short-links      # = ./tools/module.sh use short-links, from the app's root
#   iron search               # every subcommand is the app's own
#
# The app is the nearest directory, walking up from here, that holds VERSION,
# AGENTS.md and composer.json. Its tools/module.sh does all the work; this
# only finds it. Use it in your own apps: it runs the module command of
# whichever project you are in, as `npm run` would.
#
# installed-by: waffle-iron install.sh
# Reinstall or update: https://github.com/treehousetim/waffle-iron#install-iron

set -euo pipefail

dir="$PWD"
while :; do
    if [ -f "$dir/VERSION" ] && [ -f "$dir/AGENTS.md" ] && [ -f "$dir/composer.json" ]; then
        if [ -x "$dir/tools/module.sh" ]; then
            printf 'iron: %s\n' "$dir" >&2
            exec "$dir/tools/module.sh" "$@"
        fi
        printf 'iron: %s is a Waffle app from before the module command.\n' "$dir" >&2
        printf 'Bring tools/module.sh in from Waffle (https://github.com/treehousetim/waffle) to use modules.\n' >&2
        exit 1
    fi
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
done

printf 'iron: not inside a Waffle app. cd into one and try again.\n' >&2
exit 1
IRON
}

main() {
    local to="" yes=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --to)      [ $# -ge 2 ] || die "--to needs a directory"; to="$2"; shift 2 ;;
            --to=*)    to="${1#--to=}"; shift ;;
            --yes|-y)  yes=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *)         die "unknown option: $1 (try --help)" ;;
        esac
    done

    # 1. Native Windows shells half-work; WSL2 is a real userland.
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) die "native Windows shells are not supported. Use WSL2: https://learn.microsoft.com/windows/wsl/install" ;;
    esac

    # 2. A per-user command needs no root, and root would write it where the user can't.
    if [ "$(id -u)" = "0" ]; then
        die "do not run this as root or with sudo; it installs into your own home directory"
    fi

    [ -n "${HOME:-}" ] || die "HOME is not set"
    local dir="${to:-$HOME/.local/bin}"
    case "$dir" in
        /*) ;;
        *)  dir="$PWD/$dir" ;;
    esac
    local target="$dir/iron"

    # 3, 4. Never replace an `iron` this script did not write.
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ] || ! grep -qxF "$IRON_MARKER" "$target" 2>/dev/null; then
            die "$target exists and was not installed by Waffle Iron; move it aside, or choose another directory with --to"
        fi
    fi

    # 5. Another `iron` earlier on the PATH would run instead of this one.
    local found
    found="$(command -v iron 2>/dev/null || true)"
    if [ -n "$found" ] && [ "$found" != "$target" ]; then
        die "another iron is on your PATH at $found and would run instead; remove it, or install over it with --to $(dirname "$found") if it is one this script wrote"
    fi

    say "This installs the iron command:"
    say "  $target"
    say "It runs the module command (tools/module.sh) of the Waffle app you are in."

    # 6, 7. Ask on a terminal; without one, only an explicit --yes proceeds.
    if [ "$yes" -ne 1 ]; then
        if [ -t 0 ]; then
            local answer
            printf 'Install it? [y/N] '
            read -r answer || answer=""
            case "$answer" in
                y|Y|yes|YES|Yes) ;;
                *) say "Nothing installed."; exit 1 ;;
            esac
        else
            die "no terminal to ask on; run again with --yes to install without asking"
        fi
    fi

    # 9. Write it whole, then move it into place, so a failure leaves no half file.
    mkdir -p "$dir"
    trap '[ -z "$IRON_TMP" ] || rm -f "$IRON_TMP"' EXIT
    IRON_TMP="$(mktemp "$dir/.iron.XXXXXX")"
    launcher > "$IRON_TMP"
    chmod 755 "$IRON_TMP"
    mv -f "$IRON_TMP" "$target"
    IRON_TMP=''

    say "Installed $target"

    # 10. Never edit a profile: say what to add instead.
    case ":${PATH:-}:" in
        *":$dir:"*) ;;
        *)
            say ""
            say "$dir is not on your PATH. Add it, then open a new terminal:"
            case "$(basename "${SHELL:-}")" in
                zsh)  say "  echo 'export PATH=\"$dir:\$PATH\"' >> ~/.zshrc" ;;
                bash) say "  echo 'export PATH=\"$dir:\$PATH\"' >> ~/.bashrc" ;;
                fish) say "  fish_add_path $dir" ;;
                *)    say "  export PATH=\"$dir:\$PATH\"   (in your shell's startup file)" ;;
            esac
            ;;
    esac

    say ""
    say "Then, from inside a Waffle app:  iron use <module>"
    say "Modules are listed at https://github.com/treehousetim/waffle-iron"
}

main "$@"
