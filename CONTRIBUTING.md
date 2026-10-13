# Adding a module to Waffle Iron

A module is listed by a pull request that changes two files: an entry in
`index.json`, and a row in the table in `README.md`. A person reads the module
before merging. A module is a set of instructions an agent will follow inside
someone's app, so nothing is listed that nobody has read.

## Before you open the pull request

1. **Write the module** to Waffle's
   [`docs/modules.md`](https://github.com/treehousetim/waffle/blob/main/docs/modules.md):
   `MODULE.md` and `MODULE-TEST.md`, and optionally `reference/` and `tests/`.
2. **Run the format check.** Copy the module into `modules/` in a checkout of
   Waffle and run `./tools/test.sh tests/Unit/ModulesTest.php`. It must pass.
3. **Publish the files where they will stay.** A public Git repository is
   best: the entry pins a commit, so later pushes never change what was
   reviewed. A `.zip` or a single `.module.md` needs a URL that will always
   serve the same bytes.
4. **Hash them** the way the README's [Hashing](README.md#hashing) section
   says, from the pinned commit, not from your working copy.

## The pull request

- **A new module:** add it under `modules` in `index.json` with one version,
  and add its row to the README table.
- **A new version:** add the version under the module's `versions`, and
  update the README row. Do not edit the earlier version. Its `MODULE.md`
  should say under **Upgrading** what the new version changes for an
  installed app.
- **A proof:** add the Waffle version to that version's `proven-on`, and link
  the E2E artifact from the run in the pull request.

Leave `reviewed-by` as `null`. The reviewer fills it in. Fill in the pull
request checklist; it is the reviewer's list too.

## What the reviewer checks

The reviewer reads the module at the pinned commit, all of it, and checks:

1. **The entry matches the files.** The hash is right, and `name`, `title`,
   `summary`, `author`, `license`, `waffle` and `proven-on` match the front
   matter.
2. **The format check passes.**
3. **Nothing in it asks for what Waffle's `AGENTS.md` forbids:** a library
   that is not on the approved list, a secret with a default or in a file, a
   route without a permission, a skipped or weakened test.
4. **No step reaches the network,** reads a secret, touches Doppler, GitHub or
   the server, or runs a command it does not explain.
5. **The data model follows `AGENTS.md` §6,** and migrations only add.
6. **Every failure is covered** by at least one desired outcome, and the tests
   described would really prove them.
7. **Shipped `tests/` and `reference/` agree** with `MODULE.md`, and contain
   nothing beyond what it describes.
8. **The claims are true:** a `proven-on` entry has its E2E artifact.

Then the reviewer sets `reviewed-by` to their GitHub username, sets `listed`
to the merge date, and merges.

## Taking a version back

If a listed version turns out to be harmful or broken, add
`"yanked": "<one line saying why>"` to it, and say so in the README row. Agents
skip yanked versions. Entries are never deleted, so an app's `modules.json`
always points at something that can be looked up.
