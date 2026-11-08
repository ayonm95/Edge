/**
 * Edge 3D Showcase - Animation Engine (GSAP Core)
 * Deterministic frame-accurate timelines for viral concept reel and standalone gesture clips
 */

window.EdgeAnimations = (function() {
  let masterTimeline = null;
  let currentMode = 'reel'; // 'reel', 'brightness', 'volume', 'media'

  function createReelTimeline(scene) {
    const tl = gsap.timeline({ paused: true });
    const TP_W = EdgeScene.constants.TP_WIDTH;
    const TP_H = EdgeScene.constants.TP_HEIGHT;
    const TP_Z = EdgeScene.constants.TP_Z;
    const TP_Y = EdgeScene.constants.TP_Y;

    const leftX1 = -TP_W / 2 + 0.12;
    const leftX2 = -TP_W / 2 + 0.38;
    const rightX1 = TP_W / 2 - 0.38;
    const rightX2 = TP_W / 2 - 0.12;
    const bottomZ = TP_Z + TP_H / 2 - 0.14;
    const cornerX = TP_W / 2 - 0.25;
    const cornerZ = TP_Z - TP_H / 2 + 0.25;

    // Reset all elements
    tl.set({}, {
      onComplete: () => {
        scene.setPuckVisibility(0, 0);
        scene.setEdgeGlow('left', 0);
        scene.setEdgeGlow('right', 0);
        scene.setEdgeGlow('bottom', 0);
        scene.setEdgeGlow('corner', 0);
        scene.setScreenBrightness(0.35);
        EdgeHUD.showHook(false);
        EdgeHUD.showGesturePill('', '', '50%', '78%', false);
        EdgeHUD.setBrightness(35, false);
        EdgeHUD.setVolume(50, false, false);
        EdgeHUD.showMediaHUD('', '', '', false);
        EdgeHUD.showMenubarDropdown(false);
        EdgeHUD.showSocialProof(false);
        EdgeHUD.showCTA(false);
      }
    }, 0);

    // ==========================================
    // 0.0s - 0.8s: HOOK & INTRO
    // ==========================================
    tl.call(() => {
      EdgeHUD.showHook(true);
      scene.setCameraView('top-down-reel');
    }, null, 0.2);

    // ==========================================
    // 0.8s - 3.8s: ACT 1A - LEFT EDGE (BRIGHTNESS)
    // ==========================================
    tl.call(() => {
      EdgeHUD.showGesturePill('✌️', '2-Finger Slide: Display Brightness', '30%', '76%', true);
      scene.setEdgeGlow('left', 0.9, 0xff9f0a);
    }, null, 0.8);

    // Fingers approach & land on left edge
    const puckProgress = { z: TP_Z + 0.9, bright: 35, glow: 0 };
    tl.fromTo(puckProgress, 
      { z: TP_Z + 1.1, glow: 0 },
      { 
        z: TP_Z + 0.9, 
        glow: 0.9,
        duration: 0.35, 
        ease: 'power2.out',
        onUpdate: () => {
          scene.setPuckPositions(leftX1, puckProgress.z, leftX2, puckProgress.z);
          scene.setPuckVisibility(puckProgress.glow, puckProgress.glow, 0xff9f0a);
        }
      }, 
      1.1
    );

    // Sliding fingers upward along left edge (Brightness 35% -> 88%)
    tl.to(puckProgress, {
      z: TP_Z - 0.9,
      bright: 88,
      duration: 1.6,
      ease: 'power1.inOut',
      onUpdate: () => {
        scene.setPuckPositions(leftX1, puckProgress.z, leftX2, puckProgress.z);
        scene.setScreenBrightness(puckProgress.bright / 100);
        EdgeHUD.setBrightness(puckProgress.bright, true);
      }
    }, 1.5);

    // Fingers lift & settle
    tl.to(puckProgress, {
      glow: 0,
      duration: 0.3,
      onUpdate: () => {
        scene.setPuckVisibility(puckProgress.glow, puckProgress.glow, 0xff9f0a);
      },
      onComplete: () => {
        scene.setEdgeGlow('left', 0);
        EdgeHUD.setBrightness(88, false);
        EdgeHUD.showGesturePill('', '', '50%', '78%', false);
      }
    }, 3.3);

    // ==========================================
    // 3.8s - 6.8s: ACT 1B - RIGHT EDGE (VOLUME & HAPTICS)
    // ==========================================
    tl.call(() => {
      EdgeHUD.showGesturePill('✌️', '2-Finger Slide: Audio Volume + Haptics', '70%', '76%', true);
      scene.setEdgeGlow('right', 0.9, 0x0a84ff);
    }, null, 3.8);

    const volProgress = { z: TP_Z + 0.9, vol: 30, glow: 0 };
    tl.fromTo(volProgress,
      { z: TP_Z + 1.1, glow: 0 },
      {
        z: TP_Z + 0.9,
        glow: 0.9,
        duration: 0.35,
        ease: 'power2.out',
        onUpdate: () => {
          scene.setPuckPositions(rightX1, volProgress.z, rightX2, volProgress.z);
          scene.setPuckVisibility(volProgress.glow, volProgress.glow, 0x0a84ff);
        }
      },
      4.1
    );

    // Upward sliding with discrete haptic click shockwaves
    tl.to(volProgress, {
      z: TP_Z - 0.8,
      vol: 82,
      duration: 1.6,
      ease: 'power1.inOut',
      onUpdate: () => {
        scene.setPuckPositions(rightX1, volProgress.z, rightX2, volProgress.z);
        EdgeHUD.setVolume(volProgress.vol, false, true);
        // Trigger haptic shockwave tick at intervals
        if (Math.random() < 0.28) {
          scene.triggerHapticRipple(rightX2, volProgress.z, 0x0a84ff);
        }
      }
    }, 4.5);

    // Fingers lift
    tl.to(volProgress, {
      glow: 0,
      duration: 0.3,
      onUpdate: () => {
        scene.setPuckVisibility(volProgress.glow, volProgress.glow, 0x0a84ff);
      },
      onComplete: () => {
        scene.setEdgeGlow('right', 0);
        EdgeHUD.setVolume(82, false, false);
        EdgeHUD.showGesturePill('', '', '50%', '78%', false);
      }
    }, 6.3);

    // ==========================================
    // 6.8s - 8.6s: ACT 1C - TOP-RIGHT CORNER QUICK MUTE
    // ==========================================
    tl.call(() => {
      EdgeHUD.showGesturePill('☝️', 'Double-Tap Corner: Quick Mute', '75%', '35%', true);
      scene.setEdgeGlow('corner', 0.9, 0xff453a);
    }, null, 6.8);

    // Single finger tap 1 -> Mute
    tl.call(() => {
      scene.setPuckPositions(cornerX, cornerZ, cornerX, cornerZ);
      scene.setPuckVisibility(0.95, 0, 0xff453a);
      scene.triggerHapticRipple(cornerX, cornerZ, 0xff453a);
      EdgeHUD.setVolume(0, true, true);
    }, null, 7.2);

    tl.call(() => {
      scene.setPuckVisibility(0, 0);
    }, null, 7.4);

    // Single finger tap 2 -> Unmute back to 82%
    tl.call(() => {
      scene.setPuckPositions(cornerX, cornerZ, cornerX, cornerZ);
      scene.setPuckVisibility(0.95, 0, 0x30d158);
      scene.triggerHapticRipple(cornerX, cornerZ, 0x30d158);
      EdgeHUD.setVolume(82, false, true);
    }, null, 7.7);

    tl.call(() => {
      scene.setPuckVisibility(0, 0);
      scene.setEdgeGlow('corner', 0);
      EdgeHUD.setVolume(82, false, false);
      EdgeHUD.showGesturePill('', '', '50%', '78%', false);
    }, null, 8.3);

    // ==========================================
    // 8.6s - 10.8s: ACT 1D - BOTTOM STRIP MEDIA SWIPE
    // ==========================================
    tl.call(() => {
      EdgeHUD.showGesturePill('✌️', '2-Finger Swipe: Next Track', '50%', '82%', true);
      scene.setEdgeGlow('bottom', 0.9, 0xbf5af2);
    }, null, 8.6);

    const mediaProgress = { x: -1.2, glow: 0 };
    tl.fromTo(mediaProgress,
      { x: -1.5, glow: 0 },
      {
        x: -1.0,
        glow: 0.9,
        duration: 0.3,
        onUpdate: () => {
          scene.setPuckPositions(mediaProgress.x, bottomZ, mediaProgress.x + 0.35, bottomZ);
          scene.setPuckVisibility(mediaProgress.glow, mediaProgress.glow, 0xbf5af2);
        }
      },
      8.9
    );

    // Horizontal swipe right (Skip to next track)
    tl.to(mediaProgress, {
      x: 1.0,
      duration: 0.8,
      ease: 'power2.out',
      onUpdate: () => {
        scene.setPuckPositions(mediaProgress.x, bottomZ, mediaProgress.x + 0.35, bottomZ);
      },
      onComplete: () => {
        scene.triggerHapticRipple(1.0, bottomZ, 0xbf5af2);
        EdgeHUD.showMediaHUD('The Last Goodbye', 'ODESZA', 'Next Track ⏭', true);
      }
    }, 9.2);

    // Fade out media HUD
    tl.to(mediaProgress, {
      glow: 0,
      duration: 0.3,
      onUpdate: () => {
        scene.setPuckVisibility(mediaProgress.glow, mediaProgress.glow, 0xbf5af2);
      },
      onComplete: () => {
        scene.setEdgeGlow('bottom', 0);
        EdgeHUD.showGesturePill('', '', '50%', '78%', false);
      }
    }, 10.3);

    tl.call(() => {
      EdgeHUD.showMediaHUD('', '', '', false);
    }, null, 10.7);

    // ==========================================
    // 10.8s - 13.5s: ACT 2 - MENU BAR & CONTROL PANEL
    // ==========================================
    tl.call(() => {
      scene.setCameraView('menubar-focus');
      EdgeHUD.showMenubarDropdown(true);
    }, null, 10.9);

    tl.call(() => {
      EdgeHUD.showMenubarDropdown(false);
    }, null, 13.3);

    // ==========================================
    // 13.5s - 16.0s: ACT 3 - SOCIAL PROOF & CTA
    // ==========================================
    tl.call(() => {
      scene.resetCamera();
      EdgeHUD.showSocialProof(true);
    }, null, 13.5);

    tl.call(() => {
      EdgeHUD.showSocialProof(false);
      EdgeHUD.showCTA(true);
    }, null, 14.8);

    return tl;
  }

  // Standalone Brightness Clip (6s)
  function createBrightnessTimeline(scene) {
    const tl = gsap.timeline({ paused: true });
    const TP_W = EdgeScene.constants.TP_WIDTH;
    const TP_Z = EdgeScene.constants.TP_Z;
    const leftX1 = -TP_W / 2 + 0.12;
    const leftX2 = -TP_W / 2 + 0.38;

    tl.set({}, {
      onComplete: () => {
        scene.setPuckVisibility(0, 0);
        scene.setEdgeGlow('left', 0);
        scene.setScreenBrightness(0.25);
        EdgeHUD.setBrightness(25, false);
        EdgeHUD.showGesturePill('✌️', '2-Finger Slide Left Edge: Brightness', '30%', '75%', false);
      }
    }, 0);

    tl.call(() => {
      scene.setCameraView('left-focus');
      EdgeHUD.showGesturePill('✌️', '2-Finger Slide Left Edge: Brightness', '30%', '75%', true);
      scene.setEdgeGlow('left', 0.95, 0xff9f0a);
    }, null, 0.4);

    const prog = { z: TP_Z + 1.0, b: 25, glow: 0 };
    tl.to(prog, {
      glow: 0.95,
      duration: 0.4,
      onUpdate: () => {
        scene.setPuckPositions(leftX1, prog.z, leftX2, prog.z);
        scene.setPuckVisibility(prog.glow, prog.glow, 0xff9f0a);
      }
    }, 0.8);

    tl.to(prog, {
      z: TP_Z - 0.9,
      b: 92,
      duration: 3.2,
      ease: 'power1.inOut',
      onUpdate: () => {
        scene.setPuckPositions(leftX1, prog.z, leftX2, prog.z);
        scene.setScreenBrightness(prog.b / 100);
        EdgeHUD.setBrightness(prog.b, true);
      }
    }, 1.2);

    tl.to(prog, {
      glow: 0,
      duration: 0.5,
      onUpdate: () => {
        scene.setPuckVisibility(prog.glow, prog.glow, 0xff9f0a);
      },
      onComplete: () => {
        scene.setEdgeGlow('left', 0);
        EdgeHUD.setBrightness(92, false);
        EdgeHUD.showGesturePill('', '', '30%', '75%', false);
      }
    }, 4.8);

    return tl;
  }

  // Standalone Volume Clip (6s)
  function createVolumeTimeline(scene) {
    const tl = gsap.timeline({ paused: true });
    const TP_W = EdgeScene.constants.TP_WIDTH;
    const TP_Z = EdgeScene.constants.TP_Z;
    const rightX1 = TP_W / 2 - 0.38;
    const rightX2 = TP_W / 2 - 0.12;

    tl.set({}, {
      onComplete: () => {
        scene.setPuckVisibility(0, 0);
        scene.setEdgeGlow('right', 0);
        EdgeHUD.setVolume(20, false, false);
        EdgeHUD.showGesturePill('', '', '70%', '75%', false);
      }
    }, 0);

    tl.call(() => {
      scene.setCameraView('right-focus');
      EdgeHUD.showGesturePill('✌️', '2-Finger Slide Right Edge: Volume + Haptics', '70%', '75%', true);
      scene.setEdgeGlow('right', 0.95, 0x0a84ff);
    }, null, 0.4);

    const prog = { z: TP_Z + 1.0, v: 20, glow: 0 };
    tl.to(prog, {
      glow: 0.95,
      duration: 0.4,
      onUpdate: () => {
        scene.setPuckPositions(rightX1, prog.z, rightX2, prog.z);
        scene.setPuckVisibility(prog.glow, prog.glow, 0x0a84ff);
      }
    }, 0.8);

    tl.to(prog, {
      z: TP_Z - 0.9,
      v: 85,
      duration: 3.2,
      ease: 'power1.inOut',
      onUpdate: () => {
        scene.setPuckPositions(rightX1, prog.z, rightX2, prog.z);
        EdgeHUD.setVolume(prog.v, false, true);
        if (Math.random() < 0.25) {
          scene.triggerHapticRipple(rightX2, prog.z, 0x0a84ff);
        }
      }
    }, 1.2);

    tl.to(prog, {
      glow: 0,
      duration: 0.5,
      onUpdate: () => {
        scene.setPuckVisibility(prog.glow, prog.glow, 0x0a84ff);
      },
      onComplete: () => {
        scene.setEdgeGlow('right', 0);
        EdgeHUD.setVolume(85, false, false);
        EdgeHUD.showGesturePill('', '', '70%', '75%', false);
      }
    }, 4.8);

    return tl;
  }

  // Standalone Media Clip (6s)
  function createMediaTimeline(scene) {
    const tl = gsap.timeline({ paused: true });
    const TP_H = EdgeScene.constants.TP_HEIGHT;
    const TP_Z = EdgeScene.constants.TP_Z;
    const bottomZ = TP_Z + TP_H / 2 - 0.14;

    tl.set({}, {
      onComplete: () => {
        scene.setPuckVisibility(0, 0);
        scene.setEdgeGlow('bottom', 0);
        EdgeHUD.showMediaHUD('', '', '', false);
        EdgeHUD.showGesturePill('', '', '50%', '82%', false);
      }
    }, 0);

    tl.call(() => {
      scene.setCameraView('bottom-focus');
      EdgeHUD.showGesturePill('✌️', '2-Finger Swipe: Skip Tracks', '50%', '82%', true);
      scene.setEdgeGlow('bottom', 0.95, 0xbf5af2);
    }, null, 0.4);

    const prog = { x: -1.4, glow: 0 };
    tl.to(prog, {
      glow: 0.95,
      duration: 0.4,
      onUpdate: () => {
        scene.setPuckPositions(prog.x, bottomZ, prog.x + 0.35, bottomZ);
        scene.setPuckVisibility(prog.glow, prog.glow, 0xbf5af2);
      }
    }, 0.8);

    tl.to(prog, {
      x: 1.2,
      duration: 1.2,
      ease: 'power2.out',
      onUpdate: () => {
        scene.setPuckPositions(prog.x, bottomZ, prog.x + 0.35, bottomZ);
      },
      onComplete: () => {
        scene.triggerHapticRipple(1.2, bottomZ, 0xbf5af2);
        EdgeHUD.showMediaHUD('Veridis Quo', 'Daft Punk', 'Next Track ⏭', true);
      }
    }, 1.4);

    // Quick tap to pause
    tl.call(() => {
      scene.setPuckPositions(0, bottomZ, 0.35, bottomZ);
      scene.triggerHapticRipple(0.17, bottomZ, 0xffffff);
      EdgeHUD.showMediaHUD('Veridis Quo', 'Daft Punk', 'Paused ⏸', true);
    }, null, 3.4);

    tl.to(prog, {
      glow: 0,
      duration: 0.5,
      onUpdate: () => {
        scene.setPuckVisibility(prog.glow, prog.glow, 0xbf5af2);
      },
      onComplete: () => {
        scene.setEdgeGlow('bottom', 0);
        EdgeHUD.showMediaHUD('', '', '', false);
        EdgeHUD.showGesturePill('', '', '50%', '82%', false);
      }
    }, 4.8);

    return tl;
  }

  function initTimeline(mode, sceneInstance) {
    if (masterTimeline) {
      masterTimeline.kill();
    }
    currentMode = mode;
    if (mode === 'brightness') {
      masterTimeline = createBrightnessTimeline(sceneInstance);
    } else if (mode === 'volume') {
      masterTimeline = createVolumeTimeline(sceneInstance);
    } else if (mode === 'media') {
      masterTimeline = createMediaTimeline(sceneInstance);
    } else {
      masterTimeline = createReelTimeline(sceneInstance);
    }
    return masterTimeline;
  }

  return {
    initTimeline,
    getTimeline: () => masterTimeline,
    getMode: () => currentMode
  };
})();
