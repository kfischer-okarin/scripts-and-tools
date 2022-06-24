local Slack = {
  name = 'Slack',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

local function waitForUI()
  os.execute('sleep 0.3')
end

--- Slack:setStatus(message[, emote])
--- Method
--- Sets status on Slack.
---
--- Parameters:
---  * message - The status message to set
---  * emote - The emote to use (for example `:bento:`)
---
--- Returns:
---  * None
function Slack:setStatus(message, emote)
  if emote then
    Slack:sendSlackbotCommand('status ' .. emote .. ' ' .. message)
  else
    Slack:sendSlackbotCommand('status ' .. message)
  end
end

--- Slack:clearStatus()
--- Method
--- Clears status on Slack.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Slack:clearStatus()
  Slack:sendSlackbotCommand('clear')
end

--- Slack:toggleAway()
--- Method
--- Toggles away status on Slack.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Slack:toggleAway()
  Slack:sendSlackbotCommand('away')
end

--- Slack:sendSlackbotCommand(command)
--- Method
--- Sends a command to Slackbot
---
--- Parameters:
---  * command - Command and arguments (without leading `/`)
---
--- Returns:
---  * None
function Slack:sendSlackbotCommand(command)
  Slack:openChannel('Slackbot')
  hs.eventtap.keyStroke({}, '/')
  waitForUI()
  hs.eventtap.keyStrokes(command)
  waitForUI()
  hs.eventtap.keyStroke({}, 'return')
  waitForUI()
end

--- Slack:sendMessageToChannel(command)
--- Method
--- Sends a message to a slack channel.
---
--- Parameters:
---  * channel - Channel name
---  * message - Message to send
---
--- Returns:
---  * None
function Slack:sendMessageToChannel(channel, message)
  Slack:openChannel(channel)
  hs.eventtap.keyStrokes(message)
  hs.eventtap.keyStroke({}, 'return')
end

--- Slack:openChannel(command)
--- Method
--- Opens a slack channel.
---
--- Parameters:
---  * channel - Channel name
---
--- Returns:
---  * None
function Slack:openChannel(channel)
  Slack:focus()
  hs.eventtap.keyStroke({'cmd'}, 'K')
  waitForUI()
  hs.eventtap.keyStrokes(channel)
  waitForUI()
  hs.eventtap.keyStroke({}, 'return')
  waitForUI()
end

--- Slack:focus()
--- Method
--- Focuses Slack.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Slack:focus()
  hs.application.launchOrFocus('Slack')
  waitForUI()
end

return Slack
