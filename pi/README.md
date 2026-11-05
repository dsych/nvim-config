# Personal pi extensions

`agent/extensions/ctx-inspect/index.ts` customizes the context-mode tool previews.
It does not install or replace the `npm:context-mode` package.

`agent/extensions/kagi-assistant/` adds Kagi Assistant models as a pi provider; see
its [README](agent/extensions/kagi-assistant/README.md).

Run the repository's `install.sh` to link each extension into
`~/.pi/agent/extensions`. The installer leaves other extensions, settings,
keybindings, credentials and sessions alone. It links the `ctx-inspect/`
extension directory and retires the old flat `ctx-inspect.ts` entry point.
Conflicting entries are backed up under `~/.pi/agent/extension-backups`,
outside auto-discovery so a backed-up directory cannot load twice. Existing
backups are never overwritten. Correct links are unchanged on subsequent installs.

The renderer was moved from `Dsych-config/pi`; that repository no longer
installs it. The context-mode cancellation patch remains in Dsych-config and
has its own package-version requirements.

After installing, run `/reload` in existing pi sessions. New sessions discover
the linked extension automatically.

## Tests

Point `PI_PACKAGE_ROOT` at the installed pi-coding-agent package, then run from
this repository's root:

```sh
PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent \
  node --test pi/tests/ctx-inspect.test.mjs pi/tests/kagi-assistant-stream.test.mjs
node --test pi/tests/kagi-assistant.test.mjs
python3 tests/test-install.py
```

Installer tests use a disposable HOME and stub dependency installers; they
never alter the real configuration or install software.
