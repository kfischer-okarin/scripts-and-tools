buildFakeMacOs = require('spec.fake_mac_os')

CSV = loadfile('CSV.spoon/init.lua')()

describe('CSV.spoon', function()
  before_each(function()
    buildFakeMacOs() -- to define hs
  end)

  describe('readWithHeaders()', function()
    it('reads the CSV', function()
      csvString =
        '"First Name","Last Name",Age\n' ..
        'John,Doe,42\n' ..
        '"Elvis ""The King""",Presley,42\n'

      parsed = CSV.readWithHeaders(csvString)

      assert.are.same({
        {
          ['First Name'] = 'John',
          ['Last Name'] = 'Doe',
          Age = '42'
        },
        {
          ['First Name'] = 'Elvis "The King"',
          ['Last Name'] = 'Presley',
          Age = '42'
        }
      }, parsed)
    end)
  end)
end)
