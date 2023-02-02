// fixes choppy microphone audio caused by cutscenes and cameras
// by automatically executing the "stopsound" command for clients.
// This is done at the beginning and end of camera sequences.
#include "generated_props/includes"
#include "special_props/includes"

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

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

CClientCommand _apigen("apigen", "Generate metamod API", @consoleCmd );
CClientCommand _apitest("apitest", "Generate metamod API", @apiTest );

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

int g_arr_idx = 0; // array index to test

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
	FIELD_UINT,
	FIELD_FLT,
	FIELD_ENTVARS,
	FIELD_EHANDLE,
	FIELD_INT64,
	FIELD_VEC3,
	FIELD_STR,
	FIELD_SCHED,
}

class TestValue {
	uint8 v8;
	uint16 v16;
	uint32 v32;
	uint64 v64;
	float vf;
	Vector vec3;
	string_t str;
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
	TestValue(string_t v) { str = v; }
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
			str = "1234567890";
			@pev = @g_EntityFuncs.Instance(0).pev;
			ehandle = EHandle(g_EntityFuncs.Instance(0));
			@sched = cast<CBasePlayer@>(g_EntityFuncs.Instance(1)).GetSchedule();
		} // else 0s
	}
}

funcdef void pvPropSetter(CBaseEntity@ ent, TestValue);
funcdef TestValue pvPropGetter(CBaseEntity@ ent);

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
			case FIELD_STR: return 4;
			case FIELD_SCHED: return 4;
		}
		
		return 0;
	}

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
			case FIELD_STR: return "string_t";
			case FIELD_SCHED: return "void*";
		}
		
		return 0;
	}

	bool isPointer() {
		switch(fieldtype) {
			case FIELD_ENTVARS: return true;
			case FIELD_EHANDLE: return true;
			case FIELD_SCHED: return true;
		}
		
		return arraySize > 1;
	}
}

class BasePv {
	CBaseEntity@ ent;
	int test_index;
	int errors = 0;
	float findDelay = 0;
	string className;

	array<PvProp> props;
	array<PvData> test_results;
	
	BasePv() {}
	
	BasePv(CBaseEntity@ ent, string className, array<PvProp>@ props, array<PvProp>@ props_special) {
		this.className = className;
		
		println("\nGenerating API for " + className);
		
		@this.ent = @ent;		
		this.props = props;
		
		if (props_special !is null) {
			for (uint i = 0; i < props_special.size(); i++) {
				this.props.insertLast(props_special[i]);
			}
		}
		
		test_index = this.ent.entindex();
		generatePrivateApi();
	}
	
	bool find_offset(PvProp@ prop) {
		//println("TEST " + prop.name);
		
		g_arr_idx = 0;
		for (int k = 0; k < prop.arraySize; k++) {
			g_arr_idx = k;
		
			TestValue oldValue = prop.getter(ent);
			TestValue initValue = TestValue(false);
			TestValue testValue = TestValue(true);
		
			prop.setter(ent, initValue);

			g_pv_offset = -1;
			g_EngineFuncs.ServerCommand("private_api_init " + test_index + "\n");
			g_EngineFuncs.ServerExecute();
			
			prop.setter(ent, testValue);
			
			g_EngineFuncs.ServerCommand("private_api_test " + test_index + "\n");
			g_EngineFuncs.ServerExecute();
			
			prop.setter(ent, oldValue);
			
			if (g_pv_offset == -1) {
				return false;
			}
			
			int fieldsize = prop.getSize();
			bool isPointerType = prop.isPointer();
			
			if (g_pv_size != fieldsize && !isPointerType) {
				println("Bad test size: " + g_pv_size + " != " + fieldsize);
				return false;
			}
			
			if (prop.fieldtype == FIELD_BYTE || prop.fieldtype == FIELD_BOOL) {
				if (testValue.v8 != uint8(g_pv_result)) {
					println("Bad test result: " + testValue.v8 + " != " + uint8(g_pv_result));
					return false;
				}
			}
			else if (prop.fieldtype == FIELD_SHORT) {
				if (testValue.v16 != uint16(g_pv_result)) {
					println("Bad test result: " + testValue.v16 + " != " + uint16(g_pv_result));
					return false;
				}
			}
			else if (prop.fieldtype == FIELD_INT || prop.fieldtype == FIELD_UINT) {
				if (testValue.v32 != uint32(g_pv_result)) {
					println("Bad test result: " + testValue.v32 + " != " + uint32(g_pv_result));
					return false;
				}
			}
			else if (prop.fieldtype == FIELD_FLT) {
				if (testValue.vf != g_pv_result_f) {
					println("Bad test result: " + testValue.vf + " != " + g_pv_result_f);
					return false;
				}
			}
			else if (prop.fieldtype == FIELD_INT64) {
				if (testValue.v64 != uint64(g_pv_result)) {
					println("Bad test result: " + testValue.v64 + " != " + uint64(g_pv_result));
					return false;
				}
			}
			else if (prop.fieldtype == FIELD_VEC3) {
				if (testValue.vec3 != g_pv_result_vec3) {
					println("Bad test result: " + testValue.vec3.ToString() + " != " + g_pv_result_vec3.ToString());
					return false;
				}
			} else if (isPointerType) {
				// can't test value exactly
			}
			
			for (uint i = 0; i < test_results.size(); i++) {
				if (prop.name == test_results[i].prop.name && g_arr_idx < 1) {
					println("Tested duplicate field: " + prop.name);
					return false;
				}
				if (g_pv_offset == test_results[i].offset) {
					println("Fields share offsets: " + prop.name + ", " + test_results[i].prop.name);
					return true; // not an error really, just a confusing API
				}
			}
			
			test_results.insertLast(PvData(prop, g_pv_offset, g_arr_idx));
		
		}
		
		return true;
	}
	
	void write_metamod_header() {
		if (test_results.size() == 0) {
			println("No results");
			return;
		}
		
		test_results.sort(function(a,b) { return a.offset < b.offset; });
		
		string outputFile = "scripts/plugins/store/ApiGenerator/" + className + ".h";
		File@ f = g_FileSystem.OpenFile( outputFile, OpenFile::WRITE);
		
		if( f is null || !f.IsOpen() ) {
			println("Failed to open file for writing: " + outputFile);
			println("Create the 'ApiGenerator' folder if it doesn't exist.");
			return;
		}
		
		println("Writing " + outputFile);
		f.Write("// This code was automatically generated by the ApiGenerator plugin.\n");
		f.Write("// Prefer updating the generator code instead of editing this directly.\n");
		f.Write("// \"u[]\" variables are unknown data.\n\n");
		
		f.Write("#include \"EHandle.h\"\n\n");
		
		f.Write("// pev.classname = " + ent.pev.classname + "\n");
		f.Write("class " + className + " {\n");
		f.Write("public:\n");
		
		int offset = 0;
		int paddingCount = 0;
		for (uint i = 0; i < test_results.size(); i++) {
			PvProp@ prop = @test_results[i].prop;
			
			if (test_results[i].arrayIdx != 0) {
				continue; // only write the first array field that was tested
			}
			
			int gap = test_results[i].offset - offset;
			if (gap > 0) {
				f.Write("    " + "byte u" + paddingCount + "[" + gap + "];\n");
				paddingCount++;
			} else if (gap < 0) {
				println("ERROR: Field has a bad size: " + test_results[i-1].prop.name + " " + gap);
			}
			string comment = prop.desc;
			if (comment.Length() > 0) {
				comment = " // " + comment;
			}
			
			f.Write("    " + prop.ctype() + " " + prop.name + ";" + comment + "\n");
			offset = test_results[i].offset + prop.getSize();
		}
		f.Write("};\n");
		f.Close();
	}
	
	void generatePrivateApi() {
		errors = 0;
		test_results.resize(0);
		findDelay = 0;
		
		for (uint i = 0; i < props.size(); i++) {
			if (!find_offset(props[i])) {
				println("Failed to find property: " + props[i].name);
				errors++;
			}
		}
		
		println("Found " + test_results.size() + " properties");
		
		if (errors > 0)
			println("Failed to find " + errors + " properties");
		
		write_metamod_header();
	}
}

void generateApis(CBasePlayer@ plr) {
	BasePv(plr, "CBaseEntity", CBaseEntityPv, null);
	BasePv(plr, "CBaseDelay", CBaseDelayPv, null);
	BasePv(plr, "CBasePlayer", CBasePlayerPv, CBasePlayerPv_Special);
}

void apiTestLoop(EHandle h_plr) {
	CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
	
	if (plr is null) {
		return;
	}
}

void apiTest( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	g_Scheduler.SetInterval("apiTestLoop", 0.1f, -1, EHandle(plr));
}

void consoleCmd( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	generateApis(plr);
}