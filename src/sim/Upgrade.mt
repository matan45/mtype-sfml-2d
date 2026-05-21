// Player-global research upgrades. V1 has one Barracks upgrade:
// Infantry Weapons I, which permanently increases player Grunt damage.

import * from "@mtype-entt/Entt.mt";

import * from "../game/Constants.mt";
import * from "../audio/Audio.mt";
import * from "./Schema.mt";

class Upgrade {
    public static function gruntDamageFor(Registry reg, int faction): float {
        float dmg = GameConst::gruntDamage();
        if (faction == Faction::player()) {
            int lvl = reg.ctxGetInt("infantryWeaponsLevel");
            dmg = dmg + ((float)lvl) * GameConst::infantryWeaponsDamageBonus();
        }
        return dmg;
    }

    public static function run(Registry reg, float dt): void {
        if (reg.ctxGetInt("infantryWeaponsResearching") != 1) { return; }
        if (reg.ctxGetInt("lowPower") == 1) { return; }

        float left = reg.ctxGetFloat("infantryWeaponsBuildLeft") - dt;
        if (left > 0.0) {
            reg.ctxSetFloat("infantryWeaponsBuildLeft", left);
            return;
        }

        reg.ctxSetInt("infantryWeaponsResearching", 0);
        reg.ctxSetFloat("infantryWeaponsBuildLeft", 0.0);
        reg.ctxSetInt("infantryWeaponsLevel", GameConst::infantryWeaponsMaxLevel());
        Upgrade::applyInfantryWeapons(reg);
        Audio::playTada();
    }

    public static function tryStartInfantryWeapons(Registry reg): bool {
        if (reg.ctxGetInt("lowPower") == 1) { return false; }
        if (reg.ctxGetInt("infantryWeaponsResearching") == 1) { return false; }
        if (reg.ctxGetInt("infantryWeaponsLevel") >= GameConst::infantryWeaponsMaxLevel()) {
            return false;
        }

        int minerals = reg.ctxGetInt("minerals");
        int gas = reg.ctxGetInt("gas");
        if (minerals < GameConst::infantryWeaponsMineralCost()) { return false; }
        if (gas < GameConst::infantryWeaponsGasCost()) { return false; }

        reg.ctxSetInt("minerals", minerals - GameConst::infantryWeaponsMineralCost());
        reg.ctxSetInt("gas", gas - GameConst::infantryWeaponsGasCost());
        reg.ctxSetInt("infantryWeaponsResearching", 1);
        reg.ctxSetFloat("infantryWeaponsBuildLeft", GameConst::infantryWeaponsResearchTime());
        Audio::playDing();
        return true;
    }

    public static function applyInfantryWeapons(Registry reg): void {
        string[] need = ["Unit", "PlayerControlled", "Grunt"];
        EnttView v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            Unit u = (Unit) reg.get(e, "Unit");
            u.attackDamage = Upgrade::gruntDamageFor(reg, u.faction);
            reg.emplace(e, "Unit", u);
            e = v.next();
        }
        v.destroy();
    }
}
