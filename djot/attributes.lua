local find, sub = string.find, string.sub

-- Parser for attributes
-- attributes { id = "foo", class = "bar baz",
--              key1 = "val1", key2 = "val2" }
-- syntax:
--
-- attributes <- '{' whitespace* attribute (whitespace attribute)* whitespace* '}'
-- attribute <- identifier | class | keyval
-- identifier <- '#' name
-- class <- '.' name
-- name <- (nonspace, nonpunctuation other than ':', '_', '-')+
-- keyval <- key '=' val
-- key <- (ASCII_ALPHANUM | ':' | '_' | '-')+
-- val <- bareval | quotedval
-- bareval <- (ASCII_ALPHANUM | ':' | '_' | '-')+
-- quotedval <- '"' ([^"] | '\"') '"'

-- states:
local SCANNING = 0
local SCANNING_ID = 1
local SCANNING_CLASS= 2
local SCANNING_KEY = 3
local SCANNING_VALUE = 4
local SCANNING_BARE_VALUE = 5
local SCANNING_QUOTED_VALUE = 6
local SCANNING_QUOTED_VALUE_CONTINUATION = 7
local SCANNING_ESCAPED = 8
local SCANNING_ESCAPED_IN_CONTINUATION = 9
local SCANNING_COMMENT = 10
local FAIL = 11
local DONE = 12
local START = 13

local AttributeParser = {}

local handlers = {}

handlers[START] = function(self, pos)
  if find(self.subject, "^{", pos) then
    return SCANNING
  else
    return FAIL
  end
end

handlers[FAIL] = function(_self, _pos)
  return FAIL
end

handlers[DONE] = function(_self, _pos)
  return DONE
end

handlers[SCANNING] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
    return SCANNING
  elseif c == '}' then
    return DONE
  elseif c == '#' then
    self.begin = pos
    return SCANNING_ID
  elseif c == '%' then
    self.begin = pos
    return SCANNING_COMMENT
  elseif c == '.' then
    self.begin = pos
    return SCANNING_CLASS
  elseif find(c, "^[%a%d_:-]") then
    self.begin = pos
    return SCANNING_KEY
  else -- TODO
    return FAIL
  end
end

handlers[SCANNING_COMMENT] = function(self, pos)
  if sub(self.subject, pos, pos) == "%" then
    return SCANNING
  else
    return SCANNING_COMMENT
  end
end

handlers[SCANNING_ID] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if find(c, "^[^%s%p]") or c == "_" or c == "-" or c == ":" then
    return SCANNING_ID
  elseif c == '}' then
    if self.lastpos > self.begin then
      self:add_match(self.begin + 1, self.lastpos, "id")
    end
    self.begin = nil
    return DONE
  elseif find(c, "^%s") then
    if self.lastpos > self.begin then
      self:add_match(self.begin + 1, self.lastpos, "id")
    end
    self.begin = nil
    return SCANNING
  else
    return FAIL
  end
end

handlers[SCANNING_CLASS] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if find(c, "^[^%s%p]") or c == "_" or c == "-" or c == ":" then
    return SCANNING_CLASS
  elseif c == '}' then
    if self.lastpos > self.begin then
      self:add_match(self.begin + 1, self.lastpos, "class")
    end
    self.begin = nil
    return DONE
  elseif find(c, "^%s") then
    if self.lastpos > self.begin then
      self:add_match(self.begin + 1, self.lastpos, "class")
    end
    self.begin = nil
    return SCANNING
  else
    return FAIL
  end
end

handlers[SCANNING_KEY] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if c == "=" then
    self:add_match(self.begin, self.lastpos, "key")
    self.begin = nil
    return SCANNING_VALUE
  elseif find(c, "^[%a%d_:-]") then
    return SCANNING_KEY
  else
    return FAIL
  end
end

handlers[SCANNING_VALUE] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if c == '"' then
    self.begin = pos
    return SCANNING_QUOTED_VALUE
  elseif find(c, "^[%a%d_:-]") then
    self.begin = pos
    return SCANNING_BARE_VALUE
  else
    return FAIL
  end
end

handlers[SCANNING_BARE_VALUE] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if find(c, "^[%a%d_:-]") then
    return SCANNING_BARE_VALUE
  elseif c == '}' then
    self:add_match(self.begin, self.lastpos, "value")
    self.begin = nil
    return DONE
  elseif find(c, "^%s") then
    self:add_match(self.begin, self.lastpos, "value")
    self.begin = nil
    return SCANNING
  else
    return FAIL
  end
end

handlers[SCANNING_ESCAPED] = function(_self, _pos)
  return SCANNING_QUOTED_VALUE
end

handlers[SCANNING_ESCAPED_IN_CONTINUATION] = function(_self, _pos)
  return SCANNING_QUOTED_VALUE_CONTINUATION
end

handlers[SCANNING_QUOTED_VALUE] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if c == '"' then
    self:add_match(self.begin + 1, self.lastpos, "value")
    self.begin = nil
    return SCANNING
  elseif c == "\n" then
    self:add_match(self.begin + 1, self.lastpos, "value")
    self.begin = nil
    return SCANNING_QUOTED_VALUE_CONTINUATION
  elseif c == "\\" then
    return SCANNING_ESCAPED
  else
    return SCANNING_QUOTED_VALUE
  end
end

handlers[SCANNING_QUOTED_VALUE_CONTINUATION] = function(self, pos)
  local c = sub(self.subject, pos, pos)
  if self.begin == nil then
    self.begin = pos
  end
  if c == '"' then
    self:add_match(self.begin, self.lastpos, "value")
    self.begin = nil
    return SCANNING
  elseif c == "\n" then
    self:add_match(self.begin, self.lastpos, "value")
    self.begin = nil
    return SCANNING_QUOTED_VALUE_CONTINUATION
  elseif c == "\\" then
    return SCANNING_ESCAPED_IN_CONTINUATION
  else
    return SCANNING_QUOTED_VALUE_CONTINUATION
  end
end

function AttributeParser:new(subject)
  local state = {
    subject = subject,
    state = START,
    begin = nil,
    lastpos = nil,
    matches = {}
    }
  setmetatable(state, self)
  self.__index = self
  return state
end

function AttributeParser:add_match(sp, ep, tag)
  self.matches[#self.matches + 1] = {sp, ep, tag}
end

function AttributeParser:get_matches()
  return self.matches
end

-- Feed parser a slice of text from the subject, between
-- startpos and endpos inclusive.  Return status, position,
-- where status is either "done" (position should point to
-- final '}'), "fail" (position should point to first character
-- that could not be parsed), or "continue" (position should
-- point to last character parsed).
function AttributeParser:feed(startpos, endpos)
  local pos = startpos
  while pos <= endpos do
    self.state = handlers[self.state](self, pos)
    if self.state == DONE then
      return "done", pos
    elseif self.state == FAIL then
      self.lastpos = pos
      return "fail", pos
    else
      self.lastpos = pos
      pos = pos + 1
    end
  end
  return "continue", endpos
end

--[[
local test = function()
  local parser = AttributeParser:new("{a=b #ident\n.class\nkey=val1\n .class key2=\"val two \\\" ok\" x")
  local x,y,z = parser:feed(1,56)
  print(require'inspect'(parser:get_matches{}))
end

test()
--]]

return { AttributeParser = AttributeParser }
