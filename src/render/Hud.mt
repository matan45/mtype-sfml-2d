// ImGui HUD. Pulls primitive summary data from main.mt — does NOT touch
// the registry directly to keep Entt's `View` class out of this file's
// scope (it would collide with the `View` re-exported transitively via
// ImGui.mt -> Graphics.mt).
//
// Returns a HudResult so main.mt knows whether to queue a worker/grunt,
// enter placement mode, or toggle debug draw.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/ImGui.mt";

import * from "../game/Constants.mt";

class HudResult {
    public bool trainWorkerClicked;
    public bool trainGruntClicked;
    public bool placeBarracksClicked;
    public bool placeRefineryClicked;
    public bool newDebugDraw;

    public constructor() {
        this.trainWorkerClicked   = false;
        this.trainGruntClicked    = false;
        this.placeBarracksClicked = false;
        this.placeRefineryClicked = false;
        this.newDebugDraw         = false;
    }
}

class Hud {
    public static function draw(int minerals, int gas, float fps,
                                  int selectedCount, int selectedWorkerCount,
                                  int selectedBaseEntity,
                                  int baseQueueLen, float baseBuildLeft,
                                  int selectedBarracksEntity,
                                  int barracksQueueLen, float barracksBuildLeft,
                                  bool debugDraw): HudResult {
        HudResult r = new HudResult();
        r.newDebugDraw = debugDraw;

        if (ImGui::begin("Status")) {
            ImGui::text("Minerals: " + minerals);
            ImGui::text("Gas: " + gas);
            ImGui::text("FPS: " + ((int)fps));
            r.newDebugDraw = ImGui::checkbox("Debug draw (F1)", debugDraw);
        }
        ImGui::end();

        if (selectedWorkerCount > 0) {
            if (ImGui::begin("Build")) {
                int bCost = GameConst::barracksCost();
                string bLbl = "Build Barracks [" + bCost + " min]";
                if (minerals < bCost) {
                    ImGui::textDisabled(bLbl);
                } else if (ImGui::button(bLbl)) {
                    r.placeBarracksClicked = true;
                }
                int rCost = GameConst::refineryCost();
                string rLbl = "Build Refinery [" + rCost + " min]";
                if (minerals < rCost) {
                    ImGui::textDisabled(rLbl);
                } else if (ImGui::button(rLbl)) {
                    r.placeRefineryClicked = true;
                }
            }
            ImGui::end();
        }

        if (selectedCount > 0) {
            if (ImGui::begin("Selection")) {
                ImGui::text("Selected: " + selectedCount);
                if (selectedBaseEntity != 0) {
                    ImGui::separator();
                    ImGui::text("Base");
                    if (baseQueueLen > 0) {
                        ImGui::text("Queue: " + baseQueueLen + "  next in: "
                                      + Hud::fmt1(baseBuildLeft) + "s");
                    } else {
                        ImGui::text("Queue: idle");
                    }
                    int wCost = GameConst::workerCost();
                    string wLbl = "Train Worker [" + wCost + " min]";
                    if (minerals < wCost) {
                        ImGui::textDisabled(wLbl);
                    } else if (ImGui::button(wLbl)) {
                        r.trainWorkerClicked = true;
                    }
                }
                if (selectedBarracksEntity != 0) {
                    ImGui::separator();
                    ImGui::text("Barracks");
                    if (barracksQueueLen > 0) {
                        ImGui::text("Queue: " + barracksQueueLen + "  next in: "
                                      + Hud::fmt1(barracksBuildLeft) + "s");
                    } else {
                        ImGui::text("Queue: idle");
                    }
                    int gCost = GameConst::gruntCost();
                    string gLbl = "Train Grunt [" + gCost + " min]";
                    if (minerals < gCost) {
                        ImGui::textDisabled(gLbl);
                    } else if (ImGui::button(gLbl)) {
                        r.trainGruntClicked = true;
                    }
                }
            }
            ImGui::end();
        }

        return r;
    }

    // Cheap 1-decimal formatter without pulling in any stdlib.
    public static function fmt1(float v): string {
        int n = (int)(v * 10.0);
        int whole = n / 10;
        int frac  = n - whole * 10;
        if (frac < 0) { frac = -frac; }
        return whole + "." + frac;
    }
}
