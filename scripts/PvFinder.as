class PvFinder {
	CBaseEntity@ ent;
	int test_index;
	int errors = 0;
	float findDelay = 0;
	string className;

	array<PvProp> props;
	array<PvData> test_results;
	
	PvFinder() {}
	
	PvFinder(CBaseEntity@ ent, string className, array<PvProp>@ props, array<PvProp>@ props_special) {
		init(ent, className, props, props_special);
	}
	
	PvFinder(string test_ent_classname, string className, array<PvProp>@ props, array<PvProp>@ props_special) {
		CBaseEntity@ testEnt = g_EntityFuncs.CreateEntity(test_ent_classname, null, true);
		g_Scheduler.SetTimeout("failsafe_ent_remove", 0.0f, EHandle(testEnt));
		
		if (testEnt !is null) {
			init(testEnt, className, props, props_special);
		} else {
			println("Failed to create test entity for class " + className);
		}
		
		g_EntityFuncs.Remove(testEnt);
	}
	
	void init(CBaseEntity@ ent, string className, array<PvProp>@ props, array<PvProp>@ props_special) {
		println("\nGenerating API for " + className);
		
		@this.ent = @ent;
		test_index = this.ent.entindex();
		this.className = className;
		this.props = props;
		
		if (props_special !is null) {
			for (uint i = 0; i < props_special.size(); i++) {
				this.props.insertLast(props_special[i]);
			}
		}
		
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
		
		println("Writing " + outputFile);
		f.Write("#pragma once\n");
		f.Write("#pragma pack(push,1)\n\n");
		
		f.Write("// This code was automatically generated by the ApiGenerator plugin.\n");
		f.Write("// Prefer updating the generator code instead of editing this directly.\n");
		f.Write("// \"u[]\" variables are unknown data.\n\n");
		
		f.Write("// Example entity: " + ent.pev.classname + "\n");
		if (bestParent >= 0) {
			f.Write("class " + className + " : public " + g_reversed_data[bestParent].cname + " {\n");
		} else {
			f.Write("class " + className + " {\n");
		}
		
		f.Write("public:\n");
		
		int paddingCount = 0;
		int startOffset = bestParent >= 0 ? bestParentSize : 0;
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
		f.Write("};\n");
		f.Write("#pragma pack(pop)\n");
		f.Close();		
		
		g_reversed_data.insertLast(ReversedData(className, test_results, childFields));
		g_classid++;
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