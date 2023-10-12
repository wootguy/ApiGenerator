import os, re
from pathlib import Path

docs_path = 'docs'
asgen_path = 'scripts/generated_props'
headers_path = 'include/sven'
as_plugin_output_path = '../../../../../svencoop/scripts/plugins/store/ApiGenerator'
classes_to_generate = [
	'CBaseEntity',
	'CBaseDelay',
	'CBaseAnimating',
	'CBaseToggle',
	'CBasePlayerItem',
	'CBasePlayerWeapon',
	'CBasePlayerAmmo',
	'CBaseMonster',
	'CBasePlayer',
	'CBaseTank',
	'CBaseButton',
	'CBaseDoor',
	'CItemInventory',
	'CItem',
	'CGrenade',
	'CCineMonster',
	'CSprite',
	'CPathTrack',
	'CBeam',
	'CLaser',
	'CBaseTank'
]

# 2nd value is prefix for each enum value name
enums_to_generate = [
	["Activity", ""],
	["EdictFlags", ""],
	["EFFECTS", ""],
	["FixAngleMode", ""],
	["CLASS", ""],
	["DMG", ""],
	["GIB", ""],
	["USE_TYPE", ""],
	["Bullet", ""],
	["AddPlayerItemResult", ""],
	["HITGROUP", ""],
	["PFLAG", ""],
	["ObserverMode", ""],
	["Train", ""],
	["PLAYER_ANIM", ""],
	["PlayerViewMode", ""],
	["ButtonCode", ""],
	["WeaponIds", ""],
	["BeamType", ""],
	["BeamFlags", ""],
	["CBeamSpawnflags", ""],
	["TANKBULLET", ""],
	["SoundFlag", ""],
	["SOUND_CHANNEL", ""],
	["AdminLevel_t", ""],
	["FFADE", ""],
	["HUD_EFFECT", ""],
	["HUD_ELEM", ""],
	["HUD_SPR", ""],
	["HUD_NUM", ""],
	["HUD_TIME", ""],
	["NetworkMessageType", "MSG_"]
]

prop_code = {
	'bool': {
		'astype': 'FIELD_BOOL',
		'setter': '<FIELD> = value.v8 != 0;',
		'getter': 'return uint8(<FIELD> ? 1 : 0);'
	},
	'int8': {
		'astype': 'FIELD_BYTE',
		'setter': '<FIELD> = value.v8;',
		'getter': 'return <FIELD>;'
	},
	'int': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = value.v32;',
		'getter': 'return <FIELD>;'
	},
	'uint': {
		'astype': 'FIELD_UINT',
		'setter': '<FIELD> = value.v32;',
		'getter': 'return <FIELD>;'
	},
	'TOGGLE_STATE': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = TOGGLE_STATE(value.v32);',
		'getter': 'return int(<FIELD>);'
	},
	'Activity': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = Activity(value.v32);',
		'getter': 'return int(<FIELD>);'
	},
	'MONSTERSTATE': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = MONSTERSTATE(value.v32);',
		'getter': 'return int(<FIELD>);'
	},
	'SCRIPTSTATE': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = SCRIPTSTATE(value.v32);',
		'getter': 'return int(<FIELD>);'
	},
	'TANKBULLET': {
		'astype': 'FIELD_INT',
		'setter': '<FIELD> = TANKBULLET(value.v32);',
		'getter': 'return int(<FIELD>);'
	},
	'float': {
		'astype': 'FIELD_FLT',
		'setter': '<FIELD> = value.vf;',
		'getter': 'return <FIELD>;'
	},
	'Vector': {
		'astype': 'FIELD_VEC3',
		'setter': '<FIELD> = value.vec3;',
		'getter': 'return <FIELD>;'
	},
	'string_t': {
		'astype': 'FIELD_STR_T',
		'setter': '<FIELD> = value.str_t;',
		'getter': 'return <FIELD>;'
	},
	'string': {
		'astype': 'FIELD_STR',
		'setter': '/* setting string values crashes the game??? */', # '<FIELD> = value.str;',
		'getter': 'return <FIELD>;'
	},
	'entvars_t@': {
		'astype': 'FIELD_ENTVARS',
		'setter': '@<FIELD> = @value.pev;',
		'getter': 'return @<FIELD>;'
	},
	'EHandle': {
		'astype': 'FIELD_EHANDLE',
		'setter': '<FIELD> = value.ehandle;',
		'getter': 'return <FIELD>;'
	},
	'Schedule@': {
		'astype': 'FIELD_SCHED',
		'setter': '@<FIELD> = @value.sched;',
		'getter': 'return @<FIELD>;'
	},
	'const int': {
		'astype': 'READ_ONLY',
		'setter': '<FIELD> = 0;',
		'getter': 'return <FIELD>;'
	}
}
func_vals = {
	'int&': {
		'code': 'int i;',	# do we need to set up any local variables?
		'argval': 'i',		# what value should angelscript use when calling the function?
		"ctype": "int&",	# what type should C code use?
		"size": 4			# how many bytes does this argument use in C++?
	},
	'bool': {
		'argval': 'false',	
		"ctype": "bool",
		"size": 1		
	},
	'int8': {
		'argval': '0',
		"ctype": "char",
		"size": 1
	},
	'int': {
		'argval': '0',
		"ctype": "int",
		"size": 4
	},
	'int16': {
		'argval': '0',
		"ctype": "short",
		"size": 2
	},
	'uint': {
		'argval': '0',
		"ctype": "unsigned int",
		"size": 4
	},
	'TOGGLE_STATE': {
		'argval': '0',
		"ctype": "int",
		"size": 4
	},
	'Activity': {
		'argval': 'Activity(0)',
		"ctype": "int",
		"size": 4
	},
	'MONSTERSTATE': {
		'argval': 'MONSTERSTATE(0)',
		"ctype": "int",
		"size": 4
	},
	'SCRIPTSTATE': {
		'argval': 'SCRIPTSTATE(0)',
		"ctype": "int",
		"size": 4
	},
	'TANKBULLET': {
		'argval': 'TANKBULLET(0)',
		"ctype": "int",
		"size": 4
	},
	'USE_TYPE': {
		'argval': 'USE_TYPE(0)',
		"ctype": "int",
		"size": 4
	},
	'Bullet': {
		'argval': 'Bullet(0)',
		"ctype": "int",
		"size": 4
	},
	'FireBulletsDrawMode': {
		'argval': 'FireBulletsDrawMode(0)',
		"ctype": "int",
		"size": 4
	},
	'PLAYER_ANIM': {
		'argval': 'PLAYER_ANIM(0)',
		"ctype": "int",
		"size": 4
	},
	'PlayerViewMode': {
		'argval': 'PlayerViewMode(0)',
		"ctype": "int",
		"size": 4
	},
	'BeamType': {
		'argval': 'BeamType(0)',
		"ctype": "int",
		"size": 4
	},
	'CLASS': {
		'argval': 'CLASS(0)',
		"ctype": "int",
		"size": 4
	},
	'float': {
		'argval': '0',
		"ctype": "float",
		"size": 4
	},
	'Vector': {
		'argval': 'Vector(0,0,0)',
		"ctype": "Vector",
		"size": 12
	},
	'string': {
		'argval': '""',
		"ctype": "const char*",
		"size": 4
	},
	'string_t': {
		'argval': 'string_t(0)',
		"ctype": "string_t",
		"size": 4
	},
	'EHandle': {
		'argval': 'null',
		"ctype": "EHandle",
		"size": 4
	},
	'const int': {
		'argval': '0',
		"ctype": "int",
		"size": 4
	},
	'Vector&': {
		'code': 'Vector vec;',
		'argval': 'vec',
		"ctype": "Vector",
		"size": 12
	},
	'string&': {
		'code': 'string str;',
		'argval': 'str',
		"ctype": "const char*",
		"size": 4
	},
	'TraceResult&': {
		'code': 'TraceResult tr;',
		'argval': 'tr',
		"ctype": "TraceResult*",
		"size": 4
	},
	'float&': {
		'code': 'float f;',
		'argval': 'f',
		"ctype": "float&",
		"size": 4
	},
	'size_t': {
		'argval': '0',
		"ctype": "size_t",
		"size": 4
	},
	'ItemInfo&': {
		'code': 'ItemInfo iteminfo;',
		'argval': 'iteminfo',
		"ctype": "ItemInfo&",
		"size": 4
	},
	'AddPlayerItemResult': {
		'argval': '0',
		"ctype": "int",
		"size": 4
	},
	'EHandle&': {
		'argval': 'EHandle(g_EntityFuncs.Instance(0))',
		"ctype": "EHandle&",
		"size": 4
	},
	'int8&': {
		'code': 'int8 i;',
		'argval': 'i',
		"ctype": "int8&",
		"size": 4
	},
	'Waypoint&': {
		'code': 'Waypoint w;',
		'argval': 'w',
		"ctype": "Waypoint&",
		"size": 4
	}
}

# value names that are in the HLSDK and will conflict with the sven names
ignore_enum_values = [
	"FL_FLY",
	"FL_SWIM",
	"FL_CONVEYOR",
	"FL_CLIENT",
	"FL_INWATER",
	"FL_MONSTER",
	"FL_GODMODE",
	"FL_NOTARGET",
	"FL_SKIPLOCALHOST",
	"FL_ONGROUND",
	"FL_PARTIALGROUND",
	"FL_WATERJUMP",
	"FL_FROZEN",
	"FL_FAKECLIENT",
	"FL_DUCKING",
	"FL_FLOAT",
	"FL_GRAPHED",
	"FL_IMMUNE_WATER",
	"FL_IMMUNE_SLIME",
	"FL_IMMUNE_LAVA",
	"FL_PROXY",
	"FL_ALWAYSTHINK",
	"FL_BASEVELOCITY",
	"FL_MONSTERCLIP",
	"FL_ONTRAIN",
	"FL_WORLDBRUSH",
	"FL_SPECTATOR",
	"FL_CUSTOMENTITY",
	"FL_KILLME",
	"FL_DORMANT",
	"EF_BRIGHTFIELD",
	"EF_MUZZLEFLASH",
	"EF_BRIGHTLIGHT",
	"EF_DIMLIGHT",
	"EF_INVLIGHT",
	"EF_NOINTERP",
	"EF_LIGHT",
	"EF_NODRAW",
	"MAX_WEAPONS",
	"SND_STOP",
	"SND_CHANGE_VOL",
	"SND_CHANGE_PITCH",
	"CHAN_AUTO",
	"CHAN_WEAPON",
	"CHAN_VOICE",
	"CHAN_ITEM",
	"CHAN_BODY",
	"CHAN_STREAM",
	"CHAN_STATIC",
	"SVC_TEMPENTITY",
	"SVC_INTERMISSION"
]

ignore_func_names = [
	# cast functions (why are these listed?)
	'opImplCast',
	'opCast',
	
	# these aren't exposed to angelscript but are still in the documentation
	'GetUserData',
	'ClearUserData',
	
	# we know these aren't virtual (see the hlsdk)
	'edict',
	'entindex',
	'Intersects',
	'MakeDormant',
	'IsDormant',
	'GetOrigin',
	'GetClassname',
	'GetTargetname',
	
	# useless functions. Don't waste time on them
	'opEquals',
	'SUB_DoNothing',
	'SUB_Remove',
	'KeyValue', # there's a dll func in metamod for this
	
	# these share offsets with other functions. Enable these again if the generator is able to resolve that,
	# or not because these don't seem very useful
	'SetOrigin',
	'SUB_StartFadeOut',
	'SetObjectCollisionBox',
	'IRelationshipByClass',
	'SUB_CallUseToggle'
]

if not os.path.exists(docs_path):
	if os.path.exists('asdocs.txt') and (os.path.exists('ASDocGenerator.exe') or os.path.exists('ASDocGenerator')):
		print("Angelscript docs are missing. Generating them from the asdocs.txt file")
		os.system('ASDocGenerator -i asdocs.txt -o docs')
	else:
		print("Angelscript docs are missing, and so are the files required to generate them.")
		print("- Download or compile ASDocGenerator and place it in this folder")
		print("- Run the game with the -as_outputdocs launch option to generate asdocs.txt, then place in this folder")
		print("- Run this script again")

Path(asgen_path).mkdir(parents=True, exist_ok=True)
Path(as_plugin_output_path).mkdir(parents=True, exist_ok=True)

print("Generating angelscript plugin code for...")

include_code = open(os.path.join(asgen_path, 'includes.as'), 'w')

func_name_counts = {}
virtual_func_names = set({})

# on the first pass, just look for functions that appear in multiple classes.
# these will likely be virtual functions and so can be found by the vtable replacement method
# anything else is probably a normal method and not easy to find the address for
for class_to_gen in classes_to_generate:	
	with open(os.path.join(docs_path, class_to_gen + '.htm')) as htm:
		is_parsing_funcs = False
		next_td_is_decl = False
		
		for line in htm.readlines():
			if '<h2>Methods</h2>' in line:
				is_parsing_funcs = True
			if '<h2>Properties</h2>' in line:
				break
						
			if is_parsing_funcs:
				if '<tr>' in line:
					next_td_is_decl = True
				if '<td>' in line:
					if next_td_is_decl:
						next_td_is_decl = False
						func = line[line.find("<td>")+len("<td>"):line.find("</td>")]
						
						first_space = func.find(" ")
						ret_type = func[:first_space]
						func = func[first_space+1:]
						
						if ret_type == "const":
							first_space = func.find(" ")
							ret_type = func[:first_space]
							func = func[first_space+1:]
						
						args_begin = func.find("(")
						func_name = func[:args_begin]
						
						if func_name in ignore_func_names:
							continue
							
						if func_name not in func_name_counts:
							func_name_counts[func_name] = 1
						else:
							func_name_counts[func_name] += 1

for key, value in func_name_counts.items():
	if value > 1:
		virtual_func_names.add(key)

# Now generate property and function information for angelscript
for class_to_gen in classes_to_generate:
	print(class_to_gen)
	asClass = class_to_gen + "Pv"
	include_code.write("#include \"" + asClass + "\"\n")
	
	with open(os.path.join(docs_path, class_to_gen + '.htm')) as htm:
		with open(os.path.join(asgen_path, asClass + '.as'), 'w') as code:
			is_parsing_funcs = False
			is_parsing_props = False
			next_td_is_decl = False
			
			# not using a DOM parsing library because the doc format is simple and static
			props = []
			funcs = []
			for line in htm.readlines():
				if '<h2>Methods</h2>' in line:
					is_parsing_funcs = True
					is_parsing_props = False
				if '<h2>Properties</h2>' in line:
					is_parsing_props = True
					is_parsing_funcs = False
					
				if is_parsing_props:
					if '<tr>' in line:
						next_td_is_decl = True
					if '<td>' in line:
						if next_td_is_decl:
							next_td_is_decl = False
							prop = line[line.find("<td>")+len("<td>"):line.find("</td>")].split()
							
							prop_type = " ".join(prop[0:-1])
							prop_name = prop[-1]
							
							props.append([prop_type, prop_name, ""])
						elif len(props) > 0:
							desc = line[line.find("<td>")+len("<td>"):line.find("</td>")].replace('"', '\\"')
							props[-1][2] = desc
							
				if is_parsing_funcs:
					if '<tr>' in line:
						next_td_is_decl = True
					if '<td>' in line:
						if next_td_is_decl:
							next_td_is_decl = False
							func = line[line.find("<td>")+len("<td>"):line.find("</td>")]
							
							first_space = func.find(" ")
							ret_type = func[:first_space]
							func = func[first_space+1:]
							
							if ret_type == "const":
								first_space = func.find(" ")
								ret_type = func[:first_space]
								func = func[first_space+1:]
							
							args_begin = func.find("(")
							func_name = func[:args_begin]
							args = func[args_begin+1:func.find(")")].split(",")
							
							if func_name not in virtual_func_names:
								continue
							
							if class_to_gen != 'CBaseEntity':
								continue # work needed to find vtables in derived classes
							
							for idx, arg in enumerate(args):
								if len(arg) == 0:
									continue
								
								# strip qualifiers that don't matter for testing
								arg = arg.replace("const", "")
								arg = arg.replace(" in ", "")
								arg = arg.replace(" out ", "")
								arg = arg.replace(" inout ", "")
								
								# convert html entities
								arg = arg.replace("&lt;", "<")
								arg = arg.replace("&gt;", ">")
								
								# strip default values
								if '=' in arg:
									arg = arg[:arg.find("=")]
								
								arg = arg.strip()
								
								endType = arg.find(" ")
								if endType == -1:
									endType = arg.find("&")
								if endType == -1:
									endType = arg.find("@")
								if endType == -1:
									print("Failed to find separator for argument type and name: %s" % args[idx])
									continue
								
								argType = arg[:endType+1].strip()
								argName = arg[endType+1:]
								
								args[idx] = (argType, argName)
								
							if len(args) == 1 and args[0] == '':
								args = []
								
							#print("Got func: %s %s(%s)" % (ret_type, func_name, args))
							
							func_data = [func_name, ret_type, "", args]
							
							# if multiple funcs have the same name, keep the function that has the most number of arguments
							skip_func = False
							for idx, f in enumerate(funcs):
								if f[0] == func_name:
									if len(f[3]) >= len(args):
										skip_func = True
									else:
										funcs[idx] = func_data
										
							if not skip_func:
								funcs.append(func_data)
						elif len(funcs) > 0:
							desc = line[line.find("<td>")+len("<td>"):line.find("</td>")].replace('"', '\\"')
							funcs[-1][2] = desc
			
			code.write("// This code is automatically generated.\n")
			code.write("// Update the python script instead of editing this directly.\n\n")
			
			code.write("array<PvProp> " + asClass + " = {\n")
			
			for idx, prop in enumerate(props):
				prop_type = prop[0]
				prop_name = prop[1]
				prop_desc = prop[2]
				
				ent_replace = "cast<" + class_to_gen + "@>(ent)"
				
				if prop_type not in prop_code:
					print("ERROR: New prop type encountered (%s %s). Update the prop_code in this script to use this property." % (prop_type, prop_name))
					continue
					
				astype = prop_code[prop_type]['astype']
				getter = prop_code[prop_type]['getter'].replace("<FIELD>", ent_replace + "." + prop_name)
				setter = prop_code[prop_type]['setter'].replace("<FIELD>", ent_replace + "." + prop_name)
				
				if astype == 'READ_ONLY':
					code.write("\t// " + prop_type + " " + prop_name + "\n")
					continue
					
				code.write('\tPvProp("' + prop_name + '", ' + astype + ', "' + prop_desc + '",\n')
				code.write("\t\tfunction(ent) { " + getter + " },\n")
				code.write("\t\tfunction(ent, value) { " + setter + " }\n")
				
				if (idx < len(props)-1):
					code.write("\t),\n")
				else:
					code.write("\t)\n")
			
			code.write("};\n")
			
			code.write("\narray<PvFunc> " + class_to_gen + "Funcs = {\n")
			
			for idx, func in enumerate(funcs):
				func_name = func[0]
				ret_type = func[1]
				desc = func[2]
				args = func[3]
				
				ctype = 'unknown_type'
				if ret_type[-1] == "@":
					ctype = ret_type[:-1] + "*"
				elif ret_type == "void":
					ctype = "void"
				elif ret_type in func_vals:
					ctype = func_vals[ret_type]['ctype']
				else:
					print("Unknown func return type '%s'" % ret_type)
				
				code.write('\tPvFunc("' + func_name + '", "' + ret_type + '", "' + ctype + '", "' + desc + '",\n')
				
				cast_code = "cast<" + class_to_gen + "@>(ent)"
				if class_to_gen == "CBaseEntity":
					cast_code = "ent"
					
				func_call = cast_code + "." + func_name + "("
				local_vars_code = ""
				unique_locals = set({})
				
				code.write("\t\t{")
				for idx2, arg in enumerate(args):
					argtype = arg[0]
				
					argval = "0"
					argsz = 4
					ctype = "unknown_type"
					if arg[0][-1] == "@":
						argval = "null"
						argsz = 4
						ctype = arg[0][:-1] + "*"
					elif arg[0] in func_vals:
						argval = func_vals[argtype]['argval']
						argsz = func_vals[argtype]['size']
						ctype = func_vals[argtype]['ctype']
					else:
						print("Unknown func arg type '%s'" % arg[0])
					
					if argtype in func_vals and 'code' in func_vals[argtype] and argtype not in unique_locals:
						local_vars_code += func_vals[argtype]['code'] + " "
						unique_locals.add(argtype)
					
					func_call += argval
					
					code.write('PvFuncArg("' + arg[0] + '", "' + ctype + '", "' + arg[1] + '", ' + ('%d' % argsz) + ')')
					if idx2 < len(args)-1:
						code.write(', ')
						func_call += ', '
						
				code.write("},\n")
				func_call += ");"
				
				code.write("\t\tfunction(ent) { " + local_vars_code + func_call + " }\n")
				
				if (idx < len(funcs)-1):
					code.write("\t),\n")
				else:
					code.write("\t)\n")
			
			code.write("};\n")


print('\nGenerating enums for...')
enum_code = ''

for enum_to_gen in enums_to_generate:
	print(enum_to_gen[0])
	prefix = enum_to_gen[1]
	
	with open(os.path.join(docs_path, enum_to_gen[0] + '.htm')) as file:
		html = file.read()

		enum_name = re.search(r'<h1>(.*?)</h1>', html).group(1)
		values = re.findall(r'<td>(.*?)</td>\s*<td>(.*?)</td>\s*<td>(.*?)</td>', html)

		enum_str = "\n// " + enum_name + "\n"
		for i, value in enumerate(values):
			if value[0] in ignore_enum_values:
				enum_str += "// "
		
			enum_str += "#define " + prefix + value[0] + " " + value[1]
			
			comment = value[2].strip()
			if comment:
				enum_str += " // " + comment
			enum_str += "\n"
		
		enum_code += enum_str

with open(os.path.join(headers_path, 'sc_enums.h'), 'w') as file:
	file.write("// This code was automatically generated by the ApiGenerator plugin\n")
	file.write("// Value names that conflict with the HLSDK are commented out\n")
	file.write(enum_code)
	
print("\nDone!")