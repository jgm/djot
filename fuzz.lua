local djot = require("djot")
local to_html = function(s)
  local doc = djot.parse(s)
  return doc:render_html()
end

math.randomseed(os.time())

local MAXLENGTH = 128
local NUMTESTS = 100000

local activechars = {
  '\n', '\t', ' ', '[', ']', '1', '2', 'a', 'b',
  'A', 'B', 'I', 'V', 'i', 'v', '.', ')', '(',
  '{', '}', '=', '+', '_', '-', '*', '!', '>',
  '<', '`', '~'
}

local function randomstring()
  local res = ""
  local len = math.random(0,MAXLENGTH)
  for i=1,len do
    local charclass = math.random(1, 2)
    if charclass == 1 then
      res = res .. activechars[math.random(1, #activechars)]
    elseif utf8 then
      res = res .. utf8.char(math.random(1, 200))
    else
      res = res .. string.char(math.random(1, 127))
    end
  end
  return res
end

local failures = 0

io.stderr:write("Running fuzz tests: ")
for i=1,NUMTESTS do
  local s = randomstring()
  if i % 1000 == 0 then
    io.stderr:write(".");
  end
  local ok, err = pcall(function () return to_html(s) end)
  if not ok then
    -- try to minimize case
    local minimal = false
    local trim_from_front = true
    while not minimal do
      local s2
      if trim_from_front then
        s2 = string.sub(s, 2, -1)
      else
        s2 = string.sub(s, 1, -2)
      end
      local ok2, _ = pcall(function () return to_html(s2) end)
      if ok2 then
        if trim_from_front then
          trim_from_front = false
        else
          minimal = true
        end
      else
        s = s2
      end
    end
    failures = failures + 1
    io.stderr:write(string.format("\nFAILURE on\n%s\n", s))
    io.stderr:write(err .. "\n")
  end
end

io.stderr:write("\n")
os.exit(failures)

