local djot = require("djot")
local to_html = djot.djot_to_html
math.randomseed(os.time())

local function randomstring(len)
  local res = ""
  for i=1,len do
    res = res .. string.char(math.random(1, 127))
  end
  return res
end

local LENGTH = 128
local NUMTESTS = 50000
local failures = 0

for i=1,NUMTESTS do
  local s = randomstring(LENGTH)
  local ok, err = pcall(function () return to_html(s) end)
  if ok then
    if i % 1000 == 0 then
      io.stderr:write("Completed " .. i .. " tests.\n")
    end
  else
    failures = failures + 1
    io.stderr:write(string.format("\nFAILURE on\n%s\n", s))
    io.stderr:write(err .. "\n")
  end
end

io.stderr:write("\n")
os.exit(failures)

