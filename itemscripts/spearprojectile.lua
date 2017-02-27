-- Spear projectile primary ability
-- Ripped from Nuru's Spear code for use on normal weapons.
SpearProjectile = WeaponAbility:new()

function SpearProjectile:init()
  self:reset()
  self.cooldownTimer = self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function SpearProjectile:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility 
    and self.fireMode == "primary" 
    and self.cooldownTimer == 0 
    and not status.resourceLocked("energy") then

    self:setState(self.windup)
  end
end

function SpearProjectile:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  animator.setParticleEmitterActive("charge", true)
  animator.playSound("charge")

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function SpearProjectile:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  local params = copy(self.projectileParameters)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  local position = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("blade", "projectileSource")))
  if not world.lineTileCollision(mcontroller.position(), position) then
    world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), {mcontroller.facingDirection() * math.cos(self.weapon.aimAngle), math.sin(self.weapon.aimAngle)}, self.trackSourceEntity, params)
    animator.setParticleEmitterActive("charge", false)
    animator.playSound("fire")
    status.overConsumeResource("energy", self.energyUsage)
  end

  util.wait(self.stances.fire.duration)

  self.cooldownTimer = self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function SpearProjectile:reset()
  animator.setParticleEmitterActive("charge", false)
end

function SpearProjectile:uninit()
  self:reset()
end
