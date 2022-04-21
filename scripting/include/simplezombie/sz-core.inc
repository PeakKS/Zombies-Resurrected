#if defined _sz_core_included_
    #endinput
#endif
#define _sz_core_included_

#define TEAM_ZOMBIE 2
#define TEAM_HUMAN  3

forward Action SZ_OnClientHumanPre(int client);
forward void SZ_OnClientHuman(int client);
native bool SZ_SpawnHuman(int client);

forward Action SZ_OnClientZombiePre(int client);
forward void SZ_OnClientZombie(int client);
native bool SZ_SpawnZombie(int client);

//These are created in OnAdminMenuCreated so they
//are guaranteed to be ready by OnAdminMenuReady
native TopMenuObject SZ_GetAdminMenuCategory();
native TopMenu SZ_GetClientMenu();