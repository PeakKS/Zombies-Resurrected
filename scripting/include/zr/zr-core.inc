#if defined _zr_core_included_
    #endinput
#endif
#define _zr_core_included_

#define TEAM_ZOMBIE 2
#define TEAM_HUMAN  3

forward Action ZR_OnClientHumanPre(int client);
forward void ZR_OnClientHuman(int client);
native bool ZR_SpawnHuman(int client);

forward Action ZR_OnClientZombiePre(int client);
forward void ZR_OnClientZombie(int client);
native bool ZR_SpawnZombie(int client);

//These are created in OnAdminMenuCreated so they
//are guaranteed to be ready by OnAdminMenuReady
native TopMenuObject ZR_GetAdminMenuCategory();
native TopMenu ZR_GetClientMenu();