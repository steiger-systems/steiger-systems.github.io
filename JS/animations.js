/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Shared Animations & Interactions
   ═══════════════════════════════════════════════ */

(function () {
  'use strict';

  /* ── 1. Dark Mode Toggle ── */
  const themeToggle = document.getElementById('themeToggle');
  if (themeToggle) {
    themeToggle.addEventListener('click', () => {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      document.documentElement.setAttribute('data-theme', isDark ? 'light' : 'dark');
      localStorage.setItem('theme', isDark ? 'light' : 'dark');
    });
  }

  /* ── 2. Scroll Reveal — IntersectionObserver ── */
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target); // fire once
      }
    });
  }, { threshold: 0.07, rootMargin: '0px 0px -40px 0px' });

  document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

  /* ── 3. Cursor Glow ── */
  const isTouchDevice = window.matchMedia('(hover: none)').matches;
  if (!isTouchDevice && window.innerWidth > 768) {
    const glow = document.createElement('div');
    glow.className = 'cursor-glow';
    document.body.appendChild(glow);

    let glowX = -9999, glowY = -9999;
    let rafId = null;

    document.addEventListener('mousemove', (e) => {
      glowX = e.clientX;
      glowY = e.clientY;
      if (!rafId) {
        rafId = requestAnimationFrame(() => {
          glow.style.transform = `translate(calc(${glowX}px - 50%), calc(${glowY}px - 50%))`;
          rafId = null;
        });
      }
    });

    document.addEventListener('mouseleave', () => {
      glow.style.opacity = '0';
    });
    document.addEventListener('mouseenter', () => {
      glow.style.opacity = '1';
    });
  }

  /* ── 4. 3D Card Tilt ── */
  const tiltSelectors = [
    '.service-card',
    '.skill-card',
    '.project-card-small',
    '.project-card.featured',
    '.project-highlight',
    '.product-card',
  ];

  if (!isTouchDevice) {
    document.querySelectorAll(tiltSelectors.join(', ')).forEach(card => {
      card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const cx = rect.width / 2;
        const cy = rect.height / 2;
        const rotY =  ((x - cx) / cx) * 6;  // ±6°
        const rotX = -((y - cy) / cy) * 4;  // ±4°
        card.style.transition = 'transform 0.08s ease-out, box-shadow 0.08s ease-out';
        card.style.transform = `perspective(900px) rotateX(${rotX}deg) rotateY(${rotY}deg) translateY(-4px)`;
      });

      card.addEventListener('mouseleave', () => {
        card.style.transition = 'transform 0.55s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.3s ease, border-color 0.3s ease';
        card.style.transform = '';
      });
    });
  }

  /* ── 5. Counter Animation ── */
  function animateCounter(el) {
    const text = el.textContent.trim();
    const match = text.match(/^(\d+)(.*)$/);
    if (!match) return;

    const target  = parseInt(match[1], 10);
    const suffix  = match[2];
    const duration = 1400;
    const startTime = performance.now();

    function tick(now) {
      const elapsed  = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // Cubic ease-out
      const eased    = 1 - Math.pow(1 - progress, 3);
      el.textContent = Math.round(eased * target) + suffix;
      if (progress < 1) requestAnimationFrame(tick);
    }

    requestAnimationFrame(tick);
  }

  const counterObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        animateCounter(entry.target);
        counterObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.5 });

  document.querySelectorAll('.stat-number').forEach(el => {
    if (/^\d+/.test(el.textContent.trim())) {
      counterObserver.observe(el);
    }
  });

  /* ── 6. Marquee (tech-list) ── */
  const techList = document.querySelector('.tech-list');
  if (techList) {
    const items = Array.from(techList.children);
    if (items.length > 0) {
      // Build wrapper + track
      const wrapper = document.createElement('div');
      wrapper.className = 'tech-marquee-wrapper';

      const track = document.createElement('div');
      track.className = 'tech-marquee-track';

      // Duplicate items for seamless loop
      [...items, ...items.map(i => i.cloneNode(true))].forEach(item => {
        track.appendChild(item);
      });

      wrapper.appendChild(track);
      techList.parentNode.replaceChild(wrapper, techList);
    }
  }

})();
