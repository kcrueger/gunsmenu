#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

/*
    Decompiled from gunmenu.smx using the Lysis decompiler
    (https://github.com/peace-maker/lysis-java).

    Two functions (MenuHandler_Primary, MenuHandler_Secondary) triggered a
    known decompiler limitation ("Can't print expression: Heap") because they
    allocate a local string buffer to read the selected menu item. The bodies
    below for those two functions are reconstructed by hand using the
    standard SourceMod pattern for that exact situation — everything else in
    this file is the decompiler's direct output, lightly cleaned up (renamed
    args, added includes/pragmas).
*/

char g_Primary[MAXPLAYERS + 1][264];
char g_Secondary[MAXPLAYERS + 1][264];
bool g_bUsed[MAXPLAYERS + 1];
bool g_bNoAwp;

public void OnPluginStart()
{
    RegConsoleCmd("sm_guns", cmd_guns);
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
    char map[256];
    GetCurrentMap(map, sizeof(map));
    g_bNoAwp = StrEqual(map, "surf_colos2", true) || StrEqual(map, "surf_ny_bigloop_2008a", true);
}

public void OnClientDisconnect(int client)
{
    g_bUsed[client] = false;
    g_Primary[client][0] = '\0';
}

bool IsValidClient(int client)
{
    return 0 < client <= MaxClients
        && IsClientConnected(client)
        && !IsFakeClient(client)
        && IsClientInGame(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        g_bUsed[client] = false;
        RequestFrame(GiveWeapons, client);
    }
}

public void GiveWeapons(int client)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;

    if (strlen(g_Primary[client]) == 0)
    {
        // No weapon choice saved yet — used to auto-open the menu here via
        // FakeClientCommand(client, "sm_guns"). Removed so the menu only
        // opens when the player types !guns themselves.
        return;
    }

    if (GetPlayerWeaponSlot(client, 0) == -1)
    {
        if (strlen(g_Primary[client]))
            GivePlayerItem(client, g_Primary[client]);
    }

    if (strlen(g_Secondary[client]))
    {
        int weapon = GetPlayerWeaponSlot(client, 1);
        if (weapon != -1)
        {
            RemovePlayerItem(client, weapon);
            AcceptEntityInput(weapon, "Kill");
        }
        GivePlayerItem(client, g_Secondary[client]);
    }
}

public Action cmd_guns(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    if (!IsPlayerAlive(client))
    {
        PrintToChat(client, "[SM] You must be alive to use !guns.");
        return Plugin_Handled;
    }

    if (g_bUsed[client])
    {
        PrintToChat(client, "[SM] You may only use !guns once per round.");
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandler_Primary);
    menu.SetTitle("Primary weapon:");
    menu.AddItem("weapon_awp", "AWP", g_bNoAwp ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    menu.AddItem("weapon_m3", "M3");
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);

    g_bUsed[client] = true;
    return Plugin_Handled;
}

public int MenuHandler_Primary(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        if (IsValidClient(client))
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            strcopy(g_Primary[client], sizeof(g_Primary[]), info);

            Menu secondary = new Menu(MenuHandler_Secondary);
            secondary.SetTitle("Secondary weapon:");
            secondary.AddItem("weapon_usp", "USP");
            secondary.AddItem("weapon_glock", "Glock");
            secondary.ExitButton = false;
            secondary.Display(client, MENU_TIME_FOREVER);
        }
    }
    return 0;
}

public int MenuHandler_Secondary(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        if (IsValidClient(client))
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));
            strcopy(g_Secondary[client], sizeof(g_Secondary[]), info);
            GiveWeapons(client);
        }
    }
    return 0;
}
