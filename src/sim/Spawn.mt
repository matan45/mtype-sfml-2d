// Entity-and-body factories. Each function creates a Box2D body, attaches
// the right collision shape, registers the entity, emplaces components,
// and wires the body's userDataInt to the entity id so physics events
// can be mapped back to ECS.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/Body.mt";
import * from "@mtype-box2d/Shape.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Pathing.mt";

class Spawn {
    // Create a player worker at (x, y). Dynamic body, circle hard shape,
    // no sensor (workers don't auto-attack).
    public static function worker(Registry reg, World world, float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::dynamicBody());
        bd.setPosition(x, y);
        bd.setFixedRotation(true);
        bd.setLinearDamping(8.0);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setDensity(1.0);
        sd.setFriction(0.3);
        sd.setFilter(Cat::unitPlayer(),
                     Cat::terrain() | Cat::building() | Cat::resource()
                     | Cat::unitPlayer() | Cat::unitEnemy(),
                     0);
        Shape sh = Shapes::createCircle(b, sd, GameConst::workerRadius(), 0.0, 0.0);
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Unit u = new Unit();
        u.kind = UnitKind::worker();
        u.faction = Faction::player();
        u.hp = GameConst::workerHp();
        u.maxHp = GameConst::workerHp();
        u.radius = GameConst::workerRadius();
        u.speed = GameConst::workerSpeed();
        u.attackRange = 0.0;
        u.attackDamage = 0.0;
        u.attackCooldown = 0.0;
        u.cooldownLeft = 0.0;
        reg.emplace(e, "Unit", u);

        Selectable sel = new Selectable();
        sel.radius = GameConst::workerRadius() + 0.3;
        reg.emplace(e, "Selectable", sel);

        reg.emplaceTag(e, "PlayerControlled");
        reg.emplaceTag(e, "Worker");
        return e;
    }

    // Create an enemy grunt at (x, y). Dynamic body + circle hard shape +
    // larger circle sensor for target acquisition.
    public static function grunt(Registry reg, World world, float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::dynamicBody());
        bd.setPosition(x, y);
        bd.setFixedRotation(true);
        bd.setLinearDamping(8.0);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setDensity(1.2);
        sd.setFriction(0.3);
        sd.setFilter(Cat::unitEnemy(),
                     Cat::terrain() | Cat::building() | Cat::resource()
                     | Cat::unitPlayer() | Cat::unitEnemy(),
                     0);
        Shape sh = Shapes::createCircle(b, sd, GameConst::gruntRadius(), 0.0, 0.0);
        sd.destroy();

        ShapeDef sdS = new ShapeDef();
        sdS.setDensity(0.0);
        sdS.setIsSensor(true);
        sdS.enableSensorEvents(true);
        sdS.setFilter(Cat::sensor(), Cat::unitPlayer(), 0);
        Shape sens = Shapes::createCircle(b, sdS,
                                           GameConst::gruntRange() + GameConst::gruntSensorPad(),
                                           0.0, 0.0);
        sdS.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Unit u = new Unit();
        u.kind = UnitKind::grunt();
        u.faction = Faction::enemy();
        u.hp = GameConst::gruntHp();
        u.maxHp = GameConst::gruntHp();
        u.radius = GameConst::gruntRadius();
        u.speed = GameConst::gruntSpeed();
        u.attackRange = GameConst::gruntRange();
        u.attackDamage = GameConst::gruntDamage();
        u.attackCooldown = GameConst::gruntCooldown();
        u.cooldownLeft = 0.0;
        reg.emplace(e, "Unit", u);

        RangeSensor rs = new RangeSensor();
        rs.sensorShapeHandle = sens.handle;
        reg.emplace(e, "RangeSensor", rs);

        reg.emplaceTag(e, "Enemy");
        reg.emplaceTag(e, "Grunt");
        return e;
    }

    // Player base building — static body, box shape, holds production queue.
    public static function base(Registry reg, World world, float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(x, y);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setFilter(Cat::building(),
                     Cat::unitPlayer() | Cat::unitEnemy() | Cat::terrain(),
                     0);
        Shape sh = Shapes::createBox(b, sd, GameConst::baseHalfW(), GameConst::baseHalfH());
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Building bd2 = new Building();
        bd2.kind = BuildingKind::base();
        bd2.faction = Faction::player();
        bd2.hp = GameConst::baseHp();
        bd2.maxHp = GameConst::baseHp();
        bd2.producing = 0;
        bd2.buildLeft = 0.0;
        bd2.queueLen = 0;
        bd2.rallyX = x + GameConst::baseRallyDx();
        bd2.rallyY = y + GameConst::baseRallyDy();
        reg.emplace(e, "Building", bd2);

        Selectable sel = new Selectable();
        sel.radius = GameConst::baseHalfW() + 0.2;
        reg.emplace(e, "Selectable", sel);

        // Block the tiles the base occupies for pathfinding.
        Pathing::blockArea(x - GameConst::baseHalfW(), y - GameConst::baseHalfH(),
                            x + GameConst::baseHalfW(), y + GameConst::baseHalfH(), true);

        reg.emplaceTag(e, "PlayerControlled");
        reg.emplaceTag(e, "BaseBuilding");
        return e;
    }

    // Mineral pile — static body, box shape, just a place workers walk to.
    public static function resource(Registry reg, World world,
                                     float x, float y, int amount): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(x, y);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setFilter(Cat::resource(),
                     Cat::unitPlayer() | Cat::unitEnemy(),
                     0);
        Shape sh = Shapes::createBox(b, sd, GameConst::resourceHalfW(), GameConst::resourceHalfH());
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        ResourceNode rn = new ResourceNode();
        rn.amount = amount;
        rn.x = x;
        rn.y = y;
        reg.emplace(e, "ResourceNode", rn);

        Selectable sel = new Selectable();
        sel.radius = GameConst::resourceHalfW() + 0.2;
        reg.emplace(e, "Selectable", sel);

        Pathing::blockArea(x - GameConst::resourceHalfW(), y - GameConst::resourceHalfH(),
                            x + GameConst::resourceHalfW(), y + GameConst::resourceHalfH(), true);
        return e;
    }

    // Initial map: 1 base, 4 workers around it, 1 mineral pile, 2 grunts.
    // Stores base + mineral entity ids in ctx vars so workers know defaults.
    public static function initialMap(Registry reg, World world): void {
        int baseE = Spawn::base(reg, world, 0.0, 0.0);
        reg.ctxSetInt("baseEntity", baseE);

        Spawn::worker(reg, world, -2.5,  2.5);
        Spawn::worker(reg, world,  2.5,  2.5);
        Spawn::worker(reg, world, -2.5, -2.5);
        Spawn::worker(reg, world,  2.5, -2.5);

        int mineE = Spawn::resource(reg, world, 12.0, 0.0, GameConst::resourceStartAmt());
        reg.ctxSetInt("mineralEntity", mineE);

        Spawn::grunt(reg, world, 24.0,  4.0);
        Spawn::grunt(reg, world, 26.0, -3.0);
    }
}
