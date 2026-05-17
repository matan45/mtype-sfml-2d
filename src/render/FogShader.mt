// GPU-side fog of war. A single fragment shader reads the per-cell fog
// state from a `uniform float[4096]` and outputs the right alpha at every
// pixel of a world-spanning sprite. Compared to the per-cell VertexArray
// path (thousands of setVertex FFI calls per frame), this is two FFI
// calls per frame: one setFloatArray + one DrawShader::sprite.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";

import * from "../game/Constants.mt";
import * from "./Snapshots.mt";

class FogShader {
    public static Shader?  shader   = null;
    public static Texture? dummyTex = null;
    public static Sprite?  worldSpr = null;
    public static int      ready    = 0;
    public static int      ok       = 0;

    // GLSL is loaded once on first use. The plugin natives required for
    // Shaders/Textures/Sprites aren't bound until main.mt has loaded the
    // SFML plugin, so we lazy-init like Render::ensurePool.
    public static function ensureReady(): void {
        if (FogShader::ready == 1) { return; }
        FogShader::ready = 1;

        // 1x1 dummy texture — the shader doesn't sample it, but a Sprite
        // needs a Texture to exist + to give us a well-defined
        // gl_TexCoord[0] varying that goes (0..1) across the quad.
        Image img = Images::create(1, 1, 255, 255, 255, 255);
        FogShader::dummyTex = Textures::fromImage(img);
        img.destroy();

        Sprite spr = Sprites::create(FogShader::dummyTex);
        // Cover the entire world. Sprite's local size is 1x1 (texture
        // pixels); scaling by world side stretches it. Position at
        // (-worldHalf, -worldHalf) so its bottom-right corner sits at
        // (+worldHalf, +worldHalf).
        float h = GameConst::worldHalf();
        float side = h * 2.0;
        spr.setPosition(-h, -h);
        spr.setScale(side, side);
        FogShader::worldSpr = spr;

        string fragSrc =
            "uniform float fog[4096];\n"
            + "void main() {\n"
            + "    vec2 uv = gl_TexCoord[0].xy;\n"
            + "    int cx = int(uv.x * 64.0);\n"
            + "    int cy = int(uv.y * 64.0);\n"
            + "    if (cx < 0)  cx = 0;\n"
            + "    if (cy < 0)  cy = 0;\n"
            + "    if (cx > 63) cx = 63;\n"
            + "    if (cy > 63) cy = 63;\n"
            + "    float st = fog[cy * 64 + cx];\n"
            + "    if (st >= 1.5) {\n"
            + "        discard;\n"
            + "    } else if (st >= 0.5) {\n"
            + "        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.5);\n"
            + "    } else {\n"
            + "        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.92);\n"
            + "    }\n"
            + "}\n";

        Shader sh = Shaders::create();
        bool compiled = sh.loadFragFromMemory(fragSrc);
        FogShader::shader = sh;
        if (compiled) {
            FogShader::ok = 1;
        } else {
            FogShader::ok = 0;
        }
    }

    // Draw the world-space fog overlay. Caller must already have the
    // world View bound on `win`. Falls back to no-op if the shader did
    // not compile.
    //
    // After the shader draw we resync SFML's GL state cache. Without
    // this, subsequent default-shader draws (drag-box, ImGui HUD) can
    // pick up stale state and flicker.
    public static function drawWorld(RenderWindow win, WorldSnapshot snap): void {
        FogShader::ensureReady();
        if (FogShader::ok != 1) { return; }
        Shader sh = FogShader::shader;
        sh.setFloatArray("fog", snap.fogStateF);
        DrawShader::sprite(win, FogShader::worldSpr, sh);
        Camera::resetGLStates(win);
    }
}
