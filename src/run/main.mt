// Entry point. Loads native plugins, builds the world / window / registry /
// camera, runs the fixed-timestep main loop, tears down on exit.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";
import * from "@mtype-sfml/System.mt";
import * from "@mtype-sfml/ImGui.mt";

import * from "@mtype-box2d/Box2D.mt";

import * from "@mtype-entt/Entt.mt";

import * from "../game/Constants.mt";

import * from "../input/Input.mt";
import * from "../input/Selection.mt";

import * from "../render/CameraCtrl.mt";
import * from "../render/Snapshots.mt";
import * from "../render/Render.mt";
import * from "../render/Hud.mt";

import * from "../sim/Schema.mt";
import * from "../sim/Spawn.mt";
import * from "../sim/Pathing.mt";
import * from "../sim/Steering.mt";
import * from "../sim/Events.mt";
import * from "../sim/Combat.mt";
import * from "../sim/Production.mt";
import * from "../sim/Cleanup.mt";
import * from "../sim/Sampling.mt";
import * from "../sim/Commands.mt";


class App {
    public static function main(string[] args): void {
        __plugin_load("mt_modules/@mtype-sfml/mt/mtype_sfml.dll");
        __plugin_load("mt_modules/@mtype-box2d/mt/mtype_b2d.dll");
        __plugin_load("mt_modules/@mtype-entt/mt/mtype_entt.dll");
        int W = 1280;
        int H = 720;
        RenderWindow win = Sfml::createWindow("RTS-MVP", W, H);
        win.setFramerateLimit(0);
        win.setVsync(true);
        ImGui::init(win);

        World    world = Box2D::createWorld(0.0, 0.0);
        Registry reg   = Entts::createRegistry();
        Schema::registerAll(reg);

        View view = Views::create(0.0, 0.0, 60.0, 33.75);
        CameraState cam = new CameraState(0.0, 0.0, 60.0, 33.75);

        Spawn::initialMap(reg, world);

        Clock clk = Clocks::create();
        InputState in = new InputState();
        SelectionState sel = new SelectionState();
        WorldSnapshot snap = new WorldSnapshot();

        float acc       = 0.0;
        float fixedDt   = GameConst::fixedDt();
        int   subSteps  = GameConst::physSubSteps();
        float maxFrame  = GameConst::maxFrameDt();
        float fpsAvg    = 60.0;

        while (win.isOpen()) {
            Input::pump(win, in);
            if (in.quitRequested) { win.close(); }

            float frame = clk.restartSeconds();
            if (frame > maxFrame) { frame = maxFrame; }
            if (frame > 0.0001) {
                float instant = 1.0 / frame;
                fpsAvg = fpsAvg * 0.9 + instant * 0.1;
            }
            acc = acc + frame;

            while (acc >= fixedDt) {
                Commands::apply(reg, world, win, cam, in);
                Selection::update(reg, world, win, cam, in, sel);
                Combat::run(reg, world, fixedDt);
                Gather::run(reg, world, fixedDt);
                Steering::run(reg, fixedDt);
                world.step(fixedDt, subSteps);
                Events::drain(world);
                Production::run(reg, world, fixedDt);
                Cleanup::run(reg, world);
                acc = acc - fixedDt;
            }

            CameraCtrl::update(cam, in, frame);
            CameraCtrl::apply(view, cam);
            Sampling::refresh(reg, snap);

            ImGui::update(win, frame * 1000.0);

            int baseE       = reg.ctxGetInt("baseEntity");
            int selBase     = App::selectedBase(reg, baseE);
            int queueLen    = 0;
            float buildLeft = 0.0;
            if (selBase != 0) {
                Building b = (Building) reg.get(selBase, "Building");
                queueLen  = b.queueLen;
                buildLeft = b.buildLeft;
            }
            int minerals = reg.ctxGetInt("minerals");
            HudResult hr = Hud::draw(minerals, fpsAvg, snap.selectedCount,
                                       selBase, queueLen, buildLeft,
                                       GameConst::workerCost(), in.debugDraw);
            in.debugDraw = hr.newDebugDraw;
            if (hr.trainWorkerClicked && selBase != 0) {
                Production::tryQueueWorker(reg, selBase);
            }

            win.clear(28, 32, 38, 255);
            Render::world(win, view, cam, snap, world, in, sel);
            ImGui::render(win);
            win.display();
        }

        ImGui::shutdown();
        view.destroy();
        reg.destroy();
        world.destroy();
        win.destroy();

        __plugin_unload("mt_modules/@mtype-entt/mt/mtype_entt.dll");
        __plugin_unload("mt_modules/@mtype-box2d/mt/mtype_b2d.dll");
        __plugin_unload("mt_modules/@mtype-sfml/mt/mtype_sfml.dll");
    }

    // Returns the entity id of the currently-selected base (only if it is
    // PlayerControlled), else 0.
    public static function selectedBase(Registry reg, int baseE): int {
        if (baseE == 0) { return 0; }
        if (!reg.valid(baseE)) { return 0; }
        if (reg.has(baseE, "Selected")) { return baseE; }
        return 0;
    }
}

App::main([]);
