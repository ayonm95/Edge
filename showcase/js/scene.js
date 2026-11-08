/**
 * Edge 3D Showcase - Scene Engine
 * High-fidelity Three.js procedural Space Gray MacBook Pro, Glass Trackpad, Dual Touch Pucks, & Studio Lighting
 */

window.EdgeScene = (function() {
  let scene, camera, renderer, container;
  let macbookGroup, trackpadMesh, trackpadBorder;
  let edgeLeftHighlight, edgeRightHighlight, edgeBottomHighlight, cornerMuteHighlight;
  let fingerPuck1, fingerPuck2, hapticRings = [];
  let screenLight, studioKeyLight, studioRimLight, trackpadSpotLight;
  let screenMesh, screenMaterial;
  let controls;
  let isOrbiting = false;

  // Trackpad dimensions in 3D world units
  const TP_WIDTH = 5.2;
  const TP_HEIGHT = 3.4;
  const TP_Y = 0.05; // slightly above base
  const TP_Z = 1.1;  // offset forward on chassis

  function init(containerElement) {
    container = containerElement;

    // 1. Scene
    scene = new THREE.Scene();
    scene.background = null; // transparent to show CSS gradient

    // 2. Camera (Perspective with realistic focal length)
    const aspect = container.clientWidth / container.clientHeight;
    camera = new THREE.PerspectiveCamera(38, aspect, 0.1, 100);
    // Default cinematic top-down 3/4 perspective
    camera.position.set(0, 7.8, 6.2);
    camera.lookAt(0, 0, 0.6);

    // 3. Renderer with ACESFilmicToneMapping and Retina DPR
    renderer = new THREE.WebGLRenderer({
      canvas: document.getElementById('webgl-canvas'),
      antialias: true,
      alpha: true,
      powerPreference: 'high-performance'
    });
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.1;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    // 4. Studio Lighting Rig
    setupLighting();

    // 5. Construct 3D MacBook Pro & Trackpad
    buildMacBook();

    // 6. Dual Biometric Touch Pucks & Ripple System
    buildTouchPucks();

    // 7. Orbit Controls (Optional interactive mode)
    if (window.THREE.OrbitControls) {
      controls = new THREE.OrbitControls(camera, renderer.domElement);
      controls.enableDamping = true;
      controls.dampingFactor = 0.05;
      controls.maxPolarAngle = Math.PI / 2.05;
      controls.minDistance = 3.5;
      controls.maxDistance = 14;
      controls.target.set(0, 0, 0.6);
      controls.enabled = false; // enabled when user toggles 3D orbit
    }

    // Window resize handler
    window.addEventListener('resize', onResize);

    // Render loop
    animateLoop();

    return {
      scene,
      camera,
      renderer,
      setPuckPositions,
      setPuckVisibility,
      setEdgeGlow,
      setScreenBrightness,
      triggerHapticRipple,
      resetCamera,
      setCameraView,
      enableOrbitControls
    };
  }

  function setupLighting() {
    // Ambient light (subtle deep studio fill)
    const ambientLight = new THREE.AmbientLight(0x22222e, 1.2);
    scene.add(ambientLight);

    // Main Studio Key Light (Cool white soft illumination)
    studioKeyLight = new THREE.DirectionalLight(0xffffff, 2.2);
    studioKeyLight.position.set(4, 9, 5);
    studioKeyLight.castShadow = true;
    studioKeyLight.shadow.mapSize.width = 2048;
    studioKeyLight.shadow.mapSize.height = 2048;
    studioKeyLight.shadow.camera.near = 0.5;
    studioKeyLight.shadow.camera.far = 25;
    studioKeyLight.shadow.bias = -0.0001;
    scene.add(studioKeyLight);

    // Specular Rim Light (Electric cyan-blue rim highlight on chamfers)
    studioRimLight = new THREE.DirectionalLight(0x4080ff, 1.8);
    studioRimLight.position.set(-6, 7, -4);
    scene.add(studioRimLight);

    // Trackpad Overhead Spotlight (Focuses crisp specular shine on trackpad glass)
    trackpadSpotLight = new THREE.SpotLight(0xffffff, 1.6, 12, Math.PI / 6, 0.35, 1);
    trackpadSpotLight.position.set(0, 6, 1.1);
    trackpadSpotLight.target.position.set(0, 0, 1.1);
    scene.add(trackpadSpotLight);
    scene.add(trackpadSpotLight.target);

    // Screen Bounce Point Light (Reacts directly to screen brightness)
    screenLight = new THREE.PointLight(0xffffff, 0.8, 8, 1.8);
    screenLight.position.set(0, 2.2, -1.8);
    scene.add(screenLight);
  }

  function buildMacBook() {
    macbookGroup = new THREE.Group();

    // Space Gray Anodized Aluminum Material
    const aluminumMaterial = new THREE.MeshStandardMaterial({
      color: 0x1d1e22,
      metalness: 0.85,
      roughness: 0.30,
      envMapIntensity: 1.0
    });

    // Darker Interior Keyboard Well Material
    const wellMaterial = new THREE.MeshStandardMaterial({
      color: 0x121316,
      metalness: 0.7,
      roughness: 0.45
    });

    // 1. Lower Chassis (Base unibody)
    // 9.2 width x 0.28 height x 6.4 depth (proportional to 16" MacBook Pro)
    const baseGeo = createRoundedBoxGeometry(9.6, 0.28, 6.6, 0.16, 8);
    const baseMesh = new THREE.Mesh(baseGeo, aluminumMaterial);
    baseMesh.position.y = -0.14;
    baseMesh.receiveShadow = true;
    macbookGroup.add(baseMesh);

    // 2. Keyboard Well Inset
    const wellGeo = createRoundedBoxGeometry(8.6, 0.05, 3.2, 0.08, 4);
    const wellMesh = new THREE.Mesh(wellGeo, wellMaterial);
    wellMesh.position.set(0, 0.01, -1.2);
    macbookGroup.add(wellMesh);

    // Subtle Keycap Grid Simulation
    buildKeyboardKeys(wellMesh);

    // 3. Recessed Frosted Glass Trackpad
    // Apple Trackpad: large haptic Force Touch surface
    const tpGeo = createRoundedBoxGeometry(TP_WIDTH, 0.02, TP_HEIGHT, 0.08, 6);
    const trackpadMaterial = new THREE.MeshStandardMaterial({
      color: 0x25272e,
      roughness: 0.22,
      metalness: 0.35,
      envMapIntensity: 1.5
    });
    trackpadMesh = new THREE.Mesh(tpGeo, trackpadMaterial);
    trackpadMesh.position.set(0, TP_Y, TP_Z);
    trackpadMesh.receiveShadow = true;
    macbookGroup.add(trackpadMesh);

    // Trackpad Fine Metallic Border Inset
    const borderGeo = new THREE.RingGeometry(0.1, 0.12, 4); // placeholder or fine line
    const borderMat = new THREE.MeshBasicMaterial({ color: 0x444855, transparent: true, opacity: 0.4 });

    // Edge Active Highlight Strips (Neon overlays for active edge gesture regions)
    // Left Edge Strip (Orange Brightness)
    const edgeVertGeo = new THREE.PlaneGeometry(0.15, TP_HEIGHT * 0.96);
    const leftMat = new THREE.MeshBasicMaterial({
      color: 0xff9f0a,
      transparent: true,
      opacity: 0,
      side: THREE.DoubleSide
    });
    edgeLeftHighlight = new THREE.Mesh(edgeVertGeo, leftMat);
    edgeLeftHighlight.rotation.x = -Math.PI / 2;
    edgeLeftHighlight.position.set(-TP_WIDTH / 2 + 0.08, TP_Y + 0.015, TP_Z);
    macbookGroup.add(edgeLeftHighlight);

    // Right Edge Strip (Blue Volume)
    const rightMat = new THREE.MeshBasicMaterial({
      color: 0x0a84ff,
      transparent: true,
      opacity: 0,
      side: THREE.DoubleSide
    });
    edgeRightHighlight = new THREE.Mesh(edgeVertGeo, rightMat);
    edgeRightHighlight.rotation.x = -Math.PI / 2;
    edgeRightHighlight.position.set(TP_WIDTH / 2 - 0.08, TP_Y + 0.015, TP_Z);
    macbookGroup.add(edgeRightHighlight);

    // Bottom Edge Strip (Purple Media)
    const edgeHorizGeo = new THREE.PlaneGeometry(TP_WIDTH * 0.94, 0.15);
    const bottomMat = new THREE.MeshBasicMaterial({
      color: 0xbf5af2,
      transparent: true,
      opacity: 0,
      side: THREE.DoubleSide
    });
    edgeBottomHighlight = new THREE.Mesh(edgeHorizGeo, bottomMat);
    edgeBottomHighlight.rotation.x = -Math.PI / 2;
    edgeBottomHighlight.position.set(0, TP_Y + 0.015, TP_Z + TP_HEIGHT / 2 - 0.08);
    macbookGroup.add(edgeBottomHighlight);

    // Top-Right Corner Mute Highlight
    const cornerGeo = new THREE.CircleGeometry(0.25, 16);
    const cornerMat = new THREE.MeshBasicMaterial({
      color: 0xff453a,
      transparent: true,
      opacity: 0,
      side: THREE.DoubleSide
    });
    cornerMuteHighlight = new THREE.Mesh(cornerGeo, cornerMat);
    cornerMuteHighlight.rotation.x = -Math.PI / 2;
    cornerMuteHighlight.position.set(TP_WIDTH / 2 - 0.25, TP_Y + 0.016, TP_Z - TP_HEIGHT / 2 + 0.25);
    macbookGroup.add(cornerMuteHighlight);

    // 4. Laptop Display (Tilted back at authentic 105 degrees)
    const screenHingeAngle = THREE.MathUtils.degToRad(72);
    const screenLid = new THREE.Group();
    screenLid.position.set(0, 0.02, -3.2);

    // Lid Backplate
    const lidGeo = createRoundedBoxGeometry(9.6, 0.18, 6.5, 0.16, 6);
    const lidMesh = new THREE.Mesh(lidGeo, aluminumMaterial);
    lidMesh.position.set(0, 3.2, 0);
    screenLid.add(lidMesh);

    // Display Glass Screen
    const screenGlassGeo = new THREE.PlaneGeometry(9.1, 5.8);
    screenMaterial = new THREE.MeshStandardMaterial({
      color: 0x0a0c14,
      emissive: 0x1a2540,
      emissiveIntensity: 0.6,
      roughness: 0.1,
      metalness: 0.1
    });
    screenMesh = new THREE.Mesh(screenGlassGeo, screenMaterial);
    screenMesh.position.set(0, 3.2, 0.1);
    screenLid.add(screenMesh);

    // Rotate lid to open position
    screenLid.rotation.x = screenHingeAngle;
    macbookGroup.add(screenLid);

    scene.add(macbookGroup);
  }

  function buildKeyboardKeys(parentWell) {
    const keyMat = new THREE.MeshStandardMaterial({
      color: 0x090a0d,
      roughness: 0.6,
      metalness: 0.15
    });

    const rows = 5;
    const cols = 14;
    const keyW = 0.52;
    const keyH = 0.48;
    const gap = 0.08;

    const startX = -((cols - 1) * (keyW + gap)) / 2;
    const startZ = -((rows - 1) * (keyH + gap)) / 2;

    const keyGeo = createRoundedBoxGeometry(keyW, 0.04, keyH, 0.02, 2);

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        // Spacebar row exception
        if (r === rows - 1 && c >= 4 && c <= 9) {
          if (c === 4) {
            const spaceGeo = createRoundedBoxGeometry(keyW * 6 + gap * 5, 0.04, keyH, 0.02, 2);
            const spaceMesh = new THREE.Mesh(spaceGeo, keyMat);
            spaceMesh.position.set(0, 0.03, startZ + r * (keyH + gap));
            parentWell.add(spaceMesh);
          }
          continue;
        }

        const key = new THREE.Mesh(keyGeo, keyMat);
        key.position.set(startX + c * (keyW + gap), 0.03, startZ + r * (keyH + gap));
        parentWell.add(key);
      }
    }
  }

  function buildTouchPucks() {
    // Twin Biometric Neon Touch Pucks (Left Finger & Right Finger)
    const puckRadius = 0.22;

    // Glowing Neon Material (Apple Cyan / White Core with Glass Fresnel)
    const puckMat1 = new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0
    });
    const puckMat2 = new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0
    });

    const puckGeo = new THREE.CylinderGeometry(puckRadius, puckRadius, 0.04, 24);

    fingerPuck1 = new THREE.Mesh(puckGeo, puckMat1);
    fingerPuck2 = new THREE.Mesh(puckGeo, puckMat2);

    // Glowing Outer Corona Rings
    const coronaGeo = new THREE.RingGeometry(puckRadius, puckRadius + 0.14, 32);
    const coronaMat = new THREE.MeshBasicMaterial({
      color: 0x0a84ff,
      transparent: true,
      opacity: 0.85,
      side: THREE.DoubleSide
    });

    const corona1 = new THREE.Mesh(coronaGeo, coronaMat);
    corona1.rotation.x = -Math.PI / 2;
    corona1.position.y = 0.025;
    fingerPuck1.add(corona1);

    const corona2 = new THREE.Mesh(coronaGeo, coronaMat.clone());
    corona2.rotation.x = -Math.PI / 2;
    corona2.position.y = 0.025;
    fingerPuck2.add(corona2);

    fingerPuck1.position.set(0, TP_Y + 0.04, TP_Z);
    fingerPuck2.position.set(0, TP_Y + 0.04, TP_Z);

    macbookGroup.add(fingerPuck1);
    macbookGroup.add(fingerPuck2);

    // Initialize Pool of Haptic Shockwave Rings
    const ringGeo = new THREE.RingGeometry(0.1, 0.15, 32);
    for (let i = 0; i < 8; i++) {
      const ringMat = new THREE.MeshBasicMaterial({
        color: 0x0a84ff,
        transparent: true,
        opacity: 0,
        side: THREE.DoubleSide
      });
      const ringMesh = new THREE.Mesh(ringGeo, ringMat);
      ringMesh.rotation.x = -Math.PI / 2;
      ringMesh.position.set(0, TP_Y + 0.02, TP_Z);
      macbookGroup.add(ringMesh);
      hapticRings.push({ mesh: ringMesh, active: false, life: 0, maxLife: 0.45, startScale: 1, endScale: 3.5 });
    }
  }

  // Rounded Box Procedural Geometry Helper
  function createRoundedBoxGeometry(width, height, depth, radius, smoothness) {
    const shape = new THREE.Shape();
    const eps = 0.00001;
    const radiusClamped = Math.min(radius, width / 2 - eps, depth / 2 - eps);

    const x = -width / 2;
    const y = -depth / 2;
    const w = width;
    const h = depth;
    const r = radiusClamped;

    shape.moveTo(x + r, y);
    shape.lineTo(x + w - r, y);
    shape.quadraticCurveTo(x + w, y, x + w, y + r);
    shape.lineTo(x + w, y + h - r);
    shape.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    shape.lineTo(x + r, y + h);
    shape.quadraticCurveTo(x, y + h, x, y + h - r);
    shape.lineTo(x, y + r);
    shape.quadraticCurveTo(x, y, x + r, y);

    const extrudeSettings = {
      depth: height,
      bevelEnabled: true,
      bevelSegments: smoothness,
      steps: 1,
      bevelSize: r * 0.4,
      bevelThickness: r * 0.4
    };

    const geometry = new THREE.ExtrudeGeometry(shape, extrudeSettings);
    geometry.center();
    geometry.rotateX(Math.PI / 2);
    return geometry;
  }

  // Controller Functions exposed to Animation Timeline
  function setPuckPositions(x1, z1, x2, z2, y = TP_Y + 0.04) {
    fingerPuck1.position.set(x1, y, z1);
    fingerPuck2.position.set(x2, y, z2);
  }

  function setPuckVisibility(opacity1, opacity2 = opacity1, colorHex = 0x0a84ff) {
    fingerPuck1.material.opacity = opacity1;
    fingerPuck2.material.opacity = opacity2;
    if (fingerPuck1.children[0]) {
      fingerPuck1.children[0].material.opacity = opacity1 * 0.85;
      fingerPuck1.children[0].material.color.setHex(colorHex);
    }
    if (fingerPuck2.children[0]) {
      fingerPuck2.children[0].material.opacity = opacity2 * 0.85;
      fingerPuck2.children[0].material.color.setHex(colorHex);
    }
  }

  function setEdgeGlow(edge, opacity, colorHex) {
    if (edge === 'left') {
      edgeLeftHighlight.material.opacity = opacity;
      if (colorHex) edgeLeftHighlight.material.color.setHex(colorHex);
    } else if (edge === 'right') {
      edgeRightHighlight.material.opacity = opacity;
      if (colorHex) edgeRightHighlight.material.color.setHex(colorHex);
    } else if (edge === 'bottom') {
      edgeBottomHighlight.material.opacity = opacity;
      if (colorHex) edgeBottomHighlight.material.color.setHex(colorHex);
    } else if (edge === 'corner') {
      cornerMuteHighlight.material.opacity = opacity;
      if (colorHex) cornerMuteHighlight.material.color.setHex(colorHex);
    }
  }

  function setScreenBrightness(brightness0to1) {
    // Dynamic screen brightness and ambient keyboard illumination
    const intensity = 0.2 + brightness0to1 * 1.8;
    screenLight.intensity = intensity;
    screenMaterial.emissiveIntensity = 0.3 + brightness0to1 * 1.2;
    // Tint ambient illumination slightly warm on high brightness
    if (brightness0to1 > 0.6) {
      screenLight.color.setRGB(1.0, 0.95, 0.88);
    } else {
      screenLight.color.setRGB(0.9, 0.95, 1.0);
    }
  }

  function triggerHapticRipple(x, z, colorHex = 0x0a84ff) {
    // Find available ring
    const ring = hapticRings.find(r => !r.active);
    if (!ring) return;

    ring.active = true;
    ring.life = 0;
    ring.mesh.position.set(x, TP_Y + 0.02, z);
    ring.mesh.scale.set(1, 1, 1);
    ring.mesh.material.opacity = 0.9;
    ring.mesh.material.color.setHex(colorHex);
  }

  function updateHapticRings(dt) {
    hapticRings.forEach(r => {
      if (!r.active) return;
      r.life += dt;
      const progress = r.life / r.maxLife;
      if (progress >= 1) {
        r.active = false;
        r.mesh.material.opacity = 0;
      } else {
        const currentScale = THREE.MathUtils.lerp(r.startScale, r.endScale, Math.sqrt(progress));
        r.mesh.scale.set(currentScale, currentScale, 1);
        r.mesh.material.opacity = (1 - progress) * 0.85;
      }
    });
  }

  function setCameraView(preset) {
    if (!camera) return;
    if (preset === 'top-down-reel') {
      gsap.to(camera.position, { x: 0, y: 7.2, z: 4.8, duration: 1.2, ease: 'power2.inOut' });
      gsap.to(camera, { fov: 36, duration: 1.2, onUpdate: () => camera.updateProjectionMatrix() });
    } else if (preset === 'left-focus') {
      gsap.to(camera.position, { x: -2.8, y: 4.5, z: 3.5, duration: 1.0, ease: 'power2.inOut' });
    } else if (preset === 'right-focus') {
      gsap.to(camera.position, { x: 2.8, y: 4.5, z: 3.5, duration: 1.0, ease: 'power2.inOut' });
    } else if (preset === 'bottom-focus') {
      gsap.to(camera.position, { x: 0, y: 5.2, z: 3.8, duration: 1.0, ease: 'power2.inOut' });
    } else if (preset === 'menubar-focus') {
      gsap.to(camera.position, { x: 0, y: 3.8, z: 2.2, duration: 1.2, ease: 'power2.inOut' });
    }
  }

  function resetCamera() {
    gsap.to(camera.position, { x: 0, y: 7.8, z: 6.2, duration: 1.0, ease: 'power2.out' });
  }

  function enableOrbitControls(enable) {
    if (controls) {
      controls.enabled = enable;
    }
  }

  let clock = new THREE.Clock();

  function animateLoop() {
    requestAnimationFrame(animateLoop);
    const dt = clock.getDelta();

    updateHapticRings(dt);

    if (controls && controls.enabled) {
      controls.update();
    }

    renderer.render(scene, camera);
  }

  function onResize() {
    if (!container || !renderer || !camera) return;
    const width = container.clientWidth;
    const height = container.clientHeight;
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height);
  }

  return {
    init,
    constants: { TP_WIDTH, TP_HEIGHT, TP_Z, TP_Y }
  };
})();
