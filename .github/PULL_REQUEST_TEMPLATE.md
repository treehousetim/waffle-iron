**Module:** <!-- name and version -->
**Change:** <!-- new module / new version / proof / yank -->
**Source:** <!-- repository URL and commit, or file URL -->

### Author

- [ ] The files follow Waffle's `docs/modules.md`, and `./tools/test.sh tests/Unit/ModulesTest.php` passes with them in `modules/`.
- [ ] `sha256` was computed from the pinned commit, the way the README's Hashing section says.
- [ ] The entry's fields match the module's front matter.
- [ ] `reviewed-by` is `null`.
- [ ] For a proof: the E2E artifact is linked below.

### Reviewer (CONTRIBUTING.md, "What the reviewer checks")

- [ ] Read as raw text from a fresh clone; the commit is on one of the repository's own branches.
- [ ] 1. Entry matches the files, the hash checks out, and the diff touches only this entry.
- [ ] 2. Format check passes; the name is not a near-copy of a listed one.
- [ ] 3. Nothing AGENTS.md forbids: libraries, secrets, unprotected routes, weakened tests.
- [ ] 4. No step reaches the network, secrets, Doppler, GitHub or the server.
- [ ] 5. Data model follows AGENTS.md §6; migrations only add.
- [ ] 6. Every failure is covered by an outcome.
- [ ] 7. `tests/` and `reference/` agree with MODULE.md.
- [ ] 8. `proven-on` claims have artifacts.
- [ ] 9. Nothing hidden: no symlinks, odd file names, unexplained HTML comments or non-ASCII characters.
- [ ] `reviewed-by` and `listed` filled in.
