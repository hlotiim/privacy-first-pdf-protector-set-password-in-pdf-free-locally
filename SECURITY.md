# Security Policy

PDF Protect encrypts documents, so a defect here can expose a file its owner
believed was protected. Reports are welcome and taken seriously.

## Reporting a vulnerability

Please report privately rather than opening a public issue:

1. Use GitHub's [private vulnerability
   reporting](https://github.com/hlotiim/privacy-first-pdf-protector-set-password-in-pdf-free-locally/security/advisories/new)
   on this repository. This creates a draft advisory only you and the maintainer
   can see.
2. If that is unavailable, contact the maintainer through
   [roktimsaha.com](https://roktimsaha.com).

Please include the browser and version, the encryption mode selected, and the
steps to reproduce. A sample PDF helps if the bug is input-dependent — send a
harmless one, never a confidential document.

You can expect an acknowledgement within seven days. Anything that weakens
encryption or leaks a file or password off the device is treated as urgent.

## What counts as a vulnerability

In scope, and treated as a security bug:

- A file reported as protected that is readable without the password, or that is
  encrypted more weakly than the selected mode claims.
- Any transmission of a document, a password, or a derivative of either off the
  device — including telemetry, analytics, or an unexpected network request.
- A password persisting somewhere it should not, such as the URL, browser
  storage, or a cached form value after a reset.
- A bypass of the Content-Security-Policy that permits a network request.
- Any path where an incorrect password produces a silently corrupt output rather
  than an error.

Out of scope, because they are properties of the PDF standard rather than bugs
in this tool:

- **Guessing a weak password.** The encryption key is derived from the password,
  so a short or common password can be attacked offline. Use the generator.
- **Permission flags being ignored.** Printing, editing and copying
  restrictions are instructions a reader may honour or disregard; only the open
  password enforces anything. This is documented behaviour.
- **Recovering a document whose password was lost.** There is no backdoor by
  design.
- **Reading a file already open on the device**, or malware and browser
  extensions on the machine doing the encryption. Anything with that level of
  access has already won.
- Vulnerabilities in upstream qpdf itself. Report those to
  [qpdf](https://github.com/qpdf/qpdf/security); mention them here if this
  project needs to ship an updated build.

## Supported versions

The latest commit on `main`, plus the most recent
[release](https://github.com/hlotiim/privacy-first-pdf-protector-set-password-in-pdf-free-locally/releases),
receive fixes. Older downloaded copies are not patched — the tool is a single
file, so update by downloading the current one.

Note that a copy saved locally keeps working offline forever, which is a
deliberate feature. It also means a copy from before a security fix stays
vulnerable. If a fix is ever needed for the encryption path, it will be called
out prominently in the release notes.

## How the guarantees are verified

The claims are checked mechanically on every push rather than asserted:

- Encryption round trips are tested against real qpdf output, including that the
  correct password opens the file and a wrong one fails.
- The shipped file is scanned for any remote resource reference, and for the
  restrictive `default-src 'none'` policy.
- The published build is compared against its source so a stale artifact cannot
  ship.

See [`README.md`](README.md#security-notes-and-threat-model) for the full threat model,
and run `powershell -ExecutionPolicy Bypass -File run-tests.ps1` to reproduce
the suites yourself. You can also verify the no-upload behaviour directly: open
your browser's Network tab and encrypt a file.
