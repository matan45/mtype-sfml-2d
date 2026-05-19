// Bottom-right screen-space minimap. Drawn AFTER Camera:: resetView so all
// geometry is in window pixels.
//
// Layout:
//   - Square minimap, side = mapSide (200px), 10px padding from edges.
//   - Background dark gray, 2px outline.
//   - Each grid cell is rendered as a 1-cell black/dim/clear quad (fog).
//   - Buildings: faction-colored 5x5 squares.
//   - Units: faction-colored 3x3 squares.
//   - Resources: teal/green 2x2 squares (only in non-unexplored cells).
//   - Camera viewport: white wire rectangle.
//
// Click handling lives in handleClick(): if a left-click edge landed inside
// the minimap, the camera center is moved to the corresponding world point
// and the click is consumed (caller should skip Selection/Commands).

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";

import * from "../game/Constants.mt";
import * from "./CameraCtrl.mt";
import * from "./Snapshots.mt";
import * from "../input/Input.mt";

class MinimapPool {
    public RectangleShape bg;
    public RectangleShape dot;
    public RectangleShape viewBox;
    public bool ready;

    public constructor() {
        this.bg      = Rectangles:: create(1.0, 1.0);
        this.dot     = Rectangles:: create(1.0, 1.0);
        this.viewBox = Rectangles:: create(1.0, 1.0);

        this.bg.setFillColor(20, 24, 32, 230);
        this.bg.setOutlineColor(180, 180, 180, 220);
        this.bg.setOutlineThickness(2.0);

        this.viewBox.setFillColor(0, 0, 0, 0);
        this.viewBox.setOutlineColor(230, 230, 230, 220);
        this.viewBox.setOutlineThickness(1.5);

        this.ready = true;
    }
}

class Minimap {
    public static MinimapPool? pool = null;

    public static function ensurePool(): MinimapPool {
        if (Minimap:: pool == null) { Minimap:: pool = new MinimapPool(); }
        return Minimap:: pool;
    }

    // Minimap side in pixels and screen padding from window edges.
    public static function side():    int { return 200; }
    public static function padding(): int { return 10; }

    public static function hudHeight(int winH): int {
        int h = winH / 4;
        if (h < 210) { h = 210; }
        if (h > 270) { h = 270; }
        if (h > winH - 120) { h = winH - 120; }
        if (h < 160) { h = 160; }
        return h;
    }

    // Bottom-left minimap slot used by the fixed command HUD.
    // Returns [x0, y0, side, side] in screen pixels.
    public static function hudRect(int winW, int winH): int[] {
        int hudH = Minimap::hudHeight(winH);
        int side = hudH - 56;
        if (side > 220) { side = 220; }
        if (side < 140) { side = 140; }
        int[] r = new int[4];
        r[0] = 14;
        r[1] = winH - hudH + 42;
        r[2] = side;
        r[3] = side;
        return r;
    }

    // Compute the minimap rectangle in window pixels.
    // Returns [x0, y0, side, side].
    public static function rect(int winW, int winH): int[] {
        int side = Minimap:: side();
        int pad  = Minimap:: padding();
        int x0 = winW - side - pad;
        int y0 = winH - side - pad;
        int[] r = new int[4];
        r[0] = x0; r[1] = y0; r[2] = side; r[3] = side;
        return r;
    }

    public static function contains(int px, int py, int winW, int winH): bool {
        int[] r = Minimap:: rect(winW, winH);
        if (px < r[0]) { return false; }
        if (py < r[1]) { return false; }
        if (px >= r[0] + r[2]) { return false; }
        if (py >= r[1] + r[3]) { return false; }
        return true;
    }

    // Convert a screen pixel inside the minimap to world coords.
    public static function pixelToWorld(int px, int py, int winW, int winH): float[] {
        int[] r = Minimap:: rect(winW, winH);
        return Minimap::pixelToWorldInRect(px, py, r);
    }

    public static function pixelToWorldInRect(int px, int py, int[] r): float[] {
        float h = GameConst:: worldHalf();
        float world = h * 2.0;
        float fx = ((float)(px - r[0]) / (float)r[2]) * world - h;
        float fy = ((float)(py - r[1]) / (float)r[3]) * world - h;
        float[] o = new float[2];
        o[0] = fx; o[1] = fy;
        return o;
    }

    // Consume a left-click edge that landed in the minimap by panning the
    // camera. Returns true if the click was consumed.
    public static function handleClick(RenderWindow win, InputState in, CameraState cam): bool {
        if (!in.leftDownEdge) { return false; }
        int[] sz = win.size();
        if (!Minimap:: contains(in.mouseX, in.mouseY, sz[0], sz[1])) { return false; }
        float[] wp = Minimap:: pixelToWorld(in.mouseX, in.mouseY, sz[0], sz[1]);
        cam.centerX = wp[0];
        cam.centerY = wp[1];
        in.leftDownEdge = false;
        in.leftHeld     = false;
        return true;
    }

    public static function drawToTexture(RenderTexture rt, CameraState cam,
                                          WorldSnapshot snap, int sidePx): void {
        MinimapPool p = Minimap:: ensurePool();
        rt.resetView();
        rt.clear(20, 24, 32, 255);
        float x0 = 0.0;
        float y0 = 0.0;
        float side = (float)sidePx;

        RectangleShape bg = p.bg;
        bg.setOrigin(0.0, 0.0);
        bg.setPosition(x0, y0);
        bg.setSize(side, side);
        DrawTo:: rect(rt, bg);

        float h = GameConst:: worldHalf();
        float world = h * 2.0;
        float pxPerM = side / world;

        int gs = GameConst:: gridSize();
        int sg = 16;
        int cpsc = gs / sg;
        int stride = cpsc / 4;
        if (stride < 1) { stride = 1; }
        float spx = side / (float)sg;
        RectangleShape fogCell = p.dot;
        fogCell.setOrigin(0.0, 0.0);
        fogCell.setOutlineThickness(0.0);
        fogCell.setSize(spx, spx);
        int sy = 0;
        while (sy < sg) {
            int sx = 0;
            while (sx < sg) {
                int cx = sx * cpsc;
                int cy = sy * cpsc;
                int st = 0;
                int ay = 0;
                while (ay < cpsc) {
                    int ax = 0;
                    while (ax < cpsc) {
                        int s = (int)snap.fogStateF[(cy + ay) * gs + (cx + ax)];
                        if (s > st) { st = s; }
                        ax = ax + stride;
                    }
                    ay = ay + stride;
                }
                if (st != 2) {
                    int a = 235;
                    if (st == 1) { a = 130; }
                    float qx0 = x0 + ((float)sx) * spx;
                    float qy0 = y0 + side - ((float)(sy + 1)) * spx;
                    fogCell.setPosition(qx0, qy0);
                    fogCell.setFillColor(0, 0, 0, a);
                    DrawTo:: rect(rt, fogCell);
                }
                sx = sx + 1;
            }
            sy = sy + 1;
        }

        RectangleShape dot = p.dot;
        dot.setOutlineThickness(0.0);

        float tm = GameConst:: tileMeters();
        int nr = snap.resourceCount;
        int i = 0;
        while (i < nr) {
            float rx = snap.resourceX[i];
            float ry = snap.resourceY[i];
            int   rk = snap.resourceKind[i];
            int cxr = (int)((rx + h) / tm);
            int cyr = (int)((ry + h) / tm);
            int st = 0;
            if (cxr >= 0 && cyr >= 0 && cxr < gs && cyr < gs) {
                st = (int)snap.fogStateF[cyr * gs + cxr];
            }
            if (st != 0) {
                float mx = x0 + (rx + h) * pxPerM - 1.0;
                float my = y0 + side - (ry + h) * pxPerM - 1.0;
                if (rk == ResourceKind:: gas()) {
                    dot.setFillColor(120, 220, 100, 255);
                } else {
                    dot.setFillColor(60, 180, 180, 255);
                }
                dot.setOrigin(0.0, 0.0);
                dot.setPosition(mx, my);
                dot.setSize(2.0, 2.0);
                DrawTo:: rect(rt, dot);
            }
            i = i + 1;
        }

        int nb = snap.buildingCount;
        i = 0;
        while (i < nb) {
            float bx = snap.buildingX[i];
            float by = snap.buildingY[i];
            int   fc = snap.buildingFaction[i];
            int show = 1;
            if (fc != Faction:: player()) {
                int cxb = (int)((bx + h) / tm);
                int cyb = (int)((by + h) / tm);
                int st = 0;
                if (cxb >= 0 && cyb >= 0 && cxb < gs && cyb < gs) {
                    st = (int)snap.fogStateF[cyb * gs + cxb];
                }
                if (st != 2) { show = 0; }
            }
            if (show == 1) {
                float mx = x0 + (bx + h) * pxPerM - 2.5;
                float my = y0 + side - (by + h) * pxPerM - 2.5;
                if (fc == Faction:: player()) {
                    dot.setFillColor(80, 160, 240, 255);
                } else {
                    dot.setFillColor(220, 80, 80, 255);
                }
                dot.setOrigin(0.0, 0.0);
                dot.setPosition(mx, my);
                dot.setSize(5.0, 5.0);
                DrawTo:: rect(rt, dot);
            }
            i = i + 1;
        }

        int nu = snap.unitCount;
        i = 0;
        while (i < nu) {
            float ux = snap.unitX[i];
            float uy = snap.unitY[i];
            int   fc = snap.unitFaction[i];
            int show = 1;
            if (fc != Faction:: player()) {
                int cxu = (int)((ux + h) / tm);
                int cyu = (int)((uy + h) / tm);
                int st = 0;
                if (cxu >= 0 && cyu >= 0 && cxu < gs && cyu < gs) {
                    st = (int)snap.fogStateF[cyu * gs + cxu];
                }
                if (st != 2) { show = 0; }
            }
            if (show == 1) {
                float mx = x0 + (ux + h) * pxPerM - 1.5;
                float my = y0 + side - (uy + h) * pxPerM - 1.5;
                if (fc == Faction:: player()) {
                    dot.setFillColor(120, 200, 255, 255);
                } else {
                    dot.setFillColor(240, 110, 100, 255);
                }
                dot.setOrigin(0.0, 0.0);
                dot.setPosition(mx, my);
                dot.setSize(3.0, 3.0);
                DrawTo:: rect(rt, dot);
            }
            i = i + 1;
        }

        float vx0 = x0 + (cam.centerX - cam.sizeW * 0.5 + h) * pxPerM;
        float vy0 = y0 + side - (cam.centerY + cam.sizeH * 0.5 + h) * pxPerM;
        float vw  = cam.sizeW * pxPerM;
        float vh  = cam.sizeH * pxPerM;
        RectangleShape vb = p.viewBox;
        vb.setOrigin(0.0, 0.0);
        vb.setPosition(vx0, vy0);
        vb.setSize(vw, vh);
        DrawTo:: rect(rt, vb);

        rt.display();
    }

    // Draw the minimap. Caller must have already invoked Camera:: resetView.
    public static function draw(RenderWindow win, CameraState cam, WorldSnapshot snap): void {
        MinimapPool p = Minimap:: ensurePool();
        int[] sz = win.size();
        int[] r = Minimap:: rect(sz[0], sz[1]);
        float x0 = (float)r[0];
        float y0 = (float)r[1];
        float side = (float)r[2];

        // Background panel.
        RectangleShape bg = p.bg;
        bg.setOrigin(0.0, 0.0);
        bg.setPosition(x0, y0);
        bg.setSize(side, side);
        Draw:: rect(win, bg);

        // Pixel-per-world-meter on the minimap.
        float h = GameConst:: worldHalf();
        float world = h * 2.0;
        float pxPerM = side / world;

        // Fog overlay — fixed 16x16 supercell grid (256 rects max per frame);
        // each supercell summarises cpsc*cpsc world cells. Supercell state =
        // max over a stride-sampled subset of children (4x4 samples max), so
        // the inner read count stays at ~4096/frame regardless of grid size.
        int gs = GameConst:: gridSize();
        int sg = 16;
        int cpsc = gs / sg;
        int stride = cpsc / 4;
        if (stride < 1) { stride = 1; }
        float spx = side / (float)sg;
        RectangleShape fogCell = p.dot;
        fogCell.setOrigin(0.0, 0.0);
        fogCell.setOutlineThickness(0.0);
        fogCell.setSize(spx, spx);
        int sy = 0;
        while (sy < sg) {
            int sx = 0;
            while (sx < sg) {
                int cx = sx * cpsc;
                int cy = sy * cpsc;
                int st = 0;
                int ay = 0;
                while (ay < cpsc) {
                    int ax = 0;
                    while (ax < cpsc) {
                        int s = (int)snap.fogStateF[(cy + ay) * gs + (cx + ax)];
                        if (s > st) { st = s; }
                        ax = ax + stride;
                    }
                    ay = ay + stride;
                }
                if (st != 2) {
                    int a = 235;
                    if (st == 1) { a = 130; }
                    float qx0 = x0 + ((float)sx) * spx;
                    float qy0 = y0 + ((float)sy) * spx;
                    fogCell.setPosition(qx0, qy0);
                    fogCell.setFillColor(0, 0, 0, a);
                    Draw:: rect(win, fogCell);
                }
                sx = sx + 1;
            }
            sy = sy + 1;
        }

        RectangleShape dot = p.dot;
        dot.setOutlineThickness(0.0);

        // Resources (hidden in unexplored cells).
        float tm = GameConst:: tileMeters();
        int nr = snap.resourceCount;
        int i = 0;
        while (i < nr) {
            float rx = snap.resourceX[i];
            float ry = snap.resourceY[i];
            int   rk = snap.resourceKind[i];
            int cxr = (int)((rx + h) / tm);
            int cyr = (int)((ry + h) / tm);
            int st = 0;
            if (cxr >= 0 && cyr >= 0 && cxr < gs && cyr < gs) {
                st = (int)snap.fogStateF[cyr * gs + cxr];
            }
            if (st != 0) {
                float mx = x0 + (rx + h) * pxPerM - 1.0;
                float my = y0 + (ry + h) * pxPerM - 1.0;
                if (rk == ResourceKind:: gas()) {
                    dot.setFillColor(120, 220, 100, 255);
                } else {
                    dot.setFillColor(60, 180, 180, 255);
                }
                dot.setOrigin(0.0, 0.0);
                dot.setPosition(mx, my);
                dot.setSize(2.0, 2.0);
                Draw:: rect(win, dot);
            }
            i = i + 1;
        }

        // Buildings (player always; enemies only in currently-visible cells).
        int nb = snap.buildingCount;
        i = 0;
        while (i < nb) {
            float bx = snap.buildingX[i];
            float by = snap.buildingY[i];
            int   fc = snap.buildingFaction[i];
            int show = 1;
            if (fc != Faction:: player()) {
                int cxb = (int)((bx + h) / tm);
                int cyb = (int)((by + h) / tm);
                int st = 0;
                if (cxb >= 0 && cyb >= 0 && cxb < gs && cyb < gs) {
                    st = (int)snap.fogStateF[cyb * gs + cxb];
                }
                if (st != 2) { show = 0; }
            }
            if (show == 1) {
                float mx = x0 + (bx + h) * pxPerM - 2.5;
                float my = y0 + (by + h) * pxPerM - 2.5;
                if (fc == Faction:: player()) {
                    dot.setFillColor(80, 160, 240, 255);
                } else {
                    dot.setFillColor(220, 80, 80, 255);
                }
                dot.setOrigin(0.0, 0.0);
                dot.setPosition(mx, my);
                dot.setSize(5.0, 5.0);
                Draw:: rect(win, dot);
            }
            i = i + 1;
        }

        // Units (same visibility rule as buildings).
        int nu = snap.unitCount;
        i = 0;
        while (i < nu) {
            float ux = snap.unitX[i];
            float uy = snap.unitY[i];
            int   fc = snap.unitFaction[i];
            int show = 1;
            if (fc != Faction:: player()) {
                int cxu = (int)((ux + h) / tm);
                int cyu = (int)((uy + h) / tm);
                int st = 0;
                if (cxu >= 0 && cyu >= 0 && cxu < gs && cyu < gs) {
                    st = (int)snap.fogStateF[cyu * gs + cxu];
                }
                if (st != 2) { show = 0; }
            }
            if (show == 1) {
                float mx = x0 + (ux + h) * pxPerM - 1.5;
                float my = y0 + (uy + h) * pxPerM - 1.5;
                if (fc == Faction:: player()) {
                    dot.setFillColor(120, 200, 255, 255);
                } else {
                    dot.setFillColor(240, 110, 100, 255);
                }
                dot.setOrigin(0.0, 0.0);
                dot.setPosition(mx, my);
                dot.setSize(3.0, 3.0);
                Draw:: rect(win, dot);
            }
            i = i + 1;
        }

        // Camera viewport box.
        float vx0 = x0 + (cam.centerX - cam.sizeW * 0.5 + h) * pxPerM;
        float vy0 = y0 + (cam.centerY - cam.sizeH * 0.5 + h) * pxPerM;
        float vw  = cam.sizeW * pxPerM;
        float vh  = cam.sizeH * pxPerM;
        RectangleShape vb = p.viewBox;
        vb.setOrigin(0.0, 0.0);
        vb.setPosition(vx0, vy0);
        vb.setSize(vw, vh);
        Draw:: rect(win, vb);
    }
}
