local djot = require("djot")

local help = [[
djot [opts] [file*]

Options:
--matches        -m          Show matches.
--ast            -a          Show AST.
--json           -j          Use JSON for -m or -a.
--sourcepos      -p          Include source positions in AST.
--filter FILE    -f FILE     Filter AST using filter in FILE.
--verbose        -v          Verbose (show warnings).
--version                    Show version information.
--help           -h          Help.
]]

local function err(msg, code)
  io.stderr:write(msg .. "\n")
  os.exit(code)
end

local opts = {}
local files = {}

local shortcuts =
  { m = "--matches",
    a = "--ast",
    j = "--json",
    p = "--sourcepos",
    v = "--verbose",
    f = "--filter",
    h = "--help" }

local argi = 1
while arg[argi] do
  local thisarg = arg[argi]
  local longopts = {}
  if string.find(thisarg, "^%-%-%a") then
    longopts[#longopts + 1] = thisarg
  elseif string.find(thisarg, "^%-%a") then
    string.gsub(thisarg, "(%a)",
      function(x)
        longopts[#longopts + 1] = shortcuts[x] or ("-"..x)
      end)
  else
    files[#files + 1] = thisarg
  end
  for _,x in ipairs(longopts) do
    if x == "--matches" then
      opts.matches = true
    elseif x == "--ast" then
      opts.ast = true
    elseif x == "--json" then
      opts.json = true
    elseif x == "--sourcepos" then
      opts.sourcepos = true
    elseif x == "--verbose" then
      opts.verbose = true
    elseif x == "--filter" then
      if arg[argi + 1] then
        opts.filters = opts.filters or {}
        table.insert(opts.filters, arg[argi + 1])
        argi = argi + 1
      end
    elseif x == "--version" then
      io.stdout:write("djot " .. djot.version .. "\n")
      os.exit(0)
    elseif x == "--help" then
      io.stdout:write(help)
      os.exit(0)
    else
      err("Unknown option " .. x, 1)
    end
  end
  argi = argi + 1
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

local warn = function(warning)
  if opts.verbose then
    io.stderr:write(string.format("%s at byte position %d\n",
      warning.message, warning.pos))
  end
end

if opts.matches then

  io.stdout:write(djot.parse_and_render_events(inp, warn))

else

  local ast = djot.parse(inp, opts.sourcepos, warn)

  if opts.filters then
    for _,fp in ipairs(opts.filters) do
      local filt, err = djot.filter.require_filter(fp)
      if filt then
         djot.filter.apply_filter(ast, filt)
      else
        io.stderr:write("Error loading filter " .. fp .. ":\n" .. err .. "\n")
      end
    end
  end

  if opts.ast then
    if opts.json then
      io.stdout:write(djot.render_ast_json(ast))
    else
      io.stdout:write(djot.render_ast_pretty(ast))
    end
  else
    io.stdout:write(djot.render_html(ast))
  end

end

os.exit(0)
