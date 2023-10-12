#include "meta_init.h"
#include "misc_utils.h"
#include "meta_utils.h"
#include "main.h"

#pragma comment(linker, "/EXPORT:GiveFnptrsToDll=_GiveFnptrsToDll@8")
#pragma comment(linker, "/SECTION:.data,RW")

// Description of plugin
plugin_info_t Plugin_info = {
	META_INTERFACE_VERSION,	// ifvers
	"ApiGenerator",	// name
	"1.0",	// version
	__DATE__,	// date
	"w00tguy",	// author
	"https://github.com/wootguy/",	// url
	"APIGEN",	// logtag, all caps please
	PT_ANYTIME,	// (when) loadable
	PT_ANYPAUSE,	// (when) unloadable
};

#define MAX_EDICTS 8192

int32 pvSizes[MAX_EDICTS];

// private data values before a change is made by angelscript
byte* pvStates[MAX_EDICTS];

void* oldEntVtable = NULL;

int g_vtable_idx = -1; // indicates which virtual function in the vtable was called

#define MAX_VFUNC_ARG_BYTES 32

// function definitions for every possible combination of argument bytes
// TODO: the return type matters too. The game crashes when calling Center() unless return type is Vector
#define VFUNC0(i) virtual void vfunc##i() { println("Hello vfunc call at %d", i); g_vtable_idx = i; }
#define VFUNC1(i) virtual void vfunc##i(char a) { g_vtable_idx = i; }
#define VFUNC2(i) virtual void vfunc##i(short a) { g_vtable_idx = i; }
#define VFUNC3(i) virtual void vfunc##i(short a, char b) { g_vtable_idx = i; }
#define VFUNC4(i) virtual void vfunc##i(int a) { g_vtable_idx = i; }
#define VFUNC5(i) virtual void vfunc##i(int a, char b) { g_vtable_idx = i; }
#define VFUNC6(i) virtual void vfunc##i(int a, short b) { g_vtable_idx = i; }
#define VFUNC7(i) virtual void vfunc##i(int a, short b, char c) { g_vtable_idx = i; }
#define VFUNC8(i) virtual void vfunc##i(uint32_t a, uint32_t b) { println("ARGS %u %u", a, b); g_vtable_idx = i; }
#define VFUNC9(i) virtual void vfunc##i(int64_t a, char b) { g_vtable_idx = i; }
#define VFUNC10(i) virtual void vfunc##i(int64_t a, short b) { g_vtable_idx = i; }
#define VFUNC11(i) virtual void vfunc##i(int64_t a, short b, char c) { g_vtable_idx = i; }
#define VFUNC12(i) virtual void vfunc##i(int64_t a, int b) { g_vtable_idx = i; }
#define VFUNC13(i) virtual void vfunc##i(int64_t a, int b, char c) { g_vtable_idx = i; }
#define VFUNC14(i) virtual void vfunc##i(int64_t a, int b, short c) { g_vtable_idx = i; }
#define VFUNC15(i) virtual void vfunc##i(int64_t a, int b, short c, char d) { g_vtable_idx = i; }
#define VFUNC16(i) virtual void vfunc##i(int64_t a, int64_t b) { g_vtable_idx = i; }
#define VFUNC17(i) virtual void vfunc##i(int64_t a, int64_t b, char c) { g_vtable_idx = i; }
#define VFUNC18(i) virtual void vfunc##i(int64_t a, int64_t b, short c) { g_vtable_idx = i; }
#define VFUNC19(i) virtual void vfunc##i(int64_t a, int64_t b, short c, char d) { g_vtable_idx = i; }
#define VFUNC20(i) virtual void vfunc##i(int64_t a, int64_t b, int c) { g_vtable_idx = i; }
#define VFUNC21(i) virtual void vfunc##i(int64_t a, int64_t b, int c, char d) { g_vtable_idx = i; }
#define VFUNC22(i) virtual void vfunc##i(int64_t a, int64_t b, int c, short d) { g_vtable_idx = i; }
#define VFUNC23(i) virtual void vfunc##i(int64_t a, int64_t b, int c, short d, char e) { g_vtable_idx = i; }
#define VFUNC24(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c) { g_vtable_idx = i; }
#define VFUNC25(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, char d) { g_vtable_idx = i; }
#define VFUNC26(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, short d) { g_vtable_idx = i; }
#define VFUNC27(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, short d, char e) { g_vtable_idx = i; }
#define VFUNC28(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, int d) { g_vtable_idx = i; }
#define VFUNC29(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, int d, char e) { g_vtable_idx = i; }
#define VFUNC30(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, int d, short e) { g_vtable_idx = i; }
#define VFUNC31(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, int d, short e, char f) { g_vtable_idx = i; }
#define VFUNC32(i) virtual void vfunc##i(int64_t a, int64_t b, int64_t c, int64_t d) { g_vtable_idx = i; }

// define a set of virtual functions that take "i" bytes of arguments.
// add as many virtual functions as you think the largest class has
// or else the game will crash when calling one out of bounds
#define VFUNCS(i) \
	VFUNC##i(0) VFUNC##i(1) VFUNC##i(2) VFUNC##i(3) VFUNC##i(4) VFUNC##i(5) VFUNC##i(6) VFUNC##i(7) \
	VFUNC##i(8) VFUNC##i(9) VFUNC##i(10) VFUNC##i(11) VFUNC##i(12) VFUNC##i(13) VFUNC##i(14) VFUNC##i(15) \
	VFUNC##i(16) VFUNC##i(17) VFUNC##i(18) VFUNC##i(19) VFUNC##i(20) VFUNC##i(21) VFUNC##i(22) VFUNC##i(23) \
	VFUNC##i(24) VFUNC##i(25) VFUNC##i(26) VFUNC##i(27) VFUNC##i(28) VFUNC##i(29) VFUNC##i(30) VFUNC##i(31) \
	VFUNC##i(32) VFUNC##i(33) VFUNC##i(34) VFUNC##i(35) VFUNC##i(36) VFUNC##i(37) VFUNC##i(38) VFUNC##i(39) \
	VFUNC##i(40) VFUNC##i(41) VFUNC##i(42) VFUNC##i(43) VFUNC##i(44) VFUNC##i(45) VFUNC##i(46) VFUNC##i(47) \
	VFUNC##i(48) VFUNC##i(49) VFUNC##i(50) VFUNC##i(51) VFUNC##i(52) VFUNC##i(53) VFUNC##i(54) VFUNC##i(55) \
	VFUNC##i(56) VFUNC##i(57) VFUNC##i(58) VFUNC##i(59) VFUNC##i(60) VFUNC##i(61) VFUNC##i(62) VFUNC##i(63) \
	VFUNC##i(64) VFUNC##i(65) VFUNC##i(66) VFUNC##i(67) VFUNC##i(68) VFUNC##i(69) VFUNC##i(70) VFUNC##i(71) \
	VFUNC##i(72) VFUNC##i(73) VFUNC##i(74) VFUNC##i(75) VFUNC##i(76) VFUNC##i(77) VFUNC##i(78) VFUNC##i(79) \
	VFUNC##i(80) VFUNC##i(81) VFUNC##i(82) VFUNC##i(83) VFUNC##i(84) VFUNC##i(85) VFUNC##i(86) VFUNC##i(87) \
	VFUNC##i(88) VFUNC##i(89) VFUNC##i(90) VFUNC##i(91) VFUNC##i(92) VFUNC##i(93) VFUNC##i(94) VFUNC##i(95) \
	VFUNC##i(96) VFUNC##i(97) VFUNC##i(98) VFUNC##i(99) VFUNC##i(100) VFUNC##i(101) VFUNC##i(102) VFUNC##i(103) \
	VFUNC##i(104) VFUNC##i(105) VFUNC##i(106) VFUNC##i(107) VFUNC##i(108) VFUNC##i(109) VFUNC##i(110) VFUNC##i(111) \
	VFUNC##i(112) VFUNC##i(113) VFUNC##i(114) VFUNC##i(115) VFUNC##i(116) VFUNC##i(117) VFUNC##i(118) VFUNC##i(119) \
	VFUNC##i(120) VFUNC##i(121) VFUNC##i(122) VFUNC##i(123) VFUNC##i(124) VFUNC##i(125) VFUNC##i(126) VFUNC##i(127)

// define a class with a set of identical virtual functions that take the same number of arguments.
// The game crashes if you redirect a virtual function call from the game to a function that takes
// a different size of arguments.
#define VTABLE_CLASS(vfunc_arg_bytes) struct VTable##vfunc_arg_bytes { VFUNCS(vfunc_arg_bytes) };

VTABLE_CLASS(0) VTABLE_CLASS(1) VTABLE_CLASS(2) VTABLE_CLASS(3)
VTABLE_CLASS(4) VTABLE_CLASS(5) VTABLE_CLASS(6) VTABLE_CLASS(7)
VTABLE_CLASS(8) VTABLE_CLASS(9) VTABLE_CLASS(10) VTABLE_CLASS(11)
VTABLE_CLASS(12) VTABLE_CLASS(13) VTABLE_CLASS(14) VTABLE_CLASS(15)
VTABLE_CLASS(16) VTABLE_CLASS(17) VTABLE_CLASS(18) VTABLE_CLASS(19)
VTABLE_CLASS(20) VTABLE_CLASS(21) VTABLE_CLASS(22) VTABLE_CLASS(23)
VTABLE_CLASS(24) VTABLE_CLASS(25) VTABLE_CLASS(26) VTABLE_CLASS(27)
VTABLE_CLASS(28) VTABLE_CLASS(29) VTABLE_CLASS(30) VTABLE_CLASS(31)
VTABLE_CLASS(32)

// maps function argument bytes to a compatible VTable replacement
void* g_replace_tables[] = {
	new VTable0(), new VTable1(), new VTable2(), new VTable3(),
	new VTable4(), new VTable5(), new VTable6(), new VTable7(),
	new VTable8(), new VTable9(), new VTable10(), new VTable11(),
	new VTable12(), new VTable13(), new VTable14(), new VTable15(),
	new VTable16(), new VTable17(), new VTable18(), new VTable19(),
	new VTable20(), new VTable21(), new VTable22(), new VTable23(),
	new VTable24(), new VTable25(), new VTable26(), new VTable27(),
	new VTable28(), new VTable29(), new VTable30(), new VTable31(),
	new VTable32()
};

void* g_replace_table = NULL;

edict_t* validate_test_ent(int entIdx) {
	if (entIdx < 0 || entIdx >= MAX_EDICTS) {
		println("Failed to init test for edict %d. Invalid index.");
		return NULL;
	}
	if (pvSizes[entIdx] <= 0) {
		println("Failed to init test for edict %d. Private data was not initialized or PvAllocEntPrivateData hook is not enabled", entIdx);
		return NULL;
	}

	edict_t* ent = INDEXENT(entIdx);

	if (!ent->pvPrivateData) {
		println("Failed to init test for edict %d. Private data is null", entIdx);
		return NULL;
	}

	return ent;
}

void field_offset_init() {
	CommandArgs args = CommandArgs();
	args.loadArgs();

	int entIdx = atoi(args.ArgV(1).c_str());
	edict_t* ent = validate_test_ent(entIdx);

	if (!ent) {
		return;
	}

	if (pvStates[entIdx]) {
		delete[] pvStates[entIdx];
	}

	pvStates[entIdx] = new byte[pvSizes[entIdx]];
	memcpy(pvStates[entIdx], ent->pvPrivateData, pvSizes[entIdx]);
}

void vtable_offset_init() {
	CommandArgs args = CommandArgs();
	args.loadArgs();

	int entIdx = atoi(args.ArgV(1).c_str());
	int argBytes = atoi(args.ArgV(2).c_str());
	edict_t* ent = validate_test_ent(entIdx);

	oldEntVtable = NULL;

	if (!ent) {
		return;
	}

	g_vtable_idx = -1;

	if (argBytes < 0 || argBytes > MAX_VFUNC_ARG_BYTES) {
		println("Failed to init test. Unsupported virtual function argument bytes: %s", argBytes);
		return;
	}

	// replace the class's vtable with our own
	oldEntVtable = *((void**)(ent->pvPrivateData));
	*((void**)(ent->pvPrivateData)) = *((void**)g_replace_tables[argBytes]);
}

void vtable_offset_test() {
	CommandArgs args = CommandArgs();
	args.loadArgs();

	int entIdx = atoi(args.ArgV(1).c_str());
	edict_t* ent = validate_test_ent(entIdx);

	if (!ent) {
		return;
	}

	// revert vtable replacement
	if (oldEntVtable)
		*((void**)(ent->pvPrivateData)) = oldEntVtable;

	g_engfuncs.pfnServerCommand(UTIL_VarArgs("as_command .vtable_offset_result %d\n", g_vtable_idx));
	g_engfuncs.pfnServerExecute();
}

void field_offset_test() {
	CommandArgs args = CommandArgs();
	args.loadArgs();

	int entIdx = atoi(args.ArgV(1).c_str());
	edict_t* ent = validate_test_ent(entIdx);

	if (!ent) {
		return;
	}

	int firstChangedByte = -1;
	int lastChangedByte = -1;
	
	byte* oldPv = pvStates[entIdx];
	byte* newPv = (byte*)ent->pvPrivateData;

	for (int i = 0; i < pvSizes[entIdx]; i++) {
		if (oldPv[i] != newPv[i]) {
			//println("CHANGED %d", i);
			if (firstChangedByte == -1) {
				firstChangedByte = lastChangedByte = i;
			}
			else if (i - lastChangedByte == 1) {
				lastChangedByte = i;
			}
			else {
				println("Failed to test edict %d. Multiple byte ranges were changed", entIdx);
				return;
			}
		}
	}

	if (firstChangedByte == -1) {
		println("Failed to test edict %d. No byte changes detected.", entIdx);
		return;
	}

	uint64_t value = 0;
	float fvalue = 0;
	float vec3_value[3] = {0};
	int changeSz = (lastChangedByte - firstChangedByte) + 1;

	if (changeSz == 1) {
		value = newPv[firstChangedByte];
	}
	else if (changeSz == 2) {
		value = *(uint16_t*)(newPv + firstChangedByte);
	}
	else if (changeSz == 4) {
		value = *(uint32_t*)(newPv + firstChangedByte);
		fvalue = *(float*)(newPv + firstChangedByte);
	}
	else if (changeSz == 8) {
		value = *(uint64_t*)(newPv + firstChangedByte);
	}
	else if (changeSz == 4*3) {
		float* vecStart = (float*)(newPv + firstChangedByte);
		vec3_value[0] = vecStart[0];
		vec3_value[1] = vecStart[1];
		vec3_value[2] = vecStart[2];
	}
	else if (changeSz > 4*3) {
		println("Failed to test edict %d. Unexpected number of bytes changed %d", entIdx, changeSz);
		return;
	}
	
	g_engfuncs.pfnServerCommand(UTIL_VarArgs("as_command .field_offset_result %llu %f %f_%f_%f %d %d\n", 
		value, fvalue, vec3_value[0], vec3_value[1], vec3_value[2], firstChangedByte, changeSz));
	g_engfuncs.pfnServerExecute();
}

void* PvAllocEntPrivateData(edict_t* ent, int32 cb) {
	pvSizes[ENTINDEX(ent)] = cb;
	//println("Alloc private ent %d (%d bytes)", ENTINDEX(ent), cb);
	RETURN_META_VALUE(MRES_IGNORED, NULL);
}

//#include "windows/private_api.h"

void test_pv() {
	
	for (int i = 1; i <= gpGlobals->maxClients; i++) {
		edict_t* ent = INDEXENT(i);

		if (!isValidPlayer(ent)) {
			continue;
		}
		/*
		CBaseEntity* world = (CBaseEntity*)GET_PRIVATE(INDEXENT(0));
		CBasePlayer* plr = (CBasePlayer*)GET_PRIVATE(ent);
		if (!plr || !world) {
			continue;
		}
		
		for (int i = gpGlobals->maxClients; i <= gpGlobals->maxEntities; i++) {
			edict_t* ent = INDEXENT(i);
			if (!ent || (ent->v.flags & FL_MONSTER) == 0) {
				continue;
			}
			CBaseEntity* mon = (CBaseEntity*)GET_PRIVATE(ent);
			println("IRelationship from %s: %d", STRING(ent->v.classname), mon->IRelationship(plr, true));
			println("FVisible from %s: %d", STRING(ent->v.classname), mon->FVisible(plr, false));
			println("IsFacing from %s: %d", STRING(ent->v.classname), mon->IsFacing(plr->pev, 0.5));
			println("GetPointsForDamage: %f", mon->GetPointsForDamage(10));
			mon->GetDamagePoints(plr->pev, plr->pev, 100);
			//mon->SetPlayerAlly(true);
			mon->OnCreate();
			mon->OnDestroy();
		}
		
		for (int i = gpGlobals->maxClients; i <= gpGlobals->maxEntities; i++) {
			edict_t* ent = INDEXENT(i);
			if (!ent || strcmp(STRING(ent->v.classname), "multisource")) {
				continue;
			}
			CBaseEntity* but = (CBaseEntity*)GET_PRIVATE(ent);
			println("IsTriggered from %s: %d", STRING(ent->v.targetname), (int)but->IsTriggered(plr));
			println("GetNextTarget from %s: %d", STRING(ent->v.targetname), (int)but->GetNextTarget());
		}
		*/
		/*
		for (int i = gpGlobals->maxClients; i <= gpGlobals->maxEntities; i++) {
			edict_t* ent = INDEXENT(i);
			if (!ent || strcmp(STRING(ent->v.classname), "func_button")) {
				continue;
			}
			CBaseEntity* but = (CBaseEntity*)GET_PRIVATE(ent);
			
			but->Use(but, but, USE_TOGGLE, 0);
		}
		*/
		/*
		for (int i = gpGlobals->maxClients; i <= gpGlobals->maxEntities; i++) {
			edict_t* ent = INDEXENT(i);
			if (!ent || strcmp(STRING(ent->v.classname), "func_water")) {
				continue;
			}
			CBaseEntity* but = (CBaseEntity*)GET_PRIVATE(ent);
			println("GetToggleState from %s: %d", STRING(ent->v.classname), (int)but->GetToggleState());
			println("GetDelay from %s: %d", STRING(ent->v.classname), (int)but->GetDelay());
			println("IsMoving from %s: %d", STRING(ent->v.classname), (int)but->IsMoving());
			println("DamageDecal from %s: %d", STRING(ent->v.classname), (int)but->DamageDecal(DMG_BULLET));
			println("IsLockedByMaster from %s: %d", STRING(ent->v.classname), (int)but->IsLockedByMaster());
			//but->SetToggleState(TS_AT_TOP);
		}

		Vector v = Vector(0, 0, 0);
		Vector v1 = Vector(1800, -700, 76);
		Vector v2 = plr->pev->origin;

		println("Classify: %d", plr->Classify());
		println("ObjectCaps: %d", plr->ObjectCaps());
		println("GetClassification: %d", plr->GetClassification(1));
		println("GetClassificationTag: %s", plr->GetClassificationTag());
		println("GetClassificationName: %s", plr->GetClassificationName());
		println("BloodColor: %d", plr->BloodColor());
		println("IsSneaking: %d", plr->IsSneaking());
		println("IsAlive: %d", plr->IsAlive());
		println("IsBSPModel: %d", plr->IsBSPModel());
		println("ReflectGauss: %d", plr->ReflectGauss());
		println("IsInWorld: %d", plr->IsInWorld());
		println("IsMonster: %d", plr->IsMonster());
		println("IsNetClient: %d", plr->IsNetClient());
		println("IsPlayer: %d", plr->IsPlayer());
		println("IsPointEnt: %d", plr->IsPointEnt());
		println("IsBreakable: %d", plr->IsBreakable());
		println("IsMachine: %d", plr->IsMachine());
		println("TeamID: %s", plr->TeamID());
		println("Center: %f %f %f", plr->Center().x, plr->Center().y, plr->Center().z);
		println("EyePosition: %f %f %f", plr->EyePosition().x, plr->EyePosition().y, plr->EyePosition().z);
		println("EarPosition: %f %f %f", plr->EarPosition().x, plr->EarPosition().y, plr->EarPosition().z);
		println("BodyTarget: %f %f %f", plr->BodyTarget(&v).x, plr->BodyTarget(&v).y, plr->BodyTarget(&v).z);
		println("FVisibleFromPos: %d", (int)plr->FVisibleFromPos(&v2, &v1));
		println("IsRevivable: %d", (int)plr->IsRevivable());
		
		plr->EndRevive(0);

		TraceResult tr;
		Vector end = plr->pev->origin;
		Vector start = start + Vector(64, 0, 0);
		TRACE_LINE(start, end, false, NULL, &tr);

		//plr->TraceAttack(plr->pev, 20, Vector(-1,0,0), &tr, DMG_BULLET);
		//plr->TraceBleed(100, Vector(-1,0,0), &tr, DMG_BULLET);
		//plr->TakeDamage(plr->pev, plr->pev, 10, DMG_FREEZE);
		//plr->TakeHealth(100000, DMG_ACID, 200);
		//plr->TakeArmor(100000, DMG_ACID, 200);
		//plr->Killed(plr->pev, GIB_ALWAYS);
		//plr->AddPoints(10, true);
		//plr->AddPointsToTeam(10, true);

		//CBasePlayerItem* wep = (CBasePlayerItem*)GET_PRIVATE(CREATE_NAMED_ENTITY(ALLOC_STRING("weapon_crowbar")));
		//if (wep) plr->AddPlayerItem(wep);

		//CBasePlayerItem* wep = (CBasePlayerItem*)plr->m_hActiveItem.GetEntity();
		//if (wep) plr->RemovePlayerItem(wep);
		
		//CBasePlayerItem* wep = (CBasePlayerItem*)plr->m_hActiveItem.GetEntity();
		//if (wep)
		//	println("GiveAmmo: %d", wep->GiveAmmo(6, "ammo_357", 36, true, 0));

		//plr->Respawn();

		println("plr is monster? %d", (int)(plr->MyMonsterPointer() == plr));
		println("world is monster? %d", (int)(world->MyMonsterPointer() == world));

		// TODO: This is probably what needs to be done with derived classes like CBaseMonster.
		// Replace a 2nd vtable somewhere else in the private data. This is what works
		// for classes that have multiple inheritance.
		//*((void**)(test)) = *((void**)g_replace_tables[0]);
		//*((void**)((byte*)test+sizeof(BaseTest) + 4)) = *((void**)g_replace_tables[0]);
		*/
		break;
	}

	RETURN_META(MRES_IGNORED);
}

void PluginInit() {
	g_engine_hooks.pfnPvAllocEntPrivateData = PvAllocEntPrivateData;
	//g_dll_hooks.pfnStartFrame = testPlayer;

	REG_SVR_COMMAND("field_offset_init", field_offset_init);
	REG_SVR_COMMAND("field_offset_test", field_offset_test);

	REG_SVR_COMMAND("vtable_offset_init", vtable_offset_init);
	REG_SVR_COMMAND("vtable_offset_test", vtable_offset_test);

	REG_SVR_COMMAND("test_pv", test_pv);

	memset(pvSizes, 0, sizeof(int32) * MAX_EDICTS);
	memset(pvStates, 0, sizeof(char*) * MAX_EDICTS);
}

void PluginExit() {}
