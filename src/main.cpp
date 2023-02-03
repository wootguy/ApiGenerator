#include "meta_init.h"
#include "misc_utils.h"
#include "meta_utils.h"
#include "main.h"
#include "private_api.h"

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

void private_api_init() {
	CommandArgs args = CommandArgs();
	args.loadArgs();

	int entIdx = atoi(args.ArgV(1).c_str());

	if (entIdx < 0 || entIdx >= MAX_EDICTS) {
		println("Failed to init test for edict %d. Invalid index.");
		return;
	}
	if (pvSizes[entIdx] <= 0) {
		println("Failed to init test for edict %d. Private data was not initialized or PvAllocEntPrivateData hook is not enabled", entIdx);
		return;
	}

	edict_t* ent = INDEXENT(entIdx);

	if (!ent->pvPrivateData) {
		println("Failed to init test for edict %d. Private data is null", entIdx);
		return;
	}

	if (pvStates[entIdx]) {
		delete[] pvStates[entIdx];
	}

	pvStates[entIdx] = new byte[pvSizes[entIdx]];
	memcpy(pvStates[entIdx], ent->pvPrivateData, pvSizes[entIdx]);
}

void private_api_test() {
	CommandArgs args = CommandArgs();
	args.loadArgs();

	int entIdx = atoi(args.ArgV(1).c_str());

	if (entIdx < 0 || entIdx >= MAX_EDICTS) {
		println("Failed to test edict %d. Invalid index.");
		return;
	}
	if (pvSizes[entIdx] <= 0 || !pvStates[entIdx]) {
		println("Failed to test edict %d. State not initialized.");
		return;
	}

	edict_t* ent = INDEXENT(entIdx);

	if (!ent->pvPrivateData) {
		println("Failed to test edict %d. Private data is null", entIdx);
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
	else {
		println("Failed to test edict %d. Unexpected number of bytes changed %d", entIdx, changeSz);
		return;
	}
	
	g_engfuncs.pfnServerCommand(UTIL_VarArgs("as_command .private_api_result %llu %f %f_%f_%f %d %d\n", 
		value, fvalue, vec3_value[0], vec3_value[1], vec3_value[2], firstChangedByte, changeSz));
	g_engfuncs.pfnServerExecute();
}

void* PvAllocEntPrivateData(edict_t* ent, int32 cb) {
	pvSizes[ENTINDEX(ent)] = cb;
	//println("Alloc private ent %d (%d bytes)", ENTINDEX(ent), cb);
	RETURN_META_VALUE(MRES_IGNORED, NULL);
}

int lastVal = 0;

void testPlayer() {
	for (int i = 1; i <= gpGlobals->maxClients; i++) {
		edict_t* ent = INDEXENT(i);

		if (!isValidPlayer(ent)) {
			continue;
		}

		CBasePlayer* plr = (CBasePlayer*)ent->pvPrivateData;
		//CBaseAnimating* anim = (CBaseAnimating*)ent->pvPrivateData;
		//EHandle test = EHandle(plr);
		//CBasePlayer* testent = (CBasePlayer*)test.GetEntity();

		//println("BOKEAY %d", testent->m_iFOV);
	}
}

void PluginInit() {
	g_engine_hooks.pfnPvAllocEntPrivateData = PvAllocEntPrivateData;
	g_dll_hooks.pfnStartFrame = testPlayer;

	REG_SVR_COMMAND("private_api_init", private_api_init);
	REG_SVR_COMMAND("private_api_test", private_api_test);

	memset(pvSizes, 0, sizeof(int32) * MAX_EDICTS);
	memset(pvStates, 0, sizeof(char*) * MAX_EDICTS);
}

void PluginExit() {}