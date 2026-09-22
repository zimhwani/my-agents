/* Mati — site behaviour. Vanilla JS, no dependencies. */
(function () {
  'use strict';
  const d = document, root = d.documentElement;
  root.classList.replace('no-js', 'js');
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* Header: solid on scroll */
  const header = d.querySelector('.site-header');
  const onScroll = () => header && header.classList.toggle('is-scrolled', window.scrollY > 24);
  onScroll(); window.addEventListener('scroll', onScroll, { passive: true });

  /* Mobile nav */
  const toggle = d.querySelector('.nav-toggle'), nav = d.querySelector('#site-nav');
  if (toggle && nav) {
    const setOpen = (open) => {
      toggle.setAttribute('aria-expanded', String(open));
      nav.classList.toggle('is-open', open);
      root.classList.toggle('nav-open', open);
      toggle.querySelector('.nav-toggle__label').textContent = open ? 'Close' : 'Menu';
    };
    toggle.addEventListener('click', () => setOpen(toggle.getAttribute('aria-expanded') !== 'true'));
    nav.querySelectorAll('a').forEach(a => a.addEventListener('click', () => setOpen(false)));
    d.addEventListener('keydown', e => { if (e.key === 'Escape') setOpen(false); });
  }

  /* Reveal on scroll */
  const revealEls = d.querySelectorAll('[data-reveal]');
  if (reduce || !('IntersectionObserver' in window)) {
    revealEls.forEach(el => el.classList.add('is-visible'));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(en => { if (en.isIntersecting) { en.target.classList.add('is-visible'); io.unobserve(en.target); } });
    }, { rootMargin: '0px 0px -10% 0px', threshold: 0.12 });
    revealEls.forEach(el => io.observe(el));
  }

  /* Marquee: duplicate track for seamless loop */
  d.querySelectorAll('.marquee').forEach(m => {
    const track = m.querySelector('.marquee__track');
    if (!track) return;
    const clone = track.cloneNode(true); clone.setAttribute('aria-hidden', 'true');
    m.appendChild(clone);
  });

  /* Count-up stats */
  const stats = d.querySelectorAll('[data-count]');
  if (stats.length && !reduce && 'IntersectionObserver' in window) {
    const io2 = new IntersectionObserver((entries) => {
      entries.forEach(en => {
        if (!en.isIntersecting) return;
        const el = en.target, end = parseFloat(el.dataset.count), suffix = el.dataset.suffix || '';
        const t0 = performance.now(), dur = 1400;
        const tick = (t) => {
          const p = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - p, 3);
          el.textContent = Math.round(end * e) + suffix;
          if (p < 1) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick); io2.unobserve(el);
      });
    }, { threshold: 0.5 });
    stats.forEach(el => io2.observe(el));
  }

  /* Accordion (FAQ) — native <details>, animate + single-open */
  d.querySelectorAll('.accordion').forEach(acc => {
    acc.querySelectorAll('details').forEach(det => {
      det.addEventListener('toggle', () => {
        if (det.open) acc.querySelectorAll('details[open]').forEach(o => { if (o !== det) o.open = false; });
      });
    });
  });

  /* Enquiry form */
  const form = d.querySelector('#enquiry-form');
  if (form) {
    const status = form.querySelector('.form-status');
    const setStatus = (msg, kind) => { status.textContent = msg; status.className = 'form-status is-' + kind; };
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      form.querySelectorAll('.is-invalid').forEach(el => el.classList.remove('is-invalid'));
      const invalid = [...form.querySelectorAll('[required]')].filter(el => !el.checkValidity());
      if (invalid.length) {
        invalid.forEach(el => el.classList.add('is-invalid'));
        invalid[0].focus();
        setStatus('Please complete the highlighted fields.', 'error');
        return;
      }
      const endpoint = form.getAttribute('action');
      const btn = form.querySelector('[type="submit"]');
      const data = new FormData(form);
      // Honeypot
      if (data.get('_gotcha')) return;
      if (!endpoint || endpoint.includes('YOUR_FORM_ID')) {
        // No backend configured yet: fall back to a pre-filled email.
        const subject = encodeURIComponent('Booking enquiry: ' + (data.get('event_type') || 'Event') + ' — ' + data.get('name'));
        const body = encodeURIComponent([...data.entries()].filter(([k]) => !k.startsWith('_')).map(([k, v]) => k.replace(/_/g, ' ') + ': ' + v).join('\n'));
        window.location.href = 'mailto:' + (form.dataset.mailto || 'hello@mati.com.au') + '?subject=' + subject + '&body=' + body;
        setStatus('Opening your email app with the details filled in.', 'ok');
        return;
      }
      btn.disabled = true; btn.classList.add('is-loading'); setStatus('Sending…', 'pending');
      try {
        const res = await fetch(endpoint, { method: 'POST', body: data, headers: { Accept: 'application/json' } });
        if (!res.ok) throw new Error('Request failed');
        form.reset();
        form.classList.add('is-sent');
        setStatus('Thanks, got it. I will be in touch within two business days.', 'ok');
      } catch (err) {
        setStatus('Something went wrong. Please email hello@mati.com.au directly.', 'error');
      } finally { btn.disabled = false; btn.classList.remove('is-loading'); }
    });
    // Pre-select event type from ?type=
    const type = new URLSearchParams(location.search).get('type');
    const sel = form.querySelector('[name="event_type"]');
    if (type && sel && [...sel.options].some(o => o.value === type)) sel.value = type;
  }

  /* Lightbox for gallery */
  const gallery = d.querySelector('[data-lightbox]');
  if (gallery) {
    const lb = d.createElement('div'); lb.className = 'lightbox'; lb.setAttribute('role', 'dialog'); lb.setAttribute('aria-modal', 'true'); lb.hidden = true;
    lb.innerHTML = '<button class="lightbox__close" aria-label="Close">&times;</button><figure><img alt=""><figcaption></figcaption></figure>';
    d.body.appendChild(lb);
    const img = lb.querySelector('img'), cap = lb.querySelector('figcaption');
    let last = null;
    const close = () => { lb.hidden = true; root.classList.remove('nav-open'); last && last.focus(); };
    gallery.addEventListener('click', e => {
      const a = e.target.closest('a[data-full]'); if (!a) return;
      e.preventDefault(); last = a;
      img.src = a.dataset.full; img.alt = a.querySelector('img')?.alt || ''; cap.textContent = a.dataset.caption || '';
      lb.hidden = false; root.classList.add('nav-open'); lb.querySelector('button').focus();
    });
    lb.addEventListener('click', e => { if (e.target === lb || e.target.closest('.lightbox__close')) close(); });
    d.addEventListener('keydown', e => { if (e.key === 'Escape' && !lb.hidden) close(); });
  }

  /* Current year */
  d.querySelectorAll('[data-year]').forEach(el => el.textContent = new Date().getFullYear());
})();

/* Copy-to-clipboard for bios */
(function () {
  const status = document.querySelector('#copy-status');
  document.querySelectorAll('[data-copy]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const el = document.querySelector(btn.dataset.copy); if (!el) return;
      try { await navigator.clipboard.writeText(el.textContent.trim()); if (status) { status.textContent = 'Copied to clipboard.'; status.className = 'form-status is-ok mt-6'; } btn.textContent = 'Copied'; setTimeout(() => btn.textContent = btn.textContent.replace('Copied', 'Copy ' + btn.dataset.copy.replace('#bio-', '').replace('s', 'short').replace('m', 'medium').replace('l', 'long') + ' bio'), 1800); }
      catch (e) { if (status) { status.textContent = 'Copy failed. Select the text and copy manually.'; status.className = 'form-status is-error mt-6'; } }
    });
  });
})();
