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
import * from "../render/Minimap.mt";

import * from "../sim/Schema.mt";
import * from "../sim/Spawn.mt";
import * from "../sim/Pathing.mt";
import * from "../sim/Steering.mt";
import * from "../sim/Events.mt";
import * from "../sim/Combat.mt";
import * from "../sim/Construct.mt";
import * from "../sim/Placement.mt";
import * from "../sim/Production.mt";
import * from "../sim/Upgrade.mt";
import * from "../sim/Power.mt";
import * from "../sim/Cleanup.mt";
import * from "../sim/Sampling.mt";
import * from "../sim/Commands.mt";
import * from "../sim/Fog.mt";

@EntryPoint
class App {
    public static function main(string[] args): void {
        __plugin_load("mt_modules/@mtype-sfml/mt/mtype_sfml.dll");
        __plugin_load("mt_modules/@mtype-box2d/mt/mtype_b2d.dll");
        __plugin_load("mt_modules/@mtype-entt/mt/mtype_entt.dll");
        Audio::init();
        int W = 1920;
        int H = 1080;
        RenderWindow win = Sfml::createWindow("RTS-MVP", W, H);
        win.setFramerateLimit(0);
        win.setVsync(true);
        ImGui::init(win);

        World    world = Box2D::createWorld(0.0, 0.0);
        Registry reg   = Entts::createRegistry();
        Schema::registerAll(reg);
        // EnttView::next() uses 0 as its exhausted sentinel, and the
        // gameplay code also treats entity id 0 as "none". Reserve it so
        // real game entities start at 1 and are visible to all view loops.
        reg.create();

        View view = Views::create(0.0, 0.0, 60.0, 33.75);
        CameraState cam = new CameraState(0.0, 0.0, 60.0, 33.75);

        Spawn::initialMap(reg, world);

        Clock clk = Clocks::create();
        InputState input = new InputState();
        SelectionState sel = new SelectionState();
        PlacementState pls = new PlacementState();
        WorldSnapshot snap = new WorldSnapshot();

        float acc       = 0.0;
        float fixedDt   = GameConst::fixedDt();
        int   subSteps  = GameConst::physSubSteps();
        float maxFrame  = GameConst::maxFrameDt();
        float fpsAvg    = 60.0;

        while (win.isOpen()) {
            Input::pump(win, input);
            if (input.quitRequested) { win.close(); }
            Placement::update(reg, world, win, cam, input, pls);
            Commands::apply(reg, world, win, cam, input);
            Selection::update(reg, world, win, cam, input, sel);

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
                Power::refresh(reg);
                Production::run(reg, world, fixedDt);
                Upgrade::run(reg, fixedDt);
                Cleanup::run(reg, world);
                Power::refresh(reg);
                Fog::update(reg);
                acc = acc - fixedDt;
            }

            CameraCtrl::update(cam, input, frame);
            CameraCtrl::apply(view, cam);
            Sampling::refresh(reg, snap);
            Power::refresh(reg);

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
            int selPowerPlant = App::selectedPowerPlant(reg);
            int selectedWorkerCount = App::countSelectedWorkers(reg);
            int selectedPlayerUnitCount = App::countSelectedPlayerUnits(reg);
            int selectedCombatCount = App::countSelectedCombatUnits(reg);

            int selUnitE = App::singleSelectedUnit(reg);
            float selUnitHp    = 0.0;
            float selUnitMaxHp = 0.0;
            float selUnitAtk   = 0.0;
            float selUnitDef   = 0.0;
            if (selUnitE != 0) {
                Unit u = (Unit) reg.get(selUnitE, "Unit");
                selUnitHp    = u.hp;
                selUnitMaxHp = u.maxHp;
                selUnitAtk   = u.attackDamage;
                selUnitDef   = u.defense;
            }

            int minerals = reg.ctxGetInt("minerals");
            int gas      = reg.ctxGetInt("gas");
            int powerUsed = reg.ctxGetInt("powerUsed");
            int powerCap  = reg.ctxGetInt("powerCap");
            bool lowPower = reg.ctxGetInt("lowPower") == 1;
            int infantryWeaponsLevel = reg.ctxGetInt("infantryWeaponsLevel");
            bool infantryWeaponsResearching = reg.ctxGetInt("infantryWeaponsResearching") == 1;
            float infantryWeaponsBuildLeft = reg.ctxGetFloat("infantryWeaponsBuildLeft");
            HudInput hudInput = new HudInput(win, cam, snap,
                                             minerals, gas, fpsAvg,
                                             powerUsed, powerCap, lowPower,
                                             snap.selectedCount, selectedWorkerCount,
                                             selectedPlayerUnitCount, selectedCombatCount,
                                             selBase, baseQueueLen, baseBuildLeft,
                                             selBarracks, barracksQueueLen, barracksBuildLeft,
                                             selPowerPlant,
                                             infantryWeaponsLevel,
                                             infantryWeaponsResearching,
                                             infantryWeaponsBuildLeft,
                                             input.debugDraw,
                                             input.commandMode,
                                             selUnitE, selUnitHp, selUnitMaxHp,
                                             selUnitAtk, selUnitDef);
            HudResult hr = Hud::draw(hudInput);
            input.debugDraw = hr.newDebugDraw;
            input.imguiHovered = hr.hovered;
            if (hr.attackMoveClicked) {
                input.commandMode = CommandMode::attackMove();
            }
            if (hr.stopClicked) {
                Commands::stopSelected(reg);
                input.commandMode = CommandMode::normal();
            }
            if (hr.trainWorkerClicked && selBase != 0) {
                Production::tryQueueUnit(reg, selBase);
            }
            if (hr.trainGruntClicked && selBarracks != 0) {
                Production::tryQueueUnit(reg, selBarracks);
            }
            if (hr.researchInfantryWeaponsClicked && selBarracks != 0) {
                Upgrade::tryStartInfantryWeapons(reg);
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
            if (hr.placePowerPlantClicked && !pls.active) {
                pls.start(BuildingKind::powerPlant());
            }

            win.clear(28, 32, 38, 255);
            Render::world(win, view, cam, snap, world, input, sel, pls);
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

    public static function selectedPowerPlant(Registry reg): int {
        string[] need = ["Selected", "Building", "PowerPlant"];
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

    public static function countSelectedPlayerUnits(Registry reg): int {
        string[] need = ["Selected", "Unit", "PlayerControlled"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) { n = n + 1; e = v.next(); }
        v.destroy();
        return n;
    }

    public static function countSelectedCombatUnits(Registry reg): int {
        string[] need = ["Selected", "Unit", "PlayerControlled"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) {
            Unit u = (Unit) reg.get(e, "Unit");
            if (u.attackDamage > 0.0) { n = n + 1; }
            e = v.next();
        }
        v.destroy();
        return n;
    }

    // The Selected unit-bearing entity when exactly one is selected. Returns
    // 0 otherwise. Used by the HUD Selection panel to show HP/ATK/DEF.
    public static function singleSelectedUnit(Registry reg): int {
        string[] need = ["Selected", "Unit"];
        EnttView v = reg.view(need);
        int found = 0;
        int n = 0;
        int e = v.next();
        while (e != 0) {
            found = e;
            n = n + 1;
            e = v.next();
        }
        v.destroy();
        if (n == 1) { return found; }
        return 0;
    }
}


