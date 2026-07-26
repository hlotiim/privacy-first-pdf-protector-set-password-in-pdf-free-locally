# PDF Protect

A single HTML file that adds a password to PDFs using **AES-256** encryption,
entirely on your own machine. No server, no upload, no cloud, no internet
connection required.

Open `pdf-protect.html` by double-clicking it. That's the whole tool.

## What it does

- **Real encryption.** Uses [qpdf](https://qpdf.sourceforge.io/) compiled to
  WebAssembly. The output is a genuinely encrypted PDF (AES-256, security
  handler R6) that no reader can open without the password.
- **Runs offline.** jQuery, the qpdf engine and the WebAssembly binary are all
  inlined into the one file. Nothing is fetched at runtime.
- **Enforced privacy.** The page ships a Content Security Policy of
  `default-src 'none'` with no network origin allowed, so the browser itself
  guarantees your files and passwords cannot be sent anywhere.
- **Batch processing** with per-file status and error reporting.
- **Password tools**: strength estimate, generator, show/hide, confirmation.
- **Permissions**: printing, editing and copying restrictions, with an optional
  separate owner password.
- **Handles locked input**: if a PDF is already protected, it asks for the
  current password and re-encrypts with the new one.

## A note on what the password protects

The open password is what actually secures the document — the contents are
encrypted and unreadable without it.

The printing, editing and copying settings are PDF *permission flags*. Compliant
readers respect them, but they are not an encryption boundary. If the owner
password is the same as the open password, anyone who can open the file can also
lift those restrictions. Set a different owner password under **Advanced
options** if the restrictions need to mean something.

There is no recovery. An AES-256 PDF whose password is lost is gone.

## Browser support

Tested on Chrome and Edge, opened directly from `file://`. Requires a browser
with WebAssembly and `crypto.getRandomValues`, which covers anything current.

## Building from source

The shipped `pdf-protect.html` is generated. To rebuild it after changing
`src/template.html` or `src/engine.js`:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

`build.ps1` inlines `vendor/jquery.min.js`, `vendor/qpdf.js`, `src/engine.js`
and a base64 copy of `vendor/qpdf.wasm` into the template.

The WebAssembly binary is handed to the loader as a `data:` URL. That detail is
what lets the tool work from `file://`, where a browser would refuse to fetch a
sibling `.wasm` file.

## Tests

```powershell
powershell -ExecutionPolicy Bypass -File run-tests.ps1
```

This runs 80 checks in headless Chrome:

- **Engine tests** (`tests/test-template.html`) cover qpdf argument
  construction, encryption round trips, wrong/missing password rejection,
  AES-128 and RC4 modes, permission enforcement, unicode passwords, re-encrypting
  protected files and the password helpers.
- **End-to-end tests** (`tests/smoke.js`) drive the real built page: file
  selection, password validation, the encrypt run, downloaded output, the
  already-encrypted and corrupt-input flows, and CSP compliance.

Both suites report their results through `document.title`, which the runner
reads over Chrome's DevTools HTTP endpoint.

To produce an encrypted file for inspection with outside tooling:

```powershell
powershell -ExecutionPolicy Bypass -File tests\export-encrypted.ps1
```

## Layout

| Path | Purpose |
| --- | --- |
| `pdf-protect.html` | The deliverable: open this |
| `src/template.html` | UI markup, styles and jQuery application code |
| `src/engine.js` | DOM-free wrapper around qpdf-wasm |
| `build.ps1` | Inlines everything into the single file |
| `run-tests.ps1` | Builds and runs both test suites |
| `vendor/` | jQuery and the qpdf WebAssembly build |
| `tests/` | Test harnesses, drivers and the sample PDF generator |

## Credits

- [qpdf](https://github.com/qpdf/qpdf) by Jay Berkenbilt, via the
  [`@neslinesli93/qpdf-wasm`](https://www.npmjs.com/package/@neslinesli93/qpdf-wasm)
  WebAssembly build
- [jQuery](https://jquery.com/) 3.7.1
