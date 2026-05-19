// World-space fog of war overlay.
//
// Per frame we encode Fog::state into a CPU-side `Image` (one pixel per
// sim cell), upload it to a GPU `Texture` via Texture::updateFromImage,
// and draw a single full-world `Sprite` over the world. All default-state
// — one sprite draw using SFML's default sprite shader — so it doesn't
// touch the render-state-cache desync path that produced the drag-box /
// ImGui ghosting at high rect counts.
//
// State -> alpha:
//   2 (visible)    : alpha 0   (fully transparent, world shows through)
//   1 (explored)   : alpha 130 (dim)
//   0 (unexplored) : alpha 235 (heavy)
//
// Class name kept for callers (Render::world still calls
// FogShader::drawWorld). No GLSL shader is involved.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";

import * from "../game/Constants.mt";
import * from "./Snapshots.mt";

class FogShader {
    public static Image?   fogImage = null;
    public static Texture? fogTex   = null;
    public static Sprite?  fogSpr   = null;
    public static int      ready    = 0;

    public static function ensureReady(): void {
        if (FogShader::ready == 1) { return; }
        FogShader::ready = 1;

        int gs = GameConst::gridSize();
        float h = GameConst::worldHalf();
        float side = h * 2.0;

        // 1) gs × gs Image used as a scratch CPU pixel buffer. First frame
        //    overwrites every pixel, so the initial fill colour is fine.
        Image img = Images::create(gs, gs, 0, 0, 0, 235);
        FogShader::fogImage = img;
        // 2) Same-sized Texture seeded from the Image. Texture::updateFromImage
        //    each frame keeps it in sync with the simulation.
        Texture tex = Textures::fromImage(img);
        FogShader::fogTex = tex;
        // 3) Sprite that covers the world. Sprite's local size is the
        //    texture pixel size (gs × gs); scaling by (side / gs) stretches
        //    each texel to tileMeters world meters.
        Sprite spr = Sprites::create(tex);
        spr.setPosition(-h, -h);
        float scale = side / (float)gs;
        spr.setScale(scale, scale);
        FogShader::fogSpr = spr;
    }

    // Apply only the cells that changed since the last render (handed to
    // us via snap.fogDirty / snap.fogDirtyLen by Sampling::collectFog),
    // re-upload the image if anything moved, then draw the sprite. Typical
    // dirty count is the sum of sight-disc areas (~hundreds of cells) —
    // dramatically cheaper than re-encoding all 16384 every frame.
    public static function drawWorld(RenderWindow win, WorldSnapshot snap): void {
        FogShader::ensureReady();
        int gs  = GameConst::gridSize();
        Image   img = FogShader::fogImage;
        Texture tex = FogShader::fogTex;
        float[] src = snap.fogStateF;
        int[]   dirty    = snap.fogDirty;
        int     dirtyLen = snap.fogDirtyLen;

        if (dirtyLen > 0) {
            int j = 0;
            while (j < dirtyLen) {
                int idx = dirty[j];
                int st  = (int)src[idx];
                int a = 235;
                if (st == 1) { a = 130; }
                else if (st == 2) { a = 0; }
                img.setPixel(idx % gs, idx / gs, 0, 0, 0, a);
                j = j + 1;
            }
            tex.updateFromImage(img);
        }

        Draw::sprite(win, FogShader::fogSpr);
    }
}
