local block = require("djot.block")
local ast = require("djot.ast")
local html = require("djot.html")
local match = require("djot.match")
local json = require("djot.json")
local filter = require("djot.filter")

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
  return table.concat(self)
end

local Tokenizer = block.Tokenizer

-- Doc
local Doc = {}

function Doc:new(tokenizer, sourcepos)
  local ast, sourcepos_map =
    ast.to_ast(tokenizer, sourcepos)
  local state = {
    ast = ast,
    sourcepos_map = sourcepos_map,
    matches = tokenizer.matches,
  }
  setmetatable(state, self)
  self.__index = self
  return state
end

function Doc:format_source_pos(bytepos)
  local pos = self.sourcepos_map[bytepos]
  if pos then
    return string.format("line %d, column %d", pos[1], pos[2])
  else
    return string.format("byte position %d", bytepos)
  end
end

function Doc:render_ast(handle, use_json)
  if not handle then
    handle = StringHandle:new()
  end
  if use_json then
    handle:write(json.encode(self.ast))
  else
    ast.render(self.ast, handle)
  end
  if use_json then
    handle:write("\n")
  end
  return handle:flush()
end

function Doc:render_html(handle)
  if not handle then
    handle = StringHandle:new()
  end
  local renderer = html.Renderer:new()
  renderer:render(self.ast, handle)
  return handle:flush()
end

function Doc:apply_filter(filter)
  filter.traverse(filter)
end

function Doc:render_warnings(handle, as_json)
  if #warnings == 0 then
    return
  end
  if as_json then
    handle:write(json.encode(warnings))
  else
    for _,warning in ipairs(warnings) do
      handle:write(string.format("%s at %s\n",
        warning.message, self:format_source_pos(warning.pos)))
    end
  end
  if as_json then
    handle:write("\n")
  end
  return handle:flush()
end

local function parse(input, sourcepos)
  local warnings = {}
  local function warn(warning)
    warnings[#warnings + 1] = warning
  end
  local tokenizer = Tokenizer:new(input, warn)
  return Doc:new(tokenizer, sourcepos)
end

local function tokenize(input)
  return Tokenizer:new(input):tokenize()
end

local function render_matches(input, handle, use_json)
  if not handle then
    handle = StringHandle:new()
  end
  local tokenizer = Tokenizer:new(input)
  local idx = 0
  if use_json then
    handle:write("[")
  end
  for match in tokenizer:tokenize() do
    idx = idx + 1
    if use_json then
      local startpos, endpos, annotation = unpack_match(match)
      if idx > 1 then
        handle:write(",")
      end
      handle:write(json.encode({ annotation, {startpos, endpos} }))
      handle:write("\n")
    else
      handle:write(format_match(match))
    end
  end
  if use_json then
    handle:write("]\n")
  end

  return handle:flush()
end

return {
  parse = parse,
  tokenize = tokenize,
  render_matches = render_matches
}
