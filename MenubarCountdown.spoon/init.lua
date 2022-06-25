local MenubarCountdown = {
  name = 'Menubar Countdown',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

--- MenubarCountdown.new(label, endTime[, options])
--- Constructor
--- Creates a countdown displayed in the menubar.
---
--- Parameters:
---  * label - Label displayed before the countdown
---  * endTime - Time (in seconds as returned from `os.time()`) when the countdown ends
---  * options - A table containing the following optional parameters:
---    * onFinish - A function to call when the countdown finishes
---    * onClick - A function to call when the countdown is clicked
---
--- Returns:
---  * a MenubarCountdown object
function MenubarCountdown.new(label, endTime, options)
  local countdown = {
    label = label,
    endTime = endTime,
  }
  if not options then
    options = {}
  end
  countdown.onFinish = options.onFinish
  countdown.onClick = options.onClick

  setmetatable(countdown, MenubarCountdown)
  MenubarCountdown.__index = MenubarCountdown

  return countdown
end

local function refreshUI(countdown)
  remainingTime = countdown:getRemainingTime()

  minutes = math.floor(remainingTime / 60)
  hours = math.floor(minutes / 60)
  minutes = minutes % 60
  seconds = remainingTime % 60
  if hours > 0 then
    countdown.menu:setTitle(countdown.label .. ': ' .. string.format('%d:%02d:%02d', hours, minutes, seconds))
  else
    countdown.menu:setTitle(countdown.label .. ': ' .. string.format('%d:%02d', minutes, seconds))
  end
end

--- MenubarCountdown:start()
--- Method
--- Starts and displays the countdown in the menubar.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function MenubarCountdown:start()
  self.menu = hs.menubar.new()
  if self.onClick then
    self.menu:setClickCallback(self.onClick)
  end
  self.timer = hs.timer.doEvery(1, function()
    refreshUI(self)
    if (self:getRemainingTime() == 0) then
      if self.onFinish then
        self.onFinish()
      end
    end
  end)

  refreshUI(self)
end


--- MenubarCountdown:getRemainingTime()
--- Method
--- Returns seconds until countdown finishes.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Seconds until countdown finishes
function MenubarCountdown:getRemainingTime()
  return self.endTime - os.time()
end

--- MenubarCountdown:stop()
--- Method
--- Stops and removes the countdown from the menubar.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function MenubarCountdown:stop()
  self.menu:delete()
  self.timer:stop()
end

return MenubarCountdown
