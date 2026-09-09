/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Navigation
   Bewusst ohne Scroll-Animationen (Handoff: «Ruhe ist Teil des Designs»).
   ═══════════════════════════════════════════════ */

(function () {
  'use strict';

  const burger = document.getElementById('navBurger');
  if (!burger) return;

  function setOpen(open) {
    document.body.classList.toggle('nav-open', open);
    burger.setAttribute('aria-expanded', open ? 'true' : 'false');
    burger.setAttribute('aria-label', open ? 'Menü schliessen' : 'Menü öffnen');
  }

  burger.addEventListener('click', () => {
    setOpen(!document.body.classList.contains('nav-open'));
  });

  document.querySelectorAll('nav.top ul a').forEach(link => {
    link.addEventListener('click', () => setOpen(false));
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && document.body.classList.contains('nav-open')) setOpen(false);
  });
})();
