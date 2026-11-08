/**
 * Edge 3D Video Rendering Pipeline
 * Uses Puppeteer-Core with Headless Google Chrome to render frame-by-frame 60 FPS WebGL animations
 * and encodes with ffmpeg (H.264, yuv420p) for broadcast-grade social media videos.
 */

const puppeteer = require('puppeteer-core');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const OUTPUT_DIR = path.resolve(__dirname, '../showcase/videos');
const FRAMES_DIR = path.resolve(__dirname, '../showcase/frames');
const AUDIO_PATH = path.resolve(__dirname, '../showcase/reference/audio.mp3');

// Ensure output dirs exist
fs.mkdirSync(OUTPUT_DIR, { recursive: true });
fs.mkdirSync(FRAMES_DIR, { recursive: true });

async function renderSequence({
  name,
  mode = 'reel',
  aspect = '9:16', // '9:16' (1080x1920) or '16:9' (1920x1080)
  fps = 30,        // 30 or 60 fps
  duration = null, // if null, auto-detect from timeline
  includeAudio = false
}) {
  const isVertical = aspect === '9:16';
  const width = isVertical ? 1080 : 1920;
  const height = isVertical ? 1920 : 1080;

  console.log(`\n==================================================`);
  console.log(`Rendering: ${name}`);
  console.log(`Mode: ${mode} | Aspect: ${aspect} (${width}x${height}) | FPS: ${fps}`);
  console.log(`==================================================`);

  // Clean previous frames in FRAMES_DIR
  const oldFiles = fs.readdirSync(FRAMES_DIR);
  for (const f of oldFiles) {
    if (f.endsWith('.jpg') || f.endsWith('.png')) {
      fs.unlinkSync(path.join(FRAMES_DIR, f));
    }
  }

  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: [
      '--use-gl=angle',
      '--use-angle=metal',
      '--no-sandbox',
      '--disable-web-security',
      `--window-size=${width},${height}`
    ]
  });

  const page = await browser.newPage();
  await page.setViewport({ width, height, deviceScaleFactor: 1 });

  const indexPath = 'file://' + path.resolve(__dirname, '../showcase/index.html');
  await page.goto(indexPath, { waitUntil: 'load' });
  await new Promise(r => setTimeout(r, 600));

  // Configure stage aspect ratio
  await page.evaluate((vert) => {
    const stage = document.getElementById('stage');
    if (vert) {
      stage.classList.remove('mode-landscape');
      stage.classList.add('mode-vertical');
    } else {
      stage.classList.remove('mode-vertical');
      stage.classList.add('mode-landscape');
    }
    // Hide controls bar during video export
    const controls = document.getElementById('controls-bar');
    if (controls) controls.style.display = 'none';
    window.dispatchEvent(new Event('resize'));
  }, isVertical);

  // Set mode & get total duration
  const totalDuration = await page.evaluate((m) => {
    return window.__EDGE_SET_MODE__(m);
  }, mode);

  const renderDuration = duration || totalDuration;
  const totalFrames = Math.ceil(renderDuration * fps);
  console.log(`Total duration: ${renderDuration.toFixed(2)}s (${totalFrames} frames)`);

  const startTime = Date.now();

  for (let frameIndex = 0; frameIndex < totalFrames; frameIndex++) {
    const timeSec = frameIndex / fps;
    await page.evaluate((t) => {
      window.__EDGE_SEEK__(t);
    }, timeSec);

    // Frame capture using JPEG quality 95 for ultra-fast writing
    const frameNumber = String(frameIndex).padStart(5, '0');
    const framePath = path.join(FRAMES_DIR, `frame_${frameNumber}.jpg`);

    await page.screenshot({
      path: framePath,
      type: 'jpeg',
      quality: 95
    });

    if (frameIndex % 30 === 0 || frameIndex === totalFrames - 1) {
      const pct = ((frameIndex + 1) / totalFrames * 100).toFixed(1);
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      process.stdout.write(`\rCapturing frames: ${frameIndex + 1}/${totalFrames} (${pct}%) [${elapsed}s]`);
    }
  }
  console.log('\nFrame capture complete. Closing Chrome...');
  await browser.close();

  // FFmpeg H.264 Universal Encode
  const outputPath = path.join(OUTPUT_DIR, `${name}.mp4`);
  console.log(`Encoding MP4 via ffmpeg to: ${outputPath}`);

  const hasAudio = includeAudio && fs.existsSync(AUDIO_PATH);
  let ffmpegCmd;

  if (hasAudio) {
    ffmpegCmd = `ffmpeg -y -framerate ${fps} -i "${FRAMES_DIR}/frame_%05d.jpg" -i "${AUDIO_PATH}" -c:v libx264 -profile:v high -level 4.2 -preset fast -crf 19 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest "${outputPath}"`;
  } else {
    ffmpegCmd = `ffmpeg -y -framerate ${fps} -i "${FRAMES_DIR}/frame_%05d.jpg" -c:v libx264 -profile:v high -level 4.2 -preset fast -crf 19 -pix_fmt yuv420p "${outputPath}"`;
  }

  execSync(ffmpegCmd, { stdio: 'inherit' });

  // Clean frames
  const filesToDelete = fs.readdirSync(FRAMES_DIR);
  for (const f of filesToDelete) {
    if (f.endsWith('.jpg')) {
      fs.unlinkSync(path.join(FRAMES_DIR, f));
    }
  }

  const stat = fs.statSync(outputPath);
  console.log(`Successfully generated ${name}.mp4 (${(stat.size / 1024 / 1024).toFixed(2)} MB)\n`);
  return outputPath;
}

async function main() {
  const args = process.argv.slice(2);
  const target = args[0] || 'all';

  if (target === 'reel' || target === 'all') {
    // 1. Full Viral Concept Reel (1080x1920 9:16 vertical with audio, 16s)
    await renderSequence({
      name: 'edge_concept_reel_1080x1920',
      mode: 'reel',
      aspect: '9:16',
      fps: 30,
      duration: 16.0,
      includeAudio: true
    });
  }

  if (target === 'brightness' || target === 'all') {
    // 2. Left Edge Brightness Clip (1920x1080 16:9 widescreen, ~5.2s)
    await renderSequence({
      name: 'edge_brightness_gesture_3d',
      mode: 'brightness',
      aspect: '16:9',
      fps: 30,
      duration: 5.2,
      includeAudio: false
    });
  }

  if (target === 'volume' || target === 'all') {
    // 3. Right Edge Volume & Haptics Clip (1920x1080 16:9 widescreen, ~5.2s)
    await renderSequence({
      name: 'edge_volume_gesture_3d',
      mode: 'volume',
      aspect: '16:9',
      fps: 30,
      duration: 5.2,
      includeAudio: false
    });
  }

  if (target === 'media' || target === 'all') {
    // 4. Bottom Strip Media Clip (1920x1080 16:9 widescreen, ~5.2s)
    await renderSequence({
      name: 'edge_media_gesture_3d',
      mode: 'media',
      aspect: '16:9',
      fps: 30,
      duration: 5.2,
      includeAudio: false
    });
  }

  console.log('All requested videos rendered successfully!');
}

main().catch(err => {
  console.error('Fatal render error:', err);
  process.exit(1);
});
