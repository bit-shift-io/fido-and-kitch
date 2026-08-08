# The Complete AI Art Pipeline for a Hand-Painted 2D Platformer (Apple Silicon, Tiled, TypeScript) — 2026 Edition

## TL;DR
- **Run generation locally in Draw Things (free, native Apple Silicon) as your daily driver, and pay per-image on fal.ai for burst/Flux jobs.** For a hand-painted look with clean commercial licensing, your safest strong models are **SDXL fine-tunes** (Juggernaut XL, DreamShaper XL — CreativeML OpenRAIL++) and **Qwen-Image / FLUX.1 [schnell]** (both Apache 2.0). Avoid FLUX.1 [dev] weights for shipped art unless you buy BFL's commercial licence, and avoid NoobAI/some Illustrious derivatives that forbid commercial use.
- **Style consistency — the real problem — is solved by training one small style LoRA (15–30 images) plus locking seed/sampler/CFG and using IP-Adapter/ControlNet**, not by prompt-wrangling alone. Train it locally in Draw Things or for ~$2–5 on fal.ai. This is the single highest-leverage step in the whole pipeline.
- **AI is excellent for characters, props, and parallax backgrounds but is genuinely bad at seamless terrain autotiles** — hand-author or buy tile sets for terrain and reserve AI for hero art. Legally, purely AI-generated art is **not copyrightable in the US** and **Steam requires you to disclose it**; plan around both.

## Key Findings

1. **Draw Things is the correct local front-end for this user.** It is a free, native Swift/Metal app (not a Python port), runs ~20% faster than ComfyUI on the same Mac and up to ~3x faster in some tests, trains LoRAs locally, and is scriptable in JavaScript — ideal for a TS/JS dev. ComfyUI is the power-user backup when you need exotic nodes (seamless tiling, specific ControlNets). DiffusionBee is effectively abandoned (no update since Aug 2024). Skip it.
2. **Unified memory is the gating factor.** 16GB runs SD 1.5 and SDXL comfortably; Flux only via Q4 quant with swapping. 24GB is the comfortable floor for Flux (Q6_K). 48GB+ is needed for FP16 Flux. Realistic SDXL times: ~8–15s on M4 Max, ~25–40s on M2 Pro 16GB; Flux Dev ~50–90s on M4 Pro 24GB.
3. **Licensing is a minefield and matters more than quality.** FLUX.1 [dev] is non-commercial; FLUX.1 [schnell] and Qwen-Image are Apache 2.0 (commercial OK); SDXL is OpenRAIL++ (commercial OK). On Civitai you must check each model's per-model permission flags — some derivatives (e.g. NoobAI XL) explicitly forbid commercialization.
4. **For style consistency, the winning stack is: style LoRA + fixed seed + IP-Adapter (style) + ControlNet (pose/structure).** Generate one hero asset, then use it as an IP-Adapter style anchor for everything else.
5. **Skeletal/cutout animation (DragonBones free, or Spine paid) beats frame-by-frame for AI-generated hand-painted characters** because you generate one clean character, cut it into parts, and animate the rig — avoiding the frame-to-frame consistency problem that AI cannot reliably solve.
6. **Phaser 3 is the most mature TS engine for Tiled maps.** Export `.tmj`/JSON with embedded tilesets, load PNG + JSON, and use free-tex-packer for atlases.

## Details

### 1. Local image generation on Apple Silicon

**Front-ends, ranked for this user:**
- **Draw Things (free, App Store / direct).** Native Metal FlashAttention engine, on-demand weight loading (runs bigger models in less RAM), built-in model downloader (SD 1.5, SDXL, SD 3.5, Flux), ControlNet, LoRA import from Civitai, **local LoRA training**, and a **JavaScript scripting API + MCP server**. This is your primary tool.
- **ComfyUI (free, open-source).** Node-based, maximum flexibility, the widest ecosystem (seamless-tiling nodes, every ControlNet, GGUF quant support). Slower on Mac (PyTorch MPS backend) and a steeper setup. Use it for tiling and advanced workflows.
- **MLX (free, Apple's framework).** Fastest native path but code-only, narrow model support (no Flux), no ControlNet/LoRA convenience. Niche.
- **InvokeAI / Fooocus / A1111-Forge:** all run on Mac but are slower and less maintained on Apple Silicon than Draw Things; Fooocus is simple but SDXL-oriented. Not recommended as primary.
- **Mochi Diffusion:** Core ML-based, fast for SD 1.5/SDXL, limited to converted models. Fine but eclipsed by Draw Things.
- **DiffusionBee:** abandoned. Do not use.

**Memory tiers & realistic speeds (2025–2026 data):**
- **16GB (M1–M4 base):** SD 1.5 (5–15s) and SDXL (25–40s on M2 Pro) run well. Flux only via GGUF Q4_KS (~7GB), with swapping and quality loss. This is the practical floor; Flux is a compromise here.
- **24GB (e.g. M4 Pro):** Comfortable Flux Dev via Q6_K (~10GB), ~50–90s/image in ComfyUI, faster in Draw Things. Best price/performance sweet spot.
- **32GB:** Flux Q8; comfortable batching of SDXL.
- **48GB+:** FP16 Flux Dev (~24GB model), ~85s on M4 Max 48GB; comfortable everything.
- 8GB is insufficient for SDXL/Flux (SD 1.5 only). Apple Silicon is ~3–5x slower than an RTX 4090 for diffusion — plan for coffee-break iteration, not instant.

**Best models for hand-painted / illustrated 2D game art (with commercial-use verdict):**
- **SDXL fine-tunes — RECOMMENDED default.** Juggernaut XL (all-rounder), DreamShaper XL (painterly/artistic), and storybook/painterly community checkpoints. Licence: CreativeML **OpenRAIL++-M — commercial use permitted**. Largest LoRA/ControlNet ecosystem. Runs on 16GB. This is your workhorse.
- **Qwen-Image — Apache 2.0, commercial OK.** A 20B-parameter MMDiT model released by Alibaba's Qwen team on **August 4, 2025** under Apache 2.0 (weights on Hugging Face/ModelScope). Excellent prompt adherence and text-in-image (great for UI). Large (needs 24GB+ or GGUF). LoRA training works on Apple Silicon but is slow. Note the ecosystem is moving fast: a **Dec 31, 2025 Qwen-Image-2512** (20B, Apache 2.0) and a **Feb 10, 2026 unified 7B "Qwen-Image 2.0"** have since shipped.
- **FLUX.1 [schnell] — Apache 2.0, commercial OK.** Fast (4-step), good quality, safe to ship. The Flux you should use.
- **FLUX.1 [dev] — NON-COMMERCIAL.** Beautiful but you may **not** ship outputs commercially without buying BFL's self-serve commercial licence. Fine for prototyping/ideation only. FLUX.2 [klein] (Jan 2026) is Apache 2.0 and a better free-commercial Flux option.
- **Illustrious / NoobAI / Pony derivatives:** great for stylized/anime art but **licence-dangerous**. Illustrious XL v2.0 is redistributed under CreativeML Open RAIL (SDXL) (commercial OK), but **NoobAI XL's licence explicitly forbids commercialization** ("We prohibit any form of commercialization, including but not limited to monetization or commercial use of the model, derivative models, or model-generated products"), and Pony/other derivatives vary. Vet every one.
- **SD 3.5:** permissive community licence up to a revenue threshold; smaller ecosystem than SDXL.

**Where to find LoRAs/checkpoints & how to vet:** Civitai (largest), Hugging Face (official releases), Tensor.art. On Civitai, every model page shows **permission flags**: "Sell generated images", "Use on other generation services", "Sell this model/merges". For a shipped game you need "Sell generated images" = allowed. SD 1.5/SDXL models use OpenRAIL with author addendums; read them. Some models restrict use to specific platforms (TensorArt/SeaArt only) — those are unusable for a local pipeline.

### 2. Hosted / cloud generation

**Game-asset platforms (cheapest paid first):**
- **Scenario.com (scenario.gg)** — free tier: 50 credits/day, personal/eval only. Paid: **Starter $10/mo (1,500 credits), Pro $30/mo (5,000 credits, custom model training), Max $50/mo** (annual billing saves ~33%). All paid plans include a **full commercial licence** ("you own what you create... ship assets in games, sell them"). Purpose-built for style-consistent game assets: **custom model/LoRA training (10–30 images for a style, 5–15 for a character), IP-Adapter, Multi-LoRA merging, seed control.** This is the best hosted option for your exact problem if you'd rather pay than self-host. Free-plan outputs are NOT for commercial use. (Note: some third-party pages list Scenario's Pro/Max at $45/$75 — verify the live pricing page at purchase.)
- **Leonardo.ai** — free: 150 tokens/day (public images, non-exclusive commercial licence only). Paid from **$12/mo** (full ownership/commercial). Built for high-volume style-consistent assets; has custom model training, image guidance (IP-Adapter-like), and Flux/Ideogram/Nano Banana access.
- **Ideogram** — entry **$7/mo**; best for text-in-image (UI/logos). Free tier restricts commercial use.
- **Recraft** — design/vector assets, brand style sets; free tier public images.
- **Krea / Playground / Rosebud / Layer.ai** — Krea good for realtime/style; Playground cheap; verify each free tier's commercial terms (most free tiers = non-commercial or public).

**Style-consistency feature support:** Scenario (custom training + IP-Adapter + seed) and Leonardo (custom models + image guidance) are the two strongest for asset-set consistency. Ideogram/Recraft have style references but less game-specific tooling.

**Cheap pay-as-you-go APIs (for burst use, no subscription):**
- **fal.ai** — per-megapixel or per-image; diffusion models from ~$0.001–0.04/image, FLUX.1 [dev] w/ ControlNet+LoRA+IP-Adapter at **$0.075/MP (~13 images per $1)**, FLUX.2 variants higher. **LoRA training ~$0.0024/step (min 1,000 steps → ~$2.40) up to $0.008/step.** Best for burst Flux + cheap cloud LoRA training.
- **Replicate** — per-second GPU billing; similar range, better docs.
- **Together / DeepInfra** — sometimes cheaper for specific models.
- **Google Gemini 2.5 Flash Image ("Nano Banana")** — ~$0.039/image, strong character consistency and conversational editing.
- **OpenAI gpt-image-1** — premium, best text; more expensive.

Use pricepertoken.com to compare live per-image costs; the cheapest 1024×1024 diffusion APIs start around $0.001–0.002/image.

### 3. Style consistency methodology (the core section)

The reliable recipe, in order of leverage:

**A. Lock your generation recipe.** Fix **seed** (or a small set of known-good seeds), **sampler** (e.g. DPM++ 2M Karras), **CFG** (e.g. 5–7 for SDXL), and **steps** (25–30). Save these as a preset. Changing one variable at a time is the only way to debug drift.

**B. Build a reusable "style block" prompt.** Separate your prompt into fixed and variable parts:
```
[SUBJECT — varies] , 
[STYLE BLOCK — fixed for whole game]: hand-painted 2D game art, storybook illustration, 
soft painterly brushstrokes, warm gouache palette, clean silhouette, subtle rim light, 
flat even lighting, centered, plain background,
[NEGATIVE — fixed]: photo, 3d render, harsh shadows, text, watermark, busy background, 
pixel art, realistic
```
Keep the STYLE BLOCK and NEGATIVE identical across every asset.

**C. Train one style LoRA (highest leverage).** 15–30 images is the sweet spot (you can start with 10; 20–30 diverse images is the professional standard). Options:
- **Locally in Draw Things** (free): trains SDXL/Flux LoRAs on Apple Silicon; SDXL LoRA needs ~10GB peak memory (works on a 16GB Mac; iPad-class possible). Expect **30 min to ~4.5 hours** depending on steps/dataset. Use 8-bit models + Memory Saver on 16GB.
- **fal.ai / Replicate** (cheap cloud): FLUX LoRA training ~$2.40+ and ~10–20 min. Best if local is too slow.
- **kohya_ss** works but is NVIDIA-centric; on Mac, Draw Things or cloud is easier.
Pause training around 500–1,000 steps and test; don't blindly run to 2,000.

**D. IP-Adapter for style/character transfer without training.** Feed a reference image; IP-Adapter injects its style (up block) or identity. Combine two IP-Adapters (one for face/identity, one for style). This is the no-training option for consistency and is lighter on VRAM than a training run.

**E. ControlNet for structure.** Use **lineart/canny** to preserve a drawn shape, **depth** for volume, **scribble** for rough layout, **OpenPose** for character poses. Essential for turning one character into many poses.

**F. The hero-anchor workflow.** Generate/curate **one perfect "hero" asset** that defines the look. Then for every subsequent asset: use the hero as the **IP-Adapter style reference** + the shared style block + locked seed. This is the single most practical technique for a solo dev and is exactly what Scenario/Leonardo automate.

**G. Consistent characters across poses/frames.** Triad: **SDXL/your style LoRA (quality+style) + IP-Adapter FaceID (identity) + ControlNet OpenPose (pose).** Generate a 4-view reference sheet first (front/side/back/3-4), then pose from it. For animation frames specifically, do NOT try to generate each frame independently — see §6.

**Concrete prompt templates (hand-painted platformer):**

*Player character:*
```
a brave young fox explorer standing, full body, facing right, 
hand-painted 2D game art, storybook illustration, soft gouache brushstrokes, 
warm autumnal palette, clean readable silhouette, subtle rim light, flat lighting, 
centered on plain white background
neg: photo, 3d, pixel art, harsh shadows, text, watermark, busy background
```
*Enemy:*
```
a grumpy mushroom goblin, full body, 3/4 view, [STYLE BLOCK], menacing but cute, 
plain background
```
*Platform/terrain tile (see §4 caveats):*
```
seamless grassy dirt platform tile, top-down painterly texture, [STYLE BLOCK], 
tileable, even lighting, no shadows at edges
```
*Seamless texture:* same as above + enable tiling (§4).
*Prop/decoration:*
```
an ancient mossy lantern prop, [STYLE BLOCK], single object, plain background, 
soft ambient occlusion
```
*Parallax background layer:*
```
distant misty forest hills, wide horizontal composition, [STYLE BLOCK], 
atmospheric depth, muted background palette, no foreground objects, empty sky band at top
```
*UI element:*
```
a wooden fantasy button with rounded corners, game UI, [STYLE BLOCK], 
centered, plain background, clean edges
```
Use Qwen-Image or Ideogram when the UI needs legible text.

### 4. Tiles & tilesets

**Seamless output:**
- **ComfyUI-seamless-tiling** (spinagon): replaces Conv2D constant padding with **circular padding**, with independent X/Y (asymmetric) control. Use the "Seamless Tile" node between loader and sampler + "Make Circular VAE", and the "Offset Image" node to inspect seams.
- **Draw Things** has a tiling/seamless option in generation settings.
- **ComfyUI-MakeSeamlessTexture** adds a radial-mask post-processor specifically recommended for game assets; pairs well with circular VAE decoding to fix residual seams and uneven lighting.
- **Offset-and-fix** in any editor (Krita/Photopea/GIMP): offset the image by 50% so seams move to center, then heal/paint them out. Reliable manual fallback.

**Autotile / Wang sets:** You need structured sets — 47-tile blob, 16-tile, or corner (Wang) sets — for Tiled's terrain tools. **AI does not generate these coherently.** The realistic workflow is: generate ONE seamless base texture with AI, then **manually cut/compose** the transition tiles in an editor or a blob-tile generator (there are free 47-blob generators with Godot/Tiled export).

**Honest assessment — where AI fails for terrain:** AI is the wrong primary tool for platformer terrain autotiles. Seam alignment across a 47-tile set, consistent edge geometry, and pixel-exact tiling are things diffusion models do unreliably. **Recommendation: hand-author terrain tiles (or buy an asset pack) and use AI-generated base textures as the painted surface, then build the Wang set by hand.** Reserve AI for characters, props, decorations, and parallax backgrounds where its strengths shine and seams don't matter.

### 5. Post-processing pipeline

**Background removal / alpha (illustrated art with soft edges):**
- **rembg** (free, Python/CLI/Docker) — default u2net softens fine edges; switch to `-m birefnet-general` or use `isnet-anime` for drawn art. Add `-a` (alpha matting) for hair/soft edges. Scriptable and batchable — ideal for a TS/JS dev via a shell step.
- **BiRefNet** (free, state-of-the-art) — best edge quality on hair/soft/translucent edges; "Matting" variant is built for soft edges. Available in rembg backend, ComfyUI-RMBG, or fal.ai (~$0.0008/compute-second). The **Lucida** BiRefNet fine-tune (MIT) is specifically tuned for illustrations. This is your quality pick for hand-painted sprites.
- **Segment Anything (SAM/SAM2)** — text-promptable segmentation for tricky cutouts.
- **Photoroom free tier / macOS built-in** (Preview's background removal, or the Shortcuts "Remove Background" action) — quick one-offs, lower control.
Verdict: **rembg with the BiRefNet/Lucida backend** for batch, BiRefNet Matting for hero assets.

**Upscaling & cleanup:**
- **Upscayl** (free, open-source AGPLv3, **Apple Silicon native** via Vulkan/NCNN) — the default. Ships Real-ESRGAN, **UltraSharp**, Remacri, and **High Fidelity (HFA2k, artwork)** models; has a **digital-art/illustration** model and CLI (`upscayl-ncnn`) for scripting. ~3s/image at 2x on M2. Use UltraSharp or the art model for illustrated sprites.
- **Real-ESRGAN CLI** (free) — the engine under Upscayl; script it directly for batch jobs.
- **4x-UltraSharp / SwinIR** — model choices within these tools; UltraSharp is the go-to for crisp illustrated edges.

**Batch/scriptable (TS/JS dev):**
- **sharp** (Node) — trim, resize, extend/pad, power-of-two canvas, alpha handling. Your primary automation lib.
- **ImageMagick** (`convert`/`magick`) — `-trim`, `-bordercolor none -border`, `-gravity center -extent 256x256` for consistent canvas alignment and padding.
- Combine: rembg (bg removal) → sharp/ImageMagick (trim → pad → power-of-two → center) → Upscayl CLI (upscale) → free-tex-packer (atlas). All scriptable in an npm script.

**Colour/palette harmonisation:** Generating in different sessions causes palette drift. Fixes: (1) define a fixed palette in your style block; (2) post-process with a **palette-match/LUT** step (ImageMagick `-remap palette.png`, or a Node color-grading pass) to snap all assets to a master palette; (3) run all finals through one consistent color-grade LUT.

### 6. Animation & sprite tooling

**Tools (free preferred):**
- **DragonBones (free)** — skeletal/cutout 2D animation, mesh deform, exports JSON + texture atlas. Note: rebranded toward "LoongBones" with paid tiers and some compatibility concerns; the classic free build still works and there are Godot/engine runtimes. Best free skeletal option.
- **Spine (paid, one-time per named-user licence).** **Spine Essential $69** and **Spine Professional $369** — one-time per named-user licences (Professional adds IK, weights, and meshes). Crucially, these licences are **valid only if your gross revenue/financing is under $500,000 USD in the last 12 months**; above that you need **Spine Enterprise**. Best-in-class runtimes (including JS/TS, Phaser, PixiJS). Worth it if budget allows and you're under the revenue threshold.
- **Spriter (BrashMonkey)** — beginner-friendly skeletal; Spriter Pro cheap one-off.
- **Aseprite (paid ~$20 one-off)** / **LibreSprite (free fork)** / **Pixelorama (free)** — frame-by-frame, pixel-oriented (less ideal for hand-painted, but fine for frame sequences).
- **Krita (free)** — has frame-by-frame animation and is a real painting tool; good for hand-cleaning frames.
- **Blender Grease Pencil (free)** — 2D animation in a 3D space; powerful but heavy.
- **Godot / Phaser built-in** — runtime animation from sprite sheets or skeletal data.

**Frame-by-frame vs skeletal for AI art — verdict:** For a small team using AI-generated hand-painted source art, **skeletal/cutout animation wins decisively.** You generate ONE clean, high-quality character illustration, cut it into parts (head, torso, upper/lower arms, legs, etc.) in Krita/Photopea, and rig those parts in DragonBones/Spine. This sidesteps the fundamental problem that **AI cannot generate a consistent character across dozens of frame-by-frame drawings.** Frame-by-frame only makes sense for short effects (explosions, sparkles) where you can generate/hand-draw a handful of frames.

**How to rig an AI character for cutout animation:** (1) generate the character in a neutral "T/A-pose" facing side-on; (2) in an editor, separate into layers/parts on transparent background, painting in the hidden overlaps (e.g. the shoulder behind the torso); (3) import parts into DragonBones/Spine; (4) build the bone hierarchy, bind parts, add mesh deformation for squash/stretch; (5) animate; (6) export atlas + JSON.

**AI-assisted in-betweening / animating a static sprite — honest take:** Tools like **AnimateDiff** (ComfyUI) and video models can produce motion from a keyframe + ControlNet OpenPose, and quality has improved. But per multiple 2026 practitioner reports, output is **"good enough for greybox/prototype, not ship-as-is"** — it drifts over more than a second or two and needs hand-cleanup. **Do not rely on it for shipping animation.** Use it for previz or to generate rough frames you then clean by hand. Skeletal rigging remains the reliable path.

**Sprite sheet packing (free):**
- **free-tex-packer** (open-source; desktop + web at free-tex-packer.com) — trim, rotation, multipack, and **direct export presets for Phaser, PixiJS, Godot, Cocos2d**. Your default.
- **TexturePacker free / TexturePacker Online** — the paid tool has a free web version with reduced features.
- **ShoeBox** (free, Adobe AIR) — older but works.
- Phaser/PixiJS consume JSON-hash atlases directly.

### 7. Tiled editor & TypeScript integration

**Tileset prep:** Standard tile sizes are powers of two (16, 32, 48, 64px). In Tiled, set **margin** and **spacing** to match how your atlas was packed (usually margin 0, spacing 0 for a clean grid; add 1–2px spacing/extrusion to prevent bleeding if you see seams at runtime). Use **PNG** with alpha. Keep one tileset image per logical set.

**Wang sets / terrain / autotile in Tiled:** Tiled supports **Terrain/Wang sets** (corner, edge, and mixed) and can auto-place transition tiles. Prepare AI/hand-made art as a grid, then in Tiled define the Wang set by painting corner/edge colors onto each tile. As noted in §4, build these tiles deliberately — AI won't hand you a ready blob set.

**Export & TypeScript consumption:**
- Export **`.tmj`/JSON** (not `.tmx`) for web/JS engines. Use **CSV or uncompressed Base64** tile layer format and **"Embed tileset in map"** for Phaser.
- **Phaser 3** — most mature: `this.load.tilemapTiledJSON()` + `this.load.image()`; `map.addTilesetImage()`; `map.createLayer()`. The `phaser3-autotile` plugin generates 47-tile blob sets from 5 source tiles and wraps Tiled Wangset/Terrain parsing.
- **Excalibur.js** — has an official `@excaliburjs/plugin-tiled` loader for `.tmx`/`.tmj`.
- **PixiJS** — use `@kayahr/tiled` or `tiled-tmj` type-safe parsers + a Pixi tilemap renderer (`@pixi/tilemap`).
- **Kaplay/Kaboom** — has its own map helpers; you can parse Tiled JSON manually or via community loaders.
- General TS parsers: `@kayahr/tiled` (typed), `tiled-types` (TypeScript typings for the Tiled JSON format).

**Generation-to-Tiled automation:** No polished off-the-shelf "AI → Tiled" bridge exists. Practical automation: a Node script that takes finished tile PNGs → free-tex-packer (CLI/lib) → writes a Tiled-compatible tileset `.tsj` JSON. Some community tools generate tilesets/Tiled files from other engine assets (Defold↔Tiled), but you'll likely script the last-mile handoff yourself.

### 8. Legal & practical risk (verify — policies are shifting)

- **Copyright:** The **US Copyright Office's Jan 29, 2025 Part 2 report** and **Thaler v. Perlmutter, 130 F.4th 1039 (D.C. Cir. March 18, 2025)** — a unanimous three-judge panel holding "the Copyright Act of 1976 requires all eligible work to be authored in the first instance by a human being" — confirm **purely AI-generated art is not copyrightable**. The **Supreme Court denied certiorari (No. 25-449) on March 2, 2026**, leaving the ruling intact. Practical implication: a competitor could copy your fully-AI assets with no liability. Protection attaches only where a human makes substantial creative modifications (painting over, compositing, meaningful selection/arrangement). **Your hand-cutting, rigging, compositing, and editing steps are exactly what can create protectable authorship** — document them.
- **Steam:** Requires **AI disclosure** via the Steamworks Content Survey. Valve rewrote the form on **January 16, 2026**, splitting it into a **two-tier system**: "**Pre-generated**" ("any kind of content created with the help of AI tools during development") and "**Live-Generated**" content, and explicitly narrowing scope — "Efficiency gains through the use of AI powered tools is not the focus of this section" (i.e. code assistants like Copilot are exempt). Your AI-generated art IS player-facing pre-generated content → **you must disclose it**. Adoption context: close to **8,000 games had filed an AI disclosure by H1 2025, up from ~1,000 in all of 2024 (an eightfold jump)**, and roughly **1 in 5 new Steam releases now carries an AI disclosure**.
- **Other platforms:** **Epic Games Store** — no AI disclosure requirement (but the Fab marketplace has AI tagging). **itch.io** — no blanket requirement (per-page dev choice). **Apple App Store, Nintendo, PlayStation, Xbox** — no specific mandatory AI-content disclosure as of early 2026 (verify per submission).
- **EU AI Act:** **Article 50 of the EU AI Act (Regulation (EU) 2024/1689)** transparency obligations apply **from 2 August 2026**, with non-compliance fines up to **€15 million or 3% of worldwide annual turnover**; a **grace period until 2 December 2026** applies to the Article 50(2) machine-readable marking obligation for generative systems already on the market. Relevant if you sell to EU players. The Act carves out content that is "evidently artistic, creative, satirical, fictional or analogous," but that exception is assessed per-content, not per-category — don't rely on it without documentation.
- **Model licence pitfalls:** FLUX.1 [dev] non-commercial (don't ship its outputs); FLUX.1 [schnell]/Qwen-Image Apache 2.0 (safe); SDXL OpenRAIL++ (safe); **NoobAI/some Illustrious/Pony derivatives forbid or restrict commercial use** — vet each Civitai model's flags. **Hosted free tiers (Leonardo/Scenario/Ideogram) generally grant only non-commercial or non-exclusive rights on free outputs** — you must be on a paid tier for full commercial rights.
- **FTC angle:** Don't market AI art as "hand-crafted" — that framing carries deceptive-practice risk independent of platform rules.

## Recommendations

**The recommended end-to-end pipeline (free-first, this user):**

**Stage 0 — Setup (once).** Install **Draw Things** (free). Download an **SDXL painterly checkpoint** with "Sell generated images" allowed (e.g. DreamShaper XL / a storybook checkpoint — verify flag). Install **ComfyUI** for tiling. Install **Upscayl**, **rembg (BiRefNet backend)**, **free-tex-packer**, **DragonBones**. Set up a Node project with **sharp** + **ImageMagick** for batch scripts.

**Stage 1 — Define the look (once, highest leverage).** Generate/curate a **hero character**. Assemble **15–30 images** in your target style and **train a style LoRA in Draw Things** (free, ~1–4h) or on **fal.ai (~$2.40, ~15 min)**. Lock a recipe: seed set, DPM++ 2M Karras, CFG 6, 28 steps, and a fixed **style block + negative** prompt.

**Stage 2 — "I need a new enemy sprite" (repeatable):**
1. In Draw Things: your style LoRA + style block + `a grumpy mushroom goblin, 3/4 view` + locked recipe. Add **IP-Adapter** with the hero as style anchor; **ControlNet OpenPose** if you need a specific pose. Generate a batch, pick the best.
2. **Upscale** in Upscayl (UltraSharp/art model) to target resolution.
3. **Remove background** with rembg + BiRefNet Matting → clean alpha PNG.
4. **Normalize** with a Node/sharp+ImageMagick script: trim → center → pad to power-of-two → palette-match to master LUT.
5. **Rig for animation:** cut into parts in Krita/Photopea, import to **DragonBones**, build bones + mesh, animate walk/idle/attack, export atlas + JSON.
6. **Pack** all frames/parts with **free-tex-packer** (Phaser preset).
7. **Load in game:** Phaser 3 `load.atlas()` + DragonBones runtime (or Spine runtime if you upgraded), place the enemy, done.

**Time investment (honest):** Stage 0–1 is 1–2 days of setup + experimentation. Once dialed in, a new sprite is ~1–3 hours (mostly rigging and cleanup, not generation). **Painful spots:** (a) getting the style LoRA right takes iteration; (b) background removal on soft painterly edges needs manual touch-up a small fraction of the time; (c) terrain autotiles — expect to hand-build these; (d) animation rigging is the real time sink; (e) palette drift across sessions needs the LUT discipline.

**Benchmarks that change the plan:**
- If **generation is too slow** (>60s/image bugging you) or you can't fit Flux → your 16GB Mac is the bottleneck; either stick to SDXL locally or push Flux to fal.ai burst.
- If **style consistency still fails** after a LoRA + IP-Adapter → switch to **Scenario ($10–30/mo)** whose custom-model + IP-Adapter pipeline is purpose-built for this and will save weeks.
- If **animation volume grows** → buy **Spine** (one-off) for better rigging + runtimes.

**"If you can spend $X" upgrade path:**
- **~$10–30/mo:** Scenario Starter/Pro for hosted style-consistent generation + training with full commercial licence — removes the biggest pain point (consistency) and the licence ambiguity.
- **~$69–369 one-off:** Spine (Essential → Professional) for professional skeletal animation and first-class Phaser/PixiJS/TS runtimes (while under the $500k revenue threshold).
- **~$5–20 burst:** fal.ai credits for Flux/Qwen bursts and cheap cloud LoRA training when your Mac is too slow.
- **Hardware:** if buying a Mac, get **24GB+ unified memory** (32–48GB if animation/Flux-heavy) — it's the single biggest local-generation quality-of-life upgrade.

## Caveats
- **Fast-moving space:** Model releases (FLUX.2, Z-Image, Qwen-Image 2512/2.0), tool versions, and especially **platform policies and prices** change monthly. Every price and licence here should be re-verified at purchase/ship time (checked against 2025–2026 sources).
- **Benchmark numbers are approximate.** Most Apple Silicon speed figures are author "ranges," not controlled single-seed benchmarks; the one directly-measured data point (M4 Max ≈42s SDXL+5 LoRAs in Draw Things, from a MacRumors forum thread with screenshots) is the exception. Treat times as ballpark.
- **Licences can change per model and per version** (e.g. Illustrious moved between licences). The "commercial OK" verdicts above are for the versions cited; check the exact file you download.
- **Copyright non-protection is a strategic risk, not a blocker** — plenty of games ship AI art; just understand you can't fully protect it and must disclose on Steam.
- **AI in-betweening is not production-ready** for shipped hand-painted animation as of 2026 — budget for real rigging.
- This report is practical guidance, **not legal advice**; consult a lawyer for your specific commercial release.