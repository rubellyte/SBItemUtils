require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/arcfour.lua"
itemUtilsUI = {}

IUUI = itemUtilsUI

-- the directory of the mod, absolute from top of disk
IUUI.mod_directory = "D:/Steam/steamapps/common/Starbound/mods/ItemUtils"

-- the subdirectory of the mod folder in which you'll store JSON files
IUUI.item_subdir = "/items/"

-- default item filename, don't touch
IUUI.item_file = "item.json"

-- value is in seconds, increase if you lag while IUUI is open
IUUI.playerUpdateInterval = 0.0

-- here there be code, no touchies unless you know what you're doing
IUUI.enc_ignores = {
  "animation",
  "animationCustom",
  "elementalType",
  "shortdescription",
  "description",
  "level",
  "rarity",
  "primaryAbilityType",
  "altAbilityType",
  "twoHanded",
  "itemTags",
  "createdBy",
  "metadata",
  "category",
  "scripts",
  "animationScripts",
  "tooltipKind",
  "tooltipFields"
}

IUUI.enc_scripts = {
  ["/items/active/weapons/melee/meleeweapon.lua"] = "/itemscripts/meleeweapon_plus.lua",
  ["/items/active/weapons/melee/energymeleeweapon.lua"] = "/itemscripts/energymeleeweapon_plus.lua",
  ["/items/active/weapons/ranged/gun.lua"] = "/itemscripts/gun_plus.lua",
  ["/items/active/weapons/staff/staff.lua"] = "/itemscripts/staff_plus.lua",
  ["/items/active/weapons/other/magnorbs/magnorbs.lua"] = "/itemscripts/magnorbs_plus.lua",
  ["magnorbs.lua"] = "/itemscripts/magnorbs_plus.lua"
}

IUUI.widgets = {
  item_file_entry = "IUUIItemFileEntry",
  key_entry = "IUUIKeyEntry",
  player_info_canvas = "IUUIPlayerInfo"
}

function IUUI.init()
  mui.setTitle("^shadow;ItemUtils UI", "^shadow;Import/export/dupe/encrypt items.")
  if not io then
    widget.setButtonEnabled("exportItem", false)
  end
  IUUI.updateItemFile()
  IUUI.updateTimer = IUUI.playerUpdateInterval
  IUUI.updatePlayerInfo()
end

function IUUI.update(dt)
  IUUI.updateTimer = math.max(IUUI.updateTimer - dt, 0)
  if IUUI.updateTimer == 0 then
    IUUI.updateTimer = IUUI.playerUpdateInterval
    IUUI.updatePlayerInfo()
  end
end

function IUUI.importItem()
  local itemDescriptor = root.assetJson(IUUI.item_subdir..IUUI.item_file)
  player.giveItem(itemDescriptor)
end

function IUUI.exportItem()
  local itemDescriptor = player.primaryHandItem()
  if itemDescriptor ~= nil then
    local towrite = sb.printJson(itemDescriptor, 2)
    writefile = io.open(IUUI.mod_directory..IUUI.item_subdir..IUUI.item_file, "w")
    if writefile ~= nil then
      writefile:write(towrite)
      writefile:close()
    else
      sb.logError("ItemUtils: Error opening export file; confirm that directory exists?\n Directory: %s", IUUI.item_directory)
      return
    end
  end
end

function IUUI.dupeItem()
  local itemDescriptor = player.primaryHandItem()
  if itemDescriptor ~= nil then
    player.giveItem(itemDescriptor)
  end
end

function IUUI.encryptItem()
  local itemDescriptor = player.primaryHandItem() or player.altHandItem()
  local to_encrypt = copy(itemDescriptor.parameters)
  local item_config = root.itemConfig(itemDescriptor)
  local key = widget.getText(IUUI.widgets.key_entry)
  if to_encrypt and key then
    for _, ignore in ipairs(IUUI.enc_ignores) do
      if to_encrypt[ignore] then
        to_encrypt[ignore] = nil
      end
    end
    if not itemDescriptor.parameters.scripts then
      itemDescriptor.parameters.scripts = item_config.config.scripts
    end
    for i, script in ipairs(itemDescriptor.parameters.scripts) do
      if IUUI.enc_scripts[script] then
        itemDescriptor.parameters.scripts[i] = IUUI.enc_scripts[script]
      end
    end
    local encrypted = rc4.encrypt(to_encrypt, key)
    encrypted = hexlify(encrypted)
    local finalItem = {name = itemDescriptor.name, count = itemDescriptor.count, parameters = {encrypted = true, encryptedData = encrypted}}
    for _, ignore in ipairs(IUUI.enc_ignores) do
      if itemDescriptor.parameters[ignore] then
        finalItem.parameters[ignore] = itemDescriptor.parameters[ignore]
      end
    end
    player.giveItem(finalItem)
  end
end

function IUUI.updateItemFile()
  local file_name = widget.getText(IUUI.widgets.item_file_entry)
  if not file_name or file_name == "" then file_name = "item.json" end
  IUUI.item_file = file_name
end

function IUUI.updatePlayerInfo()
  local canvas = widget.bindCanvas(IUUI.widgets.player_info_canvas)
  canvas:clear()
  local sizeRect = {0, 0, canvas:size()[1], canvas:size()[2]}
  local playerRender = world.entityPortrait(player.id(), "full")
  for i, v in ipairs(playerRender) do
    pos = vec2.add(v.position, vec2.add({v.transformation[1][3], v.transformation[2][3]}, {21.5, 20.5}))
    canvas:drawImage(v.image..status.primaryDirectives(), vec2.sub(vec2.mul(pos, 3), {20, 0}), 3, v.color)
  end
  local titleformat = string.format("^shadow;%s^reset,shadow;, a %s %s\n^gray;%s", world.entityName(player.id()), player.species(), player.gender(), player.uniqueId())
  canvas:drawText(titleformat, {position = {43, 111}, horizontalAnchor = "mid", verticalAnchor = "bottom", wrapWidth = 86}, 8)
  local entidformat = string.format("^shadow;Entity ID: %s", player.id())
  canvas:drawText(entidformat, {position = {86, 111}}, 8, "white")
  local healthformat = string.format("^shadow;Health: %s%.0f/%.0f", lerpColor(status.resourcePercentage("health")),
                                     status.resource("health"), status.resourceMax("health"))
  canvas:drawText(healthformat, {position = {86, 101}}, 8, "red")
  local energyformat = string.format("^shadow;Energy: %s%.0f/%.0f", lerpColor(status.resourcePercentage("energy")),
                                     status.resource("energy"), status.resourceMax("energy"))
  canvas:drawText(energyformat, {position = {86, 91}}, 8, "green")
  local foodformat = string.format("^shadow;Food: %s%.0f/%.0f", lerpColor(status.resourcePercentage("food")),
                                     status.resource("food"), status.resourceMax("food"))
  canvas:drawText(foodformat, {position = {86, 81}}, 8, "orange")
  local playerpos = world.entityPosition(player.id())
  local posformat = string.format("^shadow;Position: %.0f X, %.0f Y", playerpos[1], playerpos[2])
  canvas:drawText(posformat, {position = {86, 71}}, 8, "white")
  local playervel = world.entityVelocity(player.id())
  local velformat = string.format("^shadow;Velocity: %.0f X, %.0f Y", playervel[1], playervel[2])
  canvas:drawText(velformat, {position = {86, 61}}, 8, "white")
end

function IUUI.canvasClickEvent(position, button, isButtonDown)
  sb.logInfo("%s", position)
end

function lerpColor(percentage)
  local color1 = {255, 73, 66}
  local color2 = {79, 255, 70}
  local finalcolor = {}
  for i, v in ipairs(color1) do
    finalcolor[i] = math.floor(util.lerp(percentage, color1[i], color2[i]))
  end
  return string.format("^#%02X%02X%02X;", finalcolor[1], finalcolor[2], finalcolor[3])
end