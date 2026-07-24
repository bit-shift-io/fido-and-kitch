# Art Asset Prompting Guide: 2D Platformer (Kid-Friendly Hybrid Style)

Welcome to the comprehensive guide for generating 2D platformer game assets. This guide outlines the art direction, style parameters, master prompt structures, and theme-specific examples for creating visual assets with a unique visual hierarchy.

---

## 🎨 Art Direction Overview

The visual hierarchy relies on a **high-contrast dual-style approach**:

1. **Foreground & Interactive Elements (Platforms, Items, Hazards, Characters)**
   * **Style:** Vector cartoon style (inspired by shows like *Bluey*).
   * **Characteristics:** Clean graphic shapes, thick rounded outlines, flat fills, or subtle gradients.
   * **Palette:** Bold, highly saturated primary and secondary colors (e.g., ruby red, emerald green, canary yellow, bright cyan).
   * **Goal:** High legibility and instant readability for young players.

2. **Backgrounds & Environmental Parallax Layers**
   * **Style:** Painterly post-impressionist (inspired by Vincent van Gogh).
   * **Characteristics:** Visible textured brushstrokes, swirling impasto techniques, soft diffused lighting, dynamic movement in sky/clouds/walls.
   * **Palette:** Rich, harmonious, slightly softer tones with vibrant swirling highlights.
   * **Goal:** A warm, inviting, artistic world depth that doesn't distract from gameplay elements.

---

## 🛠️ Master Prompt Template

Use this structured prompt format when generating assets. Plug in your specific asset description and theme adjustments into the brackets.

```text
[Specific Asset Description]
-- Style (Foreground): Vector style, thick dark outlines, clean graphic shapes, flat colors with subtle gradients, inspired by Bluey, cartoon style, friendly for kids.
-- Foreground Palette: Bold, saturated, bright primary colors, high contrast, crisp details.
-- Style (Background): Deep perspective, painterly style, visible brushstrokes, swirling impasto, soft diffused light, inspired by Vincent van Gogh, post-impressionist.
-- Composition: [2D sprite, tileable game platform, side-view scene, transparent background].
-- Negative Prompt: Realistic textures, photorealistic, complex 3D render, dark gritty lighting, muted colors, messy lines, pixel art, blurry outlines.
```

---

## 🏰 Theme 1: Medieval & Steampunk Hybrid

Combines rustic stone castle elements with brass, copper, and mechanical clockwork aesthetics.

### 1. Game Platform (Interactive Asset)
> **Prompt:** A floating platform made of medieval carved stone fitted with glowing brass and copper gears.
> 
> * **Foreground Style:** Vector cartoon style, thick rounded outlines, flat clean colors, inspired by Bluey.
> * **Aesthetics:** Saturated bright copper-orange, vibrant turquoise stone, polished brass highlights, kid-friendly look.
> * **Background Style:** Soft painterly distance, swirling Van Gogh style impasto sky, warm sunset tones.
> * **Composition:** Isolated 2D game tile sprite, side view, clean alpha transparency.
> * **Negative Prompt:** Realistic metallic rust, dark grit, photorealism, sharp jagged edges.

### 2. Goal / Level Exit (Interactive Structure)
> **Prompt:** A friendly medieval castle tower gate integrated with a massive steam-powered clock and glowing pressure valves.
> 
> * **Foreground Style:** Clean vector artwork, bold outlines, smooth cartoon shading.
> * **Aesthetics:** Canary yellow brass, cobalt blue iron, cheerful and bright color palette.
> * **Background Style:** Van Gogh painterly style, swirling golden night sky with soft impasto stars.
> * **Composition:** Isolated 2D structure sprite, centered side view.
> * **Negative Prompt:** Dark fantasy, realistic textures, mud, smoke soot.

---

## 💎 Theme 2: Underground Cave Settings

Subterranean worlds require high contrast so vector elements stand out against colorful painterly cave walls.

### 1. Collectible / Breakable Asset
> **Prompt:** A cluster of glowing crystal stalactites growing from a rocky ceiling tile.
> 
> * **Foreground Style:** Crisp 2D vector style, bold dark outlines, vibrant graphic art, friendly cartoon style.
> * **Aesthetics:** Electric neon magenta, turquoise blue, bright lime green highlights, inner light glow.
> * **Background Style:** Deep painterly cave background, swirling Van Gogh texture in deep violet and indigo.
> * **Composition:** Top-hanging 2D tileable game sprite, side view.
> * **Negative Prompt:** Real cave photography, gloomy dark shadows, brown muddy textures.

### 2. Bounce Pad / Hazard
> **Prompt:** A giant glowing cartoon mushroom used as a spring pad.
> 
> * **Foreground Style:** Vector cartoon, thick line art, clean graphic design.
> * **Aesthetics:** Vibrant polka-dot red cap, bright yellow stem, neon glow ring.
> * **Background Style:** Impasto painterly cave background with swirling bioluminescent dust particles.
> * **Composition:** Ground-placed 2D sprite, side perspective.

---

## 🚀 Theme 3: Sci-Fi & High-Tech

Hard-surface technology translated into soft, approachable vector forms.

### 1. Interactive Platform / Jump Pad
> **Prompt:** A hover platform with floating magnetic rings and glowing arrow indicators.
> 
> * **Foreground Style:** Vector art style, clean lines, smooth rounded geometric shapes, Bluey cartoon aesthetic.
> * **Aesthetics:** Bright cyan blue, hot pink accents, sunny yellow glowing arrows, bright and cheerful.
> * **Background Style:** Van Gogh post-impressionist nebula, swirling cosmic clouds of violet and teal.
> * **Composition:** Floating 2D sprite, side view.
> * **Negative Prompt:** Gritty cyberpunk, rusty metal, photorealistic 3D, military sci-fi.

---

## 🖼️ Theme 4: Full Environmental Backgrounds

Background scenes should drop the vector outlines entirely and focus purely on the painterly Van Gogh aesthetic to establish world depth.

### Medieval Countryside Background
> **Prompt:** A sprawling medieval landscape with rolling hills, distant castle turrets, and a winding river under a swirling sky.
> 
> * **Style:** Vincent van Gogh post-impressionist style, thick impasto brushstrokes, expressive texture.
> * **Aesthetics:** Deep ultramarine blues, vibrant sun yellow, emerald greens, soft diffused warm sunlight, dreamlike and friendly.
> * **Composition:** 2D parallax background layer, wide horizontal perspective, no foreground vector elements.
> * **Negative Prompt:** Outlines, vector art, flat colors, photorealism, dark dreary weather.

---

## 📋 Tips for Prompt Tuning

| Parameter | Desired Outcome | Recommended Keywords |
| :--- | :--- | :--- |
| **Foreground Clarity** | Crisp readability | `vector style`, `bold outlines`, `clean graphic shapes`, `Bluey style` |
| **Color Saturation** | Eye-catching pop | `saturated`, `primary colors`, `electric`, `bright neon` |
| **Background Depth** | Soft artistic mood | `Van Gogh style`, `impasto`, `swirling brushstrokes`, `soft lighting` |
| **Safety / Tone** | Kid-friendly | `rounded edges`, `cheerful`, `vibrant`, `whimsical` |
