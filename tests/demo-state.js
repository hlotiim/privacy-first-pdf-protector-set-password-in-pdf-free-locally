/* Drives the UI into a populated state so a screenshot can be reviewed. */
(function () {
  "use strict";

  var SAMPLE_B64 = "__SAMPLE_PDF_B64__";

  function b64ToBytes(b64) {
    var bin = atob(b64);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  jQuery(function ($) {
    var bytes = b64ToBytes(SAMPLE_B64);
    var dt = new DataTransfer();
    dt.items.add(new File([bytes], "quarterly-report.pdf", { type: "application/pdf" }));
    dt.items.add(new File([bytes], "client-contract.pdf", { type: "application/pdf" }));
    dt.items.add(new File([bytes], "medical-records.pdf", { type: "application/pdf" }));

    var picker = document.getElementById("picker");
    picker.files = dt.files;
    $(picker).trigger("change");

    $("#pw").val("Tr0ubad0ur-Anchor-Mist").trigger("input");
    $("#pw2").val("Tr0ubad0ur-Anchor-Mist").trigger("input");
    $("#advToggle").click();
    $("#print").val("low");
    $("#modify").val("none");
    $("#extract").prop("checked", false);
    $("#protect").click();

    var timer = setInterval(function () {
      if ($("#results").hasClass("show")) {
        clearInterval(timer);
        document.title = "RESULT|demo state ready";
      }
    }, 100);
  });
})();
