// Conf vars
int			g_iServerID,
			g_iRanksID,
			g_iMinPlayers,
			g_iResetStatsTime,
			g_iDeletePlayersTime,
			g_iCalibrationFixTime,
			g_iSaveInterval;
bool		g_bShowStatsEveryone,
			g_bBlockStatsOnWarmup;
float		g_fDBRetryConnTime,
			g_fCoeff,
			g_fExtraPoints[18];
KeyValues	g_hWeaponsConfigKV;

enum
{
	CFG_HEADSHOT = 0,
	CFG_ASSIST,
	CFG_SUICIDE,
	CFG_TEAMKILL,
	CFG_WIN_ROUND,
	CFG_LOSE_ROUND,
	CFG_MVP_PLAYER,
	CFG_BOMB_PLANTED,
	CFG_BOMB_DEFUSED,
	CFG_BOMB_DROPPED,
	CFG_BOMB_PICK_UP,
	CFG_HOSTAGE_KILLED,
	CFG_HOSTAGE_RESCUED
};

void LoadConfigKV()
{
	if (g_hWeaponsConfigKV)
	{
		delete g_hWeaponsConfigKV;
	}

	char szPath[256];
	g_hWeaponsConfigKV = new KeyValues("Config");
	BuildPath(Path_SM, SZF(szPath), "configs/FirePlayersStats/settings.ini");
	if(!g_hWeaponsConfigKV.ImportFromFile(szPath))
	{
		SetFailState("No found file: '%s'.", szPath);
	}

	g_hWeaponsConfigKV.Rewind();
	if (g_hWeaponsConfigKV.JumpToKey("ExtraPoins") && g_hWeaponsConfigKV.GotoFirstSubKey(false))
	{
		int i;
		do {
			g_fExtraPoints[i] = g_hWeaponsConfigKV.GetFloat(NULL_STRING, 0.0);
			#if DEBUG == 1
				static char szBuffer[32];
				g_hWeaponsConfigKV.GetSectionName(SZF(szBuffer));
				FPS_Debug("LoadConfigKV >> %s #%i: %f", szBuffer, i, g_fExtraPoints[i])
			#endif
			i++;
		} while (g_hWeaponsConfigKV.GotoNextKey(false));
	}
}

void SetCvars()
{
	ConVar Convar;
	(Convar = CreateConVar(
		"sm_fps_db_lost_conn_retry_time",	"15", 
		"Через сколько секунд повторить попытку коннекта к БД", 
		_, true, 5.0, true, 120.0
	)).AddChangeHook(ChangeCvar_DBRetryConnTime);
	g_fDBRetryConnTime = Convar.FloatValue;

	(Convar = CreateConVar(
		"sm_fps_server_id",					"0", 
		"ID сервера. Позволит использовать одну БД для многих серверов",
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ServerID);
	g_iServerID = Convar.IntValue;

	(Convar = CreateConVar(
		"sm_fps_ranks_id",					"0", 
		"ID настройки рангов. Позволит использовать одну и туже настройку рангов\n \
		для некоторых серверов, при этом можно сделать уникальную для других",
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_RanksID);
	g_iRanksID = Convar.IntValue;

	(Convar = CreateConVar(
		"sm_fps_min_players",				"4", 
		"Минимальное количество игроков для работы статистики", 
		_, true, 2.0
	)).AddChangeHook(ChangeCvar_MinPlayers);
	g_iMinPlayers = Convar.IntValue;

	(Convar = CreateConVar(
		"sm_fps_reset_stats_time",			"2592000", 
		"Минимальное время в секундах, через которое можно обнулить статистику (0 - Выключить возможность обнуления)", 
		_, true, 0.0
	)).AddChangeHook(ChangeCvar_ResetStatsTime);
	g_iResetStatsTime = Convar.IntValue;

	(Convar = CreateConVar(
		"sm_fps_show_stats_everyone",		"1", 
		"Показывать статиститку игрока всем при использовании команд просмотра (1 - Да / 0 - Нет)", 
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_ShowStatsEveryone);
	g_bShowStatsEveryone = Convar.BoolValue;

	(Convar = CreateConVar(
		"sm_fps_block_stats_on_warmup",		"1", 
		"Блокировать работу статистики на разминке (1 - Да / 0 - Нет)", 
		_, true, 0.0, true, 1.0
	)).AddChangeHook(ChangeCvar_BlockStatsOnWarmup);
	g_bBlockStatsOnWarmup = Convar.BoolValue;

	(Convar = CreateConVar(
		"sm_fps_clean_players_time",		"14", 
		"Через сколько дней удалить данные игрока", 
		_, true, 7.0, true, 90.0
	)).AddChangeHook(ChangeCvar_DeletePlayersTime);
	g_iDeletePlayersTime = Convar.IntValue * 24 * 60 * 60;

	(Convar = CreateConVar(
		"sm_fps_poins_coeff",	"1.0", 
		"Коэффициент расчета очков.\n \
		1.9 - Игрок теряет на 90% больше, чем получает за него убийца\n \
		1.0 - Игрок теряет столько же очков опыта, сколько получает убийца\n \
		0.1 - Игрок теряет только 10% очков опыта от реального значения", 
		_, true, 0.1, true, 1.9
	)).AddChangeHook(ChangeCvar_EloCoeff);
	g_fCoeff = Convar.FloatValue;

	(Convar = CreateConVar(
		"sm_fps_calibration_fix",	"1800", 
		"Время калибровки игрока. Снижает ущерб всем кого убил калибрующийся\n \
		 в течение времени в сек, если доля делимых очек менее 0.5. 0 - Отключить.", 
		_, true, 0.0, true, 7200.0
	)).AddChangeHook(ChangeCvar_CalibrationFix);
	g_iCalibrationFixTime = Convar.IntValue;

	(Convar = CreateConVar(
		"sm_fps_save_period",	"5", 
		"Интервал раундов сохранения статистики.", 
		_, true, 2.0, true, 10.0
	)).AddChangeHook(ChangeCvar_SaveInterval);
	g_iSaveInterval = Convar.IntValue;

	AutoExecConfig(true, "FirePlayersStats");

	LoadConfigKV();
}

public void ChangeCvar_DBRetryConnTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_fDBRetryConnTime = Convar.FloatValue;
}

public void ChangeCvar_ServerID(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iServerID = Convar.IntValue;
}

public void ChangeCvar_RanksID(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iRanksID = Convar.IntValue;
}

public void ChangeCvar_MinPlayers(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iMinPlayers = Convar.IntValue;
}

public void ChangeCvar_ResetStatsTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iResetStatsTime = Convar.IntValue;
}

public void ChangeCvar_ShowStatsEveryone(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bShowStatsEveryone = Convar.BoolValue;
}

public void ChangeCvar_BlockStatsOnWarmup(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_bBlockStatsOnWarmup = Convar.BoolValue;
}

public void ChangeCvar_DeletePlayersTime(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iDeletePlayersTime = Convar.IntValue * 24 * 60 * 60;
}

public void ChangeCvar_EloCoeff(ConVar Convar, const char[] oldValue, const char[] newValue)
{	
	g_fCoeff = Convar.FloatValue;
}

public void ChangeCvar_CalibrationFix(ConVar Convar, const char[] oldValue, const char[] newValue)
{	
	g_iCalibrationFixTime = Convar.IntValue;
}

public void ChangeCvar_SaveInterval(ConVar Convar, const char[] oldValue, const char[] newValue)
{
	g_iSaveInterval = Convar.IntValue;
}
