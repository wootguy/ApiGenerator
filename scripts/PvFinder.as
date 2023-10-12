class PvFinder {
	CBaseEntity@ ent;
	int test_index;
	int errors = 0;
	float findDelay = 0;
	string className;
	
	string vtableFile;

	array<PvProp> props;
	array<PvFunc> funcs;
	array<PvData> test_results;
	
	bool foundVtable = false;
	
	PvFinder() {}
	
	PvFinder(CBaseEntity@ ent, string className, array<PvProp>@ props, array<PvProp>@ props_special, array<PvFunc>@ funcs) {
		init(ent, className, props, props_special, funcs);
	}
	
	PvFinder(string test_ent_classname, string className, array<PvProp>@ props, array<PvProp>@ props_special, array<PvFunc>@ funcs) {
		CBaseEntity@ testEnt = g_EntityFuncs.CreateEntity(test_ent_classname, null, true);
		g_Scheduler.SetTimeout("failsafe_ent_remove", 0.0f, EHandle(testEnt));
		
		if (testEnt !is null) {
			init(testEnt, className, props, props_special, funcs);
		} else {
			println("Failed to create test entity for class " + className);
		}
		
		g_EntityFuncs.Remove(testEnt);
	}
	
	void init(CBaseEntity@ ent, string className, array<PvProp>@ props, array<PvProp>@ props_special, array<PvFunc>@ funcs) {
		println("\nGenerating API for " + className);
		
		@this.ent = @ent;
		test_index = this.ent.entindex();
		this.className = className;
		this.props = props;
		this.funcs = funcs;
		vtableFile = "scripts/plugins/store/ApiGenerator/_" + className + "_vtable.txt";
		
		if (props_special !is null) {
			for (uint i = 0; i < props_special.size(); i++) {
				this.props.insertLast(props_special[i]);
			}
		}
		
		generatePrivateApi();
	}
	
	// finding virtual functions causes crashes when the size of the function arguments is guessed incorrectly.
	// so, save which argument sizes were tried and continue where we left off when the game restarts
	void save_vtable_find_state(string currentFuncBeingTested, int nextGuessArgSize) {
		File@ f = g_FileSystem.OpenFile( vtableFile, OpenFile::WRITE);
		
		if (f is null || !f.IsOpen()) {
			println("Failed to open file for writing: " + vtableFile);
			println("Create the 'ApiGenerator' folder if it doesn't exist.");
			return;
		}
		
		for (uint i = 0; i < funcs.size(); i++) {
			if (funcs[i].offset != -1) {
				f.Write(funcs[i].name + "=" + funcs[i].offset + "=" + funcs[i].total_arg_bytes + "\n");
			}
		}
		
		if (nextGuessArgSize != -1)
			f.Write(currentFuncBeingTested + "?" + nextGuessArgSize + "\n");
			
		f.Close();
	}
	
	// returns next arg size to attempt for next unknown function
	int load_vtable_find_state() {
		string fpath = "scripts/plugins/store/ApiGenerator/_" + className + "_vtable.txt";
		File@ f = g_FileSystem.OpenFile( vtableFile, OpenFile::READ);
		
		if (f is null || !f.IsOpen()) {
			return -1;
		}
		
		int nextGuessIdx = -1;
		
		while(!f.EOFReached())
		{
			string line;
			f.ReadLine(line);

			line.Trim();
			if (line.Length() == 0)
			continue;

			if (int(line.Find("=")) != -1) {
				array<string> parts = line.Split("=");
				string funcName = parts[0];
				int idx = atoi(parts[1]);
				int argBytes = atoi(parts[2]);
				
				for (uint i = 0; i < funcs.size(); i++) {
					if (funcs[i].name == funcName) {
						funcs[i].total_arg_bytes = argBytes;
						set_vtable_offset(i, idx);
					}
				}
				
			} else if (int(line.Find("?")) != -1) {
				array<string> parts = line.Split("?");
				string funcName = parts[0];
				nextGuessIdx = atoi(parts[1]);
			}
			
		}

		f.Close();
		
		return nextGuessIdx;
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
			g_EngineFuncs.ServerCommand("field_offset_init " + test_index + "\n");
			g_EngineFuncs.ServerExecute();
			
			prop.setter(ent, testValue);
			
			g_EngineFuncs.ServerCommand("field_offset_test " + test_index + "\n");
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
	
	void set_vtable_offset(int funcIdx, int offset) {
		if (offset == -1) {
			println("Failed to find virtual function offset: " + funcs[funcIdx].name);
			funcs[funcIdx].offset = -2; // indicate that the call succeeded but no offset was found
			return;
		}
		
		//println(funcs[funcIdx].name + " = " + offset + " (" + funcs[funcIdx].total_arg_bytes + " byte args)");
		funcs[funcIdx].offset = offset;
		foundVtable = true;
	}
	
	void test_virtual_method(PvFunc@ func) {
		g_EngineFuncs.ServerCommand("vtable_offset_init " + test_index + " " + func.total_arg_bytes + "\n");
		g_EngineFuncs.ServerExecute();
		
		func.testFunc(ent);
		
		g_EngineFuncs.ServerCommand("vtable_offset_test " + test_index + "\n");
		g_EngineFuncs.ServerExecute();
	}
	
	bool find_virtual_methods() {
		// clear; as_reloadplugin apigenerator; .apigen
		
		int nextGuessSz = load_vtable_find_state();
		
		if (nextGuessSz != -1) {
			println("Loaded vtable find state. Next guess is " + nextGuessSz);
		}
		
		bool bruteForcing = false;
		
		for (uint i = 0; i < funcs.size(); i++) {
			PvFunc@ func = funcs[i];

			if (func.offset != -1) {
				continue;
			}
			
			int nextGuess = nextGuessSz != -1 ? (nextGuessSz+1) : 0;
			save_vtable_find_state(func.name, nextGuess);
			if (nextGuessSz != -1) {
				println("Using guess arg size instead of original estimate");
				func.total_arg_bytes = nextGuessSz;
				nextGuessSz = -1;
			}
			
			println("Testing virtual func: " + func.name + " with arg size " + func.total_arg_bytes);
			
			if (func.total_arg_bytes >= 32) {
				set_vtable_offset(i, -2); // fail
				continue;
			}
			
			test_virtual_method(func);
			
			if (g_vtable_offset == -1) {
				if (!bruteForcing) {
					bruteForcing = true;
					func.total_arg_bytes = 0;
				} else {
					func.total_arg_bytes += 1;
				}
				
				i--;
				continue;
			}
			
			set_vtable_offset(i, g_vtable_offset);
			
			if (func.total_arg_bytes != func.expectedArgSize()) {
				// save this state, but try the expected arg size in case multiple work
				save_vtable_find_state("", -1);
				
				func.total_arg_bytes = func.expectedArgSize();
				test_virtual_method(func);
				
				if (g_vtable_offset != -1) {
					set_vtable_offset(i, g_vtable_offset);
				}
			}
			
			bruteForcing = false;
		}
		
		save_vtable_find_state("", -1); // finished finding all funcs
		
		return true;
	}
	
	// No need to write classes that add no extra fields. Just use the base class.
	bool is_duplicate_of_previously_reversed_class() {
		for (uint k = 0; k < g_reversed_data.size(); k++) {
			if (test_results.size() != g_reversed_data[k].results.size()) {
				continue;
			}
			
			bool isDuplicate = true;
			bool isChildClass = true;
			
			for (uint i = 0; i < test_results.size(); i++) {
				PvData@ a = test_results[i];
				PvData@ b = g_reversed_data[k].results[i];
				
				if (a.prop.fieldtype != b.prop.fieldtype || a.offset != b.offset || a.prop.name != b.prop.name) {
					isDuplicate = false;
					break;
				}
			}
			
			if (isDuplicate) {
				println("This class is a duplicate of " + g_reversed_data[k].cname + ". A header will not be written.");
				return true;
			}
		}
		
		return false;
	}
	
	// TODO: this only searches classes that have already been reversed
	//       but it should search all classes.
	void find_parent_class(int&out bestParent, int&out bestParentSize) {
		bestParent = -1;
		bestParentSize = 0;
		for (uint k = 0; k < g_reversed_data.size(); k++) {			
			// check that everything in this potential parent class exists in the current clas.
			// Or at least that the child class does not define any data at the same position where
			// the parent class has defined a variable (for example, it's ok for CBaseMonster to
			// have m_lastDamageAmount defined at an offset where CBasePlayer has undefined data).
			//
			// Techinically that can be unsafe, but as of SC 5.25 I think CBasePlayer docs are just
			// missing some fields that are supposed to be copied from CBaseMonster.
			
			bool isSuitableParentClass = true;
			int totalSharedUniqueFields = 0;
			
			for (uint i = 0; i < g_reversed_data[k].results.size(); i++) {
				PvData@ parent = g_reversed_data[k].results[i];
				
				// is this field unique to the parent class (not inherited from a grandparent class)?
				bool isUniqueParentField = i >= g_reversed_data[k].results.size() - uint(g_reversed_data[k].childFields);
				
				PvData@ lastResult = test_results[test_results.size()-1];
				int childClassSize = lastResult.offset + lastResult.prop.getSize();
				if (parent.offset > childClassSize) {
					continue;
				}
				
				bool isLegalParentField = false;
				bool childOverlapsParentField = false;
				for (uint j = 0; j < test_results.size(); j++) {
					PvData@ child = test_results[j];
					
					if (parent.prop.fieldtype == child.prop.fieldtype && parent.offset == child.offset && parent.prop.name == child.prop.name) {
						isLegalParentField = true;
						if (isUniqueParentField)
							totalSharedUniqueFields++;
						break;
					}
					
					if (child.offset < parent.offset && child.offset + child.prop.getSize() > parent.offset) {
						childOverlapsParentField = true;
					}
					if (child.offset > parent.offset && child.offset < parent.offset + parent.prop.getSize()) {
						childOverlapsParentField = true;
					}
				}
				if (!isLegalParentField && !childOverlapsParentField) {
					// only the parent class defines this field in the angelscript docs, but the child class
					// does not define any data here so it's probably safe.
					isLegalParentField = true;
				}
				
				if (!isLegalParentField) {
					isSuitableParentClass = false;
					break;
				}
			}
			
			if (isSuitableParentClass && totalSharedUniqueFields == 0) {
				isSuitableParentClass = false;
			}
			
			if (isSuitableParentClass && g_reversed_data[k].getClassSize() > bestParentSize) {
				bestParentSize = g_reversed_data[k].getClassSize();
				bestParent = k;
			}
		}
	}
	
	int write_properties(File@ f, int startOffset) {
		int paddingCount = 0;
		int offset = 0;
		int childFields = 0;
		
		for (uint i = 0; i < test_results.size(); i++) {		
			PvProp@ prop = @test_results[i].prop;
			
			if (test_results[i].offset < startOffset) {
				offset = test_results[i].offset + prop.getSize();
				continue;
			}
			
			if (test_results[i].arrayIdx != 0) {
				continue; // only write the first array field that was tested
			}
			
			childFields++;
			
			int gap = test_results[i].offset - offset;
			
			if (i == 0 and foundVtable) {
				int oldGap = gap;
				gap -= 4;
				//println("Skip first unknown bytes due to vtable (" + oldGap + " -> " + gap + " bytes)");
			}
			
			if (gap > 0) {			
				f.Write("    " + "byte u" + g_classid + "_" + paddingCount + "[" + gap + "];\n");
				paddingCount++;
			} else if (gap < 0) {
				println("ERROR: Field has a bad size: " + test_results[i-1].prop.name + " " + gap);
			}
			string comment = prop.desc; //+ " (offset " + test_results[i].offset + ")"; 
			if (comment.Length() > 0) {
				comment = " // " + comment;
			}
			
			f.Write("    " + prop.ctype() + " " + prop.name + ";" + comment + "\n");
			offset = test_results[i].offset + prop.getSize();
		}
		
		return childFields;
	}

	int write_virtual_functions(File@ f) {
		if (funcs.size() == 0) {
			return 0;
		}
	
		funcs.sort(function(a,b) { return a.offset < b.offset; });
		int lastOffset = -1;
		int unknownFuncIdx = 0;
		int actualOffset = 0;
		int writtenFuncs = 0;
		
		// choose best function when multiple share an offset
		// the correct one is unknown, but whichever has the most accurate argument list is probably the right one
		for (uint i = 0; i < funcs.size(); i++) {
			if (funcs[i].offset < 0 || funcs[i].skipWrite) {
				continue;
			}
			
			array<int> ambigList;
			ambigList.insertLast(i);
			string ambigWith = funcs[i].name;
			
			for (uint k = 0; k < funcs.size(); k++) {
				if (i == k || funcs[k].skipWrite) {
					continue;
				}
				
				if (funcs[k].offset == funcs[i].offset) {
					if (ambigWith.Length() > 0) {
						ambigWith += ", ";
					}
					ambigWith += funcs[k].name;
					ambigList.insertLast(k);
				}
			}
			
			if (ambigList.size() > 1) {
				println("Virtual functions share offsets: " + ambigWith);
				
				int bestAmbig = 0;
				int bestScore = -1;
				for (uint k = 0; k < ambigList.size(); k++) {
					int idx = ambigList[k];
					if (funcs[idx].expectedArgSize() == funcs[idx].total_arg_bytes) {
						int score = funcs[idx].expectedArgSize();
						if (score > bestScore) {
							bestScore = score;
							bestAmbig = k;
						}
					}
				}
				for (uint k = 0; k < ambigList.size(); k++) {
					int idx = ambigList[k];
					if (int(k) != bestAmbig) {
						funcs[idx].offsetShareName = funcs[ambigList[bestAmbig]].name;
						funcs[idx].skipWrite = true;
					}
				}
			}
		}
		
		for (uint i = 0; i < funcs.size(); i++) {
			PvFunc@ func = funcs[i];
			if (func.offset < 0) {
				continue;
			}
			
			if (lastOffset < func.offset-1) {
				f.Write("\n");
				for (int k = lastOffset+1; k < func.offset; k++) {
					f.Write("    virtual void f" + g_classid + "_" + unknownFuncIdx++ + "();\n");
					actualOffset++;
				}
			}
			
			int expectedArgSize = func.expectedArgSize();
			
			string args = "";
			string comment = "";
			
			array<string> commentLines = func.desc.Split("<br>");
			for (uint k = 0; k < commentLines.size(); k++) {
				comment += "\n    // " + commentLines[k];
			}
			
			if (expectedArgSize == func.total_arg_bytes) {
				for (uint k = 0; k < func.args.size(); k++) {
					if (k > 0) {
						args += ", ";
					}
					args += func.args[k].ctype + " " + func.args[k].name;
				}
			} else {
				comment += "\n    // These parameters are likely wrong. The expected parameter list adds up to " + expectedArgSize + " bytes but " + func.total_arg_bytes + " are required.";
				args = "";
				println("Unknown arguments for " + func.name + " (expected " + expectedArgSize + " bytes, got " + func.total_arg_bytes + ")");
				
				int curArgSz = 0;
				bool overflowed = false;
				for (uint k = 0; k < func.args.size(); k++) {
					if (curArgSz + func.args[k].size <= func.total_arg_bytes) {
						curArgSz += func.args[k].size;
						if (k > 0) {
							args += ", ";
						}
						args += func.args[k].ctype + " " + func.args[k].name;
					} else {
						if (!overflowed) {
							args += " /*";
							overflowed = true;
						}
						if (k > 0) {
							args += ", ";
						}
						args += func.args[k].ctype + " " + func.args[k].name;
					}
				}
				if (overflowed) {
					args += "*/ ";
				}
				
				// just get the bytes right
				int remainingBytes = func.total_arg_bytes - curArgSz;
				int argIdx = 0;
				int longArgs = remainingBytes / 4;
				int shortArgs = (remainingBytes / 2) % 2;
				int byteArgs = remainingBytes % 2;
				
				for (int k = 0; k < longArgs; k++) {
					if (argIdx > 0 || curArgSz > 0) {
						args += ", ";
					}
					args += "int u" + (argIdx++) + "=0";
				}
				
				for (int k = 0; k < shortArgs; k++) {
					if (argIdx > 0 || curArgSz > 0) {
						args += ", ";
					}
					args += "short u" + (argIdx++) + "=0";
				}
				
				for (int k = 0; k < byteArgs; k++) {
					if (argIdx > 0 || curArgSz > 0) {
						args += ", ";
					}
					args += "char u" + (argIdx++) + "=0";
				}
			}
			
			string funcsig = func.retTypeC + " " + func.name + "(" + args + ")";
			f.Write(comment + "\n");
			
			lastOffset = func.offset;
			
			if (func.skipWrite) {
				f.Write("    // This function is commented out because it shares a vtable offset with " + func.offsetShareName + ".\n");
				f.Write("    // This may actually be the correct function, but only enable one or else the vtable will break.\n");
				f.Write("    // virtual " + funcsig + ";\n");
				continue;
			}
			
			f.Write("    virtual " + funcsig + ";\n");
			actualOffset++;
			writtenFuncs++;
		}
		
		return writtenFuncs;
	}
	
	void write_metamod_header() {
		if (test_results.size() == 0) {
			println("No results");
			return;
		}
		
		test_results.sort(function(a,b) { return a.offset < b.offset; });
		
		if (is_duplicate_of_previously_reversed_class()) {
			return;
		}
		
		int bestParent = -1;
		int bestParentSize = 0;
		find_parent_class(bestParent, bestParentSize);
		if (bestParent != -1) {
			println("This class is a child of " + g_reversed_data[bestParent].cname);
		}
		
		string outputFile = "scripts/plugins/store/ApiGenerator/" + className + ".h";
		File@ f = g_FileSystem.OpenFile( outputFile, OpenFile::WRITE);
		
		if( f is null || !f.IsOpen() ) {
			println("Failed to open file for writing: " + outputFile);
			println("Create the 'ApiGenerator' folder if it doesn't exist.");
			return;
		}
		
		f.Write("#pragma once\n");
		f.Write("#pragma pack(push,1)\n\n");
		
		f.Write("// This code was automatically generated by the ApiGenerator plugin.\n");
		f.Write("// Prefer updating the generator code instead of editing this directly.\n");
		f.Write("// \"u[]\" variables are unknown data.\n");
		
		if (g_generate_vtables && funcs.size() > 0) {
			f.Write("// \"fx_y\" virtual functions have unknown signatures and will likely crash if called.\n\n");
		} else {
			f.Write("\n");
		}
		
		f.Write("// Example entity: " + ent.pev.classname + "\n");
		if (bestParent >= 0) {
			f.Write("class " + className + " : public " + g_reversed_data[bestParent].cname + " {\n");
		} else {
			f.Write("class " + className + " {\n");
		}
		
		f.Write("public:\n");
		
		int startOffset = bestParent >= 0 ? bestParentSize : 0;
		int childFields = write_properties(f, startOffset);
		
		int writtenFuncs = write_virtual_functions(f);
		
		f.Write("};\n");
		f.Write("#pragma pack(pop)\n");
		f.Close();
		
		if (g_generate_vtables)
			println("Found " + writtenFuncs + " virtual functions");
		
		g_reversed_data.insertLast(ReversedData(className, test_results, childFields));
		g_classid++;
		
		println("Wrote " + outputFile);
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
		
		errors = 0;
		
		if (g_generate_vtables && funcs.size() > 0) {
			find_virtual_methods();
		}		
		
		write_metamod_header();
	}
}