/*
 * End-to-end test driver for the built application.
 *
 * Appended to a throwaway copy of pdf-protect.html by build.ps1 -Append, so it
 * exercises the real UI, the real CSP and the real qpdf build. Results are
 * published through document.title for tests\run-tests.ps1 to read.
 */
(function () {
  "use strict";

  var SAMPLE_B64 = "__SAMPLE_PDF_B64__";

  var lines = [];
  var pass = 0;
  var fail = 0;
  var violations = [];

  document.addEventListener("securitypolicyviolation", function (e) {
    violations.push(e.violatedDirective + " blocked " + e.blockedURI);
  });

  function log(text) { lines.push(text); }

  function check(name, condition, extra) {
    if (condition) { pass++; log("PASS  " + name); }
    else { fail++; log("FAIL  " + name + (extra ? "  :: " + extra : "")); }
  }

  function b64ToBytes(b64) {
    var bin = atob(b64);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function bytesToLatin1(bytes) {
    var s = "", chunk = 0x8000;
    for (var i = 0; i < bytes.length; i += chunk) {
      s += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return s;
  }

  function sleep(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  function waitFor(label, predicate, timeoutMs) {
    var deadline = Date.now() + (timeoutMs || 30000);
    return (function attempt() {
      if (predicate()) return Promise.resolve(true);
      if (Date.now() > deadline) {
        log("TIMEOUT waiting for " + label);
        return Promise.resolve(false);
      }
      return sleep(100).then(attempt);
    })();
  }

  function attachFiles(fileList) {
    var picker = document.getElementById("picker");
    var dt = new DataTransfer();
    fileList.forEach(function (f) { dt.items.add(f); });
    picker.files = dt.files;
    jQuery(picker).trigger("change");
  }

  function makeFile(bytes, name) {
    return new File([bytes], name, { type: "application/pdf" });
  }

  function typePassword(pw) {
    jQuery("#pw").val(pw).trigger("input");
    jQuery("#pw2").val(pw).trigger("input");
  }

  // Intercepts the Blob the app hands to the browser for download, so the
  // produced file can be inspected without touching the filesystem.
  function captureDownload($button) {
    return new Promise(function (resolve, reject) {
      var original = URL.createObjectURL;
      var timer = setTimeout(function () {
        URL.createObjectURL = original;
        reject(new Error("no object URL was created"));
      }, 5000);

      URL.createObjectURL = function (blob) {
        clearTimeout(timer);
        URL.createObjectURL = original;
        var reader = new FileReader();
        reader.onload = function () { resolve(new Uint8Array(reader.result)); };
        reader.onerror = function () { reject(reader.error); };
        reader.readAsArrayBuffer(blob);
        return original.call(URL, blob);
      };

      $button.click();
    });
  }

  jQuery(async function ($) {
    try {
      var sample = b64ToBytes(SAMPLE_B64);

      /* ---------- initial state ---------- */

      check("protect button starts disabled", $("#protect").is(":disabled"));
      check("results panel starts hidden", !$("#results").hasClass("show"));

      /* ---------- file selection ---------- */

      attachFiles([makeFile(sample, "sample.pdf")]);
      check("selected file appears in the list", $("#files li").length === 1,
        $("#files li").length + " rows");
      check("file name is shown", $("#files .fname").text() === "sample.pdf");
      check("protect stays disabled without a password", $("#protect").is(":disabled"));

      /* ---------- password validation ---------- */

      $("#pw").val("secret").trigger("input");
      $("#pw2").val("different").trigger("input");
      check("mismatch warning shows", $("#mismatch").is(":visible"));
      check("protect blocked while passwords differ", $("#protect").is(":disabled"));

      typePassword("Correct-Horse-Battery-7");
      check("mismatch warning clears", !$("#mismatch").is(":visible"));
      check("protect enabled once input is valid", !$("#protect").is(":disabled"));
      check("strength meter reports on the password",
        /Estimated strength/.test($("#meterText").text()), $("#meterText").text());

      /* ---------- generator and visibility toggle ---------- */

      $("#togglePw").click();
      check("show button reveals the password", $("#pw").attr("type") === "text");
      $("#togglePw").click();
      check("hide button masks it again", $("#pw").attr("type") === "password");

      $("#genPw").click();
      var generated = $("#pw").val();
      check("generator fills both fields", generated.length === 20 && $("#pw2").val() === generated,
        generated);
      check("generated password is rated very strong",
        /very strong/.test($("#meterText").text()), $("#meterText").text());

      typePassword("Correct-Horse-Battery-7");

      /* ---------- encrypt ---------- */

      $("#protect").click();
      var finished = await waitFor("encryption to finish", function () {
        return $("#results").hasClass("show");
      }, 60000);
      check("run completes", finished);

      check("file is marked protected", $("#files .status").hasClass("done"),
        $("#files .status").text());
      check("summary reports one success", /1 file protected/.test($("#summary").text()),
        $("#summary").text());
      check("a download button is offered", $("#files .download").length === 1);

      /* ---------- inspect the produced file ---------- */

      var out = await captureDownload($("#files .download"));
      var text = bytesToLatin1(out);
      check("download is a PDF", text.indexOf("%PDF-") === 0);
      check("download is encrypted", text.indexOf("/Encrypt") !== -1);
      check("download hides the original content", text.indexOf("Hello PDF") === -1);

      var verify = await PDFProtect.runQpdf(
        ["--show-encryption", "--password=Correct-Horse-Battery-7", "/in.pdf"],
        { "/in.pdf": out });
      var info = verify.messages.join(" ");
      check("produced file really is AES-256", /R = 6/.test(info) && /AESv3/.test(info), info);

      /* ---------- already-encrypted input ---------- */

      $("#reset").click();
      check("reset clears the file list", $("#files li").length === 0);
      check("reset clears the password", $("#pw").val() === "");

      attachFiles([makeFile(out, "already-locked.pdf")]);
      typePassword("another-password");
      $("#protect").click();

      await waitFor("second run to finish", function () {
        return $("#results").hasClass("show");
      }, 60000);

      check("locked input is flagged, not silently failed",
        $("#files .status").hasClass("locked"), $("#files .status").text());
      check("locked input explains what to do",
        /already password protected/i.test($("#files .errmsg").text()),
        $("#files .errmsg").text());
      check("an unlock field is offered", $("#files .curpw").length === 1);

      /* ---------- supplying the existing password ---------- */

      $("#files .curpw").val("Correct-Horse-Battery-7").trigger("input");
      $("#protect").click();

      await waitFor("third run to finish", function () {
        return $("#results").hasClass("show") && !$("#files .status").hasClass("working");
      }, 60000);

      check("re-encryption succeeds with the current password",
        $("#files .status").hasClass("done"),
        $("#files .status").text() + " / " + $("#files .errmsg").text());

      var out2 = await captureDownload($("#files .download"));
      var reopen = await PDFProtect.runQpdf(
        ["--password=another-password", "--decrypt", "/in.pdf", "/out.pdf"],
        { "/in.pdf": out2 });
      check("re-encrypted file opens with the new password", reopen.code === 0,
        reopen.messages.join(" "));

      /* ---------- non-pdf input ---------- */

      $("#reset").click();
      attachFiles([makeFile(new Uint8Array([1, 2, 3, 4, 5]), "broken.pdf")]);
      typePassword("whatever-password");
      $("#protect").click();

      await waitFor("failure run to finish", function () {
        return $("#results").hasClass("show");
      }, 60000);

      check("corrupt input is reported as failed", $("#files .status").hasClass("error"),
        $("#files .status").text());
      check("corrupt input shows a reason", $("#files .errmsg").text().length > 0);
      check("summary counts the failure", /1 file failed/.test($("#summary").text()),
        $("#summary").text());

      /* ---------- policy ---------- */

      check("no content security policy violations", violations.length === 0,
        violations.join("; "));

    } catch (err) {
      fail++;
      log("EXCEPTION " + (err && err.stack ? err.stack : err));
    }

    log("---- pass=" + pass + " fail=" + fail);
    document.title = "RESULT|" + lines.join(" || ");
  });
})();
