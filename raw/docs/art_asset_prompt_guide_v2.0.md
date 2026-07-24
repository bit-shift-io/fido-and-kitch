# Art Asset Prompting Guide: 2D Multi-Level Platformer (V2.0)

Welcome to the updated guide for generating 2D platformer assets. This version reflects the **multi-level puzzle-platformer layout** (inspired by classics like *Lurid Land* / *Lode Runner*) combined with a **3-layer high-clarity Van Gogh & Vector hybrid visual style**.

---

## 🎨 Art Direction Overview

The visual identity rests on a **3-Layer Parallax Visual Hierarchy** optimized for kid-friendly readability and deep artistic flavor:

1. **Layer 1: Interactive Foreground (Gameplay & Mechanics)**
   * **Style:** Crisp vector cartoon style (inspired by *Bluey*).
   * **Characteristics:** Thick dark rounded outlines, flat or clean gradient fills, bold graphic shapes, no blur.
   * **Layout Focus:** Multi-level verticality—climbing ladders, floating stone arches, water pools, breakable blocks, gems, and mechanical gears.
   * **Palette:** Ultra-saturated, high-contrast primary and neon secondary colors (ruby reds, bright turquoise, canary yellow, emerald green).

2. **Layer 2: Midground Environment**
   * **Style:** Rich Van Gogh post-impressionist style.
   * **Characteristics:** Visible impasto brushstrokes, stone castle turrets, bridges, and near hills.
   * **Visual Role:** Crisp and clear enough to give immediate world context directly behind the player without obscuring ladders or platforms.

3. **Layer 3: Far Background (Sky & Horizon)**
   * **Style:** Classic Van Gogh swirling sky.
   * **Characteristics:** Expressive starry swirls, bold moon/sun motifs, distant mountain silhouettes.
   * **Visual Role:** Deep atmospheric scale and rich color backing.

---

## 🛠️ Master Prompt Template

```text
[Specific Asset Description]
-- Perspective: 2D side-view platformer level asset.
-- Style (Foreground): Crisp 2D vector style, thick dark outlines, clean graphic shapes, inspired by Bluey, kid-friendly.
-- Foreground Palette: Bold, saturated primary colors, high contrast.
-- Style (Midground): Van Gogh post-impressionist stone structures and hills, rich texture, high clarity.
-- Style (Far Background): Swirling Van Gogh sky, impasto brushwork, deep starry night.
-- Composition: 3-layer parallax depth separation (Foreground, Midground, Far Sky).
-- Negative Prompt: Photorealism, dark gritty lighting, muted pale watercolor, blurry outlines on foreground, pixel art.
```

---

## 🏰 Theme-Specific Asset Prompts

### 1. Medieval / Steampunk Hybrid

#### Multi-Tiered Level Platform
> **Prompt:** A multi-level stone archway platform featuring vertical wooden climbing ladders, mossy stone steps, and animated brass clockwork gears underneath.
> * **Foreground Style:** Crisp vector art, thick dark outlines, bold golden brass, bright emerald moss, vibrant turquoise water below.
> * **Midground Style:** Detailed Van Gogh stone castle turrets and golden wheat fields.
> * **Far Background Style:** Swirling Van Gogh starry sky with glowing crescent moon.
> * **Composition:** 2D multi-tier level tile, side-view perspective, isolated sprite format.

#### Collectible Gems & Interactive Hazards
> **Prompt:** A set of bright ruby-red diamond gemstones floating above a multi-level platform next to a mechanical steam valve.
> * **Foreground Style:** Crisp vector cartoon style, bold outlines, electric red glow, friendly for kids.
> * **Negative Prompt:** Real glass texture, dark grit, dull tones.

---

### 2. Underground Cave Settings

#### Multi-Level Cave & Crystal Ladders
> **Prompt:** A vertical cave level structure with wooden ladders connecting multi-tiered rock platforms, glowing neon stalactites, and underground water pools.
> * **Foreground Style:** Crisp 2D vector style, thick dark outlines, vibrant neon magenta and cyan crystals.
> * **Midground Style:** Textured Van Gogh style cave arches and rich violet rock walls.
> * **Far Background Style:** Swirling bioluminescent cave backdrop with deep indigo and cobalt brushstrokes.

---

### 3. Sci-Fi & High-Tech

#### Multi-Tiered Laser & Elevator Level
> **Prompt:** A multi-level futuristic platformer grid with glowing energy ladders, cyan hover platforms, and floating power orb collectibles.
> * **Foreground Style:** Vector art style, clean rounded lines, bright cyan, hot pink, and sunny yellow accents.
> * **Midground Style:** Van Gogh painterly post-impressionist nebula station structures.
> * **Far Background Style:** Swirling cosmic space clouds with Van Gogh impasto brushwork.

---

## 📋 Parallax Tuning Reference Table

| Layer | Art Style | Edge Clarity | Saturation | Parallax Speed |
| :--- | :--- | :--- | :--- | :--- |
| **Foreground (Gameplay)** | Vector (*Bluey* style) | Ultra-sharp (Dark outlines) | Very High (Primary/Neon) | **1.0x** (1:1 with player) |
| **Midground (Context)** | Van Gogh Impasto | High / Structured | High (Rich earthy/stone) | **0.5x – 0.6x** |
| **Far Sky (Horizon)** | Van Gogh Swirls | Soft / Painterly | Deep & Rich (Blues/Yellows) | **0.1x – 0.2x** |
