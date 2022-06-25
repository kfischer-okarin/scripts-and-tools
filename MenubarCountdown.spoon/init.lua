local MenubarCountdown = {
  name = 'Menubar Countdown',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

function MenubarCountdown.new(label, endTime)
  local countdown = {}

  function countdown:start()
    countdown.menu = hs.menubar.new()
    countdown.endTime = endTime
    countdown.timer = hs.timer.doEvery(1, function()
      countdown:refreshUI()
    end)

    countdown:refreshUI()
  end

  function countdown:refreshUI()
    timeUntilEnd = self.endTime - os.time()

    minutes = math.floor(timeUntilEnd / 60)
    hours = math.floor(minutes / 60)
    minutes = minutes % 60
    seconds = timeUntilEnd % 60
    if hours > 0 then
      self.menu:setTitle(label .. ': ' .. string.format('%d:%02d:%02d', hours, minutes, seconds))
    else
      self.menu:setTitle(label .. ': ' .. string.format('%d:%02d', minutes, seconds))
    end
  end

  function countdown:stop()
    self.menu:delete()
    self.timer:stop()
  end

  return countdown
end

return MenubarCountdown
