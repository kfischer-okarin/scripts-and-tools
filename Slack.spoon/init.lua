local Slack = {
  name = 'Slack',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

local function sleep(n)
  os.execute('sleep ' .. n)
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
  sleep(0.1)
  hs.eventtap.keyStrokes(command)
  sleep(0.1)
  hs.eventtap.keyStroke({}, 'return')
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
  sleep(0.1)
  hs.eventtap.keyStrokes(channel)
  sleep(0.1)
  hs.eventtap.keyStroke({}, 'return')
  sleep(0.1)
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
  sleep(0.1)
end

return Slack
