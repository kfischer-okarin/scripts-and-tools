local CSV = {
  name = 'CSV Processing',
  version = '1.0',
  author = 'Kevin Fischer',
  license = 'MIT',
  homepage = 'https://github.com/kfischer-okarin/hammerspoon-spoons'
}

local function split(string, sep)
  if sep == nil then
    sep = "%s"
  end

  local result = {}
  for match in string:gmatch("([^" .. sep .. "]+)") do
    table.insert(result, match)
  end
  return result
end

local function readCSVLine(line)
  return hs.fnutils.imap(split(line, ','), function(value)
    if value:sub(1, 1) == '"' then
      value = value:sub(2, -2)
      value = value:gsub('""', '"')
    end

    return value
  end)
end

--- CSV.readWithHeaders(string)
--- Function
--- Reads a CSV string and returns a list of tables with the headers as keys.
---
--- Parameters:
---  * string - CSV String
---
--- Returns:
---  * A list of tables. Each element in the list is a table with the headers as keys and the respective values as values.
CSV.readWithHeaders = function(string)
  lines = split(string, '\n')
  headers = readCSVLine(lines[1])
  result = {}
  for i = 2, #lines do
    line = readCSVLine(lines[i])
    csvLine = {}
    for j = 1, #line do
      csvLine[headers[j]] = line[j]
    end
    table.insert(result, csvLine)
  end
  return result
end

return CSV
