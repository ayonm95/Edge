/**
 * Edge 3D Showcase - Liquid Glass HUD & UI System
 * macOS Sonoma/Sequoia OSD Overlays, Menu Bar Dropdown, and Viral Social Proof Cards
 */

window.EdgeHUD = (function() {
  // DOM References
  let hookContainer, hookTitle;
  let gesturePill, pillIcon, pillText;
  let hudBrightness, hudVolume, hudMedia;
  let brightnessFill, brightnessVal, brightnessIconWrap;
  let volumeFill, volumeVal, volumeIconWrap;
  let menubarDropdown;
  let socialStack;
  let ctaScreen;

  function init() {
    hookContainer = document.querySelector('.hook-container');
    hookTitle = document.querySelector('.hook-title');
    gesturePill = document.querySelector('.gesture-indicator-pill');
    pillIcon = document.querySelector('.pill-icon');
    pillText = document.querySelector('.pill-text');

    hudBrightness = document.getElementById('hud-brightness');
    brightnessFill = hudBrightness.querySelector('.hud-slider-fill');
    brightnessVal = hudBrightness.querySelector('.hud-value-label');
    brightnessIconWrap = hudBrightness.querySelector('.hud-icon-wrap');

    hudVolume = document.getElementById('hud-volume');
    volumeFill = hudVolume.querySelector('.hud-slider-fill');
    volumeVal = hudVolume.querySelector('.hud-value-label');
    volumeIconWrap = hudVolume.querySelector('.hud-icon-wrap');

    hudMedia = document.getElementById('hud-media');
    menubarDropdown = document.querySelector('.menubar-dropdown');
    socialStack = document.querySelector('.social-proof-stack');
    ctaScreen = document.querySelector('.cta-screen');
  }

  // Hook Header Animation
  function showHook(show = true) {
    if (show) {
      gsap.to(hookContainer, { opacity: 1, y: 0, duration: 0.6, ease: 'power2.out' });
    } else {
      gsap.to(hookContainer, { opacity: 0, y: -20, duration: 0.4, ease: 'power2.in' });
    }
  }

  // Floating Gesture Indicator Pill
  function showGesturePill(icon, text, x = '50%', y = '78%', show = true) {
    if (show) {
      pillIcon.textContent = icon;
      pillText.textContent = text;
      gesturePill.style.left = x;
      gesturePill.style.top = y;
      gesturePill.style.transform = 'translate(-50%, -50%) scale(1)';
      gsap.to(gesturePill, { opacity: 1, duration: 0.35, ease: 'back.out(1.5)' });
    } else {
      gsap.to(gesturePill, { opacity: 0, scale: 0.85, duration: 0.25, ease: 'power2.in' });
    }
  }

  // Brightness HUD
  function setBrightness(pct0to100, isVisible = true) {
    const clamped = Math.max(0, Math.min(100, Math.round(pct0to100)));
    brightnessFill.style.width = clamped + '%';
    brightnessVal.textContent = clamped + '%';

    // SVG icon updates based on intensity
    if (clamped < 25) {
      brightnessIconWrap.innerHTML = getSunSVG('low');
    } else if (clamped < 70) {
      brightnessIconWrap.innerHTML = getSunSVG('med');
    } else {
      brightnessIconWrap.innerHTML = getSunSVG('high');
    }

    if (isVisible) {
      gsap.to(hudBrightness, { opacity: 1, scale: 1, duration: 0.3, ease: 'power2.out' });
    } else {
      gsap.to(hudBrightness, { opacity: 0, scale: 0.9, duration: 0.25, ease: 'power2.in' });
    }
  }

  // Volume HUD
  function setVolume(pct0to100, isMuted = false, isVisible = true) {
    const clamped = Math.max(0, Math.min(100, Math.round(pct0to100)));
    volumeFill.style.width = isMuted ? '0%' : clamped + '%';
    volumeVal.textContent = isMuted ? 'Muted' : clamped + '%';

    if (isMuted) {
      volumeIconWrap.innerHTML = getSpeakerSVG('muted');
      volumeFill.style.background = '#FF453A';
    } else {
      volumeFill.style.background = '#0A84FF';
      if (clamped === 0) {
        volumeIconWrap.innerHTML = getSpeakerSVG('zero');
      } else if (clamped < 35) {
        volumeIconWrap.innerHTML = getSpeakerSVG('low');
      } else if (clamped < 70) {
        volumeIconWrap.innerHTML = getSpeakerSVG('med');
      } else {
        volumeIconWrap.innerHTML = getSpeakerSVG('high');
      }
    }

    if (isVisible) {
      gsap.to(hudVolume, { opacity: 1, scale: 1, duration: 0.3, ease: 'power2.out' });
    } else {
      gsap.to(hudVolume, { opacity: 0, scale: 0.9, duration: 0.25, ease: 'power2.in' });
    }
  }

  // Media Transport HUD
  function showMediaHUD(trackName, artistName, actionBadge = 'Next Track ⏭', isVisible = true) {
    if (isVisible) {
      hudMedia.querySelector('.media-title').textContent = trackName;
      hudMedia.querySelector('.media-artist').textContent = artistName;
      hudMedia.querySelector('.media-controls-badge').textContent = actionBadge;
      gsap.to(hudMedia, { opacity: 1, scale: 1, duration: 0.35, ease: 'back.out(1.2)' });
    } else {
      gsap.to(hudMedia, { opacity: 0, scale: 0.9, duration: 0.25, ease: 'power2.in' });
    }
  }

  // macOS Menu Bar Dropdown (Act 2)
  function showMenubarDropdown(show = true) {
    if (show) {
      gsap.to(menubarDropdown, { opacity: 1, scale: 1, y: 0, duration: 0.45, ease: 'power3.out' });
    } else {
      gsap.to(menubarDropdown, { opacity: 0, scale: 0.92, duration: 0.3, ease: 'power2.in' });
    }
  }

  // Social Proof Cards (Act 3)
  function showSocialProof(show = true) {
    if (show) {
      gsap.to(socialStack, { opacity: 1, duration: 0.5, ease: 'power2.out' });
      gsap.fromTo('.social-card', 
        { y: 30, opacity: 0 },
        { y: 0, opacity: 1, stagger: 0.15, duration: 0.45, ease: 'back.out(1.3)' }
      );
    } else {
      gsap.to(socialStack, { opacity: 0, duration: 0.35, ease: 'power2.in' });
    }
  }

  // Final Call to Action
  function showCTA(show = true) {
    if (show) {
      gsap.to(ctaScreen, { opacity: 1, scale: 1, duration: 0.5, ease: 'back.out(1.4)' });
    } else {
      gsap.to(ctaScreen, { opacity: 0, scale: 0.9, duration: 0.3, ease: 'power2.in' });
    }
  }

  // Helper SVGs matching Apple SF Symbols
  function getSunSVG(level) {
    if (level === 'low') {
      return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>`;
    }
    return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zm0-5c.55 0 1 .45 1 1v1c0 .55-.45 1-1 1s-1-.45-1-1V3c0-.55.45-1 1-1zm0 18c.55 0 1 .45 1 1v1c0 .55-.45 1-1 1s-1-.45-1-1v-1c0-.55.45-1 1-1zM4.22 4.22c.39-.39 1.02-.39 1.41 0l.71.71c.39.39.39 1.02 0 1.41-.39.39-1.02.39-1.41 0l-.71-.71c-.39-.39-.39-1.02 0-1.41zm13.44 13.44c.39-.39 1.02-.39 1.41 0l.71.71c.39.39.39 1.02 0 1.41-.39.39-1.02.39-1.41 0l-.71-.71c-.39-.39-.39-1.02 0-1.41zM2 12c0-.55.45-1 1-1h1c.55 0 1 .45 1 1s-.45 1-1 1H3c-.55 0-1-.45-1-1zm18 0c0-.55.45-1 1-1h1c.55 0 1 .45 1 1s-.45 1-1 1h-1c-.55 0-1-.45-1-1zM5.64 18.36c.39-.39 1.02-.39 1.41 0 .39.39.39 1.02 0 1.41l-.71.71c-.39.39-1.02.39-1.41 0-.39-.39-.39-1.02 0-1.41l.71-.71zM19.07 4.93c.39-.39 1.02-.39 1.41 0 .39.39.39 1.02 0 1.41l-.71.71c-.39.39-1.02.39-1.41 0-.39-.39-.39-1.02 0-1.41l.71-.71z"/></svg>`;
  }

  function getSpeakerSVG(level) {
    if (level === 'muted') {
      return `<svg viewBox="0 0 24 24" fill="none" stroke="#FF453A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>`;
    } else if (level === 'zero') {
      return `<svg viewBox="0 0 24 24" fill="currentColor"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/></svg>`;
    } else if (level === 'low') {
      return `<svg viewBox="0 0 24 24" fill="currentColor"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`;
    }
    return `<svg viewBox="0 0 24 24" fill="currentColor"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`;
  }

  return {
    init,
    showHook,
    showGesturePill,
    setBrightness,
    setVolume,
    showMediaHUD,
    showMenubarDropdown,
    showSocialProof,
    showCTA
  };
})();
