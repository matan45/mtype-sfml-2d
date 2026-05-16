// Entry point. Loads native plugins, builds the world / window / registry /
// camera, runs the fixed-timestep main loop, tears down on exit.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";
import * from "@mtype-sfml/System.mt";
import * from "@mtype-sfml/ImGui.mt";

import * from "@mtype-box2d/Box2D.mt";

import * from "@mtype-entt/Entt.mt";

import * from "../game/Constants.mt";

import * from "../audio/Audio.mt";

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
import * from "../sim/Construct.mt";
import * from "../sim/Placement.mt";
import * from "../sim/Production.mt";
import * from "../sim/Cleanup.mt";
import * from "../sim/Sampling.mt";
import * from "../sim/Commands.mt";

@EntryPoint
class App {
    public static function main(string[] args): void {
        __plugin_load("mt_modules/@mtype-sfml/mt/mtype_sfml.dll");
        __plugin_load("mt_modules/@mtype-box2d/mt/mtype_b2d.dll");
        __plugin_load("mt_modules/@mtype-entt/mt/mtype_entt.dll");
        Audio::init();
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
        PlacementState pls = new PlacementState();
        WorldSnapshot snap = new WorldSnapshot();

        float acc       = 0.0;
        float fixedDt   = GameConst::fixedDt();
        int   subSteps  = GameConst::physSubSteps();
        float maxFrame  = GameConst::maxFrameDt();
        float fpsAvg    = 60.0;

        while (win.isOpen()) {
            Input::pump(win, in);
            if (in.quitRequested) { win.close(); }
            Placement::update(reg, world, win, cam, in, pls);
            Selection::update(reg, world, win, cam, in, sel);
            Commands::apply(reg, world, win, cam, in);

            float frame = clk.restartSeconds();
            if (frame > maxFrame) { frame = maxFrame; }
            if (frame > 0.0001) {
                float instant = 1.0 / frame;
                fpsAvg = fpsAvg * 0.9 + instant * 0.1;
            }
            acc = acc + frame;

            while (acc >= fixedDt) {
                Combat::run(reg, world, fixedDt);
                Gather::run(reg, world, fixedDt);
                Construct::run(reg, world, fixedDt);
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

            int selBase     = App::selectedBase(reg);
            int baseQueueLen    = 0;
            float baseBuildLeft = 0.0;
            if (selBase != 0) {
                Building b = (Building) reg.get(selBase, "Building");
                baseQueueLen  = b.queueLen;
                baseBuildLeft = b.buildLeft;
            }
            int selBarracks = App::selectedBarracks(reg);
            int barracksQueueLen    = 0;
            float barracksBuildLeft = 0.0;
            if (selBarracks != 0) {
                Building b = (Building) reg.get(selBarracks, "Building");
                barracksQueueLen  = b.queueLen;
                barracksBuildLeft = b.buildLeft;
            }
            int selectedWorkerCount = App::countSelectedWorkers(reg);

            int minerals = reg.ctxGetInt("minerals");
            int gas      = reg.ctxGetInt("gas");
            HudResult hr = Hud::draw(minerals, gas, fpsAvg,
                                       snap.selectedCount, selectedWorkerCount,
                                       selBase, baseQueueLen, baseBuildLeft,
                                       selBarracks, barracksQueueLen, barracksBuildLeft,
                                       in.debugDraw);
            in.debugDraw = hr.newDebugDraw;
            if (hr.trainWorkerClicked && selBase != 0) {
                Production::tryQueueUnit(reg, selBase);
            }
            if (hr.trainGruntClicked && selBarracks != 0) {
                Production::tryQueueUnit(reg, selBarracks);
            }
            if (hr.placeBarracksClicked && !pls.active) {
                pls.start(BuildingKind::barracks());
            }
            if (hr.placeRefineryClicked && !pls.active) {
                pls.start(BuildingKind::refinery());
            }
            if (hr.placeCommandCenterClicked && !pls.active) {
                pls.start(BuildingKind::commandCenter());
            }

            win.clear(28, 32, 38, 255);
            Render::world(win, view, cam, snap, world, in, sel, pls);
            ImGui::render(win);
            win.display();
        }

        Audio::shutdown();
        ImGui::shutdown();
        view.destroy();
        reg.destroy();
        world.destroy();
        win.destroy();

        __plugin_unload("mt_modules/@mtype-entt/mt/mtype_entt.dll");
        __plugin_unload("mt_modules/@mtype-box2d/mt/mtype_b2d.dll");
        __plugin_unload("mt_modules/@mtype-sfml/mt/mtype_sfml.dll");
    }

    // First Selected BaseBuilding (initial Base or completed Command
    // Center). Returns 0 if no base-like building is currently selected.
    public static function selectedBase(Registry reg): int {
        string[] need = ["Selected", "Building", "BaseBuilding"];
        EnttView v = reg.view(need);
        int found = 0;
        int e = v.next();
        while (e != 0) {
            if (!reg.has(e, "Ghost")) { found = e; }
            e = v.next();
        }
        v.destroy();
        return found;
    }

    // First Selected barracks (real, not ghost). Used by the HUD to surface
    // the Train Grunt panel.
    public static function selectedBarracks(Registry reg): int {
        string[] need = ["Selected", "Building", "Barracks"];
        EnttView v = reg.view(need);
        int found = 0;
        int e = v.next();
        while (e != 0) {
            if (!reg.has(e, "Ghost")) { found = e; }
            e = v.next();
        }
        v.destroy();
        return found;
    }

    // Number of Selected player workers. Drives the visibility of the
    // Build panel.
    public static function countSelectedWorkers(Registry reg): int {
        string[] need = ["Selected", "Unit", "Worker"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) { n = n + 1; e = v.next(); }
        v.destroy();
        return n;
    }
}
