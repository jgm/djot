-- combine modules into one file

local modules = {"djot", "djot.ast", "djot.attributes", "djot.block",
                 "djot.emoji", "djot.html", "djot.inline", "djot.json",
                 "djot.match"}

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
