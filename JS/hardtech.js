/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — Menü, Header, Animationen (alle Seiten)
   Ohne JavaScript bleibt alles sichtbar: Startzustände nur per gsap.from().
   <body data-no-lenis> schaltet Smooth Scroll ab (z. B. Shop mit Dialogen).
   ═══════════════════════════════════════════════ */

(function () {
  "use strict";

  var $ = function (s) { return document.querySelector(s); };

  // Jahr im Footer
  var year = document.getElementById("year");
  if (year) year.textContent = new Date().getFullYear();

  // Endlos-Slider: zweite Kopie für den nahtlosen Loop
  var sets = document.querySelectorAll(".marquee__set");
  if (sets.length === 2) {
    sets[1].innerHTML = sets[0].innerHTML;
    sets[1].querySelectorAll("a").forEach(function (a) { a.setAttribute("tabindex", "-1"); });
  }

  // Mobiles Vollbild-Menü
  var burger = $(".nav__burger");
  var menu = $(".menu");
  if (burger && menu) {
    var setMenu = function (open) {
      document.body.classList.toggle("menu-open", open);
      burger.setAttribute("aria-expanded", open ? "true" : "false");
      burger.setAttribute("aria-label", open ? "Menü schliessen" : "Menü öffnen");
      menu.setAttribute("aria-hidden", open ? "false" : "true");
      if (open) menu.removeAttribute("inert"); else menu.setAttribute("inert", "");
    };
    burger.addEventListener("click", function () { setMenu(!document.body.classList.contains("menu-open")); });
    menu.querySelectorAll("a").forEach(function (a) { a.addEventListener("click", function () { setMenu(false); }); });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && document.body.classList.contains("menu-open")) setMenu(false);
    });
  }

  // Header-Zustand: Leiste schiebt sich weg, Nav wird hell mit Blur
  var header = $(".header");
  if (header) {
    var onScroll = function () { header.classList.toggle("is-scrolled", window.scrollY > 80); };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  if (!window.gsap || !window.ScrollTrigger) return;

  gsap.registerPlugin(ScrollTrigger);
  if (window.SplitText) gsap.registerPlugin(SplitText);
  var mm = gsap.matchMedia();
  var useLenis = !document.body.hasAttribute("data-no-lenis");

  mm.add("(prefers-reduced-motion: no-preference)", function () {
    var lenis;
    if (useLenis && window.Lenis) {
      lenis = new Lenis({ duration: 1.1, easing: function (t) { return 1 - Math.pow(1 - t, 4); } });
      lenis.on("scroll", ScrollTrigger.update);
      var tick = function (t) { lenis.raf(t * 1000); };
      gsap.ticker.add(tick);
      gsap.ticker.lagSmoothing(0);
      document.querySelectorAll('a[href^="#"]').forEach(function (a) {
        a.addEventListener("click", function (e) {
          var href = a.getAttribute("href");
          var target = href.length > 1 && document.querySelector(href);
          if (target) { e.preventDefault(); lenis.scrollTo(target, { offset: -70 }); }
        });
      });
    }

    // Headlines zeilenweise aus einer Maske
    if (window.SplitText) {
      document.querySelectorAll(".split").forEach(function (h) {
        SplitText.create(h, {
          type: "lines", mask: "lines", autoSplit: true,
          onSplit: function (self) {
            return gsap.from(self.lines, {
              yPercent: 110, duration: 1.1, ease: "expo.out", stagger: 0.08,
              scrollTrigger: { trigger: h, start: "top 88%", once: true }
            });
          }
        });
      });
    }

    gsap.utils.toArray(".reveal").forEach(function (el) {
      gsap.from(el, { y: 60, autoAlpha: 0, duration: 1, ease: "power3.out",
        scrollTrigger: { trigger: el, start: "top 85%", once: true } });
    });

    gsap.utils.toArray("[data-stagger]").forEach(function (group) {
      gsap.from(group.children, { y: 40, autoAlpha: 0, duration: 0.9, ease: "power3.out", stagger: 0.1,
        scrollTrigger: { trigger: group, start: "top 85%", once: true } });
    });

    gsap.utils.toArray(".sec-num").forEach(function (el) {
      gsap.from(el, { autoAlpha: 0, x: -20, duration: 0.8, ease: "power3.out",
        scrollTrigger: { trigger: el, start: "top 90%", once: true } });
    });

    // Hero der Startseite: Render schwebt ein, Parallaxe beim Scrollen
    if ($(".hero")) {
      gsap.from(".hero__render", { y: 60, autoAlpha: 0, scale: 0.96, duration: 1.4, ease: "expo.out", delay: 0.15 });
      gsap.to(".hero__media", { yPercent: 18, scale: 1.06, ease: "none",
        scrollTrigger: { trigger: ".hero", start: "top top", end: "bottom top", scrub: true } });
      gsap.to(".hero__scroll, .hero__caption", { autoAlpha: 0, ease: "none",
        scrollTrigger: { trigger: ".hero", start: "top top", end: "20% top", scrub: true } });
    }

    // Grosse Zeichnungen auf Unterseiten: leichte Parallaxe im Rahmen
    gsap.utils.toArray(".media-frame svg").forEach(function (svg) {
      gsap.fromTo(svg, { yPercent: -4, scale: 1.06 }, { yPercent: 4, scale: 1.06, ease: "none",
        scrollTrigger: { trigger: svg.parentNode, start: "top bottom", end: "bottom top", scrub: true } });
    });

    return function () { if (lenis) lenis.destroy(); };
  });

  // Gepinnter Produkt-Showcase (ein Pin pro Seite): Callouts nacheinander
  if ($(".showcase")) {
    mm.add("(min-width: 901px) and (prefers-reduced-motion: no-preference)", function () {
      var callouts = gsap.utils.toArray(".callout");
      var tl = gsap.timeline({
        scrollTrigger: {
          trigger: ".showcase", start: "top top",
          end: function () { return "+=" + callouts.length * 450; },
          pin: true, scrub: 0.6, invalidateOnRefresh: true,
          onUpdate: function (self) {
            var i = Math.min(callouts.length - 1, Math.floor(self.progress * callouts.length));
            callouts.forEach(function (c, n) { c.classList.toggle("is-active", n === i); });
          }
        }
      });
      tl.from(".showcase__img", { scale: 0.88, autoAlpha: 0.3, duration: 1 });
      callouts.forEach(function (c) {
        tl.from(c.querySelector(".callout__dot"), { scale: 0, duration: 0.3 })
          .from(c.querySelector(".callout__line"), { scaleX: 0, duration: 0.4 })
          .from(c.querySelector(".callout__box"), { autoAlpha: 0, y: 12, duration: 0.4 });
      });
    });
  }

  mm.add("(prefers-reduced-motion: reduce)", function () {
    gsap.set(".reveal, [data-stagger] > *, .sec-num, .hero__render", { clearProps: "all" });
  });

  window.addEventListener("load", function () { ScrollTrigger.refresh(); });
  if (document.fonts) document.fonts.ready.then(function () { ScrollTrigger.refresh(); });
})();
