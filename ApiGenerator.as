// fixes choppy microphone audio caused by cutscenes and cameras
// by automatically executing the "stopsound" command for clients.
// This is done at the beginning and end of camera sequences.
#include "asgen/CBasePlayerPv"

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

int getFieldSize(int fieldType) {
	switch(fieldType) {
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

string getFieldString(int fieldType) {
	switch(fieldType) {
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

bool isFieldPointer(int fieldType) {
	switch(fieldType) {
		case FIELD_ENTVARS: return true;
		case FIELD_EHANDLE: return true;
		case FIELD_SCHED: return true;
	}
	
	return false;
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


void find_offset_timed(BasePv@ basePv, string fieldname, int fieldtype) {
	basePv.find_offset_timed(fieldname, fieldtype);
}

class BasePv {
	CBaseEntity@ baseEnt;
	int test_index;
	int errors = 0;
	float findDelay = 0;
	string className;

	array<PvData> test_results;
	
	BasePv() {}
	
	BasePv(CBaseEntity@ baseEnt) {
		className = "CBaseEntity";
		@this.baseEnt = @baseEnt;		
		test_index = this.baseEnt.entindex();
	}
	
	bool find_offset(string fieldname, int fieldtype) {
		findDelay += 0.1f;
		//g_Scheduler.SetTimeout("find_offset_timed", findDelay, @this, fieldname, fieldtype);
		find_offset_timed(fieldname, fieldtype);
		
		return true;
	}
	
	bool find_offset_timed(string fieldname, int fieldtype) {
		println("TEST " + fieldname);
		TestValue oldValue = getValue(fieldname);
		TestValue initValue = TestValue(false);
		TestValue testValue = TestValue(true);
	
		setValue(fieldname, initValue);

		g_pv_offset = -1;
		g_EngineFuncs.ServerCommand("private_api_init " + test_index + "\n");
		g_EngineFuncs.ServerExecute();
		
		setValue(fieldname, testValue);
		
		g_EngineFuncs.ServerCommand("private_api_test " + test_index + "\n");
		g_EngineFuncs.ServerExecute();
		
		setValue(fieldname, oldValue);
		
		if (g_pv_offset == -1) {
			errors++;
			return false;
		}
		
		int fieldsize = getFieldSize(fieldtype);
		bool isPointerType = isFieldPointer(fieldtype);
		
		if (g_pv_size != fieldsize && !isPointerType) {
			println("Bad test size: " + g_pv_size + " != " + fieldsize);
			errors++;
			return false;
		}
		
		if (fieldtype == FIELD_BYTE || fieldtype == FIELD_BOOL) {
			if (testValue.v8 != uint8(g_pv_result)) {
				println("Bad test result: " + testValue.v8 + " != " + uint8(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_SHORT) {
			if (testValue.v16 != uint16(g_pv_result)) {
				println("Bad test result: " + testValue.v16 + " != " + uint16(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_INT || fieldtype == FIELD_UINT) {
			if (testValue.v32 != uint32(g_pv_result)) {
				println("Bad test result: " + testValue.v32 + " != " + uint32(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_FLT) {
			if (testValue.vf != g_pv_result_f) {
				println("Bad test result: " + testValue.vf + " != " + g_pv_result_f);
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_INT64) {
			if (testValue.v64 != uint64(g_pv_result)) {
				println("Bad test result: " + testValue.v64 + " != " + uint64(g_pv_result));
				errors++;
				return false;
			}
		}
		else if (fieldtype == FIELD_VEC3) {
			if (testValue.vec3 != g_pv_result_vec3) {
				println("Bad test result: " + testValue.vec3.ToString() + " != " + g_pv_result_vec3.ToString());
				errors++;
				return false;
			}
		} else if (isPointerType) {
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
	
	void write_metamod_header() {
		if (test_results.size() == 0) {
			println("No results");
			return;
		}
		
		println("Failed to find " + errors + " fields");
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
		f.Write("// \"u[]\" variables are unknown data, probably inherited from other classes.\n\n");
		
		f.Write("#include \"EHandle.h\"\n\n");
		
		f.Write("class " + className + " {\n");
		f.Write("public:\n");
		
		int offset = 0;
		int paddingCount = 0;
		for (uint i = 0; i < test_results.size(); i++) {
			int gap = test_results[i].offset - offset;
			if (gap > 0) {
				f.Write("    " + "byte u" + paddingCount + "[" + gap + "];\n");
				paddingCount++;
			} else if (gap < 0) {
				println("ERROR: Field has a bad size: " + test_results[i-1].name + " " + gap);
			}
			f.Write("    " + getFieldString(test_results[i].fieldType) + " " + test_results[i].name + ";\n");
			offset = test_results[i].offset + getFieldSize(test_results[i].fieldType);
		}
		f.Write("};\n");
		f.Close();
	}
	
	void setValue(string f, TestValue v) {}
	
	TestValue getValue(string f) { return TestValue(false); }
	
	void generatePrivateApi() {
		errors = 0;
		test_results.resize(0);
		findDelay = 0;
		findOffsets();
		write_metamod_header();
	}
	
	void findOffsets() {}
}

void generateApis(CBasePlayer@ plr) {
	CBasePlayerPv(plr);
}

void apiTestLoop(EHandle h_plr) {
	CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
	
	if (plr is null) {
		return;
	}
	
	//if (!plr.m_hTargetEnt.IsValid()) {
	//	plr.m_hTargetEnt = EHandle(plr);
	//	println("Created ehandle");
	//}
	
	plr.m_vecFinalDest = Vector(123, 456, 789);
}

void apiTest( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	g_Scheduler.SetInterval("apiTestLoop", 0.1f, -1, EHandle(plr));
}

void consoleCmd( const CCommand@ args ) {
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	
	generateApis(plr);
}