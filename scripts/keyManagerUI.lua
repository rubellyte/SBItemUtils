require "/scripts/JSON.lua"

keyManager = {}
kM = keyManager

JSON.strictTypes = true

function init()
  local openedBy = config.getParameter("openedBy")
  kM.keyPath = status.statusProperty("keyPath", "../mods/ItemUtils/keys.json")
  widget.setText("keysPathBox", kM.keyPath)
  kM.updateKeysPath()
  widget.setButtonEnabled("editKeyBtn", false)
  widget.setButtonEnabled("removeKeyBtn", false)
  if openedBy then
    kM.openedByItem = true
    kM.openByItem(openedBy)
    widget.setVisible("backBtn", false)
  else
    widget.setVisible("backBtn", true)
  end
end

function uninit()
  if kM.validPath then kM.writeKeys() end
end

function kM.back()
  if kM.validPath then kM.writeKeys() end
  player.interact("ScriptPane", "/interface/scripted/itemUtilsUI/itemUtilsUI.config")
  pane.dismiss()
end

function kM.updateKeyList()
  widget.clearListItems("keyScroll.keyList")
  for k,v in pairs(kM.keys) do
    local ls = "keyScroll.keyList"
    local li = widget.addListItem(ls)
    widget.setText(ls.."."..li..".keyName", "^shadow;"..k)
    widget.setText(ls.."."..li..".keyKey", "^shadow;"..v)
    widget.setData(ls.."."..li, {[k] = v})
  end
  widget.setButtonEnabled("editKeyBtn", false)
  widget.setButtonEnabled("removeKeyBtn", false)
  kM.selectedKey = nil
end

function kM.keySelected()
  local li = widget.getListSelected("keyScroll.keyList")
  if not li then return end
  if kM.validPath then
    widget.setButtonEnabled("editKeyBtn", true)
    widget.setButtonEnabled("removeKeyBtn", true)
  end
  local data = widget.getData("keyScroll.keyList."..li)
  for k,v in pairs(data) do -- iterate through the single key table
    kM.selectedKey = {id = li, name = k, key = v}
  end
end

function kM.addKey()
  local itemName = kM.getHeldItemName()
  kM.showKeyEditor(false, itemName)
end

function kM.editKey()
  if not kM.selectedKey then return end
  kM.showKeyEditor(true, kM.selectedKey.name, kM.selectedKey.key)
end

function kM.removeKey()
  if not kM.selectedKey then return end
  kM.keys[kM.selectedKey.name] = nil
  kM.writeKeys()
  kM.updateKeyList()
end

function kM.openByItem(name)
  if kM.keys[name] then
    kM.showKeyEditor(true, name, kM.keys[name])
  else
    kM.showKeyEditor(false, name)
  end
end

function kM.showKeyEditor(editing, name, key)
  widget.setVisible("editKeyFrame", true)
  widget.focus("editKeyFrame.name")
  if editing then
    widget.setText("editKeyFrame.title", "^shadow;Edit Key")
    widget.setText("editKeyFrame.name", name)
    widget.setText("editKeyFrame.key", key)
  else
    widget.setText("editKeyFrame.title", "^shadow;New Key")
    widget.setText("editKeyFrame.name", name)
  end
end

function kM.jumpToKey()
  widget.focus("editKeyFrame.key")
end

function kM.useHeldName()
  local name = kM.getHeldItemName()
  widget.setText("editKeyFrame.name", name)
end

function kM.finishKeyEdit()
  local name = widget.getText("editKeyFrame.name")
  local key = widget.getText("editKeyFrame.key")
  kM.keys[name] = key
  kM.writeKeys()
  kM.closeKeyEditor()
  kM.updateKeyList()
end

function kM.closeKeyEditor()
  widget.setText("editKeyFrame.name", "")
  widget.setText("editKeyFrame.key", "")
  widget.setVisible("editKeyFrame", false)
end

function kM.getHeldItemName()
  local item = player.swapSlotItem()
  if item then
    if item.parameters.shortdescription then return item.parameters.shortdescription
    else
      item = root.itemConfig(item)
      return item.config.shortdescription
    end
  else return "" end
end

function kM.updateKeysPath()
  local path = widget.getText("keysPathBox")
  local keys = io.open(path, "r")
  if keys then
    kM.keys = JSON:decode(keys:read("*a"))
    keys:close()
    kM.updateKeyList()
    kM.keyPath = path
    kM.validPath = true
    status.setStatusProperty("keyPath", path)
    widget.setButtonEnabled("addKeyBtn", true)
    widget.setVisible("keyPathError", false)
    if kM.selectedKey then
      widget.setButtonEnabled("editKeyBtn", true)
      widget.setButtonEnabled("removeKeyBtn", true)
    end
  else
    kM.validPath = false
    widget.setButtonEnabled("addKeyBtn", false)
    widget.setButtonEnabled("editKeyBtn", false)
    widget.setButtonEnabled("removeKeyBtn", false)
    widget.setVisible("keyPathError", true)
  end
end

function kM.writeKeys()
  local keys = assert(io.open(kM.keyPath, "w"))
  local towrite = JSON:encode_pretty(kM.keys)
  keys:write(towrite)
  keys:close()
end