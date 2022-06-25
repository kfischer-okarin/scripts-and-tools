local originalTimeFunction = os.time

local function listEqual(list1, list2)
  if #list1 ~= #list2 then
    return false
  end
  for i = 1, #list1 do
    if list1[i] ~= list2[i] then
      return false
    end
  end
  return true
end

-- Factory methods for creating Slack simulator.
local FakeSlack = {}

function FakeSlack:buildChannel(name)
  local channel = {
    name = name,
    messages = {},
    inputValue = ''
  }

  function channel:keyStroke(modifiers, key)
    if listEqual(modifiers, {}) then
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
    if listEqual(modifiers, {'cmd'}) and key == 'K' then
      slack.currentUI = FakeSlack:buildChannelSelectorUI(slack)
    end
  end

  return initialUI
end

function FakeSlack:buildChannelSelectorUI(slack)
  local inputValue = ''

  local channelSelectorUI = {}
  function channelSelectorUI:keyStroke(modifiers, key)
    if listEqual(modifiers, {}) then
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
        if listEqual(modifiers, {'cmd'}) and key == 'V' then
          macOs.focusedApplication:keyStrokes(macOs.clipboard)
        else
          macOs.focusedApplication:keyStroke(modifiers, key)
        end
      end,
      keyStrokes = function(keys)
        macOs.focusedApplication:keyStrokes(keys)
      end
    },
    menubar = {
      new = function()
        local menubar = {
          title = nil
        }

        function menubar:setTitle(title)
          self.title = title
        end

        table.insert(macOs.menubarItems, menubar)
        return menubar
      end
    },
    pasteboard = {
      setContents = function(contents)
        macOs.clipboard = contents
      end,
      getContents = function()
        return macOs.clipboard
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
    clipboard = nil,
    currentTime = nil,
    menubarItems = {}
  }

  function fakeMacOs:getApplication(application)
    return applications[application]
  end

  function fakeMacOs:freezeTime()
    self.currentTime = os.time()
    os.time = function()
      return self.currentTime
    end
  end

  function fakeMacOs:unfreezeTime()
    os.time = originalTimeFunction
  end

  _G.hs = FakeHammerspoon:build(fakeMacOs)

  return fakeMacOs
end

return buildFakeMacOs
