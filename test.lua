-- run tests
local lfs = require("lfs")
local djot = require("./djot")

local opts = {}
local i=1
while i <= #arg do
  local thisarg = arg[i]
  if string.find(thisarg, "^%-") then
    if thisarg == "-v" then
      opts.verbose = true
    elseif thisarg == "-p" then
      opts.pattern = true
    end
  elseif opts.pattern == true then
    opts.pattern = thisarg
  end
  i = i + 1
end

local Tests = {}

function Tests:new()
  local contents = {
    passed = 0,
    failed = 0,
    errors = 0,
    verbose = opts.verbose
  }
  setmetatable(contents, Tests)
  Tests.__index = Tests
  return contents
end

function Tests:do_test(file, linenum, renderer, inp, out)
  local parser = djot.Parser:new(inp)
  parser:parse()
  local actual
  if self.verbose then
    io.write(string.format("Testing %s at linen %d\n", file, linenum))
  end
  if renderer == "[html]" then
    actual = parser:render_html()
  elseif renderer == "[matches]" then
    actual = parser:render_matches()
  elseif renderer == "[ast]" then
    actual = parser:render_ast()
  end
  if actual == out then
    self.passed = self.passed + 1
    return true
  else
    io.write(string.format("FAILED at %s line %d\n", file, linenum))
    io.write(string.format("--- INPUT -------------------------------------\n%s--- EXPECTED ----------------------------------\n%s--- GOT ---------------------------------------\n%s-----------------------------------------------\n\n", inp, out, actual))
    self.failed = self.failed + 1
    return false, inp, out
  end
end

function Tests:do_tests(file)
  local f = io.open("test/" .. file,"r")
  assert(f ~= nil, "File " .. file .. " cannot be read")
  local line
  local linenum = 0
  while true do
    local inp = ""
    local out = ""
    line = f:read()
    linenum = linenum + 1
    while line and not line:match("^```") do
      line = f:read()
      linenum = linenum + 1
    end
    local testlinenum = linenum
    if not line then
      break
    end
    local ticks, modifier = line:match("^(`+)%s*(%S*)")
    local renderer = "[html]"
    if modifier and #modifier > 0 then
      renderer = modifier
    end
    line = f:read()
    linenum = linenum + 1
    while not line:match("^%.$") do
      inp = inp .. line .. "\n"
      line = f:read()
      linenum = linenum + 1
    end
    line = f:read()
    linenum = linenum + 1
    while not line:match("^" .. ticks) do
      out = out .. line .. "\n"
      line = f:read()
      linenum = linenum + 1
    end
    local ok, err = pcall(function()
          self:do_test(file, testlinenum, renderer, inp, out)
        end)
    if not ok then
      io.stderr:write(string.format("Error running test %s line %d:\n%s\n",
                                    file, linenum, err))
      self.errors = self.errors + 1
    end
  end
end

--[[
local test = function()
  local s = "a=b #ident\n.class\nkey=val1\n .class key2=\"val two \\\" ok\"}"
local parser = AttributeParser:new(s)
  local x,y = parser:feed(1,16)
  print(x,y)
  local x,y = parser:feed(17,#s)
  print(x,y)
  local matches = parser:get_matches()
  print(string.sub(parser.subject, y, y))
  print(require'inspect'(matches))
end

test()
--]]



local tests = Tests:new()
local starttime = os.clock()
for file in lfs.dir("test") do
  if string.match(file, "%.test") then
    if not opts.pattern or string.find(file, opts.pattern) then
      tests:do_tests(file)
    end
  end
end
local endtime = os.clock()

io.write(string.format("%d tests completed in %0.3f s\n",
          tests.passed + tests.failed + tests.errors, endtime - starttime))
io.write(string.format("PASSED: %4d\n", tests.passed))
io.write(string.format("FAILED: %4d\n", tests.failed))
io.write(string.format("ERRORS: %4d\n", tests.errors))
os.exit(tests.failed)

