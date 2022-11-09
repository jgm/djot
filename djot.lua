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
  return result
end

local Parser = block.Parser

function Parser:render_matches(handle, use_json)
  if not handle then
    handle = StringHandle:new()
  end
  local matches = self:get_matches()
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
  self.ast = ast.to_ast(self.subject, self.matches, self.opts, self.warn)
end

function Parser:render_ast(handle, use_json)
  if not handle then
    handle = StringHandle:new()
  end
  if not self.ast then
    self:build_ast()
  end
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
  local renderer = html.Renderer:new()
  renderer:render(self.ast, handle)
  return handle:flush()
end

-- Simple functions

local function djot_to_html(input, sourcepos)
  local parser = Parser:new(input, {sourcepos = sourcepos})
  parser:parse()
  parser:build_ast()
  local handle = StringHandle:new()
  local renderer = html.Renderer:new()
  renderer:render(parser.ast, handle)
  return handle:flush()
end

local function djot_to_ast_pretty(input, sourcepos)
  local parser = Parser:new(input, {sourcepos = sourcepos})
  parser:parse()
  parser:build_ast()
  local handle = StringHandle:new()
  ast.render(parser.ast, handle)
  return handle:flush()
end

local function djot_to_ast_json(input, sourcepos)
  local parser = Parser:new(input, {sourcepos = sourcepos})
  parser:parse()
  parser:build_ast()
  return (json.encode(parser.ast) .. "\n")
end

local function djot_to_matches_json(input)
  local parser = Parser:new(input)
  parser:parse()
  parser:build_ast()
  local matches = parser.matches
  local handle = StringHandle:new()
  local formatted_matches = {}
  for i=1,#matches do
    local startpos, endpos, annotation = unpack_match(matches[i])
    formatted_matches[#formatted_matches + 1] =
      { annotation, {startpos, endpos} }
  end
  handle:write(json.encode(formatted_matches) .. "\n")
  return handle:flush()
end

return {
  Parser = Parser,
  djot_to_html = djot_to_html,
  djot_to_ast_pretty = djot_to_ast_pretty,
  djot_to_ast_json = djot_to_ast_json,
  djot_to_matches_json = djot_to_matches_json
}
