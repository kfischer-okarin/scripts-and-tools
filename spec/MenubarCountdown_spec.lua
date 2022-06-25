require('spec.helper')
buildFakeMacOs = require('spec.fake_mac_os')

MenubarCountdown = loadfile('MenubarCountdown.spoon/init.lua')()

describe('MenubarCountdown.spoon', function()
  before_each(function()
    _G.fakeMacOs = buildFakeMacOs()
    fakeMacOs:freezeTime()
  end)

  after_each(function()
    fakeMacOs:unfreezeTime()
  end)

  describe('Started Countdown', function()
    it('shows the countdown in the menubar', function()
      countdown = MenubarCountdown.new(
        'Countdown',
        os.time() + 60 * 60
      )
      countdown:start()

      menu = find(
        fakeMacOs.menubarItems,
        function(item)
          return item.title == 'Countdown: 1:00:00'
        end
      )
      assert.is_not_nil(menu)

      fakeMacOs:advanceTime(1)

      assert.is_equal(
        'Countdown: 59:59',
        menu.title
      )
    end)
  end)
end)
