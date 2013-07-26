/***************************************************************************************

	Copyright (C) 2012 BCServ (plugins@bcserv.eu)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
***************************************************************************************/

/***************************************************************************************


	C O M P I L E   O P T I O N S


***************************************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/***************************************************************************************


	P L U G I N   I N C L U D E S


***************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <smlib/pluginmanager>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#include <clientprefs>

/***************************************************************************************


	P L U G I N   I N F O


***************************************************************************************/
public Plugin:myinfo = {
	name 						= "Damage Sound",
	author 						= "BCServ:Chanz, foo bar",
	description 				= "This plugin plays a sound when players hit each other.",
	version 					= "2.0",
	url 						= "https://forums.alliedmods.net/showthread.php?t=99552"
}

/***************************************************************************************


	P L U G I N   D E F I N E S


***************************************************************************************/
#define MAX_FLOAT_MENU_ENTRYS 13
#define MAXPITCH 255

/***************************************************************************************


	G L O B A L   V A R S


***************************************************************************************/
// Server Variables


// Plugin Internal Variables
const NUM_WEAPONS = 8;

// Console Variables
new Handle:g_cvarEnable = INVALID_HANDLE;
new Handle:g_cvarPath = INVALID_HANDLE;
new Handle:g_cvarDelay = INVALID_HANDLE;
new Handle:g_cvarActOnWeapons = INVALID_HANDLE;
new Handle:g_cvarClient_Enable = INVALID_HANDLE;
new Handle:g_cvarClient_Volume = INVALID_HANDLE;
new Handle:g_cvarClient_Pitch = INVALID_HANDLE;
new Handle:g_cvarClient_PitchTime = INVALID_HANDLE;

// Console Variables: Runtime Optimizers
new g_iPlugin_Enable = 1;
new String:g_szPlugin_Path[PLATFORM_MAX_PATH] = "";
new Float:g_flPlugin_Delay = 0.0;
new String:g_szPlugin_ActOnWeapons[255] = "";
new bool:g_bPlugin_Client_Enable = true;
new Float:g_flPlugin_Client_Volume = 1.0;
new bool:g_bPlugin_Client_Pitch = true;
new Float:g_flPlugin_Client_PitchTime = 1.0;

// Timers


// Library Load Checks
new bool:g_bClientPrefs_Loaded = false;

// Game Variables
new bool:g_bConfigsExecuted = false;

// Map Variables
new bool:g_bMap_Loaded = false;

// Client Variables
new g_iClient_HitCounter[MAXPLAYERS+1][MAXPLAYERS+1];
new Float:g_flClient_LastHit[MAXPLAYERS+1][MAXPLAYERS+1];
new bool:g_bClient_Enable[MAXPLAYERS+1];
new Float:g_flClient_Volume[MAXPLAYERS+1];
new bool:g_bClient_Pitch[MAXPLAYERS+1];
new Float:g_flClient_PitchTime[MAXPLAYERS+1];

// Cookie Variables
new Handle:g_cookieEnable = INVALID_HANDLE;
new Handle:g_cookieVolume = INVALID_HANDLE;
new Handle:g_cookiePitch = INVALID_HANDLE;
new Handle:g_cookiePitchTime = INVALID_HANDLE;

// M i s c
new String:g_szActOnWeapons[NUM_WEAPONS][32];



/***************************************************************************************


	F O R W A R D   P U B L I C S


***************************************************************************************/
public OnPluginStart()
{
	// Initialization for SMLib
	PluginManager_Initialize("damagesound", "[SM] ");
	
	// Translations
	// LoadTranslations("common.phrases");
	
	
	// Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	// Register New Commands (PluginManager_RegConsoleCmd) (If the command doesn't exist, hook it above!)
	PluginManager_RegConsoleCmd("sm_damagesound", Command_DamageSoundMenu, "Shows the damagesound menu");
	PluginManager_RegConsoleCmd("sm_hitsound", Command_DamageSoundMenu, "Shows the damagesound menu");
	
	// Register Admin Commands (PluginManager_RegAdminCmd)
	

	// Cvars: Create a global handle variable.
	g_cvarEnable = PluginManager_CreateConVar("enable", "1", "Enables or disables this plugin");
	g_cvarPath = PluginManager_CreateConVar("path", "buttons/button10.wav", "Path to damage sound file");
	g_cvarDelay = PluginManager_CreateConVar("delay", "0.0", "How many secounds should the plugin wait to play the sound again (in seconds).");
	g_cvarActOnWeapons = PluginManager_CreateConVar("actonweapon","","Specifies which weapons damagesounds will play for.  Default is all");
	g_cvarClient_Enable = PluginManager_CreateConVar("client_enable", "1", "Should the client have had DamageSound enabled by default? (1=yes/0=no)");
	g_cvarClient_Volume = PluginManager_CreateConVar("client_volume", "70", "From 0 to 100 (in percent) you can set the clients default volume of the sound.");
	g_cvarClient_Pitch = PluginManager_CreateConVar("client_pitch", "0", "Should the sound for the client pitch up with every hit by default? (1=on/0=off) (Dystopia Effect)");
	g_cvarClient_PitchTime = PluginManager_CreateConVar("client_pitch_time", "2.0", "Sets the client default setting: If the attacker did not hit his victim, after X seconds the pitch resets to normal (0=it pitches up until the victim dies)");
	
	// Hook ConVar Change
	HookConVarChange(g_cvarEnable, ConVarChange_Enable);
	HookConVarChange(g_cvarPath, ConVarChange_Path);
	HookConVarChange(g_cvarDelay, ConVarChange_Delay);
	HookConVarChange(g_cvarActOnWeapons, ConVarChange_ActOnWeapons);
	HookConVarChange(g_cvarClient_Enable, ConVarChange_Client_Enable);
	HookConVarChange(g_cvarClient_Volume, ConVarChange_Client_Volume);
	HookConVarChange(g_cvarClient_Pitch, ConVarChange_Client_Pitch);
	HookConVarChange(g_cvarClient_PitchTime, ConVarChange_Client_PitchTime);
	
	// Event Hooks
	PluginManager_HookEvent("player_hurt", Event_Hurt);
	PluginManager_HookEvent("player_death", Event_Death);
	
	// Library
	g_bClientPrefs_Loaded = (GetExtensionFileStatus("clientprefs.ext") == 1);
	if (g_bClientPrefs_Loaded) {
		
		// prepare title for clientPref menu
		decl String:menutitle[64];
		Format(menutitle, sizeof(menutitle), "%s", Plugin_Name);
		SetCookieMenuItem(PrefMenu, 0, menutitle);
		
		//Cookies
		g_cookieEnable = RegClientCookie("DmgSndConf-Enable", "DamageSound Enable cookie", CookieAccess_Private);
		g_cookieVolume = RegClientCookie("DmgSndConf-Volume", "DamageSound Volume cookie", CookieAccess_Private);
		g_cookiePitch = RegClientCookie("DmgSndConf-Pitch", "DamageSound PitchEnable cookie", CookieAccess_Private);
		g_cookiePitchTime = RegClientCookie("DmgSndConf-PitchTime", "DamageSound PitchTime cookie", CookieAccess_Private);
	}
	
	/* Features
	if(CanTestFeatures()){
		
	}
	*/
	
	// Create ADT Arrays
	
	
	// Timers
	
	
}

public OnMapStart()
{
	// hax against valvefail (thx psychonic for fix)
	if (GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE) {
		SetConVarString(Plugin_VersionCvar, Plugin_Version);
	}

	if (g_bConfigsExecuted) {

		decl String:soundpathMainDir[PLATFORM_MAX_PATH];
		Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",g_szPlugin_Path);
		File_AddToDownloadsTable(soundpathMainDir);
		
		PrecacheSound(g_szPlugin_Path);
	}

	g_bMap_Loaded = true;
}
public OnMapEnd(){
	g_bMap_Loaded = false;
	g_bConfigsExecuted = false;
}

public OnConfigsExecuted()
{
	// Set your ConVar runtime optimizers here
	g_iPlugin_Enable = GetConVarInt(g_cvarEnable);
	GetConVarString(g_cvarPath, g_szPlugin_Path, sizeof(g_szPlugin_Path));
	g_flPlugin_Delay = GetConVarFloat(g_cvarDelay);
	GetConVarString(g_cvarActOnWeapons, g_szPlugin_ActOnWeapons, sizeof(g_szPlugin_ActOnWeapons));
	g_bPlugin_Client_Enable = GetConVarBool(g_cvarClient_Enable);
	g_flPlugin_Client_Volume = GetConVarFloat(g_cvarClient_Volume);
	g_bPlugin_Client_Pitch = GetConVarBool(g_cvarClient_Pitch);
	g_flPlugin_Client_PitchTime = GetConVarFloat(g_cvarClient_PitchTime);

	// Mind: this is only here for late load, since on map change or server start, there isn't any client.
	// Remove it if you don't need it.
	Client_InitializeAll();

	new validSoundFile = IsSoundFileValid(g_szPlugin_Path);
	if (validSoundFile == 1 && g_bMap_Loaded) {

		decl String:soundpathMainDir[PLATFORM_MAX_PATH];
		Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",g_szPlugin_Path);
		File_AddToDownloadsTable(soundpathMainDir);
		PrecacheSound(g_szPlugin_Path);
	}
	else if(validSoundFile == 0){

		decl String:cvarName[MAX_NAME_LENGTH];
		GetConVarName(g_cvarPath, cvarName, sizeof(cvarName));
		LogError("cvar %s is wrong, because %s is not a valid path", cvarName, g_szPlugin_Path);
		g_szPlugin_Path[0] = '\0';
	}
	else if(validSoundFile == -1){

		decl String:cvarName[MAX_NAME_LENGTH];
		GetConVarName(g_cvarPath, cvarName, sizeof(cvarName));
		LogError("cvar %s is wrong, because the file %s does not exist", cvarName, g_szPlugin_Path);
		g_szPlugin_Path[0] = '\0';
	}

	if(g_szPlugin_ActOnWeapons[0] != '\0'){
		ExplodeString(g_szPlugin_ActOnWeapons, " ", g_szActOnWeapons, sizeof(g_szActOnWeapons), sizeof(g_szActOnWeapons[]));
	}

	g_bConfigsExecuted = true;
}

public OnClientPutInServer(client)
{
	Client_Initialize(client);
}

public OnClientPostAdminCheck(client)
{
	Client_Initialize(client);
}

public OnClientCookiesCached(client)
{
	Client_Initialize(client);
}

/**************************************************************************************


	C A L L B A C K   F U N C T I O N S


**************************************************************************************/
/**************************************************************************************

	C O N  V A R  C H A N G E

**************************************************************************************/
/* Callback Con Var Change*/
public ConVarChange_Enable(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_iPlugin_Enable = StringToInt(newVal);
}

public ConVarChange_Path(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if(IsSoundFileValid(newVal) == 1){
		
		strcopy(g_szPlugin_Path,sizeof(g_szPlugin_Path),newVal);
		
		decl String:soundpathMainDir[PLATFORM_MAX_PATH];
		Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",g_szPlugin_Path);
		File_AddToDownloadsTable(soundpathMainDir);
		PrecacheSound(g_szPlugin_Path);
	}
}

public ConVarChange_Delay(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_flPlugin_Delay = StringToFloat(newVal);
}

public ConVarChange_ActOnWeapons(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	strcopy(g_szPlugin_ActOnWeapons, sizeof(g_szPlugin_ActOnWeapons), newVal);
	if(g_szPlugin_ActOnWeapons[0] != '\0'){
		ExplodeString(g_szPlugin_ActOnWeapons, " ", g_szActOnWeapons, sizeof(g_szActOnWeapons), sizeof(g_szActOnWeapons[]));
	}
}

public ConVarChange_Client_Enable(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_bPlugin_Client_Enable = bool:StringToInt(newVal);
}

public ConVarChange_Client_Volume(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_flPlugin_Client_Volume = StringToFloat(newVal);
}

public ConVarChange_Client_Pitch(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_bPlugin_Client_Pitch = bool:StringToInt(newVal);
}

public ConVarChange_Client_PitchTime(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_flPlugin_Client_PitchTime = StringToFloat(newVal);
}

/**************************************************************************************

	C O M M A N D S

**************************************************************************************/
/* Example Command Callback
public Action:Command_(client, args)
{
	
	return Plugin_Handled;
}
*/
public PrefMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen){
	
	if (action == CookieMenuAction_SelectOption) {
		ShowDamageSoundMenu(client);
	}
}
public Action:Command_DamageSoundMenu(client,args)
{
	ShowDamageSoundMenu(client);
	return Plugin_Handled;
}
ShowDamageSoundMenu(client)
{
	new Handle:menu = CreateMenu(HandleDamageSoundMenu);
	
	SetMenuTitle(menu, "Damage Sound Menu\n\nThe Menu shows the\ncurrent settings");
	
	new String:value[14];
	new String:buffer[32];
	  
	//Enable:
	BoolToString(value, sizeof(value), g_bClient_Enable[client]);
	Format(buffer, sizeof(buffer), "DamageSound is %s", value);
	AddMenuItem(menu, "DS-Enable", buffer);
	
	//Volume:
	Format(buffer, sizeof(buffer), "Volume: %.0f %", g_flClient_Volume[client]);
	AddMenuItem(menu, "DS-Volume", buffer);
	
	//Pitch:
	BoolToString(value, sizeof(value), g_bClient_Pitch[client]);
	Format(buffer, sizeof(buffer), "Pitch is %s", value);
	AddMenuItem(menu, "DS-Pitch", buffer);
	
	//PitchTime:
	Format(buffer, sizeof(buffer), "PitchResetTime: %.2f", g_flClient_PitchTime[client]);
	AddMenuItem(menu, "DS-PitchTime", buffer);
	
	DisplayMenu(menu, client, 90);	
}
public HandleDamageSoundMenu(Handle:menu, MenuAction:action, client, param)
{
	if (action == MenuAction_Select) {
		decl String:info[32];
		decl String:savedValue[8];
		GetMenuItem(menu, param, info, sizeof(info));
		
		if(StrEqual(info,"DS-Enable",false)){
			
			g_bClient_Enable[client] = !g_bClient_Enable[client];
			IntToString(g_bClient_Enable[client], savedValue, sizeof(savedValue));
			if (g_bClientPrefs_Loaded) {
				SetClientCookie(client, g_cookieEnable, savedValue);
			}
			Client_InitializeVariables(client);
			ShowDamageSoundMenu(client);
		}
		else if(StrEqual(info,"DS-Volume",false)){
			
			ShowSettingVolumeMenu(client, info, 0.0, 1.0, MAX_FLOAT_MENU_ENTRYS);
		}
		else if(StrEqual(info,"DS-Pitch",false)){
			
			g_bClient_Pitch[client] = !g_bClient_Pitch[client];
			IntToString(g_bClient_Pitch[client], savedValue, sizeof(savedValue));
			if (g_bClientPrefs_Loaded) {
				SetClientCookie(client, g_cookiePitch, savedValue);
			}
			Client_InitializeVariables(client);
			ShowDamageSoundMenu(client);
		}
		else if(StrEqual(info,"DS-PitchTime",false)){
			
			ShowSettingSecondsMenu(client, info, 0.0, 5.0, MAX_FLOAT_MENU_ENTRYS);
		}
	}
	else if (action == MenuAction_End) {
		
		CloseHandle(menu);
	}
}
ShowSettingVolumeMenu(client, String:settingsName[], Float:rangeMin, Float:rangeMax, maxMenuEntrys)
{
	new Handle:menu = CreateMenu(HandleSettingVolumeMenu);
	SetMenuTitle(menu, "Damage Sound Menu\nSelect volume:");
	
	new String:buffer[20];
	
	for(new i=0;i<=maxMenuEntrys;i++){

		Format(buffer, sizeof(buffer), "%.0f %", (rangeMin+(((rangeMax-rangeMin)/maxMenuEntrys)*i)) * 100);
		AddMenuItem(menu, settingsName, buffer);
	}
	
	DisplayMenu(menu, client, 90);
}
public HandleSettingVolumeMenu(Handle:menu, MenuAction:action, client, param)
{
	if (action == MenuAction_Select) {
		
		decl String:info[32], String:display[32];
		new style;
		
		GetMenuItem(menu, param, info, sizeof(info), style, display, sizeof(display));

		g_flClient_Volume[client] = StringToFloat(display);
		if (g_bClientPrefs_Loaded) {
			SetClientCookie(client, g_cookieVolume, display);
		}

		ShowDamageSoundMenu(client);
	}
	else if (action == MenuAction_End) {
		
		CloseHandle(menu);
	}
}

ShowSettingSecondsMenu(client, String:settingsName[], Float:rangeMin, Float:rangeMax, maxMenuEntrys)
{
	new Handle:menu = CreateMenu(HandleSettingSecondsMenu);
	SetMenuTitle(menu, "Damage Sound Menu\nSelect pitch reset time:");
	
	new String:buffer[20];
	
	for(new i=0;i<=maxMenuEntrys;i++){
		
		Format(buffer, sizeof(buffer), "%.2f seconds", rangeMin+(((rangeMax-rangeMin)/maxMenuEntrys)*i));
		AddMenuItem(menu, settingsName, buffer);
	}
	
	DisplayMenu(menu, client, 90);
}
public HandleSettingSecondsMenu(Handle:menu, MenuAction:action, client, param)
{
	if (action == MenuAction_Select) {
		
		decl String:info[32], String:display[32];
		new style;
		
		GetMenuItem(menu, param, info, sizeof(info), style, display, sizeof(display));
		
		g_flClient_PitchTime[client] = StringToFloat(display);
		if (g_bClientPrefs_Loaded) {
			SetClientCookie(client, g_cookiePitchTime, display);
		}
		Client_InitializeVariables(client);

		ShowDamageSoundMenu(client);
	}
	else if (action == MenuAction_End) {
		
		CloseHandle(menu);
	}
}

/**************************************************************************************

	E V E N T S

**************************************************************************************/
/* Example Callback Event
public Action:Event_Example(Handle:event, const String:name[], bool:dontBroadcast)
{

}
*/
public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	g_iClient_HitCounter[attacker][client] = 0;
}

public Action:Event_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_iPlugin_Enable == 0) {
		return Plugin_Continue;
	}

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!g_bClient_Enable[attacker]){
		return Plugin_Continue;
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(Client_IsValid(client) && Client_IsValid(attacker) && (client != attacker)){
		
		decl String:weapon[32];
		Client_GetActiveWeaponName(attacker, weapon, sizeof(weapon));
		if(!IsWeaponSoundable(weapon)){
			return Plugin_Continue;
		}

		new Float:theTime = GetGameTime();

		if(g_flClient_PitchTime[attacker] > 0.0){
			
			if(theTime - g_flClient_PitchTime[attacker] >= g_flClient_LastHit[attacker][client]){
				g_iClient_HitCounter[attacker][client] = 0;
			}
		}
		
		if (g_flPlugin_Delay > 0.0) {

			if(theTime - g_flPlugin_Delay <= g_flClient_LastHit[attacker][client]){
				return Plugin_Continue;
			}
		}
		
		g_flClient_LastHit[attacker][client] = theTime;

		new calcPitch = SNDPITCH_NORMAL + g_iClient_HitCounter[attacker][client] * 4;
		if (calcPitch > MAXPITCH) {
			calcPitch = 255;
		}

		EmitSoundToClient(attacker, g_szPlugin_Path, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, g_flClient_Volume[attacker] / 100.0, calcPitch);
		EmitSoundToClient(attacker, g_szPlugin_Path, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, g_flClient_Volume[attacker], calcPitch);
		EmitSoundToClient(attacker, g_szPlugin_Path, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, g_flClient_Volume[attacker], calcPitch);
		
		if(g_bClient_Pitch[attacker]){
			g_iClient_HitCounter[attacker][client]++;
		}
	}

	return Plugin_Continue;
}

/***************************************************************************************


	P L U G I N   F U N C T I O N S


***************************************************************************************/
bool:IsWeaponSoundable(String:weapon[])
{
	new i=0;

	if (g_szActOnWeapons[0][0] == '\0') {

		return true;
	}

	for (i=0;i<sizeof(g_szActOnWeapons);i++) {

		if (StrEqual(g_szActOnWeapons[i],weapon)) {

			return true;
		}
	}
	return false;
}

IsSoundFileValid(const String:tempsoundpath[])
{
	decl String:soundpathMainDir[PLATFORM_MAX_PATH];
	Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",tempsoundpath);
	
	if(StrEqual(soundpathMainDir,"",false) || StrEqual(soundpathMainDir,"/",false)){
		return 0;
	}
	
	if(!FileExists(soundpathMainDir,true) && !FileExists(soundpathMainDir,false)){
		return -1;
	}	
	
	return 1;
}

LoadClientPrefs_Cookies(client)
{	
	g_bClient_Enable[client] 		= loadCookieOrDefBool(client, g_cookieEnable, g_bPlugin_Client_Enable);
	g_flClient_Volume[client] 		= loadCookieOrDefFloat(client, g_cookieVolume, g_flPlugin_Client_Volume);
	g_bClient_Pitch[client] 		= loadCookieOrDefBool(client, g_cookiePitch, g_bPlugin_Client_Pitch);
	g_flClient_PitchTime[client] 	= loadCookieOrDefFloat(client, g_cookiePitchTime, g_flPlugin_Client_PitchTime);
}

LoaddClientPrefs_WithoutCookies(client)
{
	g_bClient_Enable[client] 		= g_bPlugin_Client_Enable;
	g_flClient_Volume[client] 		= g_flPlugin_Client_Volume;
	g_bClient_Pitch[client] 		= g_bPlugin_Client_Pitch;
	g_flClient_PitchTime[client] 	= g_flPlugin_Client_PitchTime;
}

bool:loadCookieOrDefBool(client, Handle:cookie, bool:defaultValue)
{
	new String:buffer[64];
	GetClientCookie(client, cookie, buffer, sizeof(buffer));
	
	if(!StrEqual(buffer, "")){
		
		return bool:StringToInt(buffer);
	}
	else {
		
		return defaultValue;
	}
}

Float:loadCookieOrDefFloat(client, Handle:cookie, Float:defaultValue)
{
	new String:buffer[64];
	
	GetClientCookie(client, cookie, buffer, sizeof(buffer));
	
	if(!StrEqual(buffer, "")){
		
		return StringToFloat(buffer);
	}
	else {
		
		return defaultValue;
	}
}

BoolToString(String:str[],maxlen,bool:value)
{
	if(value){
		strcopy(str,maxlen,"On");
	}
	else {
		strcopy(str,maxlen,"Off");
	}
}

/***************************************************************************************

	S T O C K

***************************************************************************************/
stock Client_InitializeAll()
{
	LOOP_CLIENTS (client, CLIENTFILTER_ALL) {
		
		Client_Initialize(client);
	}
}

stock Client_Initialize(client)
{
	// Variables
	Client_InitializeVariables(client);
	
	
	// Functions
	
	
	/* Functions where the player needs to be in game */
	if (!IsClientInGame(client)) {
		return;
	}

	// ignore if its sourceTV
	if (IsClientSourceTV(client)) {
		return;
	}
	
	if(g_bClientPrefs_Loaded && AreClientCookiesCached(client)){
				
		LoadClientPrefs_Cookies(client);
	} 
	else{
		
		LoaddClientPrefs_WithoutCookies(client);
	}
}

stock Client_InitializeVariables(client)
{
	new Float:theGameTime = GetGameTime();
	// Client Variables

	for (new i=0; i<MAXPLAYERS+1; i++) {
		g_iClient_HitCounter[client][i] = 0;
		g_flClient_LastHit[client][i] = theGameTime;
	}
}


