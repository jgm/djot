local block = require("djot.block")
local ast = require("djot.ast")
local html = require("djot.html")
local match = require("djot.match")
local json = require("djot.json")

local unpack_match = match.unpack_match
local format_match = match.format_match

local StringHandle = {}

function StringHandle:new()
  local buffer = {}
  setmetatable(buffer, StringHandle)
  StringHandle.__index = StringHandle
  return buffer
end

function StringHandle:write(s)
  self[#self + 1] = s
end

function StringHandle:flush()
  local result = table.concat(self)
  self = {}
  return result
end

local Parser = block.Parser

function Parser:issue_warnings(handle)
  if self.opts.verbose then
    local warnings = self.warnings
    for i=1,#warnings do
      handle:write(string.format("Warning: %s at byte position %d\n",
                                    warnings[i][2], warnings[i][1]))
    end
  end
end

function Parser:render_matches(handle, use_json)
  if not handle then
    handle = StringHandle:new()
  end
  local matches = self:get_matches()
  self:issue_warnings(io.stderr)
  if use_json then
    local formatted_matches = {}
    for i=1,#matches do
      local startpos, endpos, annotation = unpack_match(matches[i])
      formatted_matches[#formatted_matches + 1] =
        { annotation, {startpos, endpos} }
    end
    handle:write(json.encode(formatted_matches) .. "\n")
  else
    for i=1,#matches do
      handle:write(format_match(matches[i]))
    end
  end
  return handle:flush()
end

function Parser:build_ast()
  self.ast = ast.to_ast(self.subject, self.matches, self.opts)
end

function Parser:render_ast(handle, use_json)
  if not handle then
    handle = StringHandle:new()
  end
  if not self.ast then
    self:build_ast()
  end
  self:issue_warnings(io.stderr)
  if use_json then
    handle:write(json.encode(self.ast) .. "\n")
  else
    ast.render(self.ast, handle)
  end
  return handle:flush()
end

function Parser:render_html(handle)
  if not handle then
    handle = StringHandle:new()
  end
  if not self.ast then
    self:build_ast()
  end
  self:issue_warnings(io.stderr)
  local renderer = html.Renderer:new()
  renderer:render(self.ast, handle)
  return handle:flush()
end

return {
  Parser = Parser
}
