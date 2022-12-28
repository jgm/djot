-- run tests
package.path = "./?.lua;" .. package.path
local djot = require("djot")

local testcases = {
  "attributes.test",
  "blockquote.test",
  "code_blocks.test",
  "definition_lists.test",
  "symbol.test",
  "emphasis.test",
  "escapes.test",
  "fenced_divs.test",
  "filters.test",
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
  "sourcepos.test",
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
  if self.verbose then
    io.write(string.format("Testing %s at linen %d\n", test.file, test.linenum))
  end
  local sourcepos = false
  if test.options:match("p") then
    sourcepos = true
  end
  local actual = ""
  if test.options:match("m") then
    actual = actual .. djot.parse_and_render_events(test.input)
  else
    local doc = djot.parse(test.input, sourcepos)
    for _,filt in ipairs(test.filters) do
      local f, err = djot.filter.load_filter(filt)
      if not f then
        error(err)
      end
      djot.filter.apply_filter(doc, f)
    end
    if test.options:match("a") then
      actual = actual .. djot.render_ast_pretty(doc)
    else -- match 'h' or empty
      actual = actual .. djot.render_html(doc)
    end
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

local function read_tests(file)
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
      local ticks, options = line:match("^(`+)%s*(.*)")

      -- parse input
      line = f:read()
      linenum = linenum + 1
      while not line:match("^[%.%!]$") do
        inp = inp .. line .. "\n"
        line = f:read()
        linenum = linenum + 1
      end

      local filters = {}
      while line == "!" do -- parse filter
        line = f:read()
        linenum = linenum + 1
        local filt = ""
        while not line:match("^[%.%!]$") do
          filt = filt .. line .. "\n"
          line = f:read()
          linenum = linenum + 1
        end
        table.insert(filters, filt)
      end

      -- parse output
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
               options = options,
               filters = filters,
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
                                    test.file, test.linenum, err))
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

      fh:write(string.format("%s%s%s\n%s",
        pretext,
        ticks,
        (test.options == "" and "") or " " .. test.options,
        test.input))
      for _,f in ipairs(test.filters) do
        fh:write(string.format("!\n%s", f))
      end
      fh:write(string.format(".\n%s%s\n", test.output, ticks))
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

io.write(string.format("%d tests completed in %0.3f s\n",
          tests.passed + tests.failed + tests.errors, endtime - starttime))
io.write(string.format("PASSED: %4d\n", tests.passed))
io.write(string.format("FAILED: %4d\n", tests.failed))
io.write(string.format("ERRORS: %4d\n", tests.errors))
os.exit(tests.failed + tests.errors)

