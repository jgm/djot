local djot = require("djot")
local to_html = function(s)
  local doc = djot.parse(s)
  return djot.render_html(doc)
end
local signal = require("posix.signal")
local resource = require("posix.sys.resource")
local times = require 'posix.sys.times'.times

-- if you want to be able to interrupt stuck fuzz tests.

math.randomseed(os.time())

local MAXLINES = 5
local MAXLENGTH = 5
local NUMTESTS = arg[1] or 200000

local activechars = {
  '\t', ' ', '[', ']', '1', '2', 'a', 'b',
  'A', 'B', 'I', 'V', 'i', 'v', '.', ')', '(',
  '{', '}', '=', '+', '_', '-', '*', '!', '>',
  '<', '`', '~'
}

local function randomstring()
  local numlines = math.random(1,MAXLINES)
  local buffer = {}
  for j=1,numlines do
    -- -1 to privilege blank lines
    local res = ""
    local len = math.random(-1,MAXLENGTH)
    if len < 0 then len = 0 end
    for i=1,len do
      local charclass = math.random(1, 4)
      if charclass < 4 then
        res = res .. activechars[math.random(1, #activechars)]
      elseif utf8 then
        res = res .. utf8.char(math.random(1, 200))
      else
        res = res .. string.char(math.random(1, 127))
      end
    end
    buffer[#buffer + 1] = res
  end
  local res = table.concat(buffer, "\n")
  return res
end

local failures = 0

io.stderr:write("Running fuzz tests: ")
for i=1,NUMTESTS do
  local s = randomstring()
  if i % 1000 == 0 then
    io.stderr:write(".");
  end
  local ok, err = pcall(function ()
    signal.signal(signal.SIGINT, function(signum)
     io.stderr:write(string.format("\nInterrupted processing on input %q\n", s))
     io.stderr:flush()
     os.exit(128 + signum)
    end)
    return to_html(s)
  end)
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
    io.stderr:write(string.format("\nFAILURE on\n%q\n", s))
    io.stderr:write(err .. "\n")
  end
end

io.stderr:write("\n")
os.exit(failures)

