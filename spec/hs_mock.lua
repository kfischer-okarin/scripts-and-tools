local function buildHsMock()
  local calls = {}

  local tableWithMethods = function(name, methods)
    local result = {}

    for _, method in ipairs(methods) do
      result[method] = function(...)
        table.insert(calls, {name .. '.' .. method, ...})
      end
    end

    return result
  end

  local hs = {
    application = tableWithMethods('hs.application', {'launchOrFocus'}),
    eventtap = tableWithMethods('hs.eventtap', {'keyStroke', 'keyStrokes'})
  }

  return hs, calls
end

return buildHsMock
