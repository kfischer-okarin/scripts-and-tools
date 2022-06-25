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
    countdown.menu:setTitle(label .. ': ' .. '1:00:00')
  end

  return countdown
end

return MenubarCountdown
