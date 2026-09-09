/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Navigation
   Bewusst ohne Scroll-Animationen (Handoff: «Ruhe ist Teil des Designs»).
   ═══════════════════════════════════════════════ */

(function () {
  'use strict';

  // Leiste liegt transparent über dem Hero; ab 10px Scroll dunkler Grund + Hairline
  const header = document.querySelector('header');
  if (header) {
    const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

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
