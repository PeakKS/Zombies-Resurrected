#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#include <cstrike>
#include "zr/zr-core"

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
    name = "Zombies Resurrected - Core",
    author = "Peak",
    description = "Core plugin for ZR",
    version = "0.1",
    url = ""
};

ConVar infectRatio;
ConVar infectTime;
Handle infectTimer;
bool firstInfected;
int priorityList[MAXPLAYERS];
StringMap savedPriority;

TopMenu adminMenu;
TopMenuObject adminCategory;

TopMenu clientMenu;

GlobalForward HumanForwardPre;
GlobalForward HumanForward;
GlobalForward ZombieForwardPre;
GlobalForward ZombieForward;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

    HumanForwardPre = new GlobalForward("ZR_OnClientHumanPre", ET_Hook, Param_Cell);
    HumanForward = new GlobalForward("ZR_OnClientHuman", ET_Ignore, Param_Cell);
    CreateNative("ZR_SpawnHuman", Native_SpawnHuman);

    ZombieForwardPre = new GlobalForward("ZR_OnClientZombiePre", ET_Hook, Param_Cell);
    ZombieForward = new GlobalForward("ZR_OnClientZombie", ET_Ignore, Param_Cell);
    CreateNative("ZR_SpawnZombie", Native_SpawnZombie);

    CreateNative("ZR_GetAdminMenuCategory", Native_GetAdminMenuCategory);
    CreateNative("ZR_GetClientMenu", Native_GetClientMenu);

    RegAdminCmd("sm_zadmin", AdminMenuCommand, ADMFLAG_GENERIC, "Open ZR admin menu");
    RegAdminCmd("sm_infect", InfectMenuCommand, ADMFLAG_SLAY, "Open ZR infection menu");
    RegConsoleCmd("sm_zmenu", ClientMenuCommand, "Open menu for client accessible ZR settings");

    RegPluginLibrary("zr-core");
    return APLRes_Success;
}

public void OnPluginStart() {
    infectRatio = CreateConVar("zr_infect_ratio", "0.15", "Percentage of humans to infect on map start");
    infectTime = CreateConVar("zr_infect_time", "20", "Time until first infection");

    HookEvent("round_start", RoundStart);
    HookEvent("round_end", RoundEnd);
    HookEvent("player_spawn", SpawnHook, EventHookMode_Pre);

    AddCommandListener(JoinTeamHook, "jointeam");
}

public void OnMapStart() {
    delete savedPriority;
    savedPriority = new StringMap();
}

public void OnClientAuthorized(int client, const char[] auth) {
    int priority;
    if (savedPriority.GetValue(auth, priority)) {
        priorityList[client] = priority;
    } else {
        priorityList[client] = 0;
    }
}

public void OnClientDisconnect(int client) {
    char auth[64];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    savedPriority.SetValue(auth, priorityList[client]);
}

void RoundStart(Event event, const char[] name, bool dontBroadcast) {
    firstInfected = false;
    infectTimer = CreateTimer(infectTime.FloatValue, FirstInfect, TIMER_FLAG_NO_MAPCHANGE);
    for (int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client)) {
            int team = GetClientTeam(client);
            if (team == TEAM_HUMAN || team == TEAM_ZOMBIE) {
                SpawnHuman(client);
            }
        }
    }
}

void RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if (IsValidHandle(infectTimer)) {
        delete infectTimer;
    }
}

Action FirstInfect(Handle timer) {
    int infectCount = RoundToCeil(GetTeamClientCount(TEAM_HUMAN) * infectRatio.FloatValue);
    int index = 0;

    for (int client = 1; client <= MaxClients; client++) {
        priorityList[client]++;
    }

    int clientsByPriority[MAXPLAYERS-1] = {1, 2, ...};
    SortCustom1D(clientsByPriority, MAXPLAYERS-1, PrioritySortFunction);

    while ((infectCount > 0) && (index < MAXPLAYERS-1)) {
        int client = clientsByPriority[index];
        if (IsClientInGame(client) && IsPlayerAlive(client)) {
            SpawnZombie(client);
            priorityList[client] = 0;
            infectCount--;
        }
        index++;
    }

    firstInfected = true;
    return Plugin_Stop;
}

int PrioritySortFunction(int elem1, int elem2, const int[] array, Handle handle) {
    return priorityList[elem2] - priorityList[elem1];
}

Action SpawnHook(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (firstInfected) {
        SpawnZombie(client);
    } else {
        SpawnHuman(client);
    }
    return Plugin_Handled;
}

Action JoinTeamHook(int client, const char[] command, int argc) {
    if (!IsPlayerAlive(client)) {
        CS_SwitchTeam(client, (firstInfected)? TEAM_ZOMBIE : TEAM_HUMAN);
        CS_RespawnPlayer(client);
    }
    return Plugin_Handled;
}

public void OnAdminMenuCreated(Handle topmenu) {
    //Create both admin and client menu here so this forward can be reused
    adminMenu = TopMenu.FromHandle(topmenu);
    adminCategory = adminMenu.AddCategory("Zombies Resurrected", AdminCategoryHandler);
    adminMenu.AddItem("Infections", InfectItemHandler, adminCategory);

    clientMenu = new TopMenu(ClientMenuHandler);
}

Action AdminMenuCommand(int client, int args) {
    adminMenu.DisplayCategory(adminCategory, client);
    return Plugin_Handled;
}

Action ClientMenuCommand(int client, int args) {
    clientMenu.Display(client, TopMenuPosition_Start);
    return Plugin_Handled;
}

void ClientMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    switch (action) {
        case TopMenuAction_DisplayTitle: strcopy(buffer, maxlength, "ZR client settings");
    }
}

void AdminCategoryHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    switch (action) {
        case TopMenuAction_DisplayOption: strcopy(buffer, maxlength, "Zombies Resurrected");
        case TopMenuAction_DisplayTitle: strcopy(buffer, maxlength, "Zombies Resurrected");
    }
}

void InfectItemHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength) {
    switch (action) {
        case TopMenuAction_DisplayOption: strcopy(buffer, maxlength, "Infections");
        case TopMenuAction_SelectOption: CreateInfectMenu(param);
    }
}

Action InfectMenuCommand(int client, int args) {
    CreateInfectMenu(client);
    return Plugin_Handled;
}

void CreateInfectMenu(int client) {
    Menu menu = new Menu(InfectMenuHandler);
    menu.SetTitle("Toggle infection on client");
    menu.ExitBackButton = true;
    AddTargetsToMenu(menu, client);
    menu.Display(client, MENU_TIME_FOREVER);
}

public int InfectMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_End: delete menu;
        case MenuAction_Cancel: adminMenu.Display(param1, TopMenuPosition_LastCategory);
        case MenuAction_Select: {
            char uid[16];
            menu.GetItem(param2, uid, sizeof(uid));
            int target = GetClientOfUserId(StringToInt(uid));
            if (target == 0) {
                PrintToChat(param1, "Client not in game");
            } else {
                int team = GetClientTeam(target);
                if (team == TEAM_HUMAN) {
                    SpawnZombie(target);
                } else if (team == TEAM_ZOMBIE) {
                    SpawnHuman(target);
                }
                CreateInfectMenu(param1);
            }
        }
    }
    return 0;
}

bool SpawnHuman(int client) {
    Action allow;
    Call_StartForward(HumanForwardPre);
    Call_PushCell(client);
    Call_Finish(allow);

    if (allow != Plugin_Continue) {
        return false;
    }
    
    CS_SwitchTeam(client, TEAM_HUMAN);
    if (!IsPlayerAlive(client)) {
        CS_RespawnPlayer(client);
    }

    Call_StartForward(HumanForward);
    Call_PushCell(client);
    Call_Finish();

    return true;
}

bool SpawnZombie(int client) {
    Action allow;
    Call_StartForward(ZombieForwardPre);
    Call_PushCell(client);
    Call_Finish(allow);

    if (allow != Plugin_Continue) {
        return false;
    }
    
    CS_SwitchTeam(client, TEAM_ZOMBIE);
    if (!IsPlayerAlive(client)) {
        CS_RespawnPlayer(client);
    }

    Call_StartForward(ZombieForward);
    Call_PushCell(client);
    Call_Finish();

    return true;
}

public any Native_SpawnHuman(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return SpawnHuman(client);
}

public any Native_SpawnZombie(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return SpawnZombie(client);
}

public any Native_GetAdminMenuCategory(Handle plguin, int numParams) {
    return adminCategory;
}

public any Native_GetClientMenu(Handle plguin, int numParams) {
    return clientMenu;
}