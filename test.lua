-- run tests
package.path = "./?.lua;" .. package.path

local testcases = {
  "attributes.test",
  "blockquote.test",
  "code_blocks.test",
  "definition_lists.test",
  "emoji.test",
  "emphasis.test",
  "escapes.test",
  "fenced_divs.test",
  "footnotes.test",
  "headings.test",
  "insert_delete_mark.test",
  "links_and_images.test",
  "lists.test",
  "math.test",
  "para.test",
  "raw.test",
  "regression.test",
  "smart.test",
  "spans.test",
  "super_subscript.test",
  "tables.test",
  "task_lists.test",
  "thematic_breaks.test",
  "verbatim.test"
}

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
  local doc = djot.parse(inp)
  local actual
  if self.verbose then
    io.write(string.format("Testing %s at linen %d\n", file, linenum))
  end
  if renderer == "[html]" then
    actual = doc:render_html()
  elseif renderer == "[matches]" then
    actual = doc:render_matches()
  elseif renderer == "[ast]" then
    actual = doc:render_ast()
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


local tests = Tests:new()
local starttime = os.clock()
for _,case in ipairs(testcases) do
  if not opts.pattern or string.find(case, opts.pattern) then
    tests:do_tests(case)
  end
end
local endtime = os.clock()

dofile("testfilters.lua")(tests)

io.write(string.format("%d tests completed in %0.3f s\n",
          tests.passed + tests.failed + tests.errors, endtime - starttime))
io.write(string.format("PASSED: %4d\n", tests.passed))
io.write(string.format("FAILED: %4d\n", tests.failed))
io.write(string.format("ERRORS: %4d\n", tests.errors))
os.exit(tests.failed)

