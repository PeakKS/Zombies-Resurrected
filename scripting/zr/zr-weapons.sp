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

enum struct WeaponData {
    int price;
    bool restricted;
}

WeaponData weaponInfo[CSWeapon_MAX_WEAPONS_NO_KNIFES];
StringMap aliasMap;

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
    BuildPath(Path_SM, path, sizeof(path), "configs/zr/zr-weapons.txt");
    
    weaponsMenu = new TopMenu(WeaponsMenuHandler);
    aliasMap = new StringMap();

    SMCParser parser = new SMCParser();
    parser.OnEnterSection = WeaponConfigNewSection;
    parser.OnLeaveSection = WeaponConfigLeaveSection;
    parser.OnKeyValue = WeaponConfigKeyValue;
    parser.ParseFile(path);
    delete parser;

    //Can use the same config pending my sourcemod PR
    //BuildPath(Path_SM, path, sizeof(path), "configs/zr/zr-weapons-menu.txt");
    if (!weaponsMenu.LoadConfig(path, error, sizeof(error))) {
        LogError("Could not load zr-weapons menu config (file \"%s\": %s", path, error);
    }
}

int _ConfigDepth = 0;
CSWeaponID _TempId;
TopMenuObject _TempItem;

SMCResult WeaponConfigNewSection(SMCParser smc, const char[] name, bool opt_quotes) {
    static TopMenuObject tempCategory;

    if (_ConfigDepth == 1) {
        tempCategory = weaponsMenu.AddCategory(name, WeaponsCategoryHandler);
    } else if (_ConfigDepth == 2) {
        _TempId = CS_AliasToWeaponID(name);
        char commandBuffer[64];
        FormatEx(commandBuffer, sizeof(commandBuffer), "sm_%s", name);
        RegConsoleCmd(commandBuffer, BuyCommand);
        _TempItem = weaponsMenu.AddItem(name, WeaponsItemHandler, tempCategory);
    }
    _ConfigDepth++;
    return SMCParse_Continue;
}

SMCResult WeaponConfigLeaveSection(SMCParser smc) {
    _ConfigDepth--;
    return SMCParse_Continue;
}

SMCResult WeaponConfigKeyValue(SMCParser cmd, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
    if (StrEqual(key, "price")) {
        weaponInfo[_TempId].price = StringToInt(value);
    } else if (StrEqual(key, "restrict")) {
        if (StrEqual(value, "yes")) {
            weaponInfo[_TempId].restricted = true;
        }
    } else if (StrEqual(key, "alias")) {
        char commandBuffer[64];
        FormatEx(commandBuffer, sizeof(commandBuffer), "sm_%s", value);
        RegConsoleCmd(commandBuffer, BuyCommand);
        char realName[64];
        weaponsMenu.GetObjName(_TempItem, realName, sizeof(realName));
        aliasMap.SetString(value, realName);
    }
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
    CSWeaponID weaponId = CS_AliasToWeaponID(weapon);
    switch (action) {
        case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "%t [$%d]", weapon, weaponInfo[weaponId].price);
        case TopMenuAction_DrawOption: buffer[0] = (!Affordable(weaponId, param) || weaponInfo[weaponId].restricted)? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
        case TopMenuAction_SelectOption: BuyWeapon(param, weapon);
    }
}

Action BuyCommand(int client, int argc) {
    char weaponName[64];
    GetCmdArg(0, weaponName, sizeof(weaponName));
    int offset = 3;
    if (CS_AliasToWeaponID(weaponName[offset]) == CSWeapon_NONE) {
        //This command was created on an alias, get the real name
        aliasMap.GetString(weaponName[3], weaponName, sizeof(weaponName));
        offset = 0;
    }
    BuyWeapon(client, weaponName[offset]);
    return Plugin_Handled;
}

bool BuyWeapon(int client, const char[] alias) {
    char fullname[64];
    FormatEx(fullname, sizeof(fullname), "weapon_%s", alias);
    CSWeaponID weaponId = CS_AliasToWeaponID(alias);

    int cash = GetEntProp(client, Prop_Send, "m_iAccount");
    int price = weaponInfo[weaponId].price;

    if (!Affordable(weaponId, client)) {
        PrintToChat(client, "%s%t", ZR_TAG, "Purchase_Fail", alias, "Purchase_Poor", price);
        return false;
    }

    if (weaponInfo[weaponId].restricted) {
        PrintToChat(client, "%s%t", ZR_TAG, "Purchase_Fail", alias, "Purchase_Restricted");
        return false;
    }

    int newWeapon = GivePlayerItem(client, fullname);
    EquipPlayerWeapon(client, newWeapon);
    Weapon_Switch(client, newWeapon);

    SetEntProp(client, Prop_Send, "m_iAccount", cash - price);

    PrintToChat(client, "%s%t", ZR_TAG, "Purchase_Success", alias, price);

    return true;
}

bool Affordable(CSWeaponID weaponID, int client) {
    return weaponInfo[weaponID].price <= GetEntProp(client, Prop_Send, "m_iAccount");
}

bool Weapon_Switch(int client, int weapon) {
    return SDKCall(CBasePlayer_Weapon_Switch, client, weapon, 0);
}