import os
from pathlib import Path

docs_path = 'docs'
asgen_path = 'asgen'
classes_to_generate = ['CBasePlayer']

if not os.path.exists('docs_path'):
	if os.path.exists('asdocs.txt') and (os.path.exists('ASDocGenerator.exe') or os.path.exists('ASDocGenerator')):
		print("Angelscript docs are missing. Generating them from the asdocs.txt file")
		os.system('ASDocGenerator -i asdocs.txt -o docs')
	else:
		print("Angelscript docs are missing, and so are the files required to generate them.")
		print("- Download or compile ASDocGenerator and place it in this folder")
		print("- Run the game with the -as_outputdocs launch option to generate asdocs.txt, then place in this folder")
		print("- Run this script again")

Path(asgen_path).mkdir(parents=True, exist_ok=True)

'''
class CBasePlayerPv : BasePv {
	CBasePlayer@ ent;

	CBasePlayerPv() {}

	CBasePlayerPv(CBasePlayer@ ent) {
		super(ent);
		className = "CBasePlayer";
		@this.ent = @ent;
		generatePrivateApi();
	}
	
	void setValue(string f, TestValue v) {
		if (f == "pev") @ent.pev = @v.pev;
		else if (f == "m_fOverrideClass") ent.m_fOverrideClass = v.v8 != 0;
	}
	
	TestValue getValue(string f) {
		TestValue val;
	
		if (f == "pev") @val.pev = @ent.pev;
		else if (f == "m_fOverrideClass") val.v8 = ent.m_fOverrideClass ? 1 : 0;
		
		return val;
	}

	void findOffsets() {
		find_offset("pev", FIELD_ENTVARS);
		find_offset("m_fOverrideClass", FIELD_BOOL);
		find_offset("m_iClassSelection", FIELD_INT);
		find_offset("m_flMaximumFadeWait", FIELD_FLT);
	}
}
'''

prop_code = {
	'bool': {
		'astype': 'FIELD_BOOL',
		'setter': '<FIELD> = v.v8 != 0;',
		'getter': 'v.v8 = <FIELD> ? 1 : 0;'
	},
	'int8': {
		'astype': 'FIELD_BYTE',
		'setter': '<FIELD> = v.v8;',
		'getter': 'v.v8 = <FIELD>;'
	},
	'int': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = v.v32;',
		'getter': 'v.v32 = <FIELD>;'
	},
	'uint': {
		'astype': 'FIELD_UINT',
		'setter': '<FIELD> = v.v32;',
		'getter': 'v.v32 = <FIELD>;'
	},
	'TOGGLE_STATE': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = TOGGLE_STATE(v.v32);',
		'getter': 'v.v32 = int(<FIELD>);'
	},
	'Activity': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = Activity(v.v32);',
		'getter': 'v.v32 = int(<FIELD>);'
	},
	'MONSTERSTATE': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = MONSTERSTATE(v.v32);',
		'getter': 'v.v32 = int(<FIELD>);'
	},
	'SCRIPTSTATE': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = SCRIPTSTATE(v.v32);',
		'getter': 'v.v32 = int(<FIELD>);'
	},
	'float': {
		'astype': 'FIELD_FLT',
		'setter': '<FIELD> = v.vf;',
		'getter': 'v.vf = <FIELD>;'
	},
	'Vector': {
		'astype': 'FIELD_VEC3',
		'setter': '<FIELD> = v.vec3;',
		'getter': 'v.vec3 = <FIELD>;'
	},
	'string_t': {
		'astype': 'FIELD_STR',
		'setter': '<FIELD> = v.str;',
		'getter': 'v.str = <FIELD>;'
	},
	'entvars_t@': {
		'astype': 'FIELD_ENTVARS',
		'setter': '@<FIELD> = @v.pev;',
		'getter': '@v.pev = @<FIELD>;'
	},
	'EHandle': {
		'astype': 'FIELD_EHANDLE',
		'setter': '<FIELD> = v.ehandle;',
		'getter': 'v.ehandle = <FIELD>;'
	},
	'Schedule@': {
		'astype': 'FIELD_SCHED',
		'setter': '@<FIELD> = @v.sched;',
		'getter': '@v.sched = @<FIELD>;'
	},
	'const int': {
		'astype': 'READ_ONLY',
		'setter': '<FIELD> = 0;',
		'getter': 'v.v32 = <FIELD>;'
	}
}

print("Generating angelscript plugin code for...")

for class_to_gen in classes_to_generate:
	print(class_to_gen)
	asClass = class_to_gen + "Pv"
	
	with open(os.path.join(docs_path, class_to_gen + '.htm')) as htm:
		with open(os.path.join(asgen_path, asClass + '.as'), 'w') as code:
			is_parsing_props = False
			next_td_is_prop = False
			
			# not using a DOM parsing library because the doc format is simple and static
			props = []
			for line in htm.readlines():
				if '<h2>Properties</h2>' in line:
					is_parsing_props = True
					
				if not is_parsing_props:
					continue
					
				if '<tr>' in line:
					next_td_is_prop = True
				if '<td>' in line and next_td_is_prop:
					next_td_is_prop = False
					prop = line[line.find("<td>")+len("<td>"):line.find("</td>")].split()
					
					prop_type = " ".join(prop[0:-1])
					prop_name = prop[-1]
					
					props.append([prop_type, prop_name])
			
			
			
			code.write("// This code is automatically generated.\n")
			code.write("// Update the python script instead of editing this directly.\n\n")
			
			code.write("class " + asClass + " : BasePv {\n")
			code.write("\t" + class_to_gen + "@ ent;\n\n")
			
			code.write("\t" + asClass + "() {}\n\n")
			
			code.write("\t" + asClass + "(" + class_to_gen + "@ ent) {\n")
			code.write("\t\tsuper(ent);\n")
			code.write("\t\tclassName = \"" + class_to_gen + "\";\n")
			code.write("\t\t@this.ent = @ent;\n")
			code.write("\t\tgeneratePrivateApi();\n")
			code.write("\t}\n\n")
			
			
			code.write("\tvoid setValue(string f, TestValue v) {\n")
			
			is_first_prop = True
			for prop in props:
				prop_type = prop[0]
				prop_name = prop[1]
				
				astype = prop_code[prop_type]['astype']
				func = prop_code[prop_type]['setter'].replace("<FIELD>", "ent." + prop_name)
				
				code.write("\t\t")
				
				if astype == 'READ_ONLY':
					code.write("//")
				
				code.write('if' if is_first_prop else 'else if')
				
				code.write(" (f == \"" + prop_name + "\") " + func + "\n")
				
				is_first_prop = False
					
			code.write("\t}\n\n")
			
			code.write("\tTestValue getValue(string f) {\n")
			code.write("\t\tTestValue v;\n\n")
			
			is_first_prop = True
			for prop in props:
				prop_type = prop[0]
				prop_name = prop[1]
				
				astype = prop_code[prop_type]['astype']
				func = prop_code[prop_type]['getter'].replace("<FIELD>", "ent." + prop_name)
				
				code.write("\t\t")
				
				if astype == 'READ_ONLY':
					code.write("//")
				
				code.write('if' if is_first_prop else 'else if')
				
				code.write(" (f == \"" + prop_name + "\") " + func + "\n")
				
				is_first_prop = False
					
			code.write("\n\t\treturn v;\n")
			code.write("\t}\n\n")
			
			
			code.write("\tvoid findOffsets() {\n")
					
			for prop in props:
				prop_type = prop[0]
				prop_name = prop[1]
				
				astype = prop_code[prop_type]['astype']
				
				code.write("\t\t")
				
				if astype == 'READ_ONLY':
					code.write("//")
				
				code.write("find_offset(\"" + prop_name + "\", " + astype + ");\n")
					
			code.write("\t}\n")
			code.write("}\n")

print("\nDone!")