/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Shared Animations & Interactions
   Dark Glass Redesign
   ═══════════════════════════════════════════════ */

(function () {
  'use strict';

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const isTouchDevice = window.matchMedia('(hover: none)').matches;

  /* ── 1. Theme Toggle (Dark ist Standard) ── */
  const themeToggle = document.getElementById('themeToggle');
  if (themeToggle) {
    themeToggle.addEventListener('click', () => {
      const isLight = document.documentElement.getAttribute('data-theme') === 'light';
      if (isLight) {
        document.documentElement.removeAttribute('data-theme');
        localStorage.setItem('theme', 'dark');
      } else {
        document.documentElement.setAttribute('data-theme', 'light');
        localStorage.setItem('theme', 'light');
      }
    });
  }

  /* ── 2. Mobile Navigation ── */
  const navBurger = document.getElementById('navBurger');
  if (navBurger) {
    navBurger.addEventListener('click', () => {
      document.body.classList.toggle('nav-open');
    });
    document.querySelectorAll('nav ul a').forEach(link => {
      link.addEventListener('click', () => document.body.classList.remove('nav-open'));
    });
  }

  /* ── 3. Header Scroll State ── */
  const header = document.querySelector('header');
  if (header) {
    const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  /* ── 4. Scroll Reveal — IntersectionObserver ── */
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target); // fire once
      }
    });
  }, { threshold: 0.07, rootMargin: '0px 0px -40px 0px' });

  document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

  /* ── 5. Cursor Glow ── */
  if (!isTouchDevice && !reducedMotion && window.innerWidth > 768) {
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

    document.addEventListener('mouseleave', () => { glow.style.opacity = '0'; });
    document.addEventListener('mouseenter', () => { glow.style.opacity = '1'; });
  }

  /* ── 6. 3D Card Tilt ── */
  const tiltSelectors = [
    '.service-card',
    '.skill-card',
    '.project-card-small',
    '.project-card.featured',
    '.project-highlight',
    '.product-card',
  ];

  if (!isTouchDevice && !reducedMotion) {
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

  /* ── 7. Counter Animation ── */
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

  /* ── 8. Marquee (tech-list) ── */
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

  /* ── 9. Hero Partikel-Canvas ── */
  const canvas = document.getElementById('heroCanvas');
  if (canvas && !reducedMotion) {
    const ctx = canvas.getContext('2d');
    const hero = canvas.parentElement;
    let particles = [];
    let width = 0, height = 0;
    let running = true;

    const CYAN = [34, 211, 238];
    const VIOLET = [129, 140, 248];

    function resize() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = hero.clientWidth;
      height = hero.clientHeight;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function spawn() {
      const count = Math.min(60, Math.floor(width / 24));
      particles = Array.from({ length: count }, () => ({
        x: Math.random() * width,
        y: Math.random() * height,
        r: 1 + Math.random() * 1.8,
        vx: (Math.random() - 0.5) * 0.28,
        vy: (Math.random() - 0.5) * 0.28,
        c: Math.random() > 0.45 ? CYAN : VIOLET,
        a: 0.25 + Math.random() * 0.5,
      }));
    }

    function frame() {
      if (!running) return;
      ctx.clearRect(0, 0, width, height);

      // Linien zwischen nahen Partikeln
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const p = particles[i], q = particles[j];
          const dx = p.x - q.x, dy = p.y - q.y;
          const dist = Math.hypot(dx, dy);
          if (dist < 130) {
            const alpha = (1 - dist / 130) * 0.14;
            ctx.strokeStyle = `rgba(${p.c[0]}, ${p.c[1]}, ${p.c[2]}, ${alpha})`;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(q.x, q.y);
            ctx.stroke();
          }
        }
      }

      // Punkte
      particles.forEach(p => {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < -10) p.x = width + 10;
        if (p.x > width + 10) p.x = -10;
        if (p.y < -10) p.y = height + 10;
        if (p.y > height + 10) p.y = -10;

        ctx.fillStyle = `rgba(${p.c[0]}, ${p.c[1]}, ${p.c[2]}, ${p.a})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fill();
      });

      requestAnimationFrame(frame);
    }

    // Pausieren, wenn Hero nicht sichtbar (Performance)
    const heroObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        const wasRunning = running;
        running = entry.isIntersecting;
        if (running && !wasRunning) requestAnimationFrame(frame);
      });
    }, { threshold: 0 });
    heroObserver.observe(hero);

    let resizeTimer = null;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => { resize(); spawn(); }, 150);
    });

    resize();
    spawn();
    requestAnimationFrame(frame);
  }

})();
