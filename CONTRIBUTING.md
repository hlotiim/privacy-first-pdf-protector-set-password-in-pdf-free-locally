# Contributing to PDF Protect

Thanks for considering a contribution. Bug reports, encryption-correctness
fixes, and browser-compatibility reports are especially valuable.

## Ground rules

This project has one hard constraint that shapes every decision:

> **Nothing may leave the user's device.** No network request, no telemetry, no
> analytics, no remote font, no CDN, no error reporting.

A change that breaks this will be declined regardless of how useful it is
otherwise. The Content-Security-Policy (`default-src 'none'`) enforces it in the
browser, and the end-to-end suites assert that no policy violation ever occurs,
so such a change will fail the tests as well as review.

Two consequences worth knowing before you start:

- **No build toolchain.** There is no npm, bundler, or transpiler. Dependencies
  are vendored in `vendor/` and inlined by `build.ps1`. Please do not introduce a
  package manager — the deliverable is one auditable HTML file.
- **The single file must stay single.** Anything the offline build needs has to
  be embeddable, which is why the wasm binary ships as a base64 data URI.

## Getting set up

You need Windows PowerShell and either Chrome or Edge. Nothing else.

```powershell
# Build both targets and run every suite
powershell -ExecutionPolicy Bypass -File run-tests.ps1
```

That regenerates the sample PDF, builds the single file and the hosted page, and
runs all three suites. It should end with `ALL TESTS PASSED`.

To build without testing:

```powershell
# Single offline file -> pdf-protect.html
powershell -ExecutionPolicy Bypass -File build.ps1

# Hosted page -> docs/index.html + docs/assets/
powershell -ExecutionPolicy Bypass -File build.ps1 -Mode hosted -Output docs\index.html
```

## Where to make a change

Edit the sources, never the generated artifacts:

| Change | Edit |
| --- | --- |
| UI, layout, copy, page metadata | `src/template.html` |
| Encryption logic, qpdf arguments, password strength | `src/engine.js` |
| Inlining, CSP, hosted vs single differences | `build.ps1` |
| Tests | `tests/` |

`pdf-protect.html` and `docs/` are **build outputs**. They are committed so the
tool can be downloaded and hosted without a build step, but a pull request that
edits them by hand will conflict with the next rebuild. Run `run-tests.ps1`,
which regenerates both, and commit the result as part of your change so the
published page never drifts from `src/`.

## Tests

The suites run in a real headless browser, because the thing being tested is
browser behaviour:

- **`tests/test-template.html`** — exercises the `PDFProtect` engine directly:
  argument construction, encryption round trips, wrong-password handling, and
  each encryption level.
- **`tests/smoke.js`** — drives the actual built page from `file://` the way a
  user would: dropping files, typing passwords, clicking through.
- **`tests/run-hosted-tests.ps1`** — serves the hosted build over real HTTP and
  runs the same smoke test, since that build fetches the wasm binary rather than
  inlining it.

Please add coverage for behaviour you change. If you touch anything that affects
the encrypted output, add an assertion against real qpdf output rather than
against an internal flag — the whole point is that the resulting file is
genuinely encrypted.

## Style

Match the surrounding code. Briefly:

- jQuery for DOM work, plain ES5-compatible JavaScript elsewhere. No frameworks.
- Comments explain *why* — a constraint, a trade-off, a surprising browser
  behaviour. Skip comments that restate the code.
- Keep the vendored files in `vendor/` unmodified so they can be diffed against
  upstream. Note the qpdf version in `vendor/qpdf.package.json` if you update it.

## Pull requests

1. Confirm `run-tests.ps1` passes and the regenerated artifacts are committed.
2. Describe what changed and why, and note any new behaviour a user would see.
3. Keep it focused. A formatting sweep mixed into a logic fix is hard to review.

## Reporting bugs

Open an [issue](https://github.com/hlotiim/privacy-first-pdf-protector-set-password-in-pdf-free-locally/issues)
with your browser and version, the encryption mode used, and the steps to
reproduce. **Never attach a confidential PDF** — reproduce with a harmless file.

Found something that weakens encryption or sends data off the device? Report it
privately instead: see [`SECURITY.md`](SECURITY.md).
