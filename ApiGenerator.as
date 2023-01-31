// fixes choppy microphone audio caused by cutscenes and cameras
// by automatically executing the "stopsound" command for clients.
// This is done at the beginning and end of camera sequences.

class PvData {
	string name;
	int offset = -1;
	int fieldType = -1;
	
	PvData() {}
	
	PvData(string name, int offset, int fieldType) {
		this.name = name;
		this.offset = offset;
		this.fieldType = fieldType;
	}
}

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

CClientCommand _apigen("apigen", "Generate metamod API", @consoleCmd );

CConCommand@ apiResultCmd;

void PluginInit() {
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "github" );
	
	@apiResultCmd = @CConCommand( "private_api_result", "metamod response to a private api test", @private_api_result );
}

uint64 g_pv_result = 0;
float g_pv_result_f = 0;
Vector g_pv_result_vec3 = Vector(0,0,0);
int g_pv_offset = -1;
int g_pv_size = -1;

void private_api_result( const CCommand@ args ) {	
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	if (args.ArgC() == 0) {
		g_pv_result = 0;
		g_pv_result_f = 0;
		g_pv_offset = -1;
		g_pv_size = -1;
		return;
	}
	
	g_pv_result = atoui64(args[1], 10);
	g_pv_result_f = atof(args[2]);
	
	
	array<string> vec3_parts = args[3].Split("_");
	g_pv_result_vec3.x = atof(vec3_parts[0]);
	g_pv_result_vec3.y = atof(vec3_parts[1]);
	g_pv_result_vec3.z = atof(vec3_parts[2]);
	
	g_pv_offset = atoi(args[4]);
	g_pv_size = atoi(args[5]);
}

enum field_types {
	FIELD_BOOL,
	FIELD_BYTE,
	FIELD_SHORT,
	FIELD_INT,
	FIELD_FLT,
	FIELD_PTR,
	FIELD_INT64,
	FIELD_VEC3,
	FIELD_STR,
}

int getFieldSize(int fieldType) {
	switch(fieldType) {
		case FIELD_BOOL: return 1;
		case FIELD_BYTE: return 1;
		case FIELD_SHORT: return 2;
		case FIELD_INT: return 4;
		case FIELD_FLT: return 4;
		case FIELD_PTR: return 4;
		case FIELD_INT64: return 8;
		case FIELD_VEC3: return 4*3;
		case FIELD_STR: return 4;
	}
	
	return 0;
}

class TestValue {
	uint8 v8;
	uint16 v16;
	uint32 v32;
	uint64 v64;
	float vf;
	Vector vec3;
	string_t str;
	
	TestValue() {}
	
	TestValue(bool setNotEmpty) {
		if (setNotEmpty) {
			v8 = 0x01;
			v16 = 0x1234;
			v32 = 0x12345678;
			v64 = 0x12345678ABCDEF01;
			vf = 1234.567f;
			vec3 = Vector(1234.567f, 2235.567f, 3234.567f);
			str = "1234567890";
		} // else 0s
	}
}

funcdef void pvSet(CBaseEntity@ ent, TestValue@ value);

entvars_t@ g_pev;

class CBaseEntityPv {
	CBaseEntity@ ent;
	int test_index;
	int errors = 0;
	string className;

	array<PvData> test_results;
	
	CBaseEntityPv() {}
	
	CBaseEntityPv(CBaseEntity@ ent) {
		className = "CBaseEntity";
		@this.ent = @ent;
		test_index = this.ent.entindex();
	}
	
	bool find_offset(string fieldname, int fieldtype, pvSet@ setValueFunc) {
		println("TEST " + fieldname);
		TestValue initValue = TestValue(false);
		TestValue setValue = TestValue(true);
	
		setValueFunc(ent, initValue);

		g_pv_offset = -1;
		g_EngineFuncs.ServerCommand("private_api_init " + test_index + "\n");
		g_EngineFuncs.ServerExecute();
		
		setValueFunc(ent, setValue);
		
		g_EngineFuncs.ServerCommand("private_api_test " + test_index + "\n");
		g_EngineFuncs.ServerExecute();
		
		if (g_pv_offset == -1) {
			errors++;
			return false;
		}
		
		int fieldsize = getFieldSize(fieldtype);
		
		if (g_pv_size != fieldsize && fieldtype != FIELD_PTR) {
			println("Bad test size: " + g_pv_size + " != " + fieldsize);
			errors++;
			return false;
		}
		
		if (fieldtype == FIELD_BYTE || fieldtype == FIELD_BOOL) {
			if (setValue.v8 != uint8(g_pv_result)) {
				println("Bad test result: " + setValue.v8 + " != " + uint8(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_SHORT) {
			if (setValue.v16 != uint16(g_pv_result)) {
				println("Bad test result: " + setValue.v16 + " != " + uint16(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_INT) {
			if (setValue.v32 != uint32(g_pv_result)) {
				println("Bad test result: " + setValue.v32 + " != " + uint32(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_FLT) {
			if (setValue.vf != g_pv_result_f) {
				println("Bad test result: " + setValue.vf + " != " + g_pv_result_f);
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_INT64) {
			if (setValue.v64 != uint64(g_pv_result)) {
				println("Bad test result: " + setValue.v64 + " != " + uint64(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_VEC3) {
			if (setValue.vec3 != g_pv_result_vec3) {
				println("Bad test result: " + setValue.vec3.ToString() + " != " + g_pv_result_vec3.ToString());
				errors++;
				return false;
			}
		} else if (fieldtype == FIELD_PTR) {
			// can't test value exactly
		}
		
		for (uint i = 0; i < test_results.size(); i++) {
			if (fieldname == test_results[i].name) {
				println("Tested duplicate field: " + fieldname);
				errors++;
				return false;
			}
			if (g_pv_offset == test_results[i].offset) {
				println("Fields share offsets: " + fieldname + ", " + test_results[i].name);
				errors++;
				return false;
			}
		}
		
		test_results.insertLast(PvData(fieldname, g_pv_offset, fieldtype));
		return true;
	}
	
	void show_test_results() {
		if (test_results.size() == 0) {
			println("No results");
			return;
		}
		
		println("\nstruct " + className + " {");
		test_results.sort(function(a,b) { return a.offset < b.offset; });
		for (uint i = 0; i < test_results.size(); i++) {
			println("    " + test_results[i].name + ": " + test_results[i].offset);
		}
		println("}");
		println("Failed to find " + errors + " fields");
	}
	
	void setValue(string fieldname, uint64 value) {}
	void generatePrivateApi() {
		errors = 0;
		test_results.resize(0);
		findOffsets();
		show_test_results();
	}
	
	void findOffsets() {
		@g_pev = @ent.pev;
	
		find_offset("pev", FIELD_PTR, function(a,b) {
			if (b.v32 == 0) @a.pev = @g_EntityFuncs.Instance(0).pev;
			if (b.v32 != 0) @a.pev = @g_pev;
		});
		
		find_offset("m_fOverrideClass", FIELD_BOOL, function(a,b) { cast<CBasePlayer@>(a).m_fOverrideClass = b.v8 != 0; });
		find_offset("m_iClassSelection", FIELD_INT, function(a,b) { cast<CBasePlayer@>(a).m_iClassSelection = b.v32; });
		find_offset("m_flMaximumFadeWait", FIELD_FLT, function(a,b) { cast<CBasePlayer@>(a).m_flMaximumFadeWait = b.vf; });
		find_offset("m_flMaximumFadeWaitB", FIELD_FLT, function(a,b) { cast<CBasePlayer@>(a).m_flMaximumFadeWaitB = b.vf; });
		find_offset("m_fCanFadeStart", FIELD_BOOL, function(a,b) { cast<CBasePlayer@>(a).m_fCanFadeStart = b.v8 != 0; });
		find_offset("m_fCustomModel", FIELD_BOOL, function(a,b) { cast<CBasePlayer@>(a).m_fCustomModel = b.v8 != 0; });
		find_offset("m_vecLastOrigin", FIELD_VEC3, function(a,b) { cast<CBasePlayer@>(a).m_vecLastOrigin = b.vec3; });
		find_offset("targetnameOutFilterType", FIELD_STR, function(a,b) { cast<CBasePlayer@>(a).targetnameOutFilterType = b.str; });
		find_offset("classnameOutFilterType", FIELD_STR, function(a,b) { cast<CBasePlayer@>(a).classnameOutFilterType = b.str; });
		find_offset("targetnameInFilterType", FIELD_STR, function(a,b) { cast<CBasePlayer@>(a).targetnameInFilterType = b.str; });
		find_offset("classnameInFilterType", FIELD_STR, function(a,b) { cast<CBasePlayer@>(a).classnameInFilterType = b.str; });
		find_offset("m_iOriginalRenderMode", FIELD_INT, function(a,b) { cast<CBasePlayer@>(a).m_iOriginalRenderMode = b.v32; });
		find_offset("m_iOriginalRenderFX", FIELD_INT, function(a,b) { cast<CBasePlayer@>(a).m_iOriginalRenderFX = b.v32; });
		find_offset("m_flOriginalRenderAmount", FIELD_FLT, function(a,b) { cast<CBasePlayer@>(a).m_flOriginalRenderAmount = b.vf; });
		find_offset("m_vecOriginalRenderColor", FIELD_VEC3, function(a,b) { cast<CBasePlayer@>(a).m_vecOriginalRenderColor = b.vec3; });
	}
}

class CBasePlayerPv : CBaseEntityPv {
	CBasePlayer@ plr;
	
	CBasePlayerPv() {}
	
	CBasePlayerPv(CBasePlayer@ plr) {
		super(plr);
		className = "CBasePlayer";
		@this.plr = @plr;
		generatePrivateApi();
	}
	
	void findOffsets() {
		CBaseEntityPv::findOffsets();
		
	}
}

bool generateApis(CBasePlayer@ plr) {
	CBasePlayerPv(plr);
	return true;
	
	/*
entvars_t@ pev 	Entity variables
bool m_fOverrideClass 	Whether this entity overrides the classification.
int m_iClassSelection 	The overridden classification.
float m_flMaximumFadeWait 	Maximum fade wait time.
float m_flMaximumFadeWaitB 	Maximum fade wait time B.
bool m_fCanFadeStart 	Whether fading can start.
bool m_fCustomModel 	Whether a custom model is used.
Vector m_vecLastOrigin 	Last origin vector
string_t targetnameOutFilterType 	Target name out filter type.
string_t classnameOutFilterType 	Class name out filter type.
string_t targetnameInFilterType 	Target name in filter type.
string_t classnameInFilterType 	Class name in filter type.
int m_iOriginalRenderMode 	Original render model.
int m_iOriginalRenderFX 	Original render FX.
float m_flOriginalRenderAmount 	Original render amount.
Vector m_vecOriginalRenderColor 	Original render color.
float m_flDelay 	Delay before fire.
string_t m_iszKillTarget 	The name of the kill target, if any.
float m_flFrameRate 	Computed FPS for current sequence.
float m_flGroundSpeed 	Computed linear movement rate for current sequence.
float m_flLastEventCheck 	Last time the event list was checked.
float m_flLastGaitEventCheck 	Last time the event list was checked.
bool m_fSequenceFinished 	Flag set when StudioAdvanceFrame moves across a frame boundry.
bool m_fSequenceLoops 	True if the sequence loops.
TOGGLE_STATE m_toggle_state 	Current toggle state.
float m_flMoveDistance 	How far a door should slide or rotate.
float m_flWait 	How long to wait before resetting.
float m_flLip 	How much to stick out of a wall. Will recede further into walls if negative.
float m_flTWidth 	For plats.
float m_flTLength 	For plats.
int m_cTriggersLeft 	Trigger_counter only: # of activations remaining.
float m_flHeight 	Height.
EHandle m_hActivator 	Handle to the activator.
Vector m_vecPosition1 	Closed position.
Vector m_vecPosition2 	Open position.
Vector m_vecAngle1 	Closed angle.
Vector m_vecAngle2 	Open angle.
Vector m_vecFinalDest 	Final destination.
Vector m_vecFinalAngle 	Final angle.
int m_bitsDamageInflict 	DMG_ damage type that the door or trigger does.
string_t m_sMaster 	This entity's master, if any.
EHandle m_hEnemy 	the entity that the monster is fighting.
EHandle m_hTargetEnt 	the entity that the monster is trying to reach.
EHandle m_hTargetTank 	Target tank to control.
float m_flFieldOfView 	width of monster's field of view ( dot product ).
float m_flWaitFinished 	if we're told to wait, this is the time that the wait will be over.
float m_flMoveWaitFinished 	if we're told to wait before moving, this is the time that the wait will be over.
Activity m_Activity 	what the monster is doing (animation).
Activity m_IdealActivity 	monster should switch to this activity.
Activity m_GaitActivity 	gaitsequence.
int m_LastHitGroup 	the last body region that took damage.
MONSTERSTATE m_MonsterState 	monster's current state.
MONSTERSTATE m_IdealMonsterState 	monster should change to this state.
int m_iTaskStatus 	Task status.
Schedule@ m_pSchedule 	Current schedule.
Schedule@ m_pScheduleSaved 	For land_on_ground schedules (remember last schedule and continue).
int m_iScheduleIndex 	Schedule index.
int m_movementGoal 	Goal that defines route.
int m_iRouteIndex 	Index into m_Route[].
float m_moveWaitTime 	How long I should wait for something to move.
float m_moveradius 	Minimum radius.
Vector m_vecMoveGoal 	Kept around for node graph moves, so we know our ultimate goal.
Activity m_movementActivity 	When moving, set this activity.
int m_iAudibleList 	first index of a linked list of sounds that the monster can hear.
int m_afSoundTypes 	Sound types that can be heard.
Vector m_vecLastPosition 	monster sometimes wants to return to where it started after an operation..
int m_iHintNode 	this is the hint node that the monster is moving towards or performing active idle on..
int m_afMemory 	Monster memory.
int m_bloodColor 	color of blood particles.
int m_iMaxHealth 	keeps track of monster's maximum health value (for re-healing, etc).
Vector m_vecEnemyLKP 	last known position of enemy. (enemy's origin).
int m_cAmmoLoaded 	how much ammo is in the weapon (used to trigger reload anim sequences).
int m_afCapability 	tells us what a monster can/can't do.
int m_afMoveShootCap 	tells us what a monster can/can't do, while moving.
float m_flNextAttack 	cannot attack again until this time.
int m_bitsDamageType 	what types of damage has monster (player) taken.
float m_lastDamageAmount 	how much damage did monster (player) last take.
float m_tbdPrev 	Time-based damage timer.
entvars_t@ pevTimeBasedInflictor 	Time based damage inflictor.
int m_failSchedule 	Schedule type to choose if current schedule fails.
float m_flHungryTime 	Time based damage inflictor.
float m_flDistTooFar 	if enemy farther away than this, bits_COND_ENEMY_TOOFAR set in CheckEnemy.
float m_flDistLook 	distance monster sees (Default 2048).
int m_iTriggerCondition 	for scripted AI, this is the condition that will cause the activation of the monster's TriggerTarget.
string_t m_iszTriggerTarget 	Name of target that should be fired.
Vector m_HackedGunPos 	HACK until we can query end of gun.
SCRIPTSTATE m_scriptState 	internal cinematic state.
EHandle m_hCine 	Cinematic entity.
EHandle m_hCineBlocker 	Entity that is blocking cinematic execution.
float m_useTime 	Don't allow +USE until this time.
string_t m_FormattedName 	The formatted name.
For better name outputs. E.g. "Alien Slave" rather than "alien_slave".
int8 m_chTextureType 	Current texture type.
See TextureType enum.
bool m_fCanFearCreatures 	Whether this monster can fear creatures.
float m_flAutomaticAttackTime 	How long an npc will attempt to fire full auto.
float m_flFallVelocity 	Current fall speed.
EHandle m_hGuardEnt 	Monster will guard this entity and turn down follow requests.
string_t m_iszGuardEntName 	Guard entity name.
Vector m_vecEffectGlowColor 	Glow shell.
int m_iEffectBlockWeapons 	Monster can't use weapons.
int m_iEffectInvulnerable 	is invulnerable (god mode)
int m_iEffectInvisible 	is invisible (render + non-targetable)
int m_iEffectNonSolid 	is non-solid
float m_flEffectRespiration 	Extra/less breathing time underwater in seconds
float m_flEffectGravity 	Gravity modifier (%)
float m_flEffectFriction 	Movement friction modifier (%)
float m_flEffectSpeed 	Movement speed modifier (%)
float m_flEffectDamage 	Damage modifier (%)
const int random_seed 	The player's random seed.
float m_flNextClientCommandTime 	The next time this player can execute a vocal client command
float m_flTimeOfLastDeath 	Time of last death.
float m_flRespawnDelayTime 	Gets added to the standard respawn delay time when killed, reset in spawn to 0.0.
EHandle m_hSpawnPoint 	Pointer for a spawn point to use.
float m_flLastMove 	When did this player move or tried to move (with the IN_ keys) ?
int m_iWeaponVolume 	How loud the player's weapon is right now.
int m_iExtraSoundTypes 	Additional classification for this weapon's sound.
int m_iWeaponFlash 	Brightness of the weapon flash.
float m_flStopExtraSoundTime 	When to stop the m_iExtraSoundTypes sounds.
int m_iFlashBattery 	Player flashlight amount. 0 <= amount <= 100.
int m_afButtonLast 	
int m_afButtonPressed 	
int m_afButtonReleased 	
float m_flPlayerFallVelocity 	Player fall velocity.
uint m_afPhysicsFlags 	
float m_flSwimTime 	How long this player has been underwater.
int m_lastPlayerDamageAmount 	Last damage taken.
int m_iDrownDmg 	Track drowning damage taken.
int m_iDrownRestored 	Track drowning damage restored.
int m_iTrain 	Train control position
EHandle m_hTank 	the tank which the player is currently controlling, NULL if no tank
float m_fDeadTime 	the time at which the player died
bool m_fLongJump 	Does this player have the longjump module?
int m_iHideHUD 	The players hud weapon info is to be hidden.
int m_iFOV 	Field of view.
EHandle m_hActiveItem 	The active item.
int m_iDeaths 	get player death count.
float m_flNextDecalTime 	Next time this player can spray a decal.
int m_iPlayerClass 	The player's class type.
*/
}

void consoleCmd( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	generateApis(plr);
}