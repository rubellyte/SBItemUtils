require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

Hitscan = WeaponAbility:new()

function Hitscan:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.impactSoundTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    self.weapon:setStance(self.stances.idle)
  end
end

function Hitscan:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.fire)
  end
end

function Hitscan:fire()
  self.weapon:setStance(self.stances.fire)

  local wasColliding = false
  
  self.beamStart = self:firePosition()
  self.beamEnd = vec2.add(self.beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
  self.beamFinalLength = self.beamLength
  sb.logInfo("%s\n%s", self.beamStart, self.beamEnd)

  self.collidePoint = world.lineCollision(self.beamStart, self.beamEnd)
  if not self.piercing then
    local ents = world.entityLineQuery(self.beamStart, self.collidePoint or self.beamEnd, {order = "nearest", includedTypes = {"creature"}})
    local finalent
    for _, ent in ipairs(ents) do
      if world.entityCanDamage(activeItem.ownerEntityId(), ent) then
        finalent = ent
        break 
      end
    end
    if finalent and world.entityExists(finalent) then
      self.collidePoint = world.entityPosition(finalent)
    end
  end
  if self.collidePoint then
    self.beamEnd = self.collidePoint

    self.beamFinalLength = world.magnitude(self.beamStart, self.beamEnd)

    animator.resetTransformationGroup("beamEnd")
    animator.translateTransformationGroup("beamEnd", {self.beamFinalLength, 0})

    if self.impactSoundTimer == 0 then
      self.impactSoundTimer = self.fireTime
    end
  end

  self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + self.beamFinalLength, self.weapon.muzzleOffset[2]}}, self.fireTime)
  self:fireProjectile(self.beamEnd)
  util.wait(0.03)

  self:muzzleFlash()
  self:reset()

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function Hitscan:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()  

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    local newChain = copy(self.tracer)

    if newChain then
      if self.collidePoint then newChain.endSegmentImage = nil end
      
      newChain.startPosition = vec2.add(self.beamStart, newChain.startOffset)
      newChain.endPosition = vec2.add(self.beamEnd, newChain.endOffset)
      
      local fade = math.floor((1 - progress) * 255)
      local directive = string.format("?multiply=ffffff%02x", fade)
      
      newChain.segmentImage = newChain.segmentImage..directive
      if newChain.endSegmentImage then
        newChain.endSegmentImage = newChain.endSegmentImage..directive
      end

      activeItem.setScriptedAnimationParameter("chains", {newChain})
    end
    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function Hitscan:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function Hitscan:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function Hitscan:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  if self.abilitySlot == "primary" then
    animator.playSound("fire")
  else
    animator.playSound("altFire")
  end

  animator.setLightActive("muzzleFlash", true)
end

function Hitscan:fireProjectile(pos)
  local params = copy(self.projectileParameters)
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  world.spawnProjectile(self.projectileType,
                        pos, 
                        activeItem.ownerEntityId(), 
                        self:aimVector(0), 
                        false, 
                        params)
end

function Hitscan:uninit()
  self:reset()
end

function Hitscan:reset()
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
end

function Hitscan:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end