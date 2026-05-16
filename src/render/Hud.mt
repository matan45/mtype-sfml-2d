// ImGui HUD. Pulls primitive summary data from main.mt — does NOT touch
// the registry directly to keep Entt's `View` class out of this file's
// scope (it would collide with the `View` re-exported transitively via
// ImGui.mt -> Graphics.mt).
//
// Returns a HudResult so main.mt knows whether to queue a worker or
// toggle debug draw.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/ImGui.mt";

class HudResult {
    public bool trainWorkerClicked;
    public bool newDebugDraw;

    public constructor() {
        this.trainWorkerClicked = false;
        this.newDebugDraw = false;
    }
}

class Hud {
    public static function draw(int minerals, float fps,
                                  int selectedCount, int selectedBaseEntity,
                                  int queueLen, float buildLeft, int workerCost,
                                  bool debugDraw): HudResult {
        HudResult r = new HudResult();
        r.newDebugDraw = debugDraw;

        if (ImGui::begin("Status")) {
            ImGui::text("Minerals: " + minerals);
            ImGui::text("FPS: " + ((int)fps));
            r.newDebugDraw = ImGui::checkbox("Debug draw (F1)", debugDraw);
        }
        ImGui::end();

        if (selectedCount > 0) {
            if (ImGui::begin("Selection")) {
                ImGui::text("Selected: " + selectedCount);
                if (selectedBaseEntity != 0) {
                    ImGui::separator();
                    ImGui::text("Base");
                    if (queueLen > 0) {
                        ImGui::text("Queue: " + queueLen + "  next in: " + Hud::fmt1(buildLeft) + "s");
                    } else {
                        ImGui::text("Queue: idle");
                    }
                    bool canAfford = minerals >= workerCost;
                    string lbl = "Train Worker [" + workerCost + " min]";
                    if (!canAfford) {
                        ImGui::textDisabled(lbl);
                    } else if (ImGui::button(lbl)) {
                        r.trainWorkerClicked = true;
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
