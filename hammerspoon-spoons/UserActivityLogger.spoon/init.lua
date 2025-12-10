local UserActivityLogger = {
  name = 'User Activity Logger',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

local fs   = hs.fs
local json = hs.json

local dataDir = (os.getenv("HOME") or "~") .. "/.local/share/UserActivityLogger"

-- Initialize logging
if not fs.attributes(dataDir, "mode") then
  fs.mkdir(dataDir)
end

-- Convenience helpers (optional)
function UserActivityLogger.logAppActive(app)
  logMessage(UserActivityLogger.LogMessage.appActive(app))
end

function UserActivityLogger.logSystemMessage(message)
  logMessage(UserActivityLogger.LogMessage.systemMessage(message))
end

function UserActivityLogger.logWindowFocus(app, window)
  logMessage(UserActivityLogger.LogMessage.windowFocus(app, window))
end

function logMessage(message)
  appendToDailyLogFile(orderedToJson(message))
end

-- LogMessage "enum" and constructors
UserActivityLogger.LogMessage = {}

function UserActivityLogger.LogMessage.appActive(app)
  return buildLogMessage("appActive", { "app", app })
end

function UserActivityLogger.LogMessage.systemMessage(message)
  return buildLogMessage("systemMessage", { "message", message })
end

function UserActivityLogger.LogMessage.windowFocus(app, window)
  return buildLogMessage("windowFocus", { "app", app }, { "window", window })
end

function buildLogMessage(type, ...)
  return {
    { "timestamp", isoTimestamp() },
    { "type",      type },
    ...
  }
end

-- ISO8601 local timestamp, e.g. 2025-08-04T12:34:56+09:00
function isoTimestamp()
  local off = os.date("%z")        -- "+0900"
  local offWithColon = off:sub(1,3) .. ":" .. off:sub(4,5)
  return os.date("%Y-%m-%dT%H:%M:%S") .. offWithColon
end

-- Convert ordered pairs to a JSON object string, preserving pair order
function orderedToJson(pairs)
  local parts = {}
  for _, kv in ipairs(pairs) do
    local k, v = kv[1], kv[2]
    local vjson = jsonLiteral(v)
    if vjson ~= nil then
      -- %q yields a properly escaped Lua string literal with double quotes,
      -- which is also valid for JSON keys.
      table.insert(parts, string.format("%q:%s", k, vjson))
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Encode a value as a JSON literal; fall back to wrapping in an array and trimming
function jsonLiteral(v)
  local ok, encoded = pcall(json.encode, v)
  if ok and encoded ~= nil then return encoded end

  ok, encoded = pcall(json.encode, { v })
  if ok and encoded and #encoded >= 2 then
    return encoded:sub(2, -2) -- trim '[' and ']'
  end

  return nil
end

function appendToDailyLogFile(line)
  if not dataDir then
    hs.alert.show("UserActivityLogger: No data directory specified")
    return
  end

  local currentDate = os.date("%Y-%m-%d")
  local path = string.format("%s/activity-%s.log", dataDir, currentDate)

  local f = io.open(path, "a")
  if f then
    f:write(line, "\n")
    f:close()
  end
end

return UserActivityLogger
