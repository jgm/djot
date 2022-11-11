-- combine modules (specified as cli arguments) into one file

local modules = {}
for i=1,#arg do
  modules[#modules + 1] =
    arg[i]:gsub("^../",""):gsub("%.lua$",""):gsub("%/",".")
end

for _,module in ipairs(modules) do
  print(string.format('package.preload["%s"] = function()', module))
  local path = "../" .. module:gsub("%.","/") .. ".lua"
  local f = assert(io.open(path, "r"))
  local content = f:read("*all")
  print(content)
  print('end\n')
end

print('local djot = require("djot")')
print('return djot')
