local unpack = unpack or table.unpack
local Parser = require("djot.block").Parser
local ast = require("djot.ast")
local html = require("djot.html")
local json = require("djot.json")
local apply_filter = require("djot.filter").apply_filter

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

-- Doc
local Doc = {}

function Doc:new(parser, sourcepos)
  local the_ast, sourcepos_map =
    ast.to_ast(parser, sourcepos)
  local state = {
    ast = the_ast,
    sourcepos_map = sourcepos_map
  }
  setmetatable(state, self)
  self.__index = self
  return state
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
  apply_filter(self.ast, filter)
  return self
end

local function parse(input, sourcepos, warn)
  local parser = Parser:new(input, warn)
  return Doc:new(parser, sourcepos)
end

local function parse_events(input, warn)
  return Parser:new(input):events()
end

local function render_matches(input, handle, use_json, warn)
  if not handle then
    handle = StringHandle:new()
  end
  local parser = Parser:new(input, warn)
  local idx = 0
  if use_json then
    handle:write("[")
  end
  for startpos, endpos, annotation in parser:events() do
    idx = idx + 1
    if use_json then
      if idx > 1 then
        handle:write(",")
      end
      handle:write(json.encode({ annotation, {startpos, endpos} }))
      handle:write("\n")
    else
      handle:write(string.format("%-s %d-%d\n", annotation, startpos, endpos))
    end
  end
  if use_json then
    handle:write("]\n")
  end

  return handle:flush()
end

return {
  parse = parse,
  parse_events = parse_events,
  render_matches = render_matches,
  version = "0.2.0"
}
