-- Factory methods for creating Slack simulator.
local FakeSlack = {}

function FakeSlack:buildChannel(name)
  local channel = {
    name = name,
    messages = {},
    inputValue = ''
  }

  function channel:keyStroke(modifiers, key)
    if #modifiers == 0 then
      if key == 'return' then
        table.insert(self.messages, self.inputValue)
        self.inputValue = ''
      else
        self.inputValue = self.inputValue .. key
      end
    end
  end

  return channel
end

function FakeSlack:buildInitialUI(slack)
  local initialUI = {}

  function initialUI:keyStroke(modifiers, key)
    if #modifiers == 1 and modifiers[1] == 'cmd' and key == 'K' then
      slack.currentUI = FakeSlack:buildChannelSelectorUI(slack)
    end
  end

  return initialUI
end

function FakeSlack:buildChannelSelectorUI(slack)
  local inputValue = ''

  local channelSelectorUI = {}
  function channelSelectorUI:keyStroke(modifiers, key)
    if #modifiers == 0 then
      if key == 'return' then
        slack.currentChannel = inputValue
        slack.currentUI = slack:getChannel(inputValue)
      else
        inputValue = inputValue .. key
      end
    end
  end

  return channelSelectorUI
end

function FakeSlack:build()
  local channels = {}

  local slack = {
    currentChannel = nil
  }

  slack.currentUI = self:buildInitialUI(slack)

  function slack:getChannel(name)
    if not channels[name] then
      channels[name] = FakeSlack:buildChannel(name)
    end

    return channels[name]
  end

  function slack:keyStroke(modifiers, key)
    self.currentUI:keyStroke(modifiers, key)
  end

  function slack:keyStrokes(key)
    for i = 1, #key do
      self:keyStroke({}, key:sub(i, i))
    end
  end

  return slack
end

FakeHammerspoon = {}

function FakeHammerspoon:build(macOs)
  return {
    application = {
      launchOrFocus = function(appName)
        macOs.focusedApplication = macOs:getApplication(appName)
      end
    },
    eventtap = {
      keyStroke = function(modifiers, key)
        macOs.focusedApplication:keyStroke(modifiers, key)
      end,
      keyStrokes = function(keys)
        macOs.focusedApplication:keyStrokes(keys)
      end
    }
  }
end

local function buildFakeMacOs()
  local applications = {
    Slack = FakeSlack:build()
  }

  local fakeMacOs = {
    focusedApplication = nil,
  }

  function fakeMacOs:getApplication(application)
    return applications[application]
  end

  _G.hs = FakeHammerspoon:build(fakeMacOs)

  return fakeMacOs
end

return buildFakeMacOs
