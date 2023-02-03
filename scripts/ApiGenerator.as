#include "generated_props/includes"
#include "special_props/includes"
#include "PvFinder"

enum field_types {
	FIELD_BOOL,
	FIELD_BYTE,
	FIELD_SHORT,
	FIELD_INT,
	FIELD_UINT,
	FIELD_FLT,
	FIELD_ENTVARS,
	FIELD_EHANDLE,
	FIELD_INT64,
	FIELD_VEC3,
	FIELD_STR_T,
	FIELD_STR,
	FIELD_SCHED,
}

funcdef void pvPropSetter(CBaseEntity@ ent, TestValue);
funcdef TestValue pvPropGetter(CBaseEntity@ ent);

// the result for a single class property
class PvData {
	PvProp@ prop;
	int offset = -1;
	int arrayIdx = 0;
	
	PvData() {}
	
	PvData(PvProp@ prop, int offset, int arrayIdx) {
		@this.prop = @prop;
		this.offset = offset;
		this.arrayIdx = arrayIdx;
	}
}

// the final result of a reveresed class, containing all properties ordered by offset
class ReversedData {
	string cname;
	array<PvData> results;
	int childFields; // fields that are not duplicated in the base class
	
	ReversedData() {}
	
	ReversedData(string cname, array<PvData> results, int childFields) {
		this.cname = cname;
		this.results = results;
		this.childFields = childFields;
	}
	
	int getClassSize() {
		PvData@ lastResult = results[results.size()-1];
		return lastResult.offset + lastResult.prop.getSize();
	}
}

// like a union, for when the function caller doesn't know the needed data type
class TestValue {
	uint8 v8;
	uint16 v16;
	uint32 v32;
	uint64 v64;
	float vf;
	Vector vec3;
	string_t str_t;
	string str;
	entvars_t@ pev;
	EHandle ehandle;
	Schedule@ sched;
	
	TestValue() {}
	
	TestValue(int8 v) { v8 = v; }
	TestValue(uint8 v) { v8 = v; }
	TestValue(int16 v) { v16 = v; }
	TestValue(uint16 v) { v16 = v; }
	TestValue(int v) { v32 = v; }
	TestValue(uint v) { v32 = v; }
	TestValue(int64 v) { v64 = v; }
	TestValue(uint64 v) { v64 = v; }
	TestValue(float v) { vf = v; }
	TestValue(Vector v) { vec3 = v; }
	TestValue(string_t v) { str_t = v; }
	TestValue(string v) { str = v; }
	TestValue(entvars_t@ v) { @pev = @v; }
	TestValue(EHandle v) { ehandle = v; }
	TestValue(Schedule@ v) { @sched = @v; }
	
	TestValue(bool setNotEmpty) {
		if (setNotEmpty) {
			v8 = 0x01;
			v16 = 0x1234;
			v32 = 0x12345678;
			v64 = 0x12345678ABCDEF01;
			vf = 1234.567f;
			vec3 = Vector(1234.567f, 2235.567f, 3234.567f);
			str_t = "1234567890";
			str = "1234567890";
			@pev = @g_EntityFuncs.Instance(0).pev;
			ehandle = EHandle(g_EntityFuncs.Instance(0));
			@sched = cast<CBasePlayer@>(g_EntityFuncs.Instance(1)).GetSchedule();
		} // else 0s
	}
}

// info needed to find a single class property
class PvProp {
	string name;
	int fieldtype;
	int arraySize = 1;
	string desc;
	pvPropSetter@ setter;
	pvPropGetter@ getter;
	
	PvProp() {}
	
	PvProp( string name, int fieldtype, string desc, pvPropGetter@ getter, pvPropSetter@ setter) {
		this.fieldtype = fieldtype;
		this.name = name;
		this.desc = desc;
		@this.setter = @setter;
		@this.getter = @getter;
		
		if (int(name.Find("[")) != -1) {
			string sz = name.SubString(name.Find("[")+1);
			sz = sz.SubString(0, name.Find("]")-1);
			arraySize = atoi(sz);
		}
	}
	
	int getSize() {
		return getTypeSize() * arraySize;
	}
	
	int getTypeSize() {
		switch(fieldtype) {
			case FIELD_BOOL: return 1;
			case FIELD_BYTE: return 1;
			case FIELD_SHORT: return 2;
			case FIELD_INT: return 4;
			case FIELD_UINT: return 4;
			case FIELD_FLT: return 4;
			case FIELD_ENTVARS: return 4;
			case FIELD_EHANDLE: return 8;
			case FIELD_INT64: return 8;
			case FIELD_VEC3: return 4*3;
			case FIELD_STR_T: return 4;
			case FIELD_STR: return 4;
			case FIELD_SCHED: return 4;
		}
		
		return 0;
	}

	// for writing the header file
	string ctype() {
		switch(fieldtype) {
			case FIELD_BOOL: return "bool";
			case FIELD_BYTE: return "byte";
			case FIELD_SHORT: return "short";
			case FIELD_INT: return "int";
			case FIELD_UINT: return "unsigned int";
			case FIELD_FLT: return "float";
			case FIELD_ENTVARS: return "entvars_t*";
			case FIELD_EHANDLE: return "EHandle";
			case FIELD_INT64: return "uint64_t";
			case FIELD_VEC3: return "vec3_t";
			case FIELD_STR_T: return "string_t";
			case FIELD_STR: return "string_t";
			case FIELD_SCHED: return "void*";
		}
		
		return 0;
	}

	// angelscript can't size/value validate these
	bool isPointer() {
		switch(fieldtype) {
			case FIELD_ENTVARS: return true;
			case FIELD_EHANDLE: return true;
			case FIELD_SCHED: return true;
		}
		
		return arraySize > 1;
	}
}

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

CClientCommand _apigen("apigen", "Generate metamod API", @apiGen );
CClientCommand _apitest("apitest", "Generate metamod API", @apiTest );

CConCommand@ apiResultCmd = @CConCommand( "private_api_result", "metamod response to a private api test", @private_api_result );

// scan results from the metamod plugin
int g_pv_offset = -1; // where data was changed
int g_pv_size = -1; // size of data changed
uint64 g_pv_result = 0; // value found, as an integer
float g_pv_result_f = 0; // value found, as a float
Vector g_pv_result_vec3 = Vector(0,0,0); // value(s) found, as a vector

int g_arr_idx = 0; // array index to test
int g_classid = 0; // make sure unknown data has unique names when inheriting

array<ReversedData> g_reversed_data; // used to exclude classes that are duplicates for CBaseEntity

void PluginInit() {
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "github" );
}

void MapInit() {
	g_Game.PrecacheOther("func_door");
	g_Game.PrecacheOther("item_inventory");
}

// metamod calls this after scanning private entity data for changes
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

void failsafe_ent_remove(EHandle h_ent) {
	g_EntityFuncs.Remove(h_ent);
}

void generateApis(CBasePlayer@ plr) {
	g_reversed_data.resize(0);

	// order is important here, it takes some guess work to figure out the hierarchy.
	// if classes have duplicate fields between them then this probably needs updating.
	// TODO: just do this in 2 passes. first one finds the field offsets, 2nd writes the
	//       headers with all classes searchable as parents.
	PvFinder(plr, "CBaseEntity", CBaseEntityPv, null);
		PvFinder("trigger_relay", "CBaseDelay", CBaseDelayPv, null);
			PvFinder(plr, "CBaseAnimating", CBaseAnimatingPv, null);
				PvFinder("func_door", "CBaseToggle", CBaseTogglePv, null);
					PvFinder("func_button", "CBaseButton", CBaseButtonPv, null);
					PvFinder("func_door", "CBaseDoor", CBaseDoorPv, null);
					PvFinder(plr, "CBaseMonster", CBaseMonsterPv, null);
						PvFinder(plr, "CBasePlayer", CBasePlayerPv, CBasePlayerPv_Special);
						PvFinder("scripted_sequence", "CCineMonster", CCineMonsterPv, null);
						PvFinder("grenade", "CGrenade", CGrenadePv, null);
						
				PvFinder("weapon_crowbar", "CBasePlayerItem", CBasePlayerItemPv, null);
					PvFinder("weapon_crowbar", "CBasePlayerWeapon", CBasePlayerWeaponPv, null);
					PvFinder("ammo_357", "CBasePlayerAmmo", CBasePlayerAmmoPv, null);
			
		PvFinder("func_tank", "CBaseTank", CBaseTankPv, null);
		PvFinder("item_inventory", "CItemInventory", CItemInventoryPv, null);
		PvFinder("item_battery", "CItem", CItemPv, null);
		PvFinder("path_track", "CPathTrack", CPathTrackPv, null);
		PvFinder("env_beam", "CBeam", CBeamPv, null);
		PvFinder("env_laser", "CLaser", CLaserPv, null);
	
	string outputFile = "scripts/plugins/store/ApiGenerator/private_api.h";
	File@ f = g_FileSystem.OpenFile( outputFile, OpenFile::WRITE);
	
	if( f is null || !f.IsOpen() ) {
		println("Failed to open file for writing: " + outputFile);
		println("Create the 'ApiGenerator' folder if it doesn't exist.");
		return;
	}
	
	f.Write("// This code was automatically generated by the ApiGenerator plugin.\n\n");
	
	f.Write("#include \"EHandle.h\"\n");
	for (uint i = 0; i < g_reversed_data.size(); i++) {
		f.Write("#include \"" + g_reversed_data[i].cname + ".h\"\n");
	}
	
	f.Close();
	
	println("\nFinished writing private APIs for " + g_reversed_data.size() + " classes.");
}

void apiTestLoop(EHandle h_plr) {
	CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
	
	if (plr is null) {
		return;
	}
	
	//CItemInventory@ testEnt = cast<CItemInventory@>(g_EntityFuncs.CreateEntity("item_inventory", null, true));
	//testEnt.m_szDisplayName = "test";
	//g_EntityFuncs.Remove(testEnt);
}

void apiTest( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	g_Scheduler.SetInterval("apiTestLoop", 0.1f, -1, EHandle(plr));
}

void apiGen( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	generateApis(plr);
}