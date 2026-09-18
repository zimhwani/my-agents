/* Guest guide behaviour: section pills, search, copy buttons, checklist, save hint */
(function () {
  "use strict";
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* Active pill by scroll position */
  var pills = Array.prototype.slice.call(document.querySelectorAll(".manual-nav a"));
  var sections = pills.map(function (a) { return document.querySelector(a.getAttribute("href")); }).filter(Boolean);
  function setActive(id) {
    pills.forEach(function (a) {
      var on = a.getAttribute("href") === "#" + id;
      a.classList.toggle("is-active", on);
      if (on) {
        a.setAttribute("aria-current", "true");
        // Scroll the pill row only (never the page): scrollIntoView on a sticky child would cancel an in-flight page scroll.
        var row = a.closest("ul");
        if (row) row.scrollTo({ left: a.offsetLeft - (row.clientWidth - a.offsetWidth) / 2, behavior: reduceMotion ? "auto" : "smooth" });
      }
      else a.removeAttribute("aria-current");
    });
  }
  if ("IntersectionObserver" in window && sections.length) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) setActive(en.target.id); });
    }, { rootMargin: "-40% 0px -55% 0px", threshold: 0 });
    sections.forEach(function (s) { io.observe(s); });
  }
  pills.forEach(function (a) { a.addEventListener("click", function () { var t = document.querySelector(a.getAttribute("href")); if (t) t.querySelectorAll("details").forEach(function (d) { d.open = true; }); }); });

  /* Open the card named in the URL hash */
  function openHash() {
    if (!location.hash) return;
    var t = document.querySelector(location.hash); if (!t) return;
    var det = t.closest("details") || t.querySelector("details"); if (det) det.open = true;
  }
  window.addEventListener("hashchange", openHash); openHash();

  /* Search */
  var q = document.getElementById("guide-search");
  var empty = document.getElementById("guide-empty");
  var cards = Array.prototype.slice.call(document.querySelectorAll(".mcard"));
  var timer;
  if (q) {
    q.addEventListener("input", function () {
      clearTimeout(timer);
      timer = setTimeout(function () {
        var term = q.value.trim().toLowerCase(); var hits = 0;
        cards.forEach(function (c) {
          var match = !term || c.textContent.toLowerCase().indexOf(term) > -1;
          c.hidden = !match; if (match) hits++;
          if (term && match) { var d = c.closest("details"); if (d) d.open = true; }
        });
        sections.forEach(function (s) { var visible = s.querySelectorAll(".mcard:not([hidden])").length; s.hidden = term ? visible === 0 : false; });
        if (empty) empty.hidden = !(term && hits === 0);
        var st = document.getElementById("search-status"); if (st) st.textContent = term ? hits + (hits === 1 ? " card matches" : " cards match") : "";
      }, 150);
    });
  }

  /* Copy buttons */
  var live = document.getElementById("copy-live");
  document.querySelectorAll("[data-copy]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");
      var done = function () {
        var orig = btn.textContent; btn.textContent = "Copied"; if (live) live.textContent = "Copied to clipboard";
        setTimeout(function () { btn.textContent = orig; if (live) live.textContent = ""; }, 1500);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback); else fallback();
      function fallback() {
        var ta = document.createElement("textarea"); ta.value = text; ta.setAttribute("readonly", ""); ta.style.position = "absolute"; ta.style.left = "-9999px";
        document.body.appendChild(ta); ta.select(); try { document.execCommand("copy"); done(); } catch (e) {} document.body.removeChild(ta);
      }
    });
  });

  /* Checkout checklist persisted per device */
  var KEY = "pamusha-checkout";
  var saved = {}; try { saved = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) {}
  document.querySelectorAll(".checklist input[type=checkbox]").forEach(function (cb) {
    if (saved[cb.id]) cb.checked = true;
    cb.addEventListener("change", function () { saved[cb.id] = cb.checked; try { localStorage.setItem(KEY, JSON.stringify(saved)); } catch (e) {} });
  });
  var done = document.querySelector(".checklist__done"), boxes = document.querySelectorAll(".checklist input[type=checkbox]");
  function checkDone() {
    if (!done) return;
    var all = boxes.length && Array.prototype.every.call(boxes, function (b) { return b.checked; });
    if (all && done.hidden) { done.hidden = false; done.textContent = done.getAttribute("data-text"); }
    else if (!all && !done.hidden) { done.hidden = true; done.textContent = ""; }
  }
  boxes.forEach(function (b) { b.addEventListener("change", checkDone); }); checkDone();
  var reset = document.getElementById("checklist-reset");
  if (reset) reset.addEventListener("click", function () { saved = {}; try { localStorage.removeItem(KEY); } catch (e) {} document.querySelectorAll(".checklist input").forEach(function (cb) { cb.checked = false; }); checkDone(); });

  /* Save-to-home-screen hint */
  var hint = document.getElementById("save-hint");
  if (hint) {
    var dismissed = false; try { dismissed = localStorage.getItem("pamusha-hint") === "1"; } catch (e) {}
    var standalone = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone;
    if (dismissed || standalone) hint.hidden = true;
    else {
      var ios = /iPhone|iPad|iPod/.test(navigator.userAgent);
      hint.querySelector("[data-hint-text]").textContent = ios ? "Tap Share, then “Add to Home Screen” to keep this guide handy." : "Open your browser menu and choose “Add to Home screen” to keep this guide handy.";
      hint.querySelector("[data-hint-dismiss]").addEventListener("click", function () { hint.hidden = true; try { localStorage.setItem("pamusha-hint", "1"); } catch (e) {} });
    }
  }
})();
