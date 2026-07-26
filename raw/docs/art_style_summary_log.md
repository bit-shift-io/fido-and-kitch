# Art Style Log & Technical Specification for AI Agents

**Target Medium:** 2D Platformer (Kid-Friendly / Multi-Level / Retro Puzzle Layout)  
**Primary Visual Goal:** Establish a high-contrast visual hierarchy that balances ultra-crisp, readable gameplay elements with a rich, painterly environment.

---

## 🎨 Core Art Direction & Visual Hierarchy

### 1. Foreground / Gameplay Layer (Layer 1)
* **Style:** Vector cartoon style (inspired by *Bluey*).
* **Line Art:** Clean, thick, rounded dark outlines on all playable surfaces, ladders, hazards, characters, and collectibles.
* **Color & Shading:** High saturation, bold primary/secondary colors, flat fills or clean vector gradients. No blur or noise.
* **Layout Structure:** Multi-level platforms, vertical ladders, arches, and water hazards (inspired by classic puzzle platformers like *Lurid Land*).
* **Purpose:** Instant readability and high contrast for young players.

### 2. Midground Parallax Layer (Layer 2)
* **Style:** Painterly post-impressionist (inspired by Vincent van Gogh).
* **Texture & Edge:** Rich impasto brushstrokes, distinct castle architecture, and near hills.
* **Clarity:** Sharp and clear (no heavy blur), but distinctly sitting behind the vector foreground without dark vector outlines.
* **Purpose:** Adds immediate spatial depth and world-building directly behind the action.

### 3. Far Background Parallax Layer (Layer 3)
* **Style:** Pure van Gogh painterly sky & horizon.
* **Palette:** Deep blues, rich gold/yellow moons, and swirling cosmic textures.
* **Lighting:** Soft, luminous, atmospheric lighting.
* **Purpose:** Sets a vast, dreamy scale for the world while maintaining color richness.

---

## 🛠️ Master Prompt Structure for Image Generation

Use this template when requesting new assets or level concept art:

```text
[Specific Asset or Level Description]

-- Foreground (Gameplay Assets): 2D vector cartoon style, thick dark outlines, clean graphic shapes, flat colors, inspired by Bluey, bright primary colors, sharp vector edges.
-- Midground (Near Environment): Painterly van Gogh style, impasto brushwork, clear castle walls and hills, distinct midground layer without vector outlines.
-- Far Background (Sky/Horizon): Deep van Gogh swirling starry night sky, rich ultramarine blues and warm golds, painterly texture.
-- Perspective & Layout: 2D side-view platformer layout, multi-level platforms with ladders and vertical paths.
-- Negative Prompt: Realistic photorealism, 3D render, dark gritty lighting, muddy colors, pixel art, blurred foreground.
```
