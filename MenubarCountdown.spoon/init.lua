local MenubarCountdown = {
  name = 'Menubar Countdown',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

function MenubarCountdown.new(label, endTime, options)
  local countdown = {}
  if not options then
    options = {}
  end

  function countdown:start()
    countdown.menu = hs.menubar.new()
    countdown.endTime = endTime
    countdown.timer = hs.timer.doEvery(1, function()
      countdown:refreshUI()
      if (self:getRemainingTime() == 0) then
        if options.onFinish then
          options.onFinish()
        end
      end
    end)
    countdown.onFinish = options.onFinish

    countdown:refreshUI()
  end

  function countdown:refreshUI()
    remainingTime = self:getRemainingTime()

    minutes = math.floor(remainingTime / 60)
    hours = math.floor(minutes / 60)
    minutes = minutes % 60
    seconds = remainingTime % 60
    if hours > 0 then
      self.menu:setTitle(label .. ': ' .. string.format('%d:%02d:%02d', hours, minutes, seconds))
    else
      self.menu:setTitle(label .. ': ' .. string.format('%d:%02d', minutes, seconds))
    end
  end

  function countdown:getRemainingTime()
    return self.endTime - os.time()
  end

  function countdown:stop()
    self.menu:delete()
    self.timer:stop()
  end

  return countdown
end

return MenubarCountdown
