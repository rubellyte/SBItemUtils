require "/scripts/util.lua"
require "/scripts/arcfour.lua"
itemUtilsUI = {}

IUUI = itemUtilsUI

IUUI.mod_directory = "D:/Steam/steamapps/common/Starbound/mods/ItemUtils"

IUUI.item_subdir = "/items/"

IUUI.item_file = "item.json"

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
  key_entry = "IUUIKeyEntry"
}

function IUUI.init()
  mui.setTitle("^shadow;ItemUtils UI", "^shadow;Import/export/dupe/encrypt items.")
  if not io then
    widget.setButtonEnabled("exportItem", false)
  end
  IUUI.updateItemFile()
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