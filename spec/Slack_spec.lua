buildHsMock = require('spec.hs_mock')

Slack = loadfile('Slack.spoon/init.lua')()

function expectCalls(...)
  local expectedCalls = table.pack(...)
  expectedCalls.n = nil

  assert.same(
    expectedCalls,
    calls
  )
end

describe('Slack.spoon', function()
  before_each(function()
    _G.hs, calls = buildHsMock()
  end)

  describe('focus()', function()
    it('focuses Slack', function()
      Slack:focus()

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'}
      )
    end)
  end)

  describe('openChannel()', function()
    it('focuses Slack and opens the correct channel', function()
      Slack:openChannel('general')

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'general'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)
  end)

  describe('sendMessageToChannel()', function()
    it('opens the correct channel and sends message', function()
      Slack:sendMessageToChannel('general', 'Hello')

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'general'},
        {'hs.eventtap.keyStroke', {}, 'return'},
        {'hs.eventtap.keyStrokes', 'Hello'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)
  end)

  describe('sendSlackbotCommand()', function()
    it('opens the Slackbot channel and sends the slash command', function()
      Slack:sendSlackbotCommand('remind me')

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'Slackbot'},
        {'hs.eventtap.keyStroke', {}, 'return'},
        {'hs.eventtap.keyStroke', {}, '/'},
        {'hs.eventtap.keyStrokes', 'remind me'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)
  end)

  describe('toggleAway()', function()
    it('sends the /away command', function()
      Slack:toggleAway()

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'Slackbot'},
        {'hs.eventtap.keyStroke', {}, 'return'},
        {'hs.eventtap.keyStroke', {}, '/'},
        {'hs.eventtap.keyStrokes', 'away'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)
  end)

  describe('setStatus()', function()
    it('can set a status without emote', function()
      Slack:setStatus('Lunch')

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'Slackbot'},
        {'hs.eventtap.keyStroke', {}, 'return'},
        {'hs.eventtap.keyStroke', {}, '/'},
        {'hs.eventtap.keyStrokes', 'status Lunch'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)

    it('can set a status with emote', function()
      Slack:setStatus('Lunch', ':bento:')

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'Slackbot'},
        {'hs.eventtap.keyStroke', {}, 'return'},
        {'hs.eventtap.keyStroke', {}, '/'},
        {'hs.eventtap.keyStrokes', 'status :bento: Lunch'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)
  end)

  describe('clearStatus()', function()
    it('sends the /clear command', function()
      Slack:clearStatus()

      expectCalls(
        {'hs.application.launchOrFocus', 'Slack'},
        {'hs.eventtap.keyStroke', {'cmd'}, 'K'},
        {'hs.eventtap.keyStrokes', 'Slackbot'},
        {'hs.eventtap.keyStroke', {}, 'return'},
        {'hs.eventtap.keyStroke', {}, '/'},
        {'hs.eventtap.keyStrokes', 'clear'},
        {'hs.eventtap.keyStroke', {}, 'return'}
      )
    end)
  end)
end)
