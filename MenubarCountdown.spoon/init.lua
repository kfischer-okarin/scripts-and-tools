local MenubarCountdown = {
  name = 'Menubar Countdown',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

function MenubarCountdown.new(label, endTime, options)
  local countdown = {
    label = label,
    endTime = endTime,
  }
  if not options then
    options = {}
  end
  countdown.onFinish = options.onFinish

  setmetatable(countdown, MenubarCountdown)
  MenubarCountdown.__index = MenubarCountdown

  return countdown
end

function MenubarCountdown:start()
  self.menu = hs.menubar.new()
  self.timer = hs.timer.doEvery(1, function()
    self:refreshUI()
    if (self:getRemainingTime() == 0) then
      if self.onFinish then
        self.onFinish()
      end
    end
  end)

  self:refreshUI()
end

function MenubarCountdown:refreshUI()
  remainingTime = self:getRemainingTime()

  minutes = math.floor(remainingTime / 60)
    hours = math.floor(minutes / 60)
  minutes = minutes % 60
  seconds = remainingTime % 60
  if hours > 0 then
    self.menu:setTitle(self.label .. ': ' .. string.format('%d:%02d:%02d', hours, minutes, seconds))
  else
    self.menu:setTitle(self.label .. ': ' .. string.format('%d:%02d', minutes, seconds))
  end
end

function MenubarCountdown:getRemainingTime()
  return self.endTime - os.time()
end

function MenubarCountdown:stop()
  self.menu:delete()
  self.timer:stop()
end

return MenubarCountdown
