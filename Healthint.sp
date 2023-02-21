#pragma	semicolon 1
#include <sourcemod>
#include <sdktools>
#include <base>
#include <log>

ConVar RadiusHealt;

int g_BeamSprite			= -1;
int g_HaloSprite			= -1;

int greyColor[4]			= {128, 128, 128, 255};
int redColor[4]				= {255, 75, 75, 255};
int g_HP_c[MAXPLAYERS + 1]		= {0, ...};

bool IncapClient[MAXPLAYERS + 1]	= {false, ...};
bool bRoundStart = true;

int HpCount[MAXPLAYERS + 1]		= {0, ...};

new Handle:cTimer[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RadiusHealt = CreateConVar("sm_ukr_radius_regen", "300", "", FCVAR_NONE);

	HookEvent("heal_success",			event_HealSuccess);
	HookEvent("round_start",			Event_RoundStart);
	HookEvent("round_end",				Event_RoundEnd);
	HookEvent("map_transition",			Event_MapTransition);
}

public Action Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	bRoundStart = true;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(cTimer[i] != null){
			if(IsClientConnected(i) && IsClientInGame(i)) {
				if(IsPlayerAlive(i) && GetClientTeam(i) == 2) {
					int hp = g_HP_c[i] + ((HpCount[i] == 1) ? 40 : (40 * HpCount[i]));
					int m_iMaxHealth = GetEntData(i, FindDataMapInfo(i, "m_iMaxHealth"), 4);
					SetHealt(i, hp, m_iMaxHealth);
				}
			}
			KillClientTimer(i);
		}
	}
}

void SetHealt(int client, int hp, int maxHp)
{
	if(hp >= maxHp) {
		SetEntData(client, FindDataMapInfo(client, "m_iHealth"), maxHp, 4, true);
	} else {
		SetEntData(client, FindDataMapInfo(client, "m_iHealth"), hp, 4, true);
	}
}

public Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	bRoundStart = true;
	return;
}

public Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	bRoundStart = false;
	return;
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
	
	if(IsClientInGame(subject))
	{
		SetEntityRenderColor(subject, 255, 255, 255, 255);
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
					HpCount[i]++;
					int m_iHealth = GetEntData(i, FindDataMapInfo(i, "m_iHealth"), 4);
					if(!bRoundStart)
					{
						int hp = m_iHealth + 40;
						int m_iMaxHealth = GetEntData(i, FindDataMapInfo(i, "m_iMaxHealth"), 4);
						SetHealt(i, hp, m_iMaxHealth);
					} else {
						RegenExtra(i, true, (2 * HpCount[i]));
						if(cTimer[i] == INVALID_HANDLE)
						{
							g_HP_c[i] = m_iHealth;
							cTimer[i] = CreateTimer(0.5, ClientTick, i, TIMER_REPEAT);
						}
					}
				}
			}
		}
	}
	
	return;
}

void KillClientTimer(int client)
{
	if(IsClientInGame(client)) {
		RegenExtra(client, false, 1);
	}
	
	IncapClient[client] = false;
	HpCount[client] = 0;
	g_HP_c[client] = 0;
	
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

public Action:ClientTick(Handle:timer, any:client)
{
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
			if(IncapClient[client])
			{
				if(g_HP_c[client] >= 3)
				{
					g_HP_c[client] = 3;
				}
			}
			
			int Hp_c = g_HP_c[client] + ((HpCount[client] == 1) ? 40 : (40 * HpCount[client]));			
			if(Hp_c > MaxHeaith)
			{
				Hp_c = MaxHeaith;
			}
			
			if(Health < 2)
			{
				GiveHealth(client);
			}
			
			if(GetEntData(client, offset, 1) > 0)
			{
				SetEntData(client, offset, 0, 1);
			}
			
			if(Health >= Hp_c)
			{
				KillClientTimer(client);
			}

			if(Health == MaxHeaith)
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
