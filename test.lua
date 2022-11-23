-- run tests
package.path = "./?.lua;" .. package.path
local djot = require("./djot")

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

local opts = {}
local i=1
while i <= #arg do
  local thisarg = arg[i]
  if string.find(thisarg, "^%-") then
    if thisarg == "-v" then
      opts.verbose = true
    elseif thisarg == "-p" then
      opts.pattern = true
    elseif thisarg == "--accept" then
      opts.accept = true
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
    accept = opts.accept,
    verbose = opts.verbose
  }
  setmetatable(contents, Tests)
  Tests.__index = Tests
  return contents
end

function Tests:do_test(test)
  local doc = djot.parse(test.input)
  local actual
  if self.verbose then
    io.write(string.format("Testing %s at linen %d\n", test.file, test.linenum))
  end
  if test.renderer == "[html]" then
    actual = doc:render_html()
  elseif test.renderer == "[matches]" then
    actual = doc:render_matches()
  elseif test.renderer == "[ast]" then
    actual = doc:render_ast()
  end
  if self.accept then
    test.output = actual
  end
  if actual == test.output then
    self.passed = self.passed + 1
    return true
  else
    io.write(string.format("FAILED at %s line %d\n", test.file, test.linenum))
    io.write(string.format("--- INPUT -------------------------------------\n%s--- EXPECTED ----------------------------------\n%s--- GOT ---------------------------------------\n%s-----------------------------------------------\n\n", test.input, test.output, actual))
    self.failed = self.failed + 1
    return false
  end
end

function read_tests(file)
  local f = io.open("test/" .. file,"r")
  assert(f ~= nil, "File " .. file .. " cannot be read")
  local line
  local linenum = 0
  return function()
    while true do
      local inp = ""
      local out = ""
      line = f:read()
      local pretext = {}
      linenum = linenum + 1
      while line and not line:match("^```") do
        pretext[#pretext + 1] = line
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
      return { file = file,
               linenum = testlinenum,
               pretext = table.concat(pretext, "\n"),
               renderer = renderer,
               input = inp,
               output = out }
    end
  end
end

function Tests:do_tests(file)
  local tests = {}
  for test in read_tests(file) do
    tests[#tests + 1] = test
    local ok, err = pcall(function()
          self:do_test(test)
        end)
    if not ok then
      io.stderr:write(string.format("Error running test %s line %d:\n%s\n",
                                    test.file, test.line, err))
      self.errors = self.errors + 1
    end
  end
  if self.accept then -- rewrite file
    local fh = io.open("test/" .. file, "w")
    for idx,test in ipairs(tests) do
      local numticks = 3
      string.gsub(test.input .. test.output, "(````*)",
                 function(x)
                   if #x >= numticks then
                     numticks = #x + 1
                   end
                  end)
      local ticks = string.rep("`", numticks)
      local pretext = test.pretext
      if #pretext > 0 or idx > 1 then
        pretext = pretext .. "\n"
      end

      fh:write(string.format("%s%s%s\n%s.\n%s%s\n",
      pretext,
      ticks,
      (test.renderer == "[html]" and "") or " " .. test.renderer,
      test.input,
      test.output,
      ticks))
    end
    fh:close()
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

