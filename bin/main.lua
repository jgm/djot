local djot = require("djot")

local help = [[
djot [opts] [file*]

Options:
-m        Show matches.
-a        Show AST.
-j        Use JSON for -m or -a.
-p        Include source positions in AST.
-M        Show memory usage.
-v        Verbose (show warnings).
-h        Help.
]]

local function err(msg, code)
  io.stderr:write(msg .. "\n")
  os.exit(code)
end

local opts = {}
local files = {}

for _,arg in ipairs(arg) do
  if string.find(arg, "^%-") then
    string.gsub(arg, "(%a)", function(x)
      if x == "m" then
        opts.matches = true
      elseif x == "a" then
        opts.ast = true
      elseif x == "j" then
        opts.json = true
      elseif x == "p" then
        opts.sourcepos = true
      elseif x == "v" then
        opts.verbose = true
      elseif x == "M" then
        opts.memory = true
      elseif x == "h" then
        io.stdout:write(help)
        os.exit(0)
      else
        err("Unknown option " .. x, 1)
      end
    end)
  else
    files[#files + 1] = arg
  end
end

local inp
if #files == 0 then
  inp = io.read("*all")
else
  local buff = {}
  for _,f in ipairs(files) do
    local ok, msg = pcall(function() io.input(f) end)
    if ok then
      table.insert(buff, io.read("*all"))
    else
      err(msg, 7)
    end
  end
  inp = table.concat(buff, "\n")
end

local warn
if opts.verbose then
  warn = function(warning)
    io.stderr:write(string.format("%s at byte position %d\n",
      warning.message, warning.pos))
    end
end

local parser = djot.Parser:new(inp, opts, warn)

local function memusage(location)
  collectgarbage("collect")
  io.stderr:write(string.format("Memory usage %-12s %6d KB\n",
    location, math.floor(collectgarbage("count"))))
end

if opts.memory then
  memusage("before parse")
end

parser:parse()

if opts.memory then
  memusage("after parse")
end


if opts.matches then
  parser:render_matches(io.stdout, opts.json)
elseif opts.ast then
  parser:render_ast(io.stdout, opts.json)
else
  parser:render_html(io.stdout)
end

if opts.memory then
  memusage("after render")
end

os.exit(0)
