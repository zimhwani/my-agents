/* Pamusha Lake House — shared behaviour (no dependencies) */
(function () {
  "use strict";

  /* ---- Owner settings ------------------------------------------------ */
  // Airbnb listing for Pamusha Lake House.
  var AIRBNB_URL = "https://www.airbnb.com.au/rooms/641000176994899769";
  // TODO(owner): free key from web3forms.com (enquiry form). Leave blank to fall back to a mailto: link.
  var WEB3FORMS_KEY = "";
  var ENQUIRY_EMAIL = ""; // TODO(owner): your email, used as a mailto: fallback when WEB3FORMS_KEY is blank

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---- Airbnb links ---------------------------------------------------- */
  document.querySelectorAll('[data-cta="airbnb"]').forEach(function (a) {
    var u = AIRBNB_URL + (AIRBNB_URL.indexOf("?") > -1 ? "&" : "?") + "utm_source=pamusha-site&utm_medium=web&utm_campaign=direct";
    a.setAttribute("href", u);
    a.setAttribute("target", "_blank");
    a.setAttribute("rel", "noopener");
  });

  document.querySelectorAll('a[target="_blank"]').forEach(function (a) {
    if (a.querySelector(".new-tab")) return;
    var s = document.createElement("span"); s.className = "visually-hidden new-tab"; s.textContent = " (opens in a new tab)"; a.appendChild(s);
  });

  /* ---- Header state ---------------------------------------------------- */
  var header = document.querySelector(".site-header");
  var bookBar = document.querySelector(".book-bar");
  var vh = window.innerHeight, scrolled = null, barShown = null;
  window.addEventListener("resize", function () { vh = window.innerHeight; }, { passive: true });
  function onScroll() {
    var y = window.scrollY;
    var s = y > 40; if (header && s !== scrolled) { header.classList.toggle("is-scrolled", s); scrolled = s; }
    var b = y > vh * 0.6; if (bookBar && b !== barShown) { bookBar.classList.toggle("is-visible", b); barShown = b; }
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---- Mobile nav ------------------------------------------------------ */
  var toggle = document.querySelector(".nav__toggle");
  var links = document.querySelector(".nav__links");
  if (toggle && links) {
    var mainEl = document.getElementById("main"), footerEl = document.querySelector(".site-footer");
    function setMenu(open) {
      toggle.setAttribute("aria-expanded", String(open));
      links.classList.toggle("is-open", open);
      document.body.style.overflow = open ? "hidden" : "";
      if (open && header) header.classList.add("is-scrolled");
      [mainEl, footerEl].forEach(function (el) { if (el) { if (open) el.setAttribute("inert", ""); else el.removeAttribute("inert"); } });
      if (open) { var first = links.querySelector("a"); if (first) first.focus(); } else { toggle.focus(); }
    }
    toggle.addEventListener("click", function () { setMenu(toggle.getAttribute("aria-expanded") !== "true"); });
    links.querySelectorAll("a").forEach(function (a) {
      a.addEventListener("click", function () { if (links.classList.contains("is-open")) { setMenu(false); } });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && links.classList.contains("is-open")) setMenu(false);
    });
    window.matchMedia("(min-width: 56.01rem)").addEventListener("change", function (m) { if (m.matches && links.classList.contains("is-open")) setMenu(false); });
  }

  /* ---- Placeholder art (shown until the owner's photos exist) ---------- */
  var SCENES = {
    dusk:     { sky: ["#E9B58A", "#C98C7A", "#3B4A5E", "#1C2430"], water: ["#4B5C70", "#1C2430"], horizon: 0.62, stars: 40 },
    night:    { sky: ["#2C3646", "#1A2230", "#0F141B"], water: ["#1C2633", "#0F141B"], horizon: 0.66, stars: 160 },
    lake:     { sky: ["#DCE6EA", "#B9CCD3", "#8FA7B1"], water: ["#9FB4BB", "#6F8A93"], horizon: 0.55, stars: 0 },
    dawn:     { sky: ["#F4E3D0", "#E8C3A5", "#BFC9CE"], water: ["#C9D3D6", "#93A6AC"], horizon: 0.6, stars: 0, steam: true },
    bush:     { sky: ["#EFE7DA", "#D9D7C4"], water: ["#8C9C86", "#4F6150"], horizon: 0.5, stars: 0, trees: true },
    beach:    { sky: ["#EAF0F2", "#C9DCE3"], water: ["#8FB2BD", "#5E8A98", "#E8DCC8"], horizon: 0.52, stars: 0, surf: true },
    interior: { sky: ["#F2EADF", "#E4D7C5"], water: ["#C9B99F", "#9B8666"], horizon: 0.7, stars: 0, room: true },
    bed:      { sky: ["#F4EEE5", "#E8DED0"], water: ["#D2C3AE", "#A8967C"], horizon: 0.68, stars: 0, room: true },
    bath:     { sky: ["#EEF0EE", "#DCE2DF"], water: ["#C1CBC6", "#8FA39B"], horizon: 0.72, stars: 0, room: true },
    kitchen:  { sky: ["#F3EEE6", "#E7DFD2"], water: ["#CDBFA9", "#8C7A5F"], horizon: 0.66, stars: 0, room: true },
    tub:      { sky: ["#E7A97E", "#8E6F78", "#2C3646"], water: ["#3C4B5B", "#1C2430"], horizon: 0.6, stars: 60, steam: true },
    fire:     { sky: ["#2A2F3A", "#1A1E27"], water: ["#3A2E26", "#1A1512"], horizon: 0.7, stars: 90, embers: true },
    map:      { sky: ["#E6E1D6", "#DDD6C8"], water: ["#B9C7CB", "#9FB1B7"], horizon: 0.5, stars: 0, mapLines: true },
    portrait: { sky: ["#EFE5D6", "#DACBB4"], water: ["#B7C2B1", "#8B9B86"], horizon: 0.75, stars: 0 }
  };
  var seed = 7;
  function rnd() { seed = (seed * 9301 + 49297) % 233280; return seed / 233280; }
  function grad(id, stops, x2, y2) {
    var s = stops.map(function (c, i) { return '<stop offset="' + (i / (stops.length - 1)) + '" stop-color="' + c + '"/>'; }).join("");
    return '<linearGradient id="' + id + '" x1="0" y1="0" x2="' + (x2 || 0) + '" y2="' + (y2 == null ? 1 : y2) + '">' + s + "</linearGradient>";
  }
  function artSVG(name, i) {
    var s = SCENES[name] || SCENES.lake;
    var W = 800, H = 800, hy = Math.round(H * s.horizon);
    var id = "g" + name + i;
    var out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + W + " " + H + '" preserveAspectRatio="xMidYMid slice" aria-hidden="true">'];
    out.push("<defs>" + grad(id + "s", s.sky) + grad(id + "w", s.water) + '<filter id="' + id + 'b"><feGaussianBlur stdDeviation="18"/></filter></defs>');
    out.push('<rect width="' + W + '" height="' + hy + '" fill="url(#' + id + 's)"/>');
    out.push('<rect y="' + hy + '" width="' + W + '" height="' + (H - hy) + '" fill="url(#' + id + 'w)"/>');
    // stars
    for (var k = 0; k < s.stars; k++) {
      out.push('<circle cx="' + (rnd() * W).toFixed(0) + '" cy="' + (rnd() * hy * 0.9).toFixed(0) + '" r="' + (0.6 + rnd() * 1.4).toFixed(1) + '" fill="#F6F1E9" opacity="' + (0.3 + rnd() * 0.7).toFixed(2) + '"/>');
    }
    // soft sun/moon glow
    if (!s.room && !s.mapLines) {
      out.push('<ellipse cx="' + (W * 0.62) + '" cy="' + (hy - 10) + '" rx="220" ry="60" fill="' + s.sky[0] + '" opacity="0.35" filter="url(#' + id + 'b)"/>');
    }
    // trees / dune silhouette
    if (s.trees || name === "dusk" || name === "night" || name === "lake" || name === "tub" || name === "dawn") {
      var pts = ["0," + hy];
      for (var x = 0; x <= W; x += 40) { pts.push(x + "," + (hy - 8 - rnd() * (s.trees ? 90 : 34))); }
      pts.push(W + "," + hy);
      out.push('<polygon points="' + pts.join(" ") + '" fill="#1C2430" opacity="' + (s.trees ? 0.55 : 0.75) + '"/>');
    }
    if (s.surf) {
      for (var w = 0; w < 5; w++) {
        var y = hy + 30 + w * 55;
        out.push('<path d="M0 ' + y + ' Q 100 ' + (y - 12) + ' 200 ' + y + ' T 400 ' + y + ' T 600 ' + y + ' T 800 ' + y + '" stroke="#F6F1E9" stroke-width="2" fill="none" opacity="' + (0.5 - w * 0.08) + '"/>');
      }
      out.push('<rect y="' + (H - 140) + '" width="' + W + '" height="140" fill="#E8DCC8"/>');
    }
    // reflections / ripples
    if (!s.room && !s.surf && !s.mapLines) {
      for (var r = 0; r < 9; r++) {
        var ry = hy + 20 + r * ((H - hy) / 10);
        var rw = 120 + rnd() * 300, rx = W * 0.3 + rnd() * W * 0.3;
        out.push('<path d="M' + (rx - rw / 2) + " " + ry + " C " + (rx - rw / 4) + " " + (ry - 4) + ", " + (rx + rw / 4) + " " + (ry + 4) + ", " + (rx + rw / 2) + " " + ry + '" stroke="#F6F1E9" stroke-width="1.2" fill="none" opacity="' + (0.35 - r * 0.03).toFixed(2) + '"/>');
      }
    }
    if (s.steam) {
      for (var t = 0; t < 4; t++) {
        var sx = W * 0.35 + t * 70;
        out.push('<path d="M' + sx + " " + (hy + 60) + " C " + (sx + 20) + " " + (hy) + ", " + (sx - 20) + " " + (hy - 60) + ", " + sx + " " + (hy - 130) + '" stroke="#F6F1E9" stroke-width="14" stroke-linecap="round" fill="none" opacity="0.18" filter="url(#' + id + 'b)"/>');
      }
    }
    if (s.embers) {
      out.push('<ellipse cx="400" cy="' + (hy + 90) + '" rx="160" ry="50" fill="#E5A46E" opacity="0.55" filter="url(#' + id + 'b)"/>');
      for (var e = 0; e < 40; e++) {
        out.push('<circle cx="' + (330 + rnd() * 140).toFixed(0) + '" cy="' + (hy + 20 - rnd() * 260).toFixed(0) + '" r="' + (1 + rnd() * 2).toFixed(1) + '" fill="#F0B27A" opacity="' + (0.2 + rnd() * 0.7).toFixed(2) + '"/>');
      }
    }
    if (s.room) {
      // Interior: warm wall, soft window glow, low furniture plane, gentle light streaks
      out.push('<ellipse cx="' + (W * 0.62) + '" cy="' + (hy * 0.45) + '" rx="' + (W * 0.28) + '" ry="' + (hy * 0.42) + '" fill="#FBF8F3" opacity="0.55" filter="url(#' + id + 'b)"/>');
      out.push('<path d="M' + (W * 0.5) + ' ' + (hy * 0.12) + ' Q ' + (W * 0.66) + ' ' + (hy * 0.02) + ' ' + (W * 0.82) + ' ' + (hy * 0.12) + ' V ' + (hy * 0.9) + ' H ' + (W * 0.5) + ' Z" fill="#FBF8F3" opacity="0.32"/>');
      for (var f = 0; f < 5; f++) {
        var lx = W * 0.2 + f * 60;
        out.push('<path d="M' + lx + ' ' + H + ' L ' + (lx + 220) + ' ' + (hy * 0.15) + '" stroke="#FBF8F3" stroke-width="' + (26 + f * 8) + '" opacity="0.06"/>');
      }
      out.push('<rect x="' + (W * 0.08) + '" y="' + (hy + 10) + '" width="' + (W * 0.84) + '" height="' + (H - hy - 90) + '" rx="10" fill="#F6F1E9" opacity="0.5"/>');
      out.push('<rect x="' + (W * 0.12) + '" y="' + (hy + 30) + '" width="' + (W * 0.76) + '" height="' + ((H - hy) * 0.28) + '" rx="8" fill="#FBF8F3" opacity="0.75"/>');
      out.push('<path d="M' + (W * 0.12) + ' ' + (hy + 30 + (H - hy) * 0.28) + ' q ' + (W * 0.38) + ' 24 ' + (W * 0.76) + ' 0" stroke="#1C2430" stroke-width="1" fill="none" opacity="0.1"/>');
    }
    if (s.mapLines) {
      for (var m = 0; m < 12; m++) {
        var my = 60 + m * 62;
        out.push('<path d="M0 ' + my + " C 200 " + (my - 40 + rnd() * 80) + ", 500 " + (my + 40 - rnd() * 80) + ", 800 " + my + '" stroke="#1C2430" stroke-width="1" fill="none" opacity="0.14"/>');
      }
      out.push('<circle cx="500" cy="380" r="8" fill="#E5A46E"/><circle cx="500" cy="380" r="18" fill="none" stroke="#E5A46E" stroke-width="2" opacity="0.6"/>');
    }
    out.push('<line x1="0" y1="' + hy + '" x2="' + W + '" y2="' + hy + '" stroke="#F6F1E9" stroke-width="1" opacity="0.35"/>');
    out.push("</svg>");
    return out.join("");
  }
  document.querySelectorAll(".art[data-scene]").forEach(function (el, i) {
    el.innerHTML = artSVG(el.getAttribute("data-scene"), i);
  });
  // Hide photos that haven't been supplied yet so the art shows instead.
  document.querySelectorAll("img[data-fallback]").forEach(function (img) {
    var mark = function () { img.classList.add("is-missing"); };
    if (img.complete && img.naturalWidth === 0) mark();
    img.addEventListener("error", mark);
  });

  /* ---- Reveal on scroll ------------------------------------------------ */
  var revealEls = document.querySelectorAll(".reveal");
  if (!reduceMotion && "IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add("is-in"); io.unobserve(en.target); } });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.05 });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("is-in"); });
  }

  /* ---- Theme toggle ---------------------------------------------------- */
  document.querySelectorAll("[data-theme-set]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var v = btn.getAttribute("data-theme-set");
      try { v === "system" ? localStorage.removeItem("pamusha-theme") : localStorage.setItem("pamusha-theme", v); } catch (e) {}
      if (v === "system") document.documentElement.removeAttribute("data-theme"); else document.documentElement.setAttribute("data-theme", v);
      document.querySelectorAll("[data-theme-set]").forEach(function (b) { b.setAttribute("aria-pressed", String(b === btn)); });
    });
  });
  (function markTheme() {
    var cur = "system"; try { cur = localStorage.getItem("pamusha-theme") || "system"; } catch (e) {}
    document.querySelectorAll("[data-theme-set]").forEach(function (b) { b.setAttribute("aria-pressed", String(b.getAttribute("data-theme-set") === cur)); });
  })();

  /* ---- Gallery lightbox ------------------------------------------------ */
  var dlg = document.getElementById("lightbox");
  if (dlg && typeof dlg.showModal === "function") {
    var items = Array.prototype.slice.call(document.querySelectorAll("[data-lightbox]"));
    var idx = 0, dImg = dlg.querySelector("img"), dArt = dlg.querySelector(".art"), dCap = dlg.querySelector(".lightbox__caption"), lastFocus;
    function show(n) {
      idx = (n + items.length) % items.length;
      var src = items[idx];
      var img = src.querySelector("img"), art = src.querySelector(".art");
      if (img && !img.classList.contains("is-missing")) { dImg.src = img.src; dImg.alt = img.alt; dImg.hidden = false; dArt.hidden = true; }
      else { dImg.hidden = true; dArt.hidden = false; dArt.innerHTML = art ? art.innerHTML : ""; }
      dCap.textContent = (src.getAttribute("data-caption") || (img ? img.alt : "")) + " (" + (idx + 1) + " of " + items.length + ")";
      dArt.setAttribute("role", "img"); dArt.setAttribute("aria-label", src.getAttribute("data-caption") || "");
    }
    items.forEach(function (it, i) {
      it.addEventListener("click", function (e) { e.preventDefault(); lastFocus = it; show(i); dlg.showModal(); });
      it.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); it.click(); } });
    });
    dlg.querySelector("[data-prev]").addEventListener("click", function () { show(idx - 1); });
    dlg.querySelector("[data-next]").addEventListener("click", function () { show(idx + 1); });
    dlg.querySelector("[data-close]").addEventListener("click", function () { dlg.close(); });
    dlg.addEventListener("keydown", function (e) { if (e.key === "ArrowLeft") show(idx - 1); if (e.key === "ArrowRight") show(idx + 1); });
    dlg.addEventListener("click", function (e) { if (e.target === dlg) dlg.close(); });
    dlg.addEventListener("close", function () { if (lastFocus) lastFocus.focus(); });
  }

  /* ---- Enquiry form ---------------------------------------------------- */
  var form = document.getElementById("enquiry-form");
  if (form) {
    var status = form.querySelector(".form__status");
    var submitBtn = form.querySelector('button[type="submit"]');
    function setErr(name, msg) {
      var f = form.querySelector('[name="' + name + '"]'); if (!f) return;
      var wrap = f.closest(".field"); var err = wrap.querySelector(".field__error");
      wrap.classList.toggle("is-invalid", !!msg); f.setAttribute("aria-invalid", msg ? "true" : "false"); if (err) err.textContent = msg || "";
    }
    var submitted = false;
    function validate(only) {
      var errs = 0, d = new FormData(form);
      var name = (d.get("name") || "").toString().trim(), email = (d.get("email") || "").toString().trim(), msg = (d.get("message") || "").toString().trim();
      var ci = d.get("checkin"), co = d.get("checkout"), guests = parseInt(d.get("guests"), 10);
      var check = function (field, bad, text) { if (only && only !== field) return; setErr(field, bad ? text : ""); if (bad) errs++; };
      check("name", !name, "Please tell us your name.");
      check("email", !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email), "Enter a valid email so we can reply.");
      check("checkout", !!(ci && co && co <= ci), "Check-out must be after check-in.");
      check("guests", !!(d.get("guests") && (isNaN(guests) || guests < 1 || guests > 9)), "We sleep up to 9 guests.");
      check("message", !msg, "Tell us what you'd like to know.");
      return errs;
    }
    form.querySelectorAll("input, textarea, select").forEach(function (f) { f.addEventListener("blur", function () { if (submitted || f.value) validate(f.name); }); });
    form.addEventListener("submit", function (e) {
      e.preventDefault(); submitted = true;
      var n = validate();
      if (n) {
        status.textContent = n === 1 ? "One field needs attention." : n + " fields need attention.";
        status.classList.add("is-visible", "is-error");
        var firstBad = form.querySelector('[aria-invalid="true"]'); if (firstBad) firstBad.focus(); return;
      }
      status.classList.remove("is-visible", "is-error");
      var d = new FormData(form);
      if (d.get("botcheck")) return; // honeypot
      var payload = {
        access_key: WEB3FORMS_KEY, subject: "Pamusha Lake House enquiry from " + d.get("name"), from_name: "Pamusha website",
        name: d.get("name"), email: d.get("email"), checkin: d.get("checkin"), checkout: d.get("checkout"), guests: d.get("guests"), message: d.get("message")
      };
      if (!WEB3FORMS_KEY && !ENQUIRY_EMAIL) {
        status.textContent = "The enquiry form isn't connected yet. Please message us through Airbnb and we'll get straight back to you.";
        status.classList.add("is-visible", "is-error");
        return;
      }
      if (!WEB3FORMS_KEY) {
        var body = "Name: " + payload.name + "\nEmail: " + payload.email + "\nDates: " + (payload.checkin || "?") + " to " + (payload.checkout || "?") + "\nGuests: " + (payload.guests || "?") + "\n\n" + payload.message;
        window.location.href = "mailto:" + ENQUIRY_EMAIL + "?subject=" + encodeURIComponent(payload.subject) + "&body=" + encodeURIComponent(body);
        status.textContent = "Your email app should open with the enquiry ready to send. If it doesn't, email us at " + ENQUIRY_EMAIL + ".";
        status.classList.add("is-visible"); status.classList.remove("is-error");
        return;
      }
      submitBtn.setAttribute("aria-busy", "true"); submitBtn.disabled = true; var orig = submitBtn.textContent; submitBtn.textContent = "Sending…";
      fetch("https://api.web3forms.com/submit", { method: "POST", headers: { "Content-Type": "application/json", Accept: "application/json" }, body: JSON.stringify(payload) })
        .then(function (r) { return r.json(); })
        .then(function (j) {
          if (j.success) {
            status.textContent = "Thanks " + payload.name + " — we've got your message and will usually reply within a day.";
            status.classList.add("is-visible"); status.classList.remove("is-error"); form.reset();
          } else { throw new Error(j.message || "failed"); }
        })
        .catch(function () {
          status.textContent = "Something went wrong sending that. Please email us directly at " + ENQUIRY_EMAIL + ".";
          status.classList.add("is-visible", "is-error");
        })
        .finally(function () { submitBtn.removeAttribute("aria-busy"); submitBtn.disabled = false; submitBtn.textContent = orig; });
    });
  }

  /* ---- Footer year ----------------------------------------------------- */
  document.querySelectorAll("[data-year]").forEach(function (el) { el.textContent = new Date().getFullYear(); });
})();
