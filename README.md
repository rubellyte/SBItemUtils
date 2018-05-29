# SBItemUtils
Starbound ItemUtils mod: Vanilla-friendly extensions to weapon scripts.

# Installation
- Download the [latest release](https://github.com/medeor413/SBItemUtils/releases) or clone the repository and extract the folder within to your Starbound installation's `mods` directory.
- If you don't already have it, install Silverfeelin's [QuickbarMini](https://github.com/Silverfeelin/Starbound-Quickbar-Mini/releases); ItemUtils depends on it.

### Optional (but strongly recommended):
- Set `safeScripts` in your `starbound.config` to `false` to enable item JSON exports and faster importing.
- Configure the file paths in the settings page of the ItemUtils UI (small gear icon in top right)
- Increase the value of `luaInstructionLimit` in `starbound.config` to allow the encryption of more complex items. You'll know if this needs to be higher if your log contains `(LuaInstructionLimitReached)` errors.

# Usage
### Item import/export/dupe:
Open the ItemUtils MUI interface. Type a file name into the box. The UI will attempt to read/write the JSON file by that name in the ItemUtils directory. The item exported/duplicated will be the one in your hand.

### Item encryption:
Type in an encryption key for your weapon, and hit "Encrypt" to make an encrypted copy of your held weapon. Add the key you used to the `keys.json` file at the root of the ItemUtils folder (create it if it doesn't exist). See `keys.json.example` for formatting. **Important encryption note:** Your item's `"animationCustom"` *cannot* be encrypted! Store part images in `"animationParts"` if you don't want them stolen!

### Weapon script enhancements:
Just add the appropriate base script (e.g. `/itemscripts/meleeweapon_plus.lua` for melee weaponry) to the `"scripts"` array of the weapon, and you'll be able to use the new features exposed to JSON.

New JSON arguments:
- Stance transformations: Stances can now include a `"transforms"` object structured like so:
```JSON
"transforms": {
  "transformationGroup1": {
    "translate": [1, 0],
    "rotate": 90,
    "scale": 0.5,
    "rotationCenter": [1, 0],
    "scaleCenter": [-1, 0]
  },
  "transformationGroup2": {
    "transform": {
      "a": 1,
      "b": 0,
      "c": 0,
      "d": 0.5,
      "tx": 0,
      "ty": 0
    }
  }
}
```
Most of these options are self-explanatory. However, `"transform"` is special; it overrides any other transforms for that group, and is a Mat3 transformation matrix. See the documentation for `animator.transformTransformationGroup` for more information.

- damageConfig options: `"damageConfig"` type objects now allow a `"damageTeam"` to be specified, and can also have the collision check for walls disabled with `"rayCheck": false`.

- Magnorbs enhancements:
  - Projectile count `"projectileCount"`
  - Orbit speed `"orbitRate"`
  - Orbit distance `"orbitDistance"`
  - Automatic firing `"autoFire"`
  - Minimum required orbs for shield `"minimumShieldOrbs"`
  - Spacing between shield parts `"shieldSpaceFactor"`
  - Multiple projectile types/configs: A `"projectileTypes"` array can be specified, containing an object for each orb. This object can contain a `"type"` and `"parameters"`. Missing `"type"`s and `"parameters"`s will be filled in with `"projectileType"` and `"projectileParameters"` respectively.
  
- Hitscan gun script parameters:
  - `"damageConfig"` controls the type of damage and knockback dealt, much like a melee weapon
  - `"maxLength"` controls the maximum effective range of the weapon
  - `"tracer"` specifies a beam to use as a bullet trail
  - `"projectileType"` specifies a projectile to spawn at the beam's impact point
  - `"projectileParameters"` specifies parameters for said projectile
  - `"piercing"` controls whether or not the shot will stop after hitting a target
  - Inherited from base gun: `"baseDps"`, `"baseDamage"`, `"baseDamageMultiplier"`, `"inaccuracy"`, `"energyUsage"`, `"fireTime"`
  
### Mech Script Changes
The mech parts manager has been modified to accept custom part configurations. To use, simply add a `"partConfig"` object to a part item containing information in the same structure as the mech config file entries.

Custom mech config will be merged with the part's default config. To avoid this behavior, change the part type to a non-existent one.

In addition, custom directives can be specified for the part by adding a `"customDirectives"` string in the `"partConfig"` object.

Finally, stats can be declared directly by adding them with the proper names to `"partParameters"`.
