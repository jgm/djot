-- combine modules (specified as cli arguments) into one file
package.path = "./?.lua;" .. package.path
local parser = require("dumbParser")

local modules = {}
for i=1,#arg do
  modules[#modules + 1] =
    arg[i]:gsub("^../",""):gsub("%.lua$",""):gsub("%/",".")
end

local buffer = {}
local function out(s)
  buffer[#buffer + 1] = s
end

for _,module in ipairs(modules) do
  out(string.format('package.preload["%s"] = function()', module))
  local path = "../" .. module:gsub("%.","/") .. ".lua"
  local f = assert(io.open(path, "r"))
  local content = f:read("*all")
  out(content)
  out('end\n')
end

out('local djot = require("djot")')
out('return djot')

local combined = table.concat(buffer, "\n")
local ast = parser.parse(combined)
parser.minify(ast)
io.stdout:write(parser.toLua(ast, false))
