## What does this change?

<!-- What changed, and why. Link any issue it closes: Closes #123 -->

## How was it verified?

<!--
Which suites did you run, and what did you check by hand? If the encrypted
output changed at all, say how you confirmed the result is still genuinely
encrypted and still opens with the password.
-->

## Checklist

- [ ] `powershell -ExecutionPolicy Bypass -File run-tests.ps1` ends with `ALL TESTS PASSED`
- [ ] I edited the sources (`src/`, `build.ps1`), not the generated `pdf-protect.html` or `docs/`
- [ ] Regenerated `pdf-protect.html` and `docs/` are committed, so the published page matches `src/`
- [ ] Tests cover the behaviour I changed
- [ ] No network request, telemetry, CDN, remote font, or external dependency was introduced
- [ ] The tool still works with no internet connection at all

## Anything reviewers should look at closely?

<!-- Trade-offs you made, alternatives you rejected, or areas you are unsure about. -->
