#include <sourcemod>
#include <multicolors>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "Server Info",
	author = "AmicuLL",
	description = "Shows info about server.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/amicull/"
}


KeyValues kvStore;
char path[PLATFORM_MAX_PATH];

bool IsOwner[MAXPLAYERS+1]; // Salvare rapida, care client index(s) este/are grupul owner.



public void OnPluginStart()
{
	BuildPath(Path_SM, path, sizeof(path), "data/kvStore_Owners.txt");

    kvStore = new KeyValues("storage");
    kvStore.ImportFromFile(path);
    // se restarteaza plugin-ul

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
            OnClientPostAdminCheck(i);
    }
	CreateTimer(300.0, spam, _, TIMER_REPEAT); // spam chat
    RegConsoleCmd("sm_info", sm_info, "Get info about owners");
}


public Action sm_info(int client, int args)
{
	//Afiseaza numele serverului
	char sBuffer[256];
	GetConVarString(FindConVar("hostname"), sBuffer,sizeof(sBuffer)); //cauta hostname-ul setat in convar
	CPrintToChat(client, "{darkred}Server name :{default} %s", sBuffer) //afiseaza

	int pieces[4];
	int longip = GetConVarInt(FindConVar("hostip")); //cauta ip-ul in convar
	int port = GetConVarInt(FindConVar("hostport")); //cauta portul in convar
	pieces[0] = (longip >> 24) & 0x000000FF; //construieste ip-ul
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	char NetIP[32];
	Format(NetIP, sizeof(NetIP), "%d.%d.%d.%d:%d", pieces[0], pieces[1], pieces[2], pieces[3], port);  
	CPrintToChat(client, "{darkred}Server IP: {default}%d.%d.%d.%d:%d", pieces[0], pieces[1], pieces[2], pieces[3], port) //afiseaza ip-ul
	
	CPrintToChat(client, "{darkred}==============================================");
	
    char name[MAX_NAME_LENGTH];
    char buffer[255];

    if (!kvStore.GotoFirstSubKey())
    {
        kvStore.Rewind();
        return Plugin_Handled;
    }

    do
    {
        kvStore.GetSectionName(buffer, sizeof(buffer));
        Format(buffer, sizeof(buffer), "http://steamcommunity.com/profiles/%s", buffer);

        kvStore.GetString("name", name, sizeof(name));

        PrintToConsole(client, "\nOwner: %s %s\n", name, buffer);
        
        if(client != 0) CPrintToChat(client, "{darkred}Owner: {default}%s {lime}%s", name, buffer);

    } while (kvStore.GotoNextKey())

    kvStore.Rewind();
	
	//char buffer[30];

    //for(int i = 1; i <= MaxClients; i++) //verifica toti jucatorii
    //{
    //    if(!IsOwner[i]) continue;
    //    if(!IsClientInGame(i)) continue;
        
    //    GetClientAuthId(i, AuthId_SteamID64, buffer, sizeof(buffer));
        
    //    if(client != 0)
    //        CPrintToChat(client, "{darkred}Owner: {default}%N\n {lime}http://steamcommunity.com/profiles/%s", i, buffer);

    //    PrintToConsole(client, "\n Owner: %N\n http://steamcommunity.com/profiles/%s \n", i, buffer);
    //}
	CPrintToChat(client, "{darkred}==============================================");
	
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	CPrintToChat(client, "{darkred}Current map:{default} %s", sBuffer);
	
	GetNextMap(sBuffer, sizeof(sBuffer));
	CPrintToChat(client, "{darkred}Next map:{default} %s", sBuffer)
	
    return Plugin_Handled;
}
public Action spam(Handle timer)
{
    CPrintToChatAll("{darkred}[Ruschi Bratia] {green}Tasteaza !info sau !comenzi pentru informatii!");

    return Plugin_Continue;
}
public void OnClientPostAdminCheck(int client)
{
    if(IsFakeClient(client)) return;

    AdminId admin = GetUserAdmin(client);
    int count = admin.GroupCount;
    char buffer[30];
    
    for(int x = 0; x < count; x++)
    {
        if( admin.GetGroup(x, buffer, sizeof(buffer)) != INVALID_GROUP_ID )
        {
            if(!StrEqual(buffer, "owner", false)) continue;
            
            IsOwner[client] = true; //seteaza credentialele ownerului pentru flag-ul lui, adica ROOT

            GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)); //procura steamid-ul de la owner
            CPrintToChatAll("{darkred}Owner {default}%N {darkred}has connected\n {lime}http://steamcommunity.com/profiles/%s", client, buffer); //afiseaza cand se conecteaza owner-ul la server si numele in functie de steamid
            PrintToConsoleAll("\nOwner: %N has connected\n http://steamcommunity.com/profiles/%s \n", client, buffer); //acelasi lucru, doar ca in consola
			
			// Adauga/Actualizeaza fisierul KeyValue.
            kvStore.JumpToKey(buffer, true);

            Format(buffer, sizeof(buffer), "%N", client);

            kvStore.SetString("name", buffer);
            kvStore.Rewind();
            kvStore.ExportToFile(path);
        }
    }
}

public void OnClientDisconnect(int client)
{
    if(IsOwner[client])
    {
        char buffer[30];
        GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)); //procura steamid-ul de la owner
        CPrintToChatAll("{darkred}Owner: {default}'%N' {darkred}has disconnected\n {lime}http://steamcommunity.com/profiles/%s", client, buffer); //afiseaza cand se deconecteaza owner-ul la server si numele in functie de steamid
        PrintToConsoleAll("\nOwner: %N has disconnected\n http://steamcommunity.com/profiles/%s \n", client, buffer); ///acelasi lucru, doar ca in consola
		
		// Adauga/Actualizeaza fisierul KeyValue.
        kvStore.JumpToKey(buffer, true);

        Format(buffer, sizeof(buffer), "%N", client);

        kvStore.SetString("name", buffer);
        kvStore.Rewind();
        kvStore.ExportToFile(path);
    }
    
    IsOwner[client] = false; //Ca sa nu fie un bug ca un player sa primeasca owner de la plugin (putin probabil, dar ca fapt divers si pentru siguranta) si ca sa dispara din lista de owneri la accesarea comenzi !info
} 