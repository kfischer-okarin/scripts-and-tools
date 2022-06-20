local function buildFakeSlack()
  local fakeSlack = {
    currentChannel = nil,
    channels = {}
  }

  function fakeSlack:getChannel(name)
    if not self.channels[name] then
      self.channels[name] = self:buildChannel(name)
    end

    return self.channels[name]
  end

  local nothingFocused = {}
  function nothingFocused:keyStroke(modifiers, key)
    if #modifiers == 1 and modifiers[1] == 'cmd' and key == 'K' then
      fakeSlack.currentUI = fakeSlack:buildChannelSelector()
    end
  end

  function fakeSlack:buildChannelSelector()
    local inputValue = ''

    local channelSelector = {}
    function channelSelector:keyStroke(modifiers, key)
      if #modifiers == 0 then
        if key == 'return' then
          fakeSlack.currentChannel = inputValue
          fakeSlack.currentUI = fakeSlack:getChannel(inputValue)
        else
          inputValue = inputValue .. key
        end
      end
    end

    return channelSelector
  end

  function fakeSlack:buildChannel(name)
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

  fakeSlack.currentUI = nothingFocused

  function fakeSlack:keyStroke(modifiers, key)
    self.currentUI:keyStroke(modifiers, key)
  end

  function fakeSlack:keyStrokes(key)
    for i = 1, #key do
      self:keyStroke({}, key:sub(i, i))
    end
  end

  return fakeSlack
end


local function buildFakeMacOs()
  local applications = {
    Slack = buildFakeSlack()
  }

  local fakeMacOs = {
    focusedApplication = nil,
  }

  function fakeMacOs:getApplication(application)
    return applications[application]
  end

  _G.hs = {
    application = {
      launchOrFocus = function(appName)
        fakeMacOs.focusedApplication = fakeMacOs:getApplication(appName)
      end
    },
    eventtap = {
      keyStroke = function(modifiers, key)
        fakeMacOs.focusedApplication:keyStroke(modifiers, key)
      end,
      keyStrokes = function(keys)
        fakeMacOs.focusedApplication:keyStrokes(keys)
      end
    }
  }

  return fakeMacOs
end

return buildFakeMacOs
