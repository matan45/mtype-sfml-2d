// Selection state machine. Tracks the active drag-box (in world coords)
// across frames; commits Selected tags on left-up. Drag distance under
// 0.3 m is treated as a single click.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/Body.mt";
import * from "@mtype-box2d/Shape.mt";
import * from "@mtype-box2d/Query.mt";

import * from "../game/Constants.mt";
import * from "../render/CameraCtrl.mt";
import * from "./Input.mt";

class SelectionState {
    public bool  dragging;
    public float startX;
    public float startY;
    public float curX;
    public float curY;

    public constructor() {
        this.dragging = false;
        this.startX = 0.0;
        this.startY = 0.0;
        this.curX = 0.0;
        this.curY = 0.0;
    }
}

class Selection {
    // Resolve `mouse` to a world coordinate using `cam` and the current
    // window size. Returns float[2].
    public static function cursorWorld(RenderWindow win, CameraState cam, InputState in): float[] {
        int[] s = win.size();
        return ScreenWorld::toWorld(in.mouseX, in.mouseY,
                                      cam.centerX, cam.centerY,
                                      cam.sizeW,   cam.sizeH,
                                      s[0],        s[1]);
    }

    public static function update(Registry reg, World world,
                                    RenderWindow win, CameraState cam,
                                    InputState in, SelectionState sel): void {
        float[] cw = Selection::cursorWorld(win, cam, in);

        if (in.leftDownEdge) {
            sel.dragging = true;
            sel.startX = cw[0];
            sel.startY = cw[1];
            sel.curX = cw[0];
            sel.curY = cw[1];
        }
        if (sel.dragging) {
            sel.curX = cw[0];
            sel.curY = cw[1];
        }
        if (in.leftUpEdge && sel.dragging) {
            float dx = sel.curX - sel.startX;
            float dy = sel.curY - sel.startY;
            float d2 = dx * dx + dy * dy;
            Selection::clearAllSelected(reg);
            if (d2 < 0.09) {
                Selection::pickSingle(reg, world, sel.curX, sel.curY);
            } else {
                Selection::pickBox(reg, world, sel.startX, sel.startY, sel.curX, sel.curY);
            }
            sel.dragging = false;
        }
    }

    public static function clearAllSelected(Registry reg): void {
        string[] need = ["Selected"];
        EnttView v = reg.view(need);
        int[] all = v.entities();
        v.destroy();
        int n = all.length;
        int i = 0;
        while (i < n) {
            reg.remove(all[i], "Selected");
            i = i + 1;
        }
    }

    public static function pickSingle(Registry reg, World world, float wx, float wy): void {
        int[] hits = Query::overlapAABB(world, wx - 0.4, wy - 0.4, wx + 0.4, wy + 0.4,
                                          Cat::all(), Cat::playerPickMask());
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e) && reg.has(e, "Selectable")) {
                    reg.emplaceTag(e, "Selected");
                    return;
                }
            }
            i = i + 1;
        }
    }

    public static function pickBox(Registry reg, World world,
                                     float x0, float y0, float x1, float y1): void {
        float minX = x0; float maxX = x1;
        if (x0 > x1) { minX = x1; maxX = x0; }
        float minY = y0; float maxY = y1;
        if (y0 > y1) { minY = y1; maxY = y0; }
        int[] hits = Query::overlapAABB(world, minX, minY, maxX, maxY,
                                          Cat::all(), Cat::unitPlayer());
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e) && reg.has(e, "Selectable")
                                  && reg.has(e, "PlayerControlled")
                                  && !reg.has(e, "BaseBuilding")
                                  && !reg.has(e, "Ghost")) {
                    reg.emplaceTag(e, "Selected");
                }
            }
            i = i + 1;
        }
    }
}
