/* ═══════════════════════════════════════════════
   STEIGER-SYSTEMS — 3D-Wortmarke im Hero
   Three.js lokal aus JS/vendor/three (kein CDN, kein Build-Schritt).
   Ohne WebGL oder bei Ladefehler bleibt der Schriftzug als Text stehen.
   ═══════════════════════════════════════════════ */

import * as THREE from "three";
import { GLTFLoader } from "three/jsm/loaders/GLTFLoader.js";
import { RoomEnvironment } from "three/jsm/environments/RoomEnvironment.js";

const stage = document.getElementById("wordmark-3d");
if (stage) init(stage);

function init(stage) {
  const MODEL = "/assets/models/wordmark.glb";
  const MAX_YAW = THREE.MathUtils.degToRad(25);   // seitlich
  const MAX_PITCH = THREE.MathUtils.degToRad(12); // hoch/runter
  const HOVER = THREE.MathUtils.degToRad(6);      // Folgen ohne Klick
  const EASE = 0.08;                              // Rückfederung pro Frame
  const IDLE_MS = 3000;                           // bis das Schwingen beginnt
  const WIDTH_RATIO = 0.7;                        // Anteil der Bildschirmbreite
  const WIDTH_RATIO_NARROW = 0.9;                 // schmale Schirme: sonst zu klein
  const COLORS = {                                // Materialnamen aus der GLB
    Ink: { light: 0x16181b, dark: 0xecebe6 },
    Accent: { light: 0x1f5fd0, dark: 0x5b8ef0 }
  };

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)");
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  } catch (e) {
    return; // kein WebGL: Text-Fallback bleibt sichtbar
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.domElement.setAttribute("aria-hidden", "true");
  stage.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  camera.position.set(0, 0, 6);

  // Umgebungslicht für saubere Kanten
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.55;

  scene.add(new THREE.HemisphereLight(0xffffff, 0xd8d6cf, 1.1));
  const key = new THREE.DirectionalLight(0xffffff, 2.1);
  key.position.set(-2.2, 3.4, 4);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xffffff, 0.5);
  fill.position.set(3, 1.5, 2);
  scene.add(fill);

  // Der Schlagschatten liegt als CSS-Filter auf dem Canvas: eine Schattenebene in der
  // Szene würde den flachen Schriftzug als zweite, lesbare Kopie daneben werfen.
  const pivot = new THREE.Group();
  scene.add(pivot);

  let model = null;
  let modelSize = new THREE.Vector3(1, 1, 1);

  new GLTFLoader().load(MODEL, function (gltf) {
    model = gltf.scene;

    // Schwerpunkt auf den Ursprung, damit sich der Schriftzug um seine Mitte dreht
    const box = new THREE.Box3().setFromObject(model);
    box.getSize(modelSize);
    const center = box.getCenter(new THREE.Vector3());
    model.position.sub(center);

    model.traverse(function (o) {
      if (!o.isMesh) return;
      o.material.envMapIntensity = 0.8;
    });
    paint();
    pivot.add(model);
    resize();
    stage.classList.add("is-ready");
  }, undefined, function () {
    stage.classList.add("is-failed"); // Textfassung bleibt stehen
  });

  // ── Farben: nur wenn die Seite selbst dunkel ist (sie ist es heute nie) ──
  function paint() {
    const dark = document.documentElement.dataset.theme === "dark";
    model.traverse(function (o) {
      const def = o.isMesh && o.material && COLORS[o.material.name];
      if (def) o.material.color.setHex(dark ? def.dark : def.light);
    });
  }

  // ── Grösse: Wortmarke auf ~70 % der Breite, bei jedem Resize neu ──
  function resize() {
    const w = stage.clientWidth;
    const h = stage.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();

    if (!model) return;
    const visibleH = 2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2) * camera.position.z;
    const visibleW = visibleH * camera.aspect;
    const ratio = w < 700 ? WIDTH_RATIO_NARROW : WIDTH_RATIO;
    const scale = Math.min(
      (visibleW * ratio) / modelSize.x,
      (visibleH * 0.5) / modelSize.y
    );
    model.scale.setScalar(scale);
  }
  window.addEventListener("resize", resize);
  resize();

  // ── Zeigersteuerung: ziehen dreht, loslassen federt zurück ──
  let targetYaw = 0, targetPitch = 0, yaw = 0, pitch = 0;
  let dragging = false, dragX = 0, dragY = 0, lastInput = performance.now();

  const soft = (value, max) => max * Math.tanh(value / max);

  function onDown(e) {
    dragging = true;
    dragX = e.clientX;
    dragY = e.clientY;
    lastInput = performance.now();
    stage.classList.add("is-dragging");
    try { stage.setPointerCapture(e.pointerId); } catch (err) { /* egal */ }
  }

  function onMove(e) {
    lastInput = performance.now();
    if (dragging) {
      targetYaw = soft((e.clientX - dragX) * 0.006, MAX_YAW);
      targetPitch = soft((e.clientY - dragY) * 0.006, MAX_PITCH);
      return;
    }
    if (e.pointerType === "touch") return;
    const r = stage.getBoundingClientRect();
    targetYaw = ((e.clientX - r.left) / r.width - 0.5) * 2 * HOVER;
    targetPitch = ((e.clientY - r.top) / r.height - 0.5) * 2 * HOVER;
  }

  function onUp(e) {
    if (!dragging) return;
    dragging = false;
    targetYaw = 0;
    targetPitch = 0;
    lastInput = performance.now();
    stage.classList.remove("is-dragging");
    try { stage.releasePointerCapture(e.pointerId); } catch (err) { /* egal */ }
  }

  stage.addEventListener("pointerdown", onDown);
  stage.addEventListener("pointermove", onMove);
  stage.addEventListener("pointerup", onUp);
  stage.addEventListener("pointercancel", onUp);
  stage.addEventListener("pointerleave", function () {
    if (!dragging) { targetYaw = 0; targetPitch = 0; }
  });

  // ── Schleife: läuft nur, solange der Hero sichtbar ist ──
  let visible = true, frame = 0;

  function tick(now) {
    frame = requestAnimationFrame(tick);
    if (model) {
      let goalYaw = targetYaw, goalPitch = targetPitch;
      if (!dragging && !reduced.matches && now - lastInput > IDLE_MS) {
        const t = (now - lastInput - IDLE_MS) / 1000;
        goalYaw += THREE.MathUtils.degToRad(4) * Math.sin(t * 0.6);
        goalPitch += THREE.MathUtils.degToRad(1.5) * Math.sin(t * 0.45);
      }
      yaw += (goalYaw - yaw) * EASE;
      pitch += (goalPitch - pitch) * EASE;
      pivot.rotation.y = yaw;
      pivot.rotation.x = pitch;
    }
    renderer.render(scene, camera);
  }

  function run(on) {
    if (on && !frame) frame = requestAnimationFrame(tick);
    if (!on && frame) { cancelAnimationFrame(frame); frame = 0; }
  }

  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (entries) {
      visible = entries[0].isIntersecting;
      run(visible && !document.hidden);
    }, { threshold: 0 }).observe(stage);
  }
  document.addEventListener("visibilitychange", function () {
    run(visible && !document.hidden);
  });
  run(true);
}
