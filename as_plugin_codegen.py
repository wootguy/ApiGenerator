import os, re
from pathlib import Path

docs_path = 'docs'
asgen_path = 'scripts/generated_props'
headers_path = 'include/sven'
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
	["GIB", ""],
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

print("Generating angelscript plugin code for...")

include_code = open(os.path.join(asgen_path, 'includes.as'), 'w')

for class_to_gen in classes_to_generate:
	print(class_to_gen)
	asClass = class_to_gen + "Pv"
	include_code.write("#include \"" + asClass + "\"\n")
	
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
				if '<td>' in line:
					if next_td_is_prop:
						next_td_is_prop = False
						prop = line[line.find("<td>")+len("<td>"):line.find("</td>")].split()
						
						prop_type = " ".join(prop[0:-1])
						prop_name = prop[-1]
						
						props.append([prop_type, prop_name, ""])
					elif len(props) > 0:
						desc = line[line.find("<td>")+len("<td>"):line.find("</td>")].replace('"', '\\"')
						props[-1][2] = desc
			
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