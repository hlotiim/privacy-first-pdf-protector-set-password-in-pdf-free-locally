/*
 * PDFProtect engine - DOM-free wrapper around qpdf-wasm.
 *
 * Inlined into both the application and the test harness by build.ps1, so it
 * must stay free of DOM and jQuery references.
 */
var PDFProtect = (function () {
  "use strict";

  var factory = null;
  var wasmUrl = null;

  function configure(options) {
    factory = options.factory;
    wasmUrl = options.wasmUrl;
  }

  /*
   * Runs one qpdf invocation on a throwaway module instance.
   *
   * A fresh instance per call is deliberate: emscripten's exit bookkeeping and
   * qpdf's argv handling are not built for repeated callMain() on one module.
   *
   * qpdf writes diagnostics with console.log/console.error, which qpdf.js binds
   * during construction, so the interception has to be installed before the
   * factory runs.
   */
  function runQpdf(args, inputs) {
    var captured = [];
    var realLog = console.log;
    var realErr = console.error;

    function capture() {
      captured.push(Array.prototype.join.call(arguments, " "));
    }

    console.log = capture;
    console.error = capture;

    var restore = function () {
      console.log = realLog;
      console.error = realErr;
    };

    return factory({
      noInitialRun: true,
      locateFile: function () { return wasmUrl; }
    }).then(function (mod) {
      var code;
      try {
        Object.keys(inputs || {}).forEach(function (name) {
          mod.FS.writeFile(name, inputs[name]);
        });
        code = mod.callMain(args);
      } finally {
        restore();
      }

      var output = null;
      try {
        output = mod.FS.readFile("/out.pdf");
      } catch (e) {
        output = null;
      }

      return { code: code, messages: captured, output: output };
    }, function (err) {
      restore();
      throw err;
    });
  }

  var PRINT_LEVELS = { full: 1, low: 1, none: 1 };
  var MODIFY_LEVELS = { all: 1, annotate: 1, form: 1, assembly: 1, none: 1 };

  function yesNo(value) { return value ? "y" : "n"; }

  /*
   * Translates UI options into a qpdf argument vector.
   *
   * Passwords are passed as single argv elements (--user-password=<value>), so
   * a password may safely contain spaces, quotes or a leading dash.
   */
  function buildEncryptArgs(opts) {
    var userPassword = opts.userPassword || "";
    var ownerPassword = opts.ownerPassword == null ? userPassword : opts.ownerPassword;
    var bits = opts.bits || 256;
    var useAes = opts.useAes !== false;
    var args = [];

    if (opts.currentPassword) {
      args.push("--password=" + opts.currentPassword);
    }

    // Global option, so it has to precede the --encrypt ... -- block: qpdf
    // otherwise rejects it as an unrecognised encryption sub-option.
    if (bits === 128 && !useAes) {
      args.push("--allow-weak-crypto");
    }

    args.push("--encrypt");
    args.push("--user-password=" + userPassword);
    args.push("--owner-password=" + ownerPassword);
    args.push("--bits=" + bits);

    if (bits === 128) {
      args.push("--use-aes=" + yesNo(useAes));
    }

    var print = PRINT_LEVELS[opts.print] ? opts.print : "full";
    var modify = MODIFY_LEVELS[opts.modify] ? opts.modify : "all";
    args.push("--print=" + print);
    args.push("--modify=" + modify);
    args.push("--extract=" + yesNo(opts.extract !== false));

    // PDF 2.0 (R6) dropped the accessibility bit, so qpdf only honours this for
    // the older handlers; it is harmless to pass either way.
    args.push("--accessibility=" + yesNo(opts.accessibility !== false));

    // qpdf refuses an empty owner password unless the risk is acknowledged:
    // with no owner password every viewer can lift the restrictions.
    if (!ownerPassword) {
      args.push("--allow-insecure");
    }

    args.push("--");

    if (opts.optimize) {
      args.push("--object-streams=generate");
      args.push("--stream-data=compress");
    }

    args.push("/in.pdf", "/out.pdf");
    return args;
  }

  function joinMessages(messages) {
    return (messages || []).join("\n").replace(/^this\.program:\s*/gm, "").trim();
  }

  function needsPassword(text) {
    return /invalid password/i.test(text);
  }

  /*
   * Encrypts one PDF. Resolves with a result object rather than rejecting, so
   * a bad file in a batch does not abort the rest.
   *
   * qpdf exit codes: 0 success, 2 error, 3 success with warnings.
   */
  function encrypt(bytes, opts) {
    var args = buildEncryptArgs(opts);
    return runQpdf(args, { "/in.pdf": bytes }).then(function (res) {
      var text = joinMessages(res.messages);

      if (res.code === 0 || (res.code === 3 && res.output && res.output.length)) {
        return {
          ok: true,
          bytes: res.output,
          warnings: res.code === 3 ? text : "",
          args: args
        };
      }

      return {
        ok: false,
        error: text || ("qpdf exited with code " + res.code),
        needsPassword: needsPassword(text),
        args: args
      };
    }, function (err) {
      return {
        ok: false,
        error: String(err && err.message ? err.message : err),
        needsPassword: false,
        args: args
      };
    });
  }

  /* ---------- password helpers ---------- */

  var LOWER = "abcdefghijkmnopqrstuvwxyz";
  var UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  var DIGITS = "23456789";
  var SYMBOLS = "!@#$%^&*()-_=+[]{};:,.?";

  /*
   * Uniform random index via rejection sampling; the naive modulo of a random
   * byte would bias towards the start of the alphabet.
   */
  function randomIndex(limit) {
    var max = Math.floor(256 / limit) * limit;
    var buf = new Uint8Array(1);
    var value;
    do {
      crypto.getRandomValues(buf);
      value = buf[0];
    } while (value >= max);
    return value % limit;
  }

  function generatePassword(length, useSymbols) {
    var alphabet = LOWER + UPPER + DIGITS + (useSymbols === false ? "" : SYMBOLS);
    var out = "";
    for (var i = 0; i < length; i++) {
      out += alphabet.charAt(randomIndex(alphabet.length));
    }
    return out;
  }

  /*
   * Rough entropy estimate in bits, based on the character classes used and
   * discounted for obvious repetition or sequences. It is a guide, not a
   * substitute for a real password-strength library.
   */
  function estimateStrength(password) {
    if (!password) {
      return { bits: 0, label: "empty", level: 0 };
    }

    var pool = 0;
    if (/[a-z]/.test(password)) pool += 26;
    if (/[A-Z]/.test(password)) pool += 26;
    if (/[0-9]/.test(password)) pool += 10;
    if (/[^A-Za-z0-9]/.test(password)) pool += 33;

    var unique = {};
    for (var i = 0; i < password.length; i++) unique[password.charAt(i)] = 1;
    var uniqueCount = Object.keys(unique).length;

    // Repeating a small set of characters adds far less entropy than length
    // alone suggests, so score against the effective (unique) length.
    var effectiveLength = password.length * (uniqueCount / password.length);
    var bits = Math.log(pool || 1) / Math.log(2) * effectiveLength;

    if (/^(.)\1*$/.test(password)) bits = Math.min(bits, 8);
    if (/^(?:0123456789|1234567890|abcdefghij|qwertyuiop|password|letmein)/i.test(password)) {
      bits = Math.min(bits, 12);
    }

    bits = Math.round(bits);

    var level, label;
    if (bits < 28) { level = 1; label = "very weak"; }
    else if (bits < 45) { level = 2; label = "weak"; }
    else if (bits < 65) { level = 3; label = "reasonable"; }
    else if (bits < 90) { level = 4; label = "strong"; }
    else { level = 5; label = "very strong"; }

    return { bits: bits, label: label, level: level };
  }

  return {
    configure: configure,
    runQpdf: runQpdf,
    buildEncryptArgs: buildEncryptArgs,
    encrypt: encrypt,
    generatePassword: generatePassword,
    estimateStrength: estimateStrength
  };
})();
