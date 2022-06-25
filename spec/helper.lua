function find(table, condition)
  for i, v in ipairs(table) do
    if condition(v) then
      return v
    end
  end
  return nil
end
