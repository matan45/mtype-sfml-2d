// Fixed RTS command HUD inspired by classic base-builder layouts. ImGui owns
// the bottom command surface; the minimap is still rendered by SFML into an
// offscreen texture and then displayed as an ImGui image.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";
import * from "@mtype-sfml/ImGui.mt";

import * from "../game/Constants.mt";
import * from "./CameraCtrl.mt";
import * from "./Snapshots.mt";
import * from "./Minimap.mt";

class HudResult {
    public bool trainWorkerClicked;
    public bool trainGruntClicked;
    public bool placeBarracksClicked;
    public bool placeRefineryClicked;
    public bool placeCommandCenterClicked;
    public bool newDebugDraw;
    public bool hovered;

    public constructor() {
        this.trainWorkerClicked        = false;
        this.trainGruntClicked         = false;
        this.placeBarracksClicked      = false;
        this.placeRefineryClicked      = false;
        this.placeCommandCenterClicked = false;
        this.newDebugDraw              = false;
        this.hovered                   = false;
    }
}

class HudPool {
    public RenderTexture minimapRt;
    public int minimapSide;

    public constructor() {
        this.minimapRt = RenderTextures::create(220, 220);
        this.minimapSide = 220;
    }
}

class Hud {
    public static HudPool? pool = null;

    public static function ensurePool(): HudPool {
        if (Hud::pool == null) { Hud::pool = new HudPool(); }
        return Hud::pool;
    }

    public static function draw(RenderWindow win, CameraState cam,
                                  WorldSnapshot snap,
                                  int minerals, int gas, float fps,
                                  int selectedCount, int selectedWorkerCount,
                                  int selectedBaseEntity,
                                  int baseQueueLen, float baseBuildLeft,
                                  int selectedBarracksEntity,
                                  int barracksQueueLen, float barracksBuildLeft,
                                  bool debugDraw,
                                  int selectedUnitEntity,
                                  float selUnitHp, float selUnitMaxHp,
                                  float selUnitAtk, float selUnitDef): HudResult {
        HudResult r = new HudResult();
        r.newDebugDraw = debugDraw;

        int[] sz = win.size();
        int winW = sz[0];
        int winH = sz[1];
        int hudH = Minimap::hudHeight(winH);
        int hudY = winH - hudH;
        int[] miniRect = Minimap::hudRect(winW, winH);
        int miniSide = miniRect[2];

        HudPool p = Hud::ensurePool();
        if (p.minimapSide != miniSide) {
            p.minimapRt.resize(miniSide, miniSide);
            p.minimapSide = miniSide;
        }
        Minimap::drawToTexture(p.minimapRt, cam, snap, miniSide);
        Texture miniTex = p.minimapRt.getTexture();

        Hud::pushTheme();
        ImGui::setNextWindowPos(0.0, (float)hudY);
        ImGui::setNextWindowSize((float)winW, (float)hudH);
        if (ImGui::beginFixed("##CommandHud")) {
            if (ImGui::isWindowHovered()) { r.hovered = true; }

            Hud::drawResourceStrip(minerals, gas, fps, r);
            Hud::drawMinimap(miniTex, miniRect, hudY, cam, r);
            Hud::drawSelectionPanel(winW, hudH, miniRect,
                                    selectedCount, selectedBaseEntity,
                                    baseQueueLen, baseBuildLeft,
                                    selectedBarracksEntity,
                                    barracksQueueLen, barracksBuildLeft,
                                    selectedUnitEntity, selUnitHp,
                                    selUnitMaxHp, selUnitAtk, selUnitDef);
            Hud::drawCommandPanel(winW, hudH, minerals,
                                  selectedWorkerCount, selectedBaseEntity,
                                  selectedBarracksEntity, r);
        }
        ImGui::end();
        Hud::popTheme();
        miniTex.destroy();

        return r;
    }

    public static function drawResourceStrip(int minerals, int gas,
                                              float fps, HudResult r): void {
        ImGui::setCursorPos(14.0, 8.0);
        if (ImGui::beginChild("##resourceStrip", 0.0, 28.0, false)) {
            ImGui::textColored(0.58, 0.92, 0.98, 1.0, "MINERALS " + minerals);
            ImGui::sameLine();
            ImGui::textColored(0.58, 0.86, 0.50, 1.0, "GAS " + gas);
            ImGui::sameLine();
            ImGui::textColored(0.78, 0.82, 0.82, 1.0, "FPS " + ((int)fps));
            ImGui::sameLine();
            r.newDebugDraw = ImGui::checkbox("Debug draw (F1)", r.newDebugDraw);
        }
        ImGui::endChild();
    }

    public static function drawMinimap(Texture miniTex, int[] miniRect,
                                        int hudY, CameraState cam,
                                        HudResult r): void {
        ImGui::setCursorPos((float)miniRect[0], (float)(miniRect[1] - hudY));
        if (ImGui::beginChild("##minimapPane", (float)miniRect[2],
                               (float)miniRect[3], true)) {
            ImGui::image(miniTex, (float)miniRect[2], (float)miniRect[3]);
            if (ImGui::isItemClicked()) {
                float[] mp = ImGui::getMousePos();
                float[] wp = Minimap::pixelToWorldInRect((int)mp[0], (int)mp[1], miniRect);
                cam.centerX = wp[0];
                cam.centerY = wp[1];
                r.hovered = true;
            }
        }
        ImGui::endChild();
    }

    public static function drawSelectionPanel(int winW, int hudH, int[] miniRect,
                                               int selectedCount,
                                               int selectedBaseEntity,
                                               int baseQueueLen,
                                               float baseBuildLeft,
                                               int selectedBarracksEntity,
                                               int barracksQueueLen,
                                               float barracksBuildLeft,
                                               int selectedUnitEntity,
                                               float selUnitHp,
                                               float selUnitMaxHp,
                                               float selUnitAtk,
                                               float selUnitDef): void {
        float pad = 14.0;
        float top = 42.0;
        float rightW = Hud::clampf((float)winW * 0.24, 320.0, 420.0);
        float x = (float)(miniRect[0] + miniRect[2]) + pad;
        float w = (float)winW - x - rightW - pad * 2.0;
        if (w < 260.0) { w = 260.0; }
        float h = (float)hudH - top - pad;

        ImGui::setCursorPos(x, top);
        if (ImGui::beginChild("##selectionPane", w, h, true)) {
            ImGui::textColored(0.86, 0.88, 0.82, 1.0, "SELECTION");
            ImGui::separator();
            if (selectedCount == 0) {
                ImGui::textDisabled("No units selected");
            } else {
                ImGui::text("Selected: " + selectedCount);
            }

            if (selectedUnitEntity != 0) {
                ImGui::spacing();
                ImGui::textColored(0.70, 0.82, 0.98, 1.0, "UNIT");
                float hpFrac = Hud::fraction(selUnitHp, selUnitMaxHp);
                ImGui::progressBar(hpFrac, -1.0, 16.0,
                                   "HP " + Hud::fmt1(selUnitHp) + " / " + Hud::fmt1(selUnitMaxHp));
                ImGui::text("ATK " + Hud::fmt1(selUnitAtk));
                ImGui::sameLine();
                ImGui::text("DEF " + Hud::fmt1(selUnitDef));
            }

            if (selectedBaseEntity != 0) {
                ImGui::spacing();
                ImGui::separator();
                ImGui::textColored(0.70, 0.82, 0.98, 1.0, "COMMAND CENTER");
                Hud::drawQueue(baseQueueLen, baseBuildLeft, GameConst::workerBuildTime());
            }

            if (selectedBarracksEntity != 0) {
                ImGui::spacing();
                ImGui::separator();
                ImGui::textColored(0.70, 0.82, 0.98, 1.0, "BARRACKS");
                Hud::drawQueue(barracksQueueLen, barracksBuildLeft, GameConst::gruntBuildTime());
            }
        }
        ImGui::endChild();
    }

    public static function drawCommandPanel(int winW, int hudH, int minerals,
                                             int selectedWorkerCount,
                                             int selectedBaseEntity,
                                             int selectedBarracksEntity,
                                             HudResult r): void {
        float pad = 14.0;
        float top = 42.0;
        float w = Hud::clampf((float)winW * 0.24, 320.0, 420.0);
        float x = (float)winW - w - pad;
        float h = (float)hudH - top - pad;

        ImGui::setCursorPos(x, top);
        if (ImGui::beginChild("##commandPane", w, h, true)) {
            ImGui::textColored(0.86, 0.88, 0.82, 1.0, "COMMANDS");
            ImGui::separator();

            int any = 0;
            if (selectedWorkerCount > 0) {
                any = 1;
                ImGui::textColored(0.70, 0.82, 0.98, 1.0, "BUILD");
                if (Hud::commandButton("Command Center", GameConst::commandCenterCost(), minerals)) {
                    r.placeCommandCenterClicked = true;
                }
                if (Hud::commandButton("Barracks", GameConst::barracksCost(), minerals)) {
                    r.placeBarracksClicked = true;
                }
                if (Hud::commandButton("Refinery", GameConst::refineryCost(), minerals)) {
                    r.placeRefineryClicked = true;
                }
            }

            if (selectedBaseEntity != 0) {
                any = 1;
                ImGui::spacing();
                ImGui::textColored(0.70, 0.82, 0.98, 1.0, "PRODUCTION");
                if (Hud::commandButton("Train Worker", GameConst::workerCost(), minerals)) {
                    r.trainWorkerClicked = true;
                }
            }

            if (selectedBarracksEntity != 0) {
                any = 1;
                ImGui::spacing();
                ImGui::textColored(0.70, 0.82, 0.98, 1.0, "PRODUCTION");
                if (Hud::commandButton("Train Grunt", GameConst::gruntCost(), minerals)) {
                    r.trainGruntClicked = true;
                }
            }

            if (any == 0) {
                ImGui::textDisabled("Select a worker or production building");
            }
        }
        ImGui::endChild();
    }

    public static function drawQueue(int queueLen, float buildLeft,
                                      float buildTime): void {
        if (queueLen > 0) {
            float frac = 1.0 - Hud::fraction(buildLeft, buildTime);
            ImGui::progressBar(frac, -1.0, 16.0,
                               "Queue " + queueLen + "  " + Hud::fmt1(buildLeft) + "s");
        } else {
            ImGui::textDisabled("Queue: idle");
        }
    }

    public static function commandButton(string label, int cost, int minerals): bool {
        string full = label + " [" + cost + " min]";
        if (minerals < cost) {
            ImGui::textDisabled(full);
            return false;
        }
        return ImGui::button(full);
    }

    public static function pushTheme(): void {
        ImGui::pushStyleColor("WindowBg", 0.06, 0.08, 0.09, 0.94);
        ImGui::pushStyleColor("ChildBg", 0.09, 0.11, 0.12, 0.92);
        ImGui::pushStyleColor("Border", 0.38, 0.42, 0.38, 0.80);
        ImGui::pushStyleColor("Button", 0.19, 0.25, 0.26, 1.0);
        ImGui::pushStyleColor("ButtonHovered", 0.28, 0.36, 0.36, 1.0);
        ImGui::pushStyleColor("ButtonActive", 0.38, 0.48, 0.46, 1.0);
        ImGui::pushStyleColor("FrameBg", 0.12, 0.16, 0.17, 1.0);
        ImGui::pushStyleColor("TextDisabled", 0.48, 0.52, 0.50, 1.0);
        ImGui::pushStyleVarVec2("WindowPadding", 0.0, 0.0);
        ImGui::pushStyleVarVec2("FramePadding", 8.0, 5.0);
        ImGui::pushStyleVarVec2("ItemSpacing", 8.0, 6.0);
        ImGui::pushStyleVarFloat("WindowRounding", 0.0);
        ImGui::pushStyleVarFloat("WindowBorderSize", 0.0);
        ImGui::pushStyleVarFloat("ChildRounding", 2.0);
        ImGui::pushStyleVarFloat("ChildBorderSize", 1.0);
    }

    public static function popTheme(): void {
        ImGui::popStyleVar(7);
        ImGui::popStyleColor(8);
    }

    public static function fraction(float v, float max): float {
        if (max <= 0.0001) { return 0.0; }
        float f = v / max;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }
        return f;
    }

    public static function clampf(float v, float lo, float hi): float {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    public static function fmt1(float v): string {
        int n = (int)(v * 10.0);
        int whole = n / 10;
        int frac  = n - whole * 10;
        if (frac < 0) { frac = -frac; }
        return whole + "." + frac;
    }
}
