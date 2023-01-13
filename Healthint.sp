#pragma	semicolon 1
#include <sourcemod>
#include <sdktools>
#include <base>
#include <log>

ConVar RadiusHealt;

int g_BeamSprite = -1;
int g_HaloSprite = -1;

int greyColor[4]	= {128, 128, 128, 255};
int redColor[4]		= {255, 75, 75, 255};

new Handle:cTimer[MAXPLAYERS + 1];
bool IncapClient[MAXPLAYERS + 1] = {false, ...};

public void OnPluginStart()
{
	RadiusHealt = CreateConVar("sm_ukr_radius_regen", "300", "", FCVAR_NONE);

	HookEvent("heal_success", event_HealSuccess);
}

public void OnMapStart()
{
	g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("sprites/glow01.vmt");
}

public event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int subject = GetClientOfUserId(event.GetInt("subject"));
	
	if(!IsClientInGame(subject))
	{
		return;
	}
	
	float vec[3];
	GetClientAbsOrigin(subject, vec);
	vec[2] += 10.0;
	
	if(g_BeamSprite > -1 && g_HaloSprite > -1)
	{
		TE_SetupBeamRingPoint(vec, 10.0, RadiusHealt.FloatValue, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vec, 10.0, RadiusHealt.FloatValue, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, redColor, 10, 0);
		TE_SendToAll();
	}
	
	float cVec[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != subject && IsClientInGame(i))
		{
			if(IsPlayerAlive(i) && GetClientTeam(i) == 2)
			{
				GetClientAbsOrigin(i, cVec);
				if(GetVectorDistance(vec, cVec) < RadiusHealt.FloatValue)
				{
					if(cTimer[i] == INVALID_HANDLE)
					{
						int hp = GetEntProp(i, Prop_Send, "m_iHealth");
						RegenExtra(i, true);
						cTimer[i] = CreateTimer(0.5, ClientTick, i | (hp << 7), TIMER_REPEAT);
					}
				}
			}
		}
	}
	
	if(IsClientInGame(subject))
	{
		SetEntityRenderColor(subject, 255, 255, 255, 255);
	}
	return;
}

void KillClientTimer(int client)
{
	if(IsClientInGame(client)) {
		RegenExtra(client, false);
	}
	
	IncapClient[client] = false;
	
	if(cTimer[client] != INVALID_HANDLE) {
		KillTimer(cTimer[client]);
		cTimer[client] = INVALID_HANDLE;
	}
}

stock void GiveHealth(int client)
{
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give health");
	SetCommandFlags("give", flags);
	SetEntityHealth(client, 3);
}

public Action:ClientTick(Handle:timer, any:gClient)
{
	int client = gClient & 0x7f;
	int hp = gClient >> 7;

	if(IsClientConnected(client) && IsClientInGame(client))
	{
		if(GetClientTeam(client) == 2)
		{
			int Health = GetEntProp(client, Prop_Send, "m_iHealth");
			int MaxHeaith = GetEntProp(client, Prop_Send, "m_iMaxHealth");
			int offset = FindSendPropInfo("CTerrorPlayer", "m_currentReviveCount");
			int incap = GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
			
			if(incap == 1)
			{
				if(IncapClient[client] == false)
				{
					IncapClient[client] = true;
					GiveHealth(client);
				}
			}
			if(Health < 2)
			{
				GiveHealth(client);
			}
			else if(GetEntData(client, offset, 1) > 0)
			{
				SetEntData(client, offset, 0, 1);
			}
			else if(Health >= (hp + 40) || (Health == MaxHeaith))
			{
				KillClientTimer(client);
			}
		}
		else
		{
			KillClientTimer(client);
		}
	}
	else
	{
		KillClientTimer(client);
	}
}
