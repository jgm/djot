-- this allows the code to work with both lua and luajit:
local unpack = unpack or table.unpack
local attributes = require("djot.attributes")
local find, byte = string.find, string.byte

-- allow up to 3 captures...
local function bounded_find(subj, patt, startpos, endpos)
  local sp,ep,c1,c2,c3 = find(subj, patt, startpos)
  if ep and ep <= endpos then
    return sp,ep,c1,c2,c3
  end
end

-- General note on the parsing strategy:  our objective is to
-- parse without backtracking. To that end, we keep a stack of
-- potential 'openers' for links, images, emphasis, and other
-- inline containers.  When we parse a potential closer for
-- one of these constructions, we can scan the stack of openers
-- for a match, which will tell us the location of the potential
-- opener. We can then change the annotation of the match at
-- that location to '+emphasis' or whatever.

local InlineParser = {}

function InlineParser:new(subject, warn)
  local state =
    { warn = warn or function() end, -- function to issue warnings
      subject = subject, -- text to parse
      matches = {}, -- table pos : (endpos, annotation)
      openers = {}, -- map from closer_type to array of (pos, data) in reverse order
      verbatim = 0, -- parsing verbatim span to be ended by n backticks
      verbatim_type = nil, -- whether verbatim is math or regular
      destination = false, -- parsing link destination in ()
      firstpos = 0, -- position of first slice
      lastpos = 0,  -- position of last slice
      allow_attributes = true, -- allow parsing of attributes
      attribute_parser = nil,  -- attribute parser
      attribute_start = nil,  -- start of potential attribute
      attribute_slices = nil, -- slices we've tried to parse as attributes
    }
  setmetatable(state, self)
  self.__index = self
  return state
end

function InlineParser:add_match(startpos, endpos, annotation)
  self.matches[startpos] = {startpos, endpos, annotation}
end

function InlineParser:add_opener(name, ...)
  -- 1 = startpos, 2 = endpos, 3 = annotation, 4 = substartpos, 5 = endpos
  --
  -- [link text](url)
  -- ^         ^^
  -- 1,2      4 5  3 = "explicit_link"

  if not self.openers[name] then
    self.openers[name] = {}
  end
  table.insert(self.openers[name], {...})
end

function InlineParser:clear_openers(startpos, endpos)
  -- remove other openers in between the matches
  for _,v in pairs(self.openers) do
    local i = #v
    while v[i] do
      local sp,ep,_,sp2,ep2 = unpack(v[i])
      if sp >= startpos and ep <= endpos then
        v[i] = nil
      elseif (sp2 and sp2 >= startpos) and (ep2 and ep2 <= endpos) then
        v[i][3] = nil
        v[i][4] = nil
        v[i][5] = nil
      else
        break
      end
      i = i - 1
    end
  end
end

function InlineParser:str_matches(startpos, endpos)
  for i = startpos, endpos do
    local m = self.matches[i]
    if m then
      local sp, ep, annot = unpack(m)
      if annot ~= "str" and annot ~= "escape" then
        self.matches[i] = {sp, ep, "str"}
      end
    end
  end
end

local function matches_pattern(match, patt)
  if match then
    return string.find(match[3], patt)
  end
end


function InlineParser.between_matched(c, annotation, defaultmatch, opentest)
  return function(self, pos, endpos)
    defaultmatch = defaultmatch or "str"
    local subject = self.subject
    local can_open = find(subject, "^%S", pos + 1)
    local can_close = find(subject, "^%S", pos - 1)
    local has_open_marker = matches_pattern(self.matches[pos - 1], "^open%_marker")
    local has_close_marker = pos + 1 <= endpos and
                              byte(subject, pos + 1) == 125 -- }
    local endcloser = pos
    local startopener = pos

    if type(opentest) == "function" then
      can_open = can_open and opentest(self, pos)
    end

    -- allow explicit open/close markers to override:
    if has_open_marker then
      can_open = true
      can_close = false
      startopener = pos - 1
    end
    if not has_open_marker and has_close_marker then
      can_close = true
      can_open = false
      endcloser = pos + 1
    end

    if has_open_marker and defaultmatch:match("^right") then
      defaultmatch = defaultmatch:gsub("^right", "left")
    elseif has_close_marker and defaultmatch:match("^left") then
      defaultmatch = defaultmatch:gsub("^left", "right")
    end

    local d
    if has_close_marker then
      d = "{" .. c
    else
      d = c
    end
    local openers = self.openers[d]
    if can_close and openers and #openers > 0 then
       -- check openers for a match
      local openpos, openposend = unpack(openers[#openers])
      if openposend ~= pos - 1 then -- exclude empty emph
        self:clear_openers(openpos, pos)
        self:add_match(openpos, openposend, "+" .. annotation)
        self:add_match(pos, endcloser, "-" .. annotation)
        return endcloser + 1
      end
    end

    -- if we get here, we didn't match an opener
    if can_open then
      if has_open_marker then
        d = "{" .. c
      else
        d = c
      end
      self:add_opener(d, startopener, pos)
      self:add_match(startopener, pos, defaultmatch)
      return pos + 1
    else
      self:add_match(pos, endcloser, defaultmatch)
      return endcloser + 1
    end
  end
end

InlineParser.matchers = {
    -- 96 = `
    [96] = function(self, pos, endpos)
      local subject = self.subject
      local _, endchar = bounded_find(subject, "^`*", pos, endpos)
      if not endchar then
        return nil
      end
      if find(subject, "^%$%$", pos - 2) and
          not find(subject, "^\\", pos - 3) then
        self.matches[pos - 2] = nil
        self.matches[pos - 1] = nil
        self:add_match(pos - 2, endchar, "+display_math")
        self.verbatim_type = "display_math"
      elseif find(subject, "^%$", pos - 1) then
        self.matches[pos - 1] = nil
        self:add_match(pos - 1, endchar, "+inline_math")
        self.verbatim_type = "inline_math"
      else
        self:add_match(pos, endchar, "+verbatim")
        self.verbatim_type = "verbatim"
      end
      self.verbatim = endchar - pos + 1
      return endchar + 1
    end,

    -- 92 = \
    [92] = function(self, pos, endpos)
      local subject = self.subject
      local _, endchar = bounded_find(subject, "^[ \t]*\r?\n",  pos + 1, endpos)
      self:add_match(pos, pos, "escape")
      if endchar then
        -- see if there were preceding spaces
        if #self.matches > 0 then
          local sp, ep, annot = unpack(self.matches[#self.matches])
          if annot == "str" then
            while ep >= sp and
                 (subject:byte(ep) == 32 or subject:byte(ep) == 9) do
              ep = ep -1
            end
            if ep < sp then
              self.matches[#self.matches] = nil
            else
              self:add_match(sp, ep, "str")
            end
          end
        end
        self:add_match(pos + 1, endchar, "hardbreak")
        return endchar + 1
      else
        local _, ec = bounded_find(subject, "^[%p ]", pos + 1, endpos)
        if not ec then
          self:add_match(pos, pos, "str")
          return pos + 1
        else
          self:add_match(pos, pos, "escape")
          if find(subject, "^ ", pos + 1) then
            self:add_match(pos + 1, ec, "nbsp")
          else
            self:add_match(pos + 1, ec, "str")
          end
          return ec + 1
        end
      end
    end,

    -- 60 = <
    [60] = function(self, pos, endpos)
      local subject = self.subject
      local starturl, endurl =
              bounded_find(subject, "^%<[^<>%s]+%>", pos, endpos)
      if starturl then
        local is_url = bounded_find(subject, "^%a+:", pos + 1, endurl)
        local is_email = bounded_find(subject, "^[^:]+%@", pos + 1, endurl)
        if is_email then
          self:add_match(starturl, starturl, "+email")
          self:add_match(starturl + 1, endurl - 1, "str")
          self:add_match(endurl, endurl, "-email")
          return endurl + 1
        elseif is_url then
          self:add_match(starturl, starturl, "+url")
          self:add_match(starturl + 1, endurl - 1, "str")
          self:add_match(endurl, endurl, "-url")
          return endurl + 1
        end
      end
    end,

    -- 126 = ~
    [126] = InlineParser.between_matched('~', 'subscript'),

    -- 94 = ^
    [94] = InlineParser.between_matched('^', 'superscript'),

    -- 91 = [
    [91] = function(self, pos, endpos)
      local sp, ep = bounded_find(self.subject, "^%^([^]]+)%]", pos + 1, endpos)
      if sp then -- footnote ref
        self:add_match(pos, ep, "footnote_reference")
        return ep + 1
      else
        self:add_opener("[", pos, pos)
        self:add_match(pos, pos, "str")
        return pos + 1
      end
    end,

    -- 93 = ]
    [93] = function(self, pos, endpos)
      local openers = self.openers["["]
      local subject = self.subject
      if openers and #openers > 0 then
        local opener = openers[#openers]
        if opener[3] == "reference_link" then
          -- found a reference link
          -- add the matches
          local is_image = bounded_find(subject, "^!", opener[1] - 1, endpos)
                  and not bounded_find(subject, "^[\\]", opener[1] - 2, endpos)
          if is_image then
            self:add_match(opener[1] - 1, opener[1] - 1, "image_marker")
            self:add_match(opener[1], opener[2], "+imagetext")
            self:add_match(opener[4], opener[4], "-imagetext")
          else
            self:add_match(opener[1], opener[2], "+linktext")
            self:add_match(opener[4], opener[4], "-linktext")
          end
          self:add_match(opener[5], opener[5], "+reference")
          self:add_match(pos, pos, "-reference")
          -- convert all matches to str
          self:str_matches(opener[5] + 1, pos - 1)
          -- remove from openers
          self:clear_openers(opener[1], pos)
          return pos + 1
        elseif bounded_find(subject, "^%[", pos + 1, endpos) then
          opener[3] = "reference_link"
          opener[4] = pos  -- intermediate ]
          opener[5] = pos + 1  -- intermediate [
          self:add_match(pos, pos + 1, "str")
          -- remove any openers between [ and ]
          self:clear_openers(opener[1] + 1, pos - 1)
          return pos + 2
        elseif bounded_find(subject, "^%(", pos + 1, endpos) then
          self.openers["("] = {} -- clear ( openers
          opener[3] = "explicit_link"
          opener[4] = pos  -- intermediate ]
          opener[5] = pos + 1  -- intermediate (
          self.destination = true
          self:add_match(pos, pos + 1, "str")
          -- remove any openers between [ and ]
          self:clear_openers(opener[1] + 1, pos - 1)
          return pos + 2
        elseif bounded_find(subject, "^%{", pos + 1, endpos) then
          -- assume this is attributes, bracketed span
          self:add_match(opener[1], opener[2], "+span")
          self:add_match(pos, pos, "-span")
          -- remove any openers between [ and ]
          self:clear_openers(opener[1], pos)
          return pos + 1
        end
      end
    end,


    -- 40 = (
    [40] = function(self, pos)
      if not self.destination then return nil end
      self:add_opener("(", pos, pos)
      self:add_match(pos, pos, "str")
      return pos + 1
    end,

    -- 41 = )
    [41] = function(self, pos, endpos)
      if not self.destination then return nil end
      local parens = self.openers["("]
      if parens and #parens > 0 and parens[#parens][1] then
        parens[#parens] = nil -- clear opener
        self:add_match(pos, pos, "str")
        return pos + 1
      else
        local subject = self.subject
        local openers = self.openers["["]
        if openers and #openers > 0
            and openers[#openers][3] == "explicit_link" then
          local opener = openers[#openers]
          -- we have inline link
          local is_image = bounded_find(subject, "^!", opener[1] - 1, endpos)
                 and not bounded_find(subject, "^[\\]", opener[1] - 2, endpos)
          if is_image then
            self:add_match(opener[1] - 1, opener[1] - 1, "image_marker")
            self:add_match(opener[1], opener[2], "+imagetext")
            self:add_match(opener[4], opener[4], "-imagetext")
          else
            self:add_match(opener[1], opener[2], "+linktext")
            self:add_match(opener[4], opener[4], "-linktext")
          end
          self:add_match(opener[5], opener[5], "+destination")
          self:add_match(pos, pos, "-destination")
          self.destination = false
          -- convert all matches to str
          self:str_matches(opener[5] + 1, pos - 1)
          -- remove from openers
          self:clear_openers(opener[1], pos)
          return pos + 1
        end
      end
    end,

    -- 95 = _
    [95] = InlineParser.between_matched('_', 'emph'),

    -- 42 = *
    [42] = InlineParser.between_matched('*', 'strong'),

    -- 123 = {
    [123] = function(self, pos, endpos)
      if bounded_find(self.subject, "^[_*~^+='\"-]", pos + 1, endpos) then
        self:add_match(pos, pos, "open_marker")
        return pos + 1
      elseif self.allow_attributes then
        self.attribute_parser = attributes.AttributeParser:new(self.subject)
        self.attribute_start = pos
        self.attribute_slices = {}
        return pos
      else
        self:add_match(pos, pos, "str")
        return pos + 1
      end
    end,

    -- 58 = :
    [58] = function(self, pos, endpos)
      local sp, ep = bounded_find(self.subject, "^%:[%w_+-]+%:", pos, endpos)
      if sp then
        self:add_match(sp, ep, "symbol")
        return ep + 1
      else
        self:add_match(pos, pos, "str")
        return pos + 1
      end
    end,

    -- 43 = +
    [43] = InlineParser.between_matched("+", "insert", "str",
                           function(self, pos)
                             return find(self.subject, "^%{", pos - 1) or
                                    find(self.subject, "^%}", pos + 1)
                           end),

    -- 61 = =
    [61] = InlineParser.between_matched("=", "mark", "str",
                           function(self, pos)
                             return find(self.subject, "^%{", pos - 1) or
                                    find(self.subject, "^%}", pos + 1)
                           end),

    -- 39 = '
    [39] = InlineParser.between_matched("'", "single_quoted", "right_single_quote",
                           function(self, pos) -- test to open
                             return pos == 1 or
                               find(self.subject, "^[%s\"'-([]", pos - 1)
                             end),

    -- 34 = "
    [34] = InlineParser.between_matched('"', "double_quoted", "left_double_quote"),

    -- 45 = -
    [45] = function(self, pos, endpos)
      local subject = self.subject
      local nextpos
      if byte(subject, pos - 1) == 123 or
         byte(subject, pos + 1) == 125 then -- (123 = { 125 = })
        nextpos = InlineParser.between_matched("-", "delete", "str",
                           function(slf, p)
                             return find(slf.subject, "^%{", p - 1) or
                                    find(slf.subject, "^%}", p + 1)
                           end)(self, pos, endpos)
        return nextpos
      end
      -- didn't match a del, try for smart hyphens:
      local _, ep = find(subject, "^%-*", pos)
      if endpos < ep then
        ep = endpos
      end
      local hyphens = 1 + ep - pos
      if byte(subject, ep + 1) == 125 then -- 125 = }
        hyphens = hyphens - 1 -- last hyphen is close del
      end
      if hyphens == 0 then  -- this means we have '-}'
        self:add_match(pos, pos + 1, "str")
        return pos + 2
      end
      -- Try to construct a homogeneous sequence of dashes
      local all_em = hyphens % 3 == 0
      local all_en = hyphens % 2 == 0
      while hyphens > 0 do
        if all_em then
          self:add_match(pos, pos + 2, "em_dash")
          pos = pos + 3
          hyphens = hyphens - 3
        elseif all_en then
          self:add_match(pos, pos + 1, "en_dash")
          pos = pos + 2
          hyphens = hyphens - 2
        elseif hyphens >= 3 and (hyphens % 2 ~= 0 or hyphens > 4) then
          self:add_match(pos, pos + 2, "em_dash")
          pos = pos + 3
          hyphens = hyphens - 3
        elseif hyphens >= 2 then
          self:add_match(pos, pos + 1, "en_dash")
          pos = pos + 2
          hyphens = hyphens - 2
        else
          self:add_match(pos, pos, "str")
          pos = pos + 1
          hyphens = hyphens - 1
        end
      end
      return pos
    end,

    -- 46 = .
    [46] = function(self, pos, endpos)
      if bounded_find(self.subject, "^%.%.", pos + 1, endpos) then
        self:add_match(pos, pos +2, "ellipses")
        return pos + 3
      end
    end
  }

function InlineParser:single_char(pos)
  self:add_match(pos, pos, "str")
  return pos + 1
end

-- Reparse attribute_slices that we tried to parse as an attribute
function InlineParser:reparse_attributes()
  local slices = self.attribute_slices
  if not slices then
    return
  end
  self.allow_attributes = false
  self.attribute_parser = nil
  self.attribute_start = nil
  if slices then
    for i=1,#slices do
      self:feed(unpack(slices[i]))
    end
  end
  self.allow_attributes = true
  self.attribute_slices = nil
end

-- Feed a slice to the parser, updating state.
function InlineParser:feed(spos, endpos)
  local special = "[][\\`{}_*()!<>~^:=+$\r\n'\".-]"
  local subject = self.subject
  local matchers = self.matchers
  local pos
  if self.firstpos == 0 or spos < self.firstpos then
    self.firstpos = spos
  end
  if self.lastpos == 0 or endpos > self.lastpos then
    self.lastpos = endpos
  end
  pos = spos
  while pos <= endpos do
    if self.attribute_parser then
      local sp = pos
      local ep2 = bounded_find(subject, special, pos, endpos)
      if not ep2 or ep2 > endpos then
        ep2 = endpos
      end
      local status, ep = self.attribute_parser:feed(sp, ep2)
      if status == "done" then
        local attribute_start = self.attribute_start
        -- add attribute matches
        self:add_match(attribute_start, attribute_start, "+attributes")
        self:add_match(ep, ep, "-attributes")
        local attr_matches = self.attribute_parser:get_matches()
        -- add attribute matches
        for i=1,#attr_matches do
          self:add_match(unpack(attr_matches[i]))
        end
        -- restore state to prior to adding attribute parser:
        self.attribute_parser = nil
        self.attribute_start = nil
        self.attribute_slices = nil
        pos = ep + 1
      elseif status == "fail" then
        self:reparse_attributes()
        pos = sp  -- we'll want to go over the whole failed portion again,
                  -- as no slice was added for it
      elseif status == "continue" then
        if #self.attribute_slices == 0 then
          self.attribute_slices = {}
        end
        self.attribute_slices[#self.attribute_slices + 1] = {sp,ep}
        pos = ep + 1
      end
    else
      -- find next interesting character:
      local newpos = bounded_find(subject, special, pos, endpos) or endpos + 1
      if newpos > pos then
        self:add_match(pos, newpos - 1, "str")
        pos = newpos
        if pos > endpos then
          break -- otherwise, fall through:
        end
      end
      -- if we get here, then newpos = pos,
      -- i.e. we have something interesting at pos
      local c = byte(subject, pos)

      if c == 13 or c == 10 then -- cr or lf
        if c == 13 and bounded_find(subject, "^[%n]", pos + 1, endpos) then
          self:add_match(pos, pos + 1, "softbreak")
          pos = pos + 2
        else
          self:add_match(pos, pos, "softbreak")
          pos = pos + 1
        end
      elseif self.verbatim > 0 then
        if c == 96 then
          local _, endchar = bounded_find(subject, "^`+", pos, endpos)
          if endchar and endchar - pos + 1 == self.verbatim then
            -- check for raw attribute
            local sp, ep =
              bounded_find(subject, "^%{%=[^%s{}`]+%}", endchar + 1, endpos)
            if sp and self.verbatim_type == "verbatim" then -- raw
              self:add_match(pos, endchar, "-" .. self.verbatim_type)
              self:add_match(sp, ep, "raw_format")
              pos = ep + 1
            else
              self:add_match(pos, endchar, "-" .. self.verbatim_type)
              pos = endchar + 1
            end
            self.verbatim = 0
            self.verbatim_type = nil
          else
            endchar = endchar or endpos
            self:add_match(pos, endchar, "str")
            pos = endchar + 1
          end
        else
          self:add_match(pos, pos, "str")
          pos = pos + 1
        end
      else
        local matcher = matchers[c]
        pos = (matcher and matcher(self, pos, endpos)) or self:single_char(pos)
      end
    end
  end
end

  -- Return true if we're parsing verbatim content.
function InlineParser:in_verbatim()
  return self.verbatim > 0
end

function InlineParser:get_matches()
  local sorted = {}
  local subject = self.subject
  local lastsp, lastep, lastannot
  if self.attribute_parser then -- we're still in an attribute parse
    self:reparse_attributes()
  end
  for i=self.firstpos, self.lastpos do
    if self.matches[i] then
      local sp, ep, annot = unpack(self.matches[i])
      if annot == "str" and lastannot == "str" and lastep + 1 == sp then
          -- consolidate adjacent strs
        sorted[#sorted] = {lastsp, ep, annot}
        lastsp, lastep, lastannot = lastsp, ep, annot
      else
        sorted[#sorted + 1] = self.matches[i]
        lastsp, lastep, lastannot = sp, ep, annot
      end
    end
  end
  if #sorted > 0 then
    local last = sorted[#sorted]
    local startpos, endpos, annot = unpack(last)
    -- remove final softbreak
    if annot == "softbreak" then
      sorted[#sorted] = nil
      last = sorted[#sorted]
      if not last then
        return sorted
      end
      startpos, endpos, annot = unpack(last)
    end
    -- remove trailing spaces
    if annot == "str" and byte(subject, endpos) == 32 then
      while endpos > startpos and byte(subject, endpos) == 32 do
        endpos = endpos - 1
      end
      sorted[#sorted] = {startpos, endpos, annot}
    end
    if self.verbatim > 0 then -- unclosed verbatim
      self.warn({ message = "Unclosed verbatim", pos = endpos })
      sorted[#sorted + 1] = {endpos, endpos, "-" .. self.verbatim_type}
    end
  end
  return sorted
end

return { InlineParser = InlineParser }
