# ApiGenerator
This is a combination of server plugins that reverse engineers the entity classes in Sven Co-op. The result is a set of header files that you can use for developing metamod plugins that need game-specific entity data.

How it works:
1. A list of private properties is created from the angelscript documentation.
2. The angelscript plugin changes a private property value in an entity, then calls a function in the metamod plugin.
3. Metamod scans for any changes in the edict's `pvPrivateData`, then returns a byte offset of where it thinks the private field is located.
4. Angelscript validates what metamod thinks, orders the located fields by offset, then fills in any gaps with byte arrays.

Class methods are not included, but a lot of the code might be similar to the [HLSDK](https://github.com/ValveSoftware/halflife).

Some classes that you can see in the [angelscript docs](https://baso88.github.io/SC_AngelScript/docs/Classes.htm) are excluded here because they are duplicates of their parent class (e.g. CGrenade and CBaseMonster have identical properties).

# Setup for plugin developers
1. Copy the [header files](https://github.com/wootguy/ApiGenerator/tree/master/include/sven) to your project.
2. Add `#include "private_api.h"` to your source code. This includes all the private entity classes.
3. Cast the private data field from an edict to the class you need. This is unsafe, so you'll need to be sure of the entity type before you cast.

Example code:

```
#include "private_api.h"

// example safety check
bool is_valid_player(edict_t* plr) {
    return plr && plr->pvPrivateData && (plr->v.flags & FL_CLIENT);
}

void kill_this_player(edict_t* player_edict) {
    if (!is_valid_player(player_edict)) {
        return; // crash avoided!
    }

    CBasePlayer* player_ent = (CBasePlayer*)player_edict->pvPrivateData;
    
    player_ent->m_flFallVelocity = 99999;
}
```

# Updating headers
The header files will likely become invalid when a new version of Sven Co-op is released, causing crashes for the plugins that use them. Follow the steps below to generate new header files with the updated property offsets.

If any classes have been added/removed/renamed in the angelscript API, then you'll need to update this [python class list](https://github.com/wootguy/ApiGenerator/blob/16c18d244acaf5b1e04e893788c2c2b0037ecc56/as_plugin_codegen.py#L6-L28) and [this plugin code](https://github.com/wootguy/ApiGenerator/blob/16c18d244acaf5b1e04e893788c2c2b0037ecc56/scripts/ApiGenerator.as#L251-L275). New field types (e.g. uint64) will need code updates [here](https://github.com/wootguy/ApiGenerator/blob/16c18d244acaf5b1e04e893788c2c2b0037ecc56/as_plugin_codegen.py#L42-L128), [here](https://github.com/wootguy/ApiGenerator/blob/16c18d244acaf5b1e04e893788c2c2b0037ecc56/scripts/ApiGenerator.as#L5-L19), [here](https://github.com/wootguy/ApiGenerator/blob/16c18d244acaf5b1e04e893788c2c2b0037ecc56/scripts/ApiGenerator.as#L60-L106) and [here](https://github.com/wootguy/ApiGenerator/blob/16c18d244acaf5b1e04e893788c2c2b0037ecc56/scripts/ApiGenerator.as#L137-L187).

1. Install [Metamod-p](https://github.com/wootguy/metamod-p/blob/master/README.md) and [Python](https://www.python.org/downloads/).
2. [Download](https://github.com/wootguy/ApiGenerator/archive/refs/heads/master.zip) this project's source and extract to `Sven Co-op/svencoop_addon/scripts/plugins/ApiGenerator-master`.
3. Run the game with the `-as_outputdocs` launch option to generate `asdocs.txt`. Move that file to the `ApiGenerator-master` folder.
4. Run the python script. It will generate the angelscript docs and required code for the angelscript plugin.
5. Compile the ApiGenerator metamod plugin and install it (See Compile Instructions section)
6. Install the ApiGenerator angelscript plugin (see below)
```
    "plugin"
    {
        "name" "ApiGenerator"
        "script" "ApiGenerator-master/scripts/ApiGenerator"
    }
```
7. Go to your `Sven Co-op/svencoop/scripts/plugins/store/` folder and create a folder named `ApiGenerator`
8. Launch Sven Co-op, start any map, then type `developer 1; clear; .apigen` into the console.
9. Header files should be output to the the folder created in step 7. If not, check the console for errors.
10. Recompile your plugins using the new header files.

# Compile Instructions
Open a command prompt in the root folder of the project and follow instructions below to build the ApiGenerator metamod plugin.

Windows:
```
mkdir build && cd build
cmake -A Win32 ..
cmake --build . --config Release
```
Linux:
```
mkdir build; cd build
cmake .. -DCMAKE_BUILD_TYPE=RELEASE
make
```
