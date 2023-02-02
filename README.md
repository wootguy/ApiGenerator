# ApiGenerator
This is a combination of server plugins that reverse engineers the entity classes in Sven Co-op. The result is a set of header files that you can use for developing metamod plugins that use game-specific entity data.

How it works:
1. A list of private properties is created from the angelscript documentation.
2. The angelscript plugin changes a private property value in an entity, then calls a function in the metamod plugin.
3. Metamod scans for any changes in the entity's `pvPrivateData` field, then returns a byte offset of where it thinks the field is located.
4. Angelscript validates what metamod thinks, orders the located fields by offset, then fills in any gaps with byte arrays.

Class methods are not included, but a lot of the code might be similar to the [HLSDK](https://github.com/ValveSoftware/halflife). Some classes that you can see in the [angelscript docs](https://baso88.github.io/SC_AngelScript/docs/Classes.htm) are excluded here because they are duplicates of their parent class (e.g. CGrenade and CBaseMonster have identical properties).

# Setup for plugin developers
1. Copy the [header files](https://github.com/wootguy/ApiGenerator/tree/master/include/sven) to your project.
2. Add `#include "private_api.h"` to your source code. This includes all the private entity classes.
3. Cast the private data field from an edict to the class you need. This is unsafe, so you'll need to be sure of the entity type before you cast.

Example code:

```
#include "private_api.h"

// example safety check
bool is_valid_player(edict_t* plr) {
    return plr && (plr->v.flags & FL_CLIENT) && plr->pvPrivateData;
}

void kill_this_player(edict_t* player_edict) {
    if (!is_valid_player(player_edict)) {
        return; // crash avoided!
    }

    CBasePlayer* player_ent = (CBasePlayer*)player_edict->pvPrivateData;
    
    player_ent->m_flFallVelocity = 99999;
}
```

The generated header files don't include inheritance information because the ordering of inherited fields is not gauranteed to be the same for every compiler. However, you can tell by the shared fields what the hierarchy looks like. As of this writing (SC 5.25), this is what it appears to be:
```
CBaseEntity
├─ CBaseAnimating
│  ├─ CBaseMonster
│  │  ├─ CBasePlayer
│  │  ├─ CCineMonster
├─ CBaseDelay
│  ├─ CBaseToggle
│  │  ├─ CBaseButton
├─ CBasePlayerItem
│  ├─ CBasePlayerWeapon
├─ CBaseTank
├─ CItemInventory
├─ CPathTrack
├─ CBaseToggle
```
So, it's safe to cast a CBasePlayer to a CBaseMonster for example. You can double check with angelscript if you want (`cast<CBaseMonster@>(playerEntity) !is null`). Many Sven Co-op entities are shared with the [HLSDK](https://github.com/ValveSoftware/halflife), so you can check there to see which types of entities can be cast to these classes (e.g. "func_door" -> CBaseToggle).

# Updating headers
The header files will likely become invalid when a new version of Sven Co-op is released, causing crashes for the plugins that use them. Follow these steps to generate new header files with the updated property offsets.

1. Install [Metamod-p](https://github.com/wootguy/metamod-p/blob/master/README.md) and [Python](https://www.python.org/downloads/).
1. [Download](https://github.com/wootguy/ApiGenerator/archive/refs/heads/master.zip) this project's source and extract to `Sven Co-op/svencoop_addon/scripts/plugins/ApiGenerator-master`.
2. Run the game with the `-as_outputdocs` launch option to generate `asdocs.txt`. Move that file to the `ApiGenerator-master` folder.
3. Run the python script. It will generate the angelscript docs and required code for the angelscript plugin.
4. Compile the ApiGenerator metamod plugin and install it (See Compile Instructions section)
5. Install the ApiGenerator angelscript plugin (see below)
```
    "plugin"
    {
        "name" "ApiGenerator"
        "script" "ApiGenerator-master/scripts/ApiGenerator"
    }
```
6. Go to your `Sven Co-op/svencoop/scripts/plugins/store/` folder and create a folder named `ApiGenerator`
7. Launch Sven Co-op, start any map, then type `developer 1; clear; .apigen` into the console.
8. Header files should be output to the the folder created in step 7. If not, check the console for errors.
9. Recompile your plugins using the new header files.

# Compile Instructions
Open a command prompt in the root folder of the project and follow instructions below to build the ApiGenerator metamod plugin.

Windows:
```
mkdir build && cd build
cmake ..
cmake --build . --config Release
```
Linux:
```
mkdir build; cd build
cmake .. -DCMAKE_BUILD_TYPE=RELEASE
make
```
