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
TopMenu weaponsMenu;

GameData weaponsGameData;
Handle SDKWeapon_Deploy;
Handle SDKWeapon_GetSlot;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    RegPluginLibrary("zr-weapons");
    return APLRes_Success;
}

public void OnPluginStart() {
    RegConsoleCmd("sm_zmarket", WeaponsMenuCommand, "Open the weapons menu");
    RegConsoleCmd("sm_guns", WeaponsMenuCommand, "Open the weapons menu");

    weaponsGameData = LoadGameConfigFile("zr-weapons.games");

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(weaponsGameData, SDKConf_Virtual, "CBaseCombatWeapon::Deploy");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
    SDKWeapon_Deploy = EndPrepSDKCall();

    if(SDKWeapon_Deploy == null) {
        LogError("Failed to prep CBaseCombatWeapon::Deploy SDK Call");
    }

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(weaponsGameData, SDKConf_Virtual, "CBaseCombatWeapon::GetSlot");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
    SDKWeapon_GetSlot = EndPrepSDKCall();

    if(SDKWeapon_GetSlot == null) {
        LogError("Failed to prep CBaseCombatWeapon::GetSlot SDK Call");
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
    clientMenu.AddItem("ZR Weapons", ClientMenuHandler, INVALID_TOPMENUOBJECT);
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
    SelectWeapon(client, newWeapon);
    return true;
}

void SelectWeapon(int client, int weapon) {
    if (SDKCall(SDKWeapon_Deploy, weapon))
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}
/*
int GetSlot(int weapon) {
    return SDKCall(SDKWeapon_GetSlot, weapon);
}
*/