/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Farbschema und Navigation
   Farbschema wie im Payload-Template: Auto / Hell / Dunkel.
   «Auto» folgt der Systemeinstellung und wird nicht gespeichert.
   Das Setzen beim Laden passiert inline im <head> (kein Aufblitzen).
   ═══════════════════════════════════════════════ */

(function () {
  'use strict';

  var KEY = 'ss-theme';
  var root = document.documentElement;
  var systemDark = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function readStored() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }

  function applyTheme(pref) {
    var theme = (pref === 'light' || pref === 'dark')
      ? pref
      : (systemDark && systemDark.matches ? 'dark' : 'light');
    root.setAttribute('data-theme', theme);
  }

  /* ── 1. Farbschema-Auswahl im Footer ── */
  var select = document.getElementById('themeSelect');
  if (select) {
    var stored = readStored();
    select.value = (stored === 'light' || stored === 'dark') ? stored : 'auto';

    select.addEventListener('change', function () {
      var value = select.value;
      try {
        if (value === 'auto') localStorage.removeItem(KEY);
        else localStorage.setItem(KEY, value);
      } catch (e) { /* Speicher gesperrt: Auswahl gilt nur für diese Seite */ }
      applyTheme(value);
    });
  }

  /* «Auto» reagiert live auf einen Wechsel der Systemeinstellung */
  if (systemDark) {
    var onSystemChange = function () {
      var pref = readStored();
      if (pref !== 'light' && pref !== 'dark') applyTheme('auto');
    };
    if (systemDark.addEventListener) systemDark.addEventListener('change', onSystemChange);
    else if (systemDark.addListener) systemDark.addListener(onSystemChange);
  }

  /* ── 2. Mobile Navigation ── */
  var burger = document.getElementById('navBurger');
  if (burger) {
    var setOpen = function (open) {
      document.body.classList.toggle('nav-open', open);
      burger.setAttribute('aria-expanded', open ? 'true' : 'false');
      burger.setAttribute('aria-label', open ? 'Menü schliessen' : 'Menü öffnen');
    };

    burger.addEventListener('click', function () {
      setOpen(!document.body.classList.contains('nav-open'));
    });

    document.querySelectorAll('nav.top ul a').forEach(function (link) {
      link.addEventListener('click', function () { setOpen(false); });
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && document.body.classList.contains('nav-open')) setOpen(false);
    });
  }
})();
