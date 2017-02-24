require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/arcfour.lua"
require "/scripts/activeitem/stances.lua"

function init()
  if config.getParameter("encrypted") then
    local encryptedData = config.getParameter("encryptedData")
    local keys = root.assetJson("/keys.json")
    local keyname = config.getParameter("shortdescription")
    if not keyname then
      sb.logInfo("%s", root.itemConfig(world.entityHandItemDescriptor(activeItem.ownerEntityId(), activeItem.hand())))
      keyname = root.itemConfig(world.entityHandItemDescriptor(activeItem.ownerEntityId(), activeItem.hand())).config.shortdescription
    end
    if keys[keyname] then
      self.decryptedData = rc4.decrypt(b64dec(config.getParameter("encryptedData")), true, keys[keyname])
      if not self.decryptedData then
        sb.logError("ItemUtils: Decryption for item \"%s\" with key \"%s\" failed!", keyname, keys[keyname])
        return
      end
    else
      sb.logError("ItemUtils: Key not found for item \"%s\"!", keyname)
      return
    end
    config.getConfigParameter = config.getParameter
    config.getParameter = function (key, default)
        if self.decryptedData[key] then
          return self.decryptedData[key]
        else
          return config.getConfigParameter(key, default)
        end
      end
  end
  activeItem.setCursor("/cursors/reticle0.cursor")

  self.projectileCount = config.getParameter("projectileCount", 3)
  self.projectileType = config.getParameter("projectileType")
  self.projectileParameters = config.getParameter("projectileParameters")
  self.projectileTypes = config.getParameter("projectileTypes", {})
  for i = 1, self.projectileCount do
    if #self.projectileTypes < i then
      self.projectileTypes[i] = {}
    end
    if not self.projectileTypes[i].type then
      self.projectileTypes[i].type = self.projectileType
    end
    if not self.projectileTypes[i].parameters then
      self.projectileTypes[i].parameters = self.projectileParameters
    end
  end
  self.projectileParameters.power = self.projectileParameters.power * root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1))
  self.cooldownTime = config.getParameter("cooldownTime", 0)
  self.cooldownTimer = self.cooldownTime
  self.orbitDistance = config.getParameter("orbitDistance", 0)
  self.shieldSpaceFactor = (0.075 * self.projectileCount) * config.getParameter("shieldSpaceFactor", 1)
  self.minimumShieldOrbs = config.getParameter("minimumShieldOrbs", self.projectileCount)
  self.autoFire = config.getParameter("autoFire", false)
  self.orbitPlayer = config.getParameter("orbitPlayer")
  self.defaultIds = {}
  
  initStances()

  for i = 1, self.projectileCount do
    self.defaultIds[i] = false
  end
  
  storage.projectileIds = storage.projectileIds or self.defaultIds
  checkProjectiles()

  self.orbitRate = config.getParameter("orbitRate", 1) * -2 * math.pi

  animator.resetTransformationGroup("orbs")
  for i = 1, self.projectileCount do
    animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
  end
  setOrbPosition(1, self.orbitDistance)

  self.shieldActive = false
  self.shieldTransformTimer = 0
  self.shieldTransformTime = config.getParameter("shieldTransformTime", 0.1)
  self.shieldPoly = animator.partPoly("glove", "shieldPoly")
  self.shieldEnergyCost = config.getParameter("shieldEnergyCost", 50)
  self.shieldHealth = 1000
  self.shieldKnockback = config.getParameter("shieldKnockback", 0)
  if self.shieldKnockback > 0 then
    self.knockbackDamageSource = {
      poly = self.shieldPoly,
      damage = 0,
      damageType = "Knockback",
      sourceEntity = activeItem.ownerEntityId(),
      team = activeItem.ownerTeam(),
      knockback = self.shieldKnockback,
      rayCheck = true,
      damageRepeatTimeout = 0.5
    }
  end

  setStance("idle")

  updateHand()
end

function update(dt, fireMode, shiftHeld)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  updateStance(dt)
  checkProjectiles()

  if fireMode == "alt" and availableOrbCount() >= self.minimumShieldOrbs and not status.resourceLocked("energy") and status.resourcePositive("shieldStamina") then
    if not self.shieldActive then
      activateShield()
    end
    setOrbAnimationState("shield")
    self.shieldTransformTimer = math.min(self.shieldTransformTime, self.shieldTransformTimer + dt)
  else
    self.shieldTransformTimer = math.max(0, self.shieldTransformTimer - dt)
    if self.shieldTransformTimer > 0 then
      setOrbAnimationState("unshield")
    end
  end

  if self.shieldTransformTimer == 0 and fireMode == "primary" and self.cooldownTimer == 0 then
    if ((not self.autoFire) and self.lastFireMode ~= "primary") or self.autoFire then
      local nextOrbIndex = nextOrb()
      if nextOrbIndex then
        fire(nextOrbIndex)
      end
    end
  end
  self.lastFireMode = fireMode

  if self.shieldActive then
    if not status.resourcePositive("shieldStamina") or not status.overConsumeResource("energy", self.shieldEnergyCost * dt) then
      deactivateShield()
    else
      self.damageListener:update()
    end
  end

  if self.shieldTransformTimer > 0 then
    local transformRatio = self.shieldTransformTimer / self.shieldTransformTime
    setOrbPosition(1 - transformRatio * (1 - self.shieldSpaceFactor), self.orbitDistance)
    animator.resetTransformationGroup("orbs")
    animator.translateTransformationGroup("orbs", {(transformRatio * -1.5) + (self.orbitDistance * transformRatio), 0})
    for i = 1, self.projectileCount do
      animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "shield" or "hidden")
    end
  else
    if self.shieldActive then
      deactivateShield()
      setOrbPosition(1, self.orbitDistance)
    end
    animator.resetTransformationGroup("orbs")
    animator.rotateTransformationGroup("orbs", -self.armAngle or 0)
    for i = 1, self.projectileCount do
      animator.rotateTransformationGroup("orb"..i, self.orbitRate * dt)
      animator.setAnimationState("orb"..i, storage.projectileIds[i] == false and "orb" or "hidden")
    end
  end

  updateAim()
  updateHand()
end

function uninit()
  activeItem.setItemShieldPolys()
  activeItem.setItemDamageSources()
  status.clearPersistentEffects("magnorbShield")
  animator.stopAllSounds("shieldLoop")
end

function nextOrb()
  for i = 1, self.projectileCount do
    if not storage.projectileIds[i] then
      return i
    end
  end
end

function availableOrbCount()
  local available = 0
  for i = 1, self.projectileCount do
    if not storage.projectileIds[i] then
      available = available + 1
    end
  end
  return available
end

function updateHand()
  local isFrontHand = (activeItem.hand() == "primary") == (mcontroller.facingDirection() < 0)
  animator.setGlobalTag("hand", isFrontHand and "front" or "back")
  activeItem.setOutsideOfHand(isFrontHand)
end

function fire(orbIndex)
  local params = copy(self.projectileTypes[orbIndex].parameters)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.ownerAimPosition = activeItem.ownerAimPosition()
  local firePos = firePosition(orbIndex)
  if world.lineCollision(mcontroller.position(), firePos) then return end
  local projectileId = world.spawnProjectile(
      self.projectileTypes[orbIndex].type,
      firePosition(orbIndex),
      activeItem.ownerEntityId(),
      aimVector(orbIndex),
      false,
      params
    )
  if projectileId then
    storage.projectileIds[orbIndex] = projectileId
    self.cooldownTimer = self.cooldownTime
    animator.playSound("fire")
  end
end

function firePosition(orbIndex)
  return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("orb"..orbIndex, "orbPosition")))
end

function aimVector(orbIndex)
  return vec2.norm(world.distance(activeItem.ownerAimPosition(), firePosition(orbIndex)))
end

function checkProjectiles()
  for i, projectileId in ipairs(storage.projectileIds) do
    if projectileId and not world.entityExists(projectileId) then
      storage.projectileIds[i] = false
    end
  end
end

function activateShield()
  self.shieldActive = true
  animator.resetTransformationGroup("orbs")
  animator.playSound("shieldOn")
  animator.playSound("shieldLoop", -1)
  setStance("shield")
  activeItem.setItemShieldPolys({self.shieldPoly})
  activeItem.setItemDamageSources({self.knockbackDamageSource})
  status.setPersistentEffects("magnorbShield", {{stat = "shieldHealth", amount = self.shieldHealth}})
  self.damageListener = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.hitType == "ShieldHit" then
        if status.resourcePositive("shieldStamina") then
          animator.playSound("shieldBlock")
        else
          animator.playSound("shieldBreak")
        end
        return
      end
    end
  end)
end

function deactivateShield()
  self.shieldActive = false
  animator.playSound("shieldOff")
  animator.stopAllSounds("shieldLoop")
  setStance("idle")
  activeItem.setItemShieldPolys()
  activeItem.setItemDamageSources()
  status.clearPersistentEffects("magnorbShield")
end

function setOrbPosition(spaceFactor, distance)
  for i = 1, self.projectileCount do
    animator.resetTransformationGroup("orb"..i)
    local distanceVector = {distance, 0}
    animator.translateTransformationGroup("orb"..i, distanceVector)
    animator.rotateTransformationGroup("orb"..i, 2 * math.pi * spaceFactor * ((i - ((self.projectileCount / 2) + 0.5)) / self.projectileCount))
  end
end

function setOrbAnimationState(newState)
  for i = 1, self.projectileCount do
    if animator.animationState("orb"..i) ~= "hidden" then
      animator.setAnimationState("orb"..i, newState)
    end
  end
end
