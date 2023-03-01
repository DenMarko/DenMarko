#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <log>

#define MaxCountRescue 64

public Plugin:myinfo =
{
	name = "Survivor Rescue no limits",
	author = "Den Марко",
	description = "Rescue no limits",
	version = "1.0",
	url = "http://www.sourcemod.com/"
};

bool bRoundStart = false;
bool bFinaleStart = false;

int iCountRescue = -1;
int iRescueId[MaxCountRescue]			= {-1, ...};

float fPlayerTResetRescue[MAXPLAYERS+1]	= {0.0, ...};

Handle hTimerStart = null;

ConVar g_fMinRescueTime;

public void OnPluginStart()
{
	LogMessegToFile("Plugins init all values in hooks");

	HookEvent("round_start",		Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("map_transition",		Event_MapTransition,	EventHookMode_PostNoCopy);
	HookEvent("finale_win",			Event_FinalWin,		EventHookMode_PostNoCopy);
	HookEvent("finale_start",		Event_finale_start,	EventHookMode_PostNoCopy);
	
	g_fMinRescueTime = FindConVar("rescue_min_dead_time");

	if(hTimerStart == null){
		hTimerStart = CreateTimer(1.0, RescueFrames, INVALID_HANDLE, TIMER_REPEAT);
	}
}

public void OnPluginEnd()
{
	LogMessegToFile("Plugins Is end hooks in timer stop");

	UnhookEvent("round_start",			Event_RoundStart,		EventHookMode_PostNoCopy);
	UnhookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	UnhookEvent("map_transition",		Event_MapTransition,	EventHookMode_PostNoCopy);
	UnhookEvent("finale_win",			Event_FinalWin,		EventHookMode_PostNoCopy);
	UnhookEvent("finale_start",			Event_finale_start,	EventHookMode_PostNoCopy);

	if(hTimerStart != null){
		delete hTimerStart;
		hTimerStart = null;
	}
}

bool IsGoodFrame()
{
	if(bFinaleStart)
	{
		return true;
	}
	if(!bRoundStart)
	{
		return true;
	}
	return false;
}

public Action RescueFrames(Handle h)
{
	if(IsGoodFrame()) {
		return Plugin_Continue;
	}

	char cName[128];
	if(IsPlayerDeath())
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i))
			{
				if(GetClientTeam(i) == 2 && !IsPlayerAlive(i))
				{
					if(IsFakeClient(i))
					{
						GetClientName(i, cName, sizeof(cName));
						if (StrEqual(cName, "New_Bot", true))
						{
							continue;
						}
					}

					if(!IsPlayerDeathTimeValid(i))
					{
						continue;
					}
					
					if(IsPlayersRescue(i))
					{
						continue;
					}

					float vClient[3], vPos[3], distance = 800.0;
					int index = -1;
					for(int j = 0; j < iCountRescue; j++)
					{
						int g_SRescue = EntRefToEntIndex(iRescueId[j]);
						if(IsValidEntRef(g_SRescue))
						{
							if(GetEntPropEnt(g_SRescue, Prop_Send, "m_survivor") == -1)
							{
								GetEntPropVector(g_SRescue, Prop_Data, "m_vecOrigin", vPos);
								for(int g = 1; g <= MaxClients; g++)
								{
									if(IsClientConnected(g) && IsClientInGame(g))
									{
										if(GetClientTeam(g) == 2 && IsPlayerAlive(g))
										{
											GetClientAbsOrigin(g, vClient);
											float dist = GetVectorDistance(vPos, vClient);
											if(dist < distance)
											{
												distance = dist;
												index = j;
											}
										}
									}
								}
							}
						}
					}
					
					if(index != -1)
					{
						int g_rEntity = EntRefToEntIndex(iRescueId[index]);
						if(IsValidEntRef(g_rEntity))
						{
							if(GetEntPropEnt(g_rEntity, Prop_Send, "m_survivor") == -1)
							{
								Rescue(g_rEntity, i);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

stock bool IsValidEntRef(int entity)
{
	if( entity && entity != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

public void OnMapEnd()
{
	bRoundStart = false;
	ClearData();
	return;
}

public Action Event_finale_start(Event event, const char[] name, bool DontBroad)
{
	bFinaleStart = true;
	return Plugin_Continue;
}

public Action Event_FinalWin(Event event, const char[] name, bool DontBroad)
{
	bRoundStart = false;
	ClearData();
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool DontBroad)
{
	if(!bRoundStart)
	{
		CreateTimer(1.0, TimerStart);
	}
	bRoundStart = true;
	return Plugin_Continue;
}

public Action TimerStart(Handle h)
{
	int g_Rescue = -1;
	while((g_Rescue = FindEntityByClassname(g_Rescue, "info_survivor_rescue")) != -1)
	{
		iCountRescue++;
		iRescueId[iCountRescue] = EntIndexToEntRef(g_Rescue);
	}
	return Plugin_Continue;
}

public Action Event_MapTransition(Event event, const char[] name, bool DontBroad)
{
	bRoundStart = false;
	ClearData();
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool DontBroad)
{
	bRoundStart = false;
	ClearData();
	return Plugin_Continue;
}

void ClearData()
{
	for(int i = 0; i < iCountRescue; i++)
	{
		iRescueId[i] = -1;
	}
	iCountRescue = -1;
	bFinaleStart = false;
}

bool IsPlayerDeath()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(GetClientTeam(i) == 2 && !IsPlayerAlive(i))
			{
				return true;
			}
		}
	}
	return false;
}

bool IsPlayersRescue(int client)
{
	float fGameTime = GetGameTime();
	for(int i = 0; i < iCountRescue; i++)
	{
		int iEntity = EntRefToEntIndex(iRescueId[i]);
		if(iEntity != -1)
		{
			if(GetEntPropEnt(iEntity, Prop_Send, "m_survivor") == client)
			{
				if(((fPlayerTResetRescue[client] + 1.0) - fGameTime) <= 0) {
					fPlayerTResetRescue[client] = (fGameTime + 20.0);
				}

				if(fGameTime < fPlayerTResetRescue[client]) {
					return true;
				} else {
					Rescue(iEntity, 0);
					return false;
				}
			}
		}
	}
	return false;
}

bool IsPlayerDeathTimeValid(int client)
{
	float fDeathTime = GetEntPropFloat(client, Prop_Send, "m_flDeathTime");
	float gameTime = GetGameTime();
	if(gameTime > (fDeathTime + g_fMinRescueTime.FloatValue))
	{
		return true;
	}
	return false;
}
