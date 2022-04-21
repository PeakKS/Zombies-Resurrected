#include <sourcemod>
#include <topmenus>
#include <adminmenu>
#include <cstrike>
#include <sdktools>
#include "zr/zr-core"

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
    name = "Zombies Resurrected - Weapons",
    author = "Peak",
    description = "Handle buying and restriction of weapons in ZR",
    version = "0.1",
    url = ""
};

TopMenu clientMenu;
TopMenuObject weaponsCategory;
TopMenu weaponsMenu;

GameData sdkhooksGameData;
Handle CBasePlayer_Weapon_Switch;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    RegPluginLibrary("zr-weapons");
    return APLRes_Success;
}

public void OnPluginStart() {
    RegConsoleCmd("sm_zmarket", WeaponsMenuCommand, "Open the weapons menu");
    RegConsoleCmd("sm_guns", WeaponsMenuCommand, "Open the weapons menu");

    sdkhooksGameData = LoadGameConfigFile("sdkhooks.games/engine.csgo");

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(sdkhooksGameData, SDKConf_Virtual, "Weapon_Switch");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
    CBasePlayer_Weapon_Switch = EndPrepSDKCall();

    if(CBasePlayer_Weapon_Switch == null) {
        LogError("Failed to prep Weapon_Switch SDK Call");
    }

    LoadTranslations("zr-weapons.phrases");

    char path[PLATFORM_MAX_PATH];
    char error[256];
    
    weaponsMenu = new TopMenu(WeaponsMenuHandler);
    BuildPath(Path_SM, path, sizeof(path), "configs/zr/zr-weapons-menu.txt");

    SMCParser parser = new SMCParser();
    parser.OnEnterSection = WeaponConfigNewSection;
    parser.OnKeyValue = WeaponConfigKeyValue;
    parser.ParseFile(path);
    delete parser;

    
    if (!weaponsMenu.LoadConfig(path, error, sizeof(error))) {
        LogError("Could not load zr-weapons menu config (file \"%s\": %s", path, error);
    }
}

TopMenuObject tempCategory;

SMCResult WeaponConfigNewSection(SMCParser smc, const char[] name, bool opt_quotes) {
    tempCategory = weaponsMenu.AddCategory(name, WeaponsCategoryHandler);
    return SMCParse_Continue;
}

SMCResult WeaponConfigKeyValue(SMCParser cmd, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
    weaponsMenu.AddItem(value, WeaponsItemHandler, tempCategory);
    return SMCParse_Continue;
}

public void OnAdminMenuReady(Handle topmenu) {
    clientMenu = ZR_GetClientMenu();
    weaponsCategory = clientMenu.AddCategory("ZR Weapons", WeaponsCategoryHandler);
    clientMenu.AddItem("Choose Weapons", ClientMenuHandler, weaponsCategory);
}

void ClientMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    switch (action) {
        case TopMenuAction_DisplayOption: strcopy(buffer, maxlength, "ZR Weapons");
        case TopMenuAction_SelectOption: weaponsMenu.Display(param, TopMenuPosition_Start);
    }
}

Action WeaponsMenuCommand(int client, int args) {
    weaponsMenu.Display(client, TopMenuPosition_Start);
    return Plugin_Handled;
}

void WeaponsMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    switch (action) {
        case TopMenuAction_DisplayTitle: strcopy(buffer, maxlength, "ZR Weapons");
    }
}

void WeaponsCategoryHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    switch (action) {
        case TopMenuAction_DisplayTitle: topmenu.GetObjName(topobj_id, buffer, maxlength);
        case TopMenuAction_DisplayOption: topmenu.GetObjName(topobj_id, buffer, maxlength);
    }
}

void WeaponsItemHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    char weapon[64];
    topmenu.GetObjName(topobj_id, weapon, sizeof(weapon));

    switch (action) {
        case TopMenuAction_DisplayOption: {
            FormatEx(buffer, maxlength, "%t", weapon);
        }
        case TopMenuAction_SelectOption: {
            BuyWeapon(param, weapon);
        }
    }
}

bool BuyWeapon(int client, const char[] weapon) {
    char fullname[64];
    FormatEx(fullname, sizeof(fullname), "weapon_%s", weapon);
    int newWeapon = GivePlayerItem(client, fullname);
    EquipPlayerWeapon(client, newWeapon);
    Weapon_Switch(client, newWeapon);
    return true;
}

bool Weapon_Switch(int client, int weapon) {
    return SDKCall(CBasePlayer_Weapon_Switch, client, weapon, 0);
}