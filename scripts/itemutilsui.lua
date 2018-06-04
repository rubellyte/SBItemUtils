require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/JSON.lua"
require "/scripts/cryptomanager.lua"

itemUtilsUI = {}

IUUI = itemUtilsUI

IUUI.itemDirectory = ""

IUUI.itemSubdir = ""

IUUI.itemFile = "item.json"

IUUI.playerUpdateInterval = 1 / 60

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
  "tooltipFields",
  "seed"
}

IUUI.enc_scripts = {
  ["/items/active/weapons/melee/meleeweapon.lua"] = "/itemscripts/meleeweapon_plus.lua",
  ["/items/active/weapons/melee/energymeleeweapon.lua"] = "/itemscripts/energymeleeweapon_plus.lua",
  ["/items/active/weapons/ranged/gun.lua"] = "/itemscripts/gun_plus.lua",
  ["/items/active/weapons/staff/staff.lua"] = "/itemscripts/staff_plus.lua",
  ["/items/active/weapons/other/magnorbs/magnorbs.lua"] = "/itemscripts/magnorbs_plus.lua",
  ["magnorbs.lua"] = "/itemscripts/magnorbs_plus.lua"
}


IUUI.settingsOpen = false

JSON.strictTypes = true

function init()
  IUUI.useIo = not not io
  IUUI.itemDirectory = status.statusProperty("IUUI.itemDirectory", "")
  IUUI.itemSubdir = status.statusProperty("IUUI.itemSubdir", "")
  IUUI.playerUpdateInterval = status.statusProperty("IUUI.playerUpdateInterval", 1/60)
  IUUI.mainWidgets = config.getParameter("mainWidgets")
  IUUI.settingsWidgets = config.getParameter("settingsWidgets")
  if not IUUI.useIo then
    widget.setButtonEnabled("exportItem", false)
  end
  IUUI.updateItemFile()
  IUUI.updateTimer = IUUI.playerUpdateInterval
  IUUI.updatePlayerInfo()
end

function update(dt)
  IUUI.updateTimer = math.max(IUUI.updateTimer - dt, 0)
  if IUUI.updateTimer == 0 then
    IUUI.updateTimer = IUUI.playerUpdateInterval
    IUUI.updatePlayerInfo()
  end
end

function IUUI.toggleSettings()
  if IUUI.settingsOpen then
    for i, v in ipairs(IUUI.mainWidgets) do
      widget.setVisible(v, true)
    end
    for i, v in ipairs(IUUI.settingsWidgets) do
      widget.setVisible(v, false)
    end
    IUUI.settingsOpen = false
  else
    local turnOff = IUUI.useIo and {"subdirLabel", "subdirBox"} or {"itemDirLabel", "itemDirBox"}
    for i, v in ipairs(IUUI.mainWidgets) do
      widget.setVisible(v, false)
    end
    for i, v in ipairs(IUUI.settingsWidgets) do
      widget.setVisible(v, true)
    end
    for i, v in ipairs(turnOff) do
      widget.setVisible(v, false)
    end
    widget.setText("itemDirBox", IUUI.itemDirectory)
    widget.setText("subdirBox", IUUI.itemSubdir)
    widget.setText("canvasUpdateBox", IUUI.playerUpdateInterval)
    IUUI.settingsOpen = true
  end
end

function IUUI.importItem()
  if IUUI.useIo then
    if IUUI.itemDirectory == "" then
      sb.logError("ItemUtils: Import failed, no item directory configured!")
      return
    end
    local readfile = io.open(IUUI.itemDirectory..IUUI.itemFile, "r")
    if readfile ~= nil then
      local textData = readfile:read("*a")
      local itemDescriptor = JSON:decode(textData)
      readfile:close()
      player.giveItem(itemDescriptor)
    else
      sb.logError("ItemUtils: Error opening import file; confirm that directory exists?\n File: %s%s", IUUI.itemDirectory, IUUI.itemFile)
    end
  else
    if IUUI.itemSubdir == "" then
      sb.logError("ItemUtils: No item subdirectory configured!")
      return
    end
    local itemDescriptor = root.assetJson(IUUI.itemSubdir..IUUI.itemFile)
    player.giveItem(itemDescriptor)
  end
end

function IUUI.exportItem()
  if IUUI.itemDirectory == "" then
    sb.logError("ItemUtils: Export failed, no item directory configured!")
    return
  end
  local itemDescriptor = player.swapSlotItem()
  if itemDescriptor ~= nil then
    local towrite = sb.printJson(itemDescriptor, 2)
    local writefile = io.open(IUUI.itemDirectory..IUUI.itemFile, "w")
    if writefile ~= nil then
      writefile:write(towrite)
      writefile:close()
      pane.playSound("/sfx/interface/item_pickup.ogg")
    else
      sb.logError("ItemUtils: Error opening export file; confirm that directory exists?\n Directory: %s", IUUI.itemDirectory)
      return
    end
  end
end

function IUUI.dupeItem()
  local itemDescriptor = player.swapSlotItem()
  if itemDescriptor ~= nil then
    player.giveItem(itemDescriptor)
  end
end

function IUUI.encryptItem()
  local itemDescriptor = player.swapSlotItem()
  if not itemDescriptor then return end
  local to_encrypt = copy(itemDescriptor.parameters)
  local item_config = root.itemConfig(itemDescriptor)
  local key = widget.getText("keyEntryBox")
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
    local encrypted = crypto.encrypt(to_encrypt, key)
    local finalItem = {name = itemDescriptor.name, count = itemDescriptor.count, parameters = {encrypted = true, cryptoVersion = 3, encryptedData = encrypted}}
    for _, ignore in ipairs(IUUI.enc_ignores) do
      if itemDescriptor.parameters[ignore] then
        finalItem.parameters[ignore] = itemDescriptor.parameters[ignore]
      end
    end
    player.giveItem(finalItem)
    if IUUI.useIo then
      local keyPath = status.statusProperty("keyPath", "../mods/ItemUtils/keys.json")
      local keyFile = io.open(keyPath, "r")
      if keyFile then
        local keys = JSON:decode(keyFile:read("*a"))
        keyFile:close()
        keys[finalItem.parameters.shortdescription] = key
        keyFile = io.open(keyPath, "w")
        keyFile:write(JSON:encode_pretty(keys))
        keyFile:close()
      end
    end
  end
end

function IUUI.openKeyManager()
  player.interact("ScriptPane", "/interface/scripted/keyManager/keyManager.config")
  pane.dismiss()
end

function IUUI.updateItemFile()
  local file_name = widget.getText("pathEntryBox")
  if not file_name or file_name == "" then file_name = "item.json" end
  IUUI.itemFile = file_name
end

function IUUI.updateItemDir()
  local path = widget.getText("itemDirBox")
  if not path then path = "" end
  IUUI.itemDirectory = path
  status.setStatusProperty("IUUI.itemDirectory", path)
end

function IUUI.updateSubdir()
  local path = widget.getText("itemSubdirBox")
  if not path then path = "" end
  IUUI.itemSubdir = path
  status.setStatusProperty("IUUI.itemSubdir", path)
end

function IUUI.updateCanvasRate()
  local rate = widget.getText("canvasUpdateBox")
  rate = tonumber(rate)
  if not rate then rate = 60 end
  rate = 1 / rate
  IUUI.playerUpdateInterval = rate
  status.setStatusProperty("IUUI.playerUpdateInterval", rate)
end

function IUUI.updatePlayerInfo()
  local canvas = widget.bindCanvas("playerInfo")
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

function lerpColor(percentage)
  local color1 = {255, 73, 66}
  local color2 = {79, 255, 70}
  local finalcolor = {}
  for i, v in ipairs(color1) do
    finalcolor[i] = math.floor(util.lerp(percentage, color1[i], color2[i]))
  end
  return string.format("^#%02X%02X%02X;", finalcolor[1], finalcolor[2], finalcolor[3])
end