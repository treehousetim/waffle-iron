#!/bin/bash
#
# tests/install-test.sh — the tests for install.sh and the `iron` it writes.
#
#   bash tests/install-test.sh
#
# Runs in a scratch HOME with a bare PATH, so it never touches your own
# ~/.local/bin or finds your own `iron`. Plain bash 3.2 and POSIX tools, like
# the installer. GitHub Actions runs it on macOS and Linux for every pull
# request (.github/workflows/test.yml).
#
# Failure list. Each test names the numbers it proves.
#
#  1. Run on a native Windows shell → refused, pointing at WSL2.
#  2. Run as root or with sudo → refused.
#  3. An `iron` exists that this script did not write (a file or a symlink) → refused, left untouched.
#  4. An `iron` this script wrote earlier → replaced, which is how iron is updated.
#  5. Another `iron` comes earlier on the PATH → refused, naming it.
#  6. No terminal and no --yes → refused, nothing written.
#  7. The owner answers no → nothing written. (Needs a terminal; checked by hand.)
#  8. The download is cut off partway → nothing runs, nothing written.
#  9. Writing fails → no half-written file left behind.
# 10. The directory is not on the PATH → says what to add; no profile is edited.
# 11. An unknown option → refused.
# 12. Run as `bash -c "$(curl …)"`, where $0 is not the script → help and install still work.
# 13. `iron` outside a Waffle app → says so, exit 1.
# 14. `iron` deep inside an app → runs the app root's tools/module.sh with the arguments unchanged
#     (spaces, quotes, $, globs).
# 15. A parent directory holds a stray tools/module.sh but is not an app → not treated as one.
# 16. The nearest app predates tools/module.sh → says so, and never walks on to an outer app.
# 17. `iron` prints which app it is acting on before handing over.
# 18. tools/module.sh's exit code is iron's exit code.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$HERE/install.sh"

SCRATCH="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/iron-test.XXXXXX")" && pwd -P)"
trap 'chmod -R u+w "$SCRATCH" 2>/dev/null; rm -rf "$SCRATCH"' EXIT

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/      /'; }

# A fresh HOME, and a PATH with only the system and a shim directory.
fresh() {
    rm -rf "$SCRATCH/home" "$SCRATCH/shims"
    mkdir -p "$SCRATCH/home" "$SCRATCH/shims"
    export HOME="$SCRATCH/home"
    export PATH="$SCRATCH/shims:/usr/bin:/bin"
    export SHELL=/bin/zsh
}

# A shim that replaces a system command for one test.
shim() {
    printf '#!/bin/bash\n%s\n' "$2" > "$SCRATCH/shims/$1"
    chmod 755 "$SCRATCH/shims/$1"
}

# Runs the installer without a terminal; output in $OUT, status in $STATUS.
run_install() {
    OUT="$(bash "$INSTALL" "$@" </dev/null 2>&1)"
    STATUS=$?
}

contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

IRON_DIR_DEFAULT() { printf '%s/.local/bin' "$HOME"; }

# ---------------------------------------------------------------------------
# The installer
# ---------------------------------------------------------------------------

fresh
shim uname 'echo MINGW64_NT-10.0'
run_install --yes
if [ $STATUS -ne 0 ] && contains "$OUT" "WSL2" && [ ! -e "$(IRON_DIR_DEFAULT)/iron" ]; then
    pass "refuses a native Windows shell (1)"
else
    fail "refuses a native Windows shell (1)" "$OUT"
fi

fresh
shim id 'echo 0'
run_install --yes
if [ $STATUS -ne 0 ] && contains "$OUT" "root" && [ ! -e "$(IRON_DIR_DEFAULT)/iron" ]; then
    pass "refuses root (2)"
else
    fail "refuses root (2)" "$OUT"
fi

fresh
mkdir -p "$(IRON_DIR_DEFAULT)"
printf '#!/bin/sh\necho someone else\n' > "$(IRON_DIR_DEFAULT)/iron"
run_install --yes
if [ $STATUS -ne 0 ] && contains "$OUT" "not installed by Waffle Iron" \
    && [ "$(cat "$(IRON_DIR_DEFAULT)/iron")" = "$(printf '#!/bin/sh\necho someone else')" ]; then
    pass "refuses to replace a file it did not write, and leaves it alone (3)"
else
    fail "refuses to replace a file it did not write, and leaves it alone (3)" "$OUT"
fi

fresh
mkdir -p "$(IRON_DIR_DEFAULT)" "$SCRATCH/home/elsewhere"
printf '#!/bin/sh\n# installed-by: waffle-iron install.sh\n' > "$SCRATCH/home/elsewhere/real"
ln -s "$SCRATCH/home/elsewhere/real" "$(IRON_DIR_DEFAULT)/iron"
run_install --yes
if [ $STATUS -ne 0 ] && [ -L "$(IRON_DIR_DEFAULT)/iron" ]; then
    pass "refuses to replace a symlink, even to a file carrying the marker (3)"
else
    fail "refuses to replace a symlink, even to a file carrying the marker (3)" "$OUT"
fi

fresh
run_install --yes
first=$STATUS
printf '\n# an older copy\n' >> "$(IRON_DIR_DEFAULT)/iron"
run_install --yes
if [ $first -eq 0 ] && [ $STATUS -eq 0 ] && ! grep -q 'an older copy' "$(IRON_DIR_DEFAULT)/iron"; then
    pass "replaces an iron it wrote earlier (4)"
else
    fail "replaces an iron it wrote earlier (4)" "$OUT"
fi

fresh
printf '#!/bin/sh\n' > "$SCRATCH/shims/iron"; chmod 755 "$SCRATCH/shims/iron"
run_install --yes
if [ $STATUS -ne 0 ] && contains "$OUT" "$SCRATCH/shims/iron" && [ ! -e "$(IRON_DIR_DEFAULT)/iron" ]; then
    pass "refuses when another iron is earlier on the PATH, naming it (5)"
else
    fail "refuses when another iron is earlier on the PATH, naming it (5)" "$OUT"
fi

fresh
run_install
if [ $STATUS -ne 0 ] && contains "$OUT" "--yes" && [ ! -e "$(IRON_DIR_DEFAULT)/iron" ]; then
    pass "without a terminal, refuses unless given --yes (6)"
else
    fail "without a terminal, refuses unless given --yes (6)" "$OUT"
fi

fresh
total="$(wc -l < "$INSTALL")"
head -n $((total - 1)) "$INSTALL" > "$SCRATCH/cut-at-end.sh"
head -n $((total / 2)) "$INSTALL" > "$SCRATCH/cut-in-middle.sh"
out_end="$(bash "$SCRATCH/cut-at-end.sh" --yes </dev/null 2>&1)"
out_mid="$(bash "$SCRATCH/cut-in-middle.sh" --yes </dev/null 2>&1)"
if [ ! -e "$(IRON_DIR_DEFAULT)/iron" ] && ! contains "$out_end" "Installed" && ! contains "$out_mid" "Installed" \
    && ! contains "$out_end$out_mid" "This installs"; then
    pass "a download cut off partway runs nothing (8)"
else
    fail "a download cut off partway runs nothing (8)" "$out_end$out_mid"
fi

fresh
mkdir -p "$SCRATCH/home/locked"
chmod 555 "$SCRATCH/home/locked"
run_install --yes --to "$SCRATCH/home/locked"
leftover="$(ls -A "$SCRATCH/home/locked")"
chmod 755 "$SCRATCH/home/locked"
if [ $STATUS -ne 0 ] && [ -z "$leftover" ]; then
    pass "a write that fails leaves nothing behind (9)"
else
    fail "a write that fails leaves nothing behind (9)" "$OUT${leftover:+ / left: $leftover}"
fi

fresh
run_install --yes
if [ $STATUS -eq 0 ] && contains "$OUT" "is not on your PATH" && contains "$OUT" "~/.zshrc" \
    && [ -z "$(ls -A "$HOME" | grep -v '^\.local$')" ]; then
    pass "off the PATH: says what to add and edits no profile (10)"
else
    fail "off the PATH: says what to add and edits no profile (10)" "$OUT"
fi

fresh
export PATH="$(IRON_DIR_DEFAULT):$PATH"
run_install --yes
if [ $STATUS -eq 0 ] && ! contains "$OUT" "not on your PATH"; then
    pass "on the PATH: says nothing about it (10)"
else
    fail "on the PATH: says nothing about it (10)" "$OUT"
fi

fresh
run_install --bogus
if [ $STATUS -ne 0 ] && contains "$OUT" "unknown option"; then
    pass "refuses an unknown option (11)"
else
    fail "refuses an unknown option (11)" "$OUT"
fi

fresh
help="$(bash -c "$(cat "$INSTALL")" -- --help </dev/null 2>&1)"
OUT="$(bash -c "$(cat "$INSTALL")" -- --yes </dev/null 2>&1)"; STATUS=$?
if contains "$help" "Usage: install.sh" && [ $STATUS -eq 0 ] && [ -x "$(IRON_DIR_DEFAULT)/iron" ]; then
    pass "works as bash -c \"\$(curl …)\": help and install (12)"
else
    fail "works as bash -c \"\$(curl …)\": help and install (12)" "$help$OUT"
fi

# ---------------------------------------------------------------------------
# The launcher it writes
# ---------------------------------------------------------------------------

fresh
run_install --yes
IRON="$(IRON_DIR_DEFAULT)/iron"

# app/ is a Waffle app whose tools/module.sh prints each argument on its own
# line and exits 7.
make_app() {
    mkdir -p "$1/tools" "$1/src/app/deep"
    touch "$1/VERSION" "$1/AGENTS.md" "$1/composer.json"
    printf '#!/bin/bash\nfor a in "$@"; do printf "arg:%%s\\n" "$a"; done\nexit 7\n' > "$1/tools/module.sh"
    chmod 755 "$1/tools/module.sh"
}

mkdir -p "$SCRATCH/nowhere"
out="$(cd "$SCRATCH/nowhere" && "$IRON" use short-links 2>&1)"; status=$?
if [ $status -eq 1 ] && contains "$out" "not inside a Waffle app"; then
    pass "outside an app: says so, exit 1 (13)"
else
    fail "outside an app: says so, exit 1 (13)" "$out"
fi

make_app "$SCRATCH/app"
stdout="$(cd "$SCRATCH/app/src/app/deep" && "$IRON" use 'two words' '$HOME' '*' "it's" 2>"$SCRATCH/stderr")"; status=$?
expected="$(printf 'arg:use\narg:two words\narg:$HOME\narg:*\narg:it'"'"'s')"
if [ "$stdout" = "$expected" ]; then
    pass "deep inside an app: runs the root's module command, arguments unchanged (14)"
else
    fail "deep inside an app: runs the root's module command, arguments unchanged (14)" "$stdout"
fi
if contains "$(cat "$SCRATCH/stderr")" "iron: $SCRATCH/app"; then
    pass "says which app it is acting on (17)"
else
    fail "says which app it is acting on (17)" "$(cat "$SCRATCH/stderr")"
fi
if [ $status -eq 7 ]; then
    pass "passes the module command's exit code through (18)"
else
    fail "passes the module command's exit code through (18)" "status $status"
fi

mkdir -p "$SCRATCH/stray/tools" "$SCRATCH/stray/inner"
printf '#!/bin/bash\necho STRAY\n' > "$SCRATCH/stray/tools/module.sh"; chmod 755 "$SCRATCH/stray/tools/module.sh"
out="$(cd "$SCRATCH/stray/inner" && "$IRON" use x 2>&1)"; status=$?
if [ $status -eq 1 ] && ! contains "$out" "STRAY" && contains "$out" "not inside a Waffle app"; then
    pass "a stray tools/module.sh without the app's files is not an app (15)"
else
    fail "a stray tools/module.sh without the app's files is not an app (15)" "$out"
fi

make_app "$SCRATCH/outer"
mkdir -p "$SCRATCH/outer/old/sub"
touch "$SCRATCH/outer/old/VERSION" "$SCRATCH/outer/old/AGENTS.md" "$SCRATCH/outer/old/composer.json"
out="$(cd "$SCRATCH/outer/old/sub" && "$IRON" use x 2>&1)"; status=$?
if [ $status -eq 1 ] && contains "$out" "before the module command" && ! contains "$out" "arg:"; then
    pass "an app from before tools/module.sh: says so, never walks on to an outer app (16)"
else
    fail "an app from before tools/module.sh: says so, never walks on to an outer app (16)" "$out"
fi

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
