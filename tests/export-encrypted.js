/*
 * Encrypts the sample PDF through the shipped app's engine and publishes the
 * result as base64 in document.title, so the runner can write it to disk and
 * verify it against tooling outside the browser.
 */
(function () {
  "use strict";

  var SAMPLE_B64 = "__SAMPLE_PDF_B64__";

  function b64ToBytes(b64) {
    var bin = atob(b64);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function bytesToB64(bytes) {
    var s = "", chunk = 0x8000;
    for (var i = 0; i < bytes.length; i += chunk) {
      s += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return btoa(s);
  }

  jQuery(async function () {
    try {
      var res = await PDFProtect.encrypt(b64ToBytes(SAMPLE_B64), {
        userPassword: "test-password-123",
        ownerPassword: "owner-password-456",
        print: "none",
        extract: false
      });

      document.title = res.ok
        ? "RESULT|" + bytesToB64(res.bytes)
        : "RESULT|ERROR " + res.error;
    } catch (err) {
      document.title = "RESULT|ERROR " + err;
    }
  });
})();
