// All world-space drawing. Pulls live data from the registry + Box2D
// bodies each frame (no cached transforms). Reuses a tiny pool of shape
// handles — never allocates a SFML shape per entity per frame.
//
// NAMESPACE NOTE: both @mtype-entt/Entt.mt and @mtype-sfml/Graphics.mt
// define a class named `View`. We only need queries here, so we DO NOT
// import Entt.mt directly — instead, Sampling.mt does the iteration
// and hands us plain int[] / float[] snapshots.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";
import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/DebugDraw.mt";

import * from "../game/Constants.mt";
import * from "./CameraCtrl.mt";
import * from "../input/Input.mt";
import * from "../input/Selection.mt";
import * from "../sim/Placement.mt";
import * from "./Snapshots.mt";

// Pool of shape primitives reused across the frame. Created once on
// startup by Render::init and never destroyed until shutdown.
class RenderPool {
    public CircleShape    unitCircle;
    public CircleShape    selectionRing;
    public CircleShape    debugCircle;
    public RectangleShape buildingRect;
    public RectangleShape resourceRect;
    public RectangleShape hpBack;
    public RectangleShape hpFront;
    public RectangleShape dragBox;
    public ConvexShape    debugPoly;
    public VertexArray    debugSegments;
    public bool ready;

    public constructor() {
        this.unitCircle    = Circles::create(0.4);
        this.selectionRing = Circles::create(0.6);
        this.debugCircle   = Circles::create(0.5);
        this.buildingRect  = Rectangles::create(4.0, 4.0);
        this.resourceRect  = Rectangles::create(2.0, 2.0);
        this.hpBack        = Rectangles::create(1.0, 0.15);
        this.hpFront       = Rectangles::create(1.0, 0.15);
        this.dragBox       = Rectangles::create(1.0, 1.0);
        this.debugPoly     = ConvexShapes::create(8);
        this.debugSegments = VertexArrays::create(Primitive::lines(), 1024);

        this.selectionRing.setFillColor(0, 0, 0, 0);
        this.selectionRing.setOutlineColor(80, 230, 110, 220);
        this.selectionRing.setOutlineThickness(0.08);

        this.debugCircle.setFillColor(0, 0, 0, 0);
        this.debugCircle.setOutlineColor(230, 230, 60, 200);
        this.debugCircle.setOutlineThickness(0.05);

        this.debugPoly.setFillColor(0, 0, 0, 0);
        this.debugPoly.setOutlineColor(230, 230, 60, 200);
        this.debugPoly.setOutlineThickness(0.05);

        this.dragBox.setFillColor(80, 200, 110, 40);
        this.dragBox.setOutlineColor(80, 230, 110, 220);
        this.dragBox.setOutlineThickness(1.5);

        this.ready = true;
    }
}

class Render {
    // Lazy-initialized: RenderPool's constructor calls SFML natives, so it
    // can only run after main.mt has loaded the SFML plugin.
    public static RenderPool? pool = null;

    public static function ensurePool(): RenderPool {
        if (Render::pool == null) {
            Render::pool = new RenderPool();
        }
        return Render::pool;
    }

    public static function world(RenderWindow win, View view, CameraState cam,
                                   WorldSnapshot snap, World physics,
                                   InputState in, SelectionState sel,
                                   PlacementState pls): void {
        RenderPool p = Render::ensurePool();
        Camera::setView(win, view);

        // Buildings.
        int nb = snap.buildingCount;
        int i = 0;
        while (i < nb) {
            float bx = snap.buildingX[i];
            float by = snap.buildingY[i];
            int   fc = snap.buildingFaction[i];
            int   bk = snap.buildingKind[i];
            int   gh = snap.buildingIsGhost[i];
            float hw = snap.buildingHw[i];
            float hh = snap.buildingHh[i];
            RectangleShape r = p.buildingRect;
            r.setSize(hw * 2.0, hh * 2.0);
            r.setOrigin(hw, hh);
            r.setPosition(bx, by);
            int rC = 80;  int gC = 130; int bC = 200;
            if (bk == BuildingKind::barracks()) {
                rC = 130; gC = 120; bC = 60;
            } else if (bk == BuildingKind::refinery()) {
                rC = 60; gC = 170; bC = 160;
            }
            if (fc != Faction::player()) {
                rC = 200; gC = 90; bC = 80;
            }
            int alpha = 255;
            if (gh == 1) { alpha = 110; }
            r.setFillColor(rC, gC, bC, alpha);
            r.setOutlineColor(20, 20, 30, alpha);
            r.setOutlineThickness(0.06);
            Draw::rect(win, r);

            // Ghost: progress bar above.
            if (gh == 1) {
                float prog = snap.buildingProgress[i];
                if (prog < 0.0) { prog = 0.0; }
                if (prog > 1.0) { prog = 1.0; }
                float bw = hw * 1.6;
                float bh = 0.18;
                float pbx = bx - bw * 0.5;
                float pby = by - hh - 0.5;
                RectangleShape back = p.hpBack;
                back.setSize(bw, bh);
                back.setOrigin(0.0, 0.0);
                back.setPosition(pbx, pby);
                back.setFillColor(30, 30, 40, 230);
                back.setOutlineThickness(0.0);
                Draw::rect(win, back);

                RectangleShape front = p.hpFront;
                front.setSize(bw * prog, bh);
                front.setOrigin(0.0, 0.0);
                front.setPosition(pbx, pby);
                front.setFillColor(220, 200, 90, 230);
                front.setOutlineThickness(0.0);
                Draw::rect(win, front);
            }
            i = i + 1;
        }

        // Resources.
        int nr = snap.resourceCount;
        i = 0;
        while (i < nr) {
            float rx = snap.resourceX[i];
            float ry = snap.resourceY[i];
            int   rk = snap.resourceKind[i];
            float hw = snap.resourceHw[i];
            float hh = snap.resourceHh[i];
            RectangleShape r = p.resourceRect;
            r.setSize(hw * 2.0, hh * 2.0);
            r.setOrigin(hw, hh);
            r.setPosition(rx, ry);
            if (rk == ResourceKind::gas()) {
                r.setFillColor(120, 220, 100, 255);
            } else {
                r.setFillColor(60, 180, 180, 255);
            }
            r.setOutlineColor(20, 20, 30, 255);
            r.setOutlineThickness(0.05);
            Draw::rect(win, r);
            i = i + 1;
        }

        // Units.
        int nu = snap.unitCount;
        i = 0;
        while (i < nu) {
            float ux = snap.unitX[i];
            float uy = snap.unitY[i];
            int   fc = snap.unitFaction[i];
            float rd = snap.unitRadius[i];

            CircleShape c = p.unitCircle;
            c.setRadius(rd);
            c.setOrigin(rd, rd);
            c.setPosition(ux, uy);
            if (fc == Faction::player()) {
                c.setFillColor(100, 160, 240, 255);
            } else {
                c.setFillColor(230, 90, 80, 255);
            }
            c.setOutlineColor(20, 20, 30, 255);
            c.setOutlineThickness(0.04);
            Draw::circle(win, c);
            i = i + 1;
        }

        // Selection rings (units + selected building).
        int ns = snap.selectedCount;
        i = 0;
        while (i < ns) {
            float sx = snap.selectedX[i];
            float sy = snap.selectedY[i];
            float sr = snap.selectedRadius[i];
            CircleShape c = p.selectionRing;
            float ring = sr + 0.15;
            c.setRadius(ring);
            c.setOrigin(ring, ring);
            c.setPosition(sx, sy);
            Draw::circle(win, c);
            i = i + 1;
        }

        // HP bars over units with hp < maxHp.
        i = 0;
        while (i < nu) {
            float hp = snap.unitHp[i];
            float mx = snap.unitMaxHp[i];
            if (hp < mx) {
                float ux = snap.unitX[i];
                float uy = snap.unitY[i];
                float rd = snap.unitRadius[i];
                float bw = 1.0;
                float bh = 0.15;
                float bx = ux - bw * 0.5;
                float by = uy - rd - 0.5;
                RectangleShape back = p.hpBack;
                back.setSize(bw, bh);
                back.setOrigin(0.0, 0.0);
                back.setPosition(bx, by);
                back.setFillColor(60, 20, 20, 230);
                back.setOutlineThickness(0.0);
                Draw::rect(win, back);

                RectangleShape front = p.hpFront;
                float frac = hp / mx;
                if (frac < 0.0) { frac = 0.0; }
                if (frac > 1.0) { frac = 1.0; }
                front.setSize(bw * frac, bh);
                front.setOrigin(0.0, 0.0);
                front.setPosition(bx, by);
                front.setFillColor(80, 220, 100, 230);
                front.setOutlineThickness(0.0);
                Draw::rect(win, front);
            }
            i = i + 1;
        }

        // Debug-draw overlay (Box2D shapes).
        if (in.debugDraw) {
            physics.setDebugDrawFlags(true, false, false, false, true, false);
            physics.draw();

            int cc = DebugDraw::circleCount(physics);
            int j = 0;
            while (j < cc) {
                float[] d = DebugDraw::circle(physics, j);
                float cx = d[0];
                float cy = d[1];
                float radius = d[2];
                CircleShape c = p.debugCircle;
                c.setRadius(radius);
                c.setOrigin(radius, radius);
                c.setPosition(cx, cy);
                Draw::circle(win, c);
                j = j + 1;
            }
            int sc = DebugDraw::segmentCount(physics);
            if (sc > 0) {
                VertexArray va = p.debugSegments;
                int need = sc * 2;
                if (va.size() < need) { va.resize(need); }
                j = 0;
                while (j < sc) {
                    float[] s = DebugDraw::segment(physics, j);
                    va.setVertex(j * 2,     s[0], s[1], 230, 230, 60, 220, 0.0, 0.0);
                    va.setVertex(j * 2 + 1, s[2], s[3], 230, 230, 60, 220, 0.0, 0.0);
                    j = j + 1;
                }
                Draw::vertexArray(win, va);
            }
        }

        // Placement preview (world space, drawn on top of buildings/units).
        if (pls.active) {
            float hw = GameConst::barracksHalfW();
            float hh = GameConst::barracksHalfH();
            if (pls.kind == BuildingKind::refinery()) {
                hw = GameConst::refineryHalfW();
                hh = GameConst::refineryHalfH();
            } else if (pls.kind == BuildingKind::commandCenter()) {
                hw = GameConst::baseHalfW();
                hh = GameConst::baseHalfH();
            }
            RectangleShape r = p.buildingRect;
            r.setSize(hw * 2.0, hh * 2.0);
            r.setOrigin(hw, hh);
            r.setPosition(pls.snapX, pls.snapY);
            if (pls.validPos) {
                r.setFillColor(80, 230, 110, 90);
                r.setOutlineColor(80, 230, 110, 220);
            } else {
                r.setFillColor(230, 80, 80, 90);
                r.setOutlineColor(230, 80, 80, 220);
            }
            r.setOutlineThickness(0.08);
            Draw::rect(win, r);
        }

        Camera::resetView(win);

        // Drag-box overlay (screen space).
        if (sel.dragging) {
            int[] sz = win.size();
            float minX = sel.startX; float maxX = sel.curX;
            if (sel.startX > sel.curX) { minX = sel.curX; maxX = sel.startX; }
            float minY = sel.startY; float maxY = sel.curY;
            if (sel.startY > sel.curY) { minY = sel.curY; maxY = sel.startY; }
            // World -> screen using camera + window size.
            float wx0 = ((minX - cam.centerX) / cam.sizeW) * (float)sz[0] + (float)sz[0] * 0.5;
            float wy0 = ((minY - cam.centerY) / cam.sizeH) * (float)sz[1] + (float)sz[1] * 0.5;
            float wx1 = ((maxX - cam.centerX) / cam.sizeW) * (float)sz[0] + (float)sz[0] * 0.5;
            float wy1 = ((maxY - cam.centerY) / cam.sizeH) * (float)sz[1] + (float)sz[1] * 0.5;
            RectangleShape r = p.dragBox;
            r.setOrigin(0.0, 0.0);
            r.setPosition(wx0, wy0);
            r.setSize(wx1 - wx0, wy1 - wy0);
            Draw::rect(win, r);
        }
    }
}
