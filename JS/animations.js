/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Shared Animations & Interactions
   Industrial / Technical Redesign
   ═══════════════════════════════════════════════ */

(function () {
  'use strict';

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── 1. Mobile Navigation ── */
  const navBurger = document.getElementById('navBurger');
  if (navBurger) {
    navBurger.addEventListener('click', () => {
      document.body.classList.toggle('nav-open');
    });
    document.querySelectorAll('nav ul a').forEach(link => {
      link.addEventListener('click', () => document.body.classList.remove('nav-open'));
    });
  }

  /* ── 2. Header Scroll State ── */
  const header = document.querySelector('header');
  if (header) {
    const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  /* ── 3. Scroll Reveal — IntersectionObserver ── */
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target); // fire once
      }
    });
  }, { threshold: 0.07, rootMargin: '0px 0px -40px 0px' });

  document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

  /* ── 4. Counter Animation ── */
  function animateCounter(el) {
    const text = el.textContent.trim();
    const match = text.match(/^(\d+)(.*)$/);
    if (!match) return;

    const target  = parseInt(match[1], 10);
    const suffix  = match[2];
    const duration = 1200;
    const startTime = performance.now();

    function tick(now) {
      const elapsed  = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased    = 1 - Math.pow(1 - progress, 3); // cubic ease-out
      el.textContent = Math.round(eased * target) + suffix;
      if (progress < 1) requestAnimationFrame(tick);
    }

    requestAnimationFrame(tick);
  }

  const counterObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        if (!reducedMotion) animateCounter(entry.target);
        counterObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.5 });

  document.querySelectorAll('.stat-number').forEach(el => {
    if (/^\d+/.test(el.textContent.trim())) {
      counterObserver.observe(el);
    }
  });

  /* ── 5. Marquee (tech-list) ── */
  const techList = document.querySelector('.tech-list');
  if (techList && !reducedMotion) {
    const items = Array.from(techList.children);
    if (items.length > 0) {
      const wrapper = document.createElement('div');
      wrapper.className = 'tech-marquee-wrapper';

      const track = document.createElement('div');
      track.className = 'tech-marquee-track';

      [...items, ...items.map(i => i.cloneNode(true))].forEach(item => {
        track.appendChild(item);
      });

      wrapper.appendChild(track);
      techList.parentNode.replaceChild(wrapper, techList);
    }
  }

})();
