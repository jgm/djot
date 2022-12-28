local InlineParser = require("djot.inline").InlineParser
local attributes = require("djot.attributes")
local unpack = unpack or table.unpack
local find, sub, byte = string.find, string.sub, string.byte

local Container = {}

function Container:new(spec, data)
  self = spec
  local contents = {}
  setmetatable(contents, self)
  self.__index = self
  if data then
    for k,v in pairs(data) do
      contents[k] = v
    end
  end
  return contents
end

local function get_list_styles(marker)
  if marker == "+" or marker == "-" or marker == "*" or marker == ":" then
    return {marker}
  elseif find(marker, "^[+*-] %[[Xx ]%]") then
    return {"X"} -- task list
  elseif find(marker, "^[(]?%d+[).]") then
    return {(marker:gsub("%d+","1"))}
  -- in ambiguous cases we return two values
  elseif find(marker, "^[(]?[ivxlcdm][).]") then
    return {(marker:gsub("%a+", "a")), (marker:gsub("%a+", "i"))}
  elseif find(marker, "^[(]?[IVXLCDM][).]") then
    return {(marker:gsub("%a+", "A")), (marker:gsub("%a+", "I"))}
  elseif find(marker, "^[(]?%l[).]") then
    return {(marker:gsub("%l", "a"))}
  elseif find(marker, "^[(]?%u[).]") then
    return {(marker:gsub("%u", "A"))}
  elseif find(marker, "^[(]?[ivxlcdm]+[).]") then
    return {(marker:gsub("%a+", "i"))}
  elseif find(marker, "^[(]?[IVXLCDM]+[).]") then
    return {(marker:gsub("%a+", "I"))}
  else -- doesn't match any list style
    return {}
  end
end

local Parser = {}

function Parser:new(subject, warn)
  -- ensure the subject ends with a newline character
  if not subject:find("[\r\n]$") then
    subject = subject .. "\n"
  end
  local state = {
    warn = warn or function() end,
    subject = subject,
    indent = 0,
    startline = nil,
    starteol = nil,
    endeol = nil,
    matches = {},
    containers = {},
    pos = 1,
    last_matched_container = 0,
    timer = {},
    finished_line = false,
    returned = 0 }
  setmetatable(state, self)
  self.__index = self
  return state
end

-- parameters are start and end position
function Parser:parse_table_row(sp, ep)
  local orig_matches = #self.matches  -- so we can rewind
  local startpos = self.pos
  self:add_match(sp, sp, "+row")
  -- skip | and any initial space in the cell:
  self.pos = find(self.subject, "%S", sp + 1)
  -- check to see if we have a separator line
  local seps = {}
  local p = self.pos
  local sepfound = false
  while not sepfound do
    local sepsp, sepep, left, right, trailing =
      find(self.subject, "^(%:?)%-%-*(%:?)([ \t]*%|[ \t]*)", p)
    if sepep then
      local st = "separator_default"
      if #left > 0 and #right > 0 then
        st = "separator_center"
      elseif #right > 0 then
        st = "separator_right"
      elseif #left > 0 then
        st = "separator_left"
      end
      seps[#seps + 1] = {sepsp, sepep - #trailing, st}
      p = sepep + 1
      if p == self.starteol then
        sepfound = true
        break
      end
    else
      break
    end
  end
  if sepfound then
    for i=1,#seps do
      self:add_match(unpack(seps[i]))
    end
    self:add_match(self.starteol - 1, self.starteol - 1, "-row")
    self.pos = self.starteol
    self.finished_line = true
    return true
  end
  local inline_parser = InlineParser:new(self.subject, self.warn)
  self:add_match(sp, sp, "+cell")
  local complete_cell = false
  while self.pos <= ep do
    -- parse a chunk as inline content
    local nextbar, _
    while not nextbar do
      _, nextbar = self:find("^[^|\r\n]*|")
      if not nextbar then
        break
      end
      if string.find(self.subject, "^\\", nextbar - 1) then -- \|
        inline_parser:feed(self.pos, nextbar)
        self.pos = nextbar + 1
        nextbar = nil
      else
        inline_parser:feed(self.pos, nextbar - 1)
        if inline_parser:in_verbatim() then
          inline_parser:feed(nextbar, nextbar)
          self.pos = nextbar + 1
          nextbar = nil
        else
          self.pos = nextbar + 1
        end
      end
    end
    complete_cell = nextbar
    if not complete_cell then
      break
    end
    -- add a table cell
    local cell_matches = inline_parser:get_matches()
    for i=1,#cell_matches do
      local s,e,ann = unpack(cell_matches[i])
      if i == #cell_matches and ann == "str" then
        -- strip trailing space
        while byte(self.subject, e) == 32 and e >= s do
          e = e - 1
        end
      end
      self:add_match(s,e,ann)
    end
    self:add_match(nextbar, nextbar, "-cell")
    if nextbar < ep then
      -- reset inline parser state
      inline_parser = InlineParser:new(self.subject, self.warn)
      self:add_match(nextbar, nextbar, "+cell")
      self.pos = find(self.subject, "%S", self.pos)
    end
  end
  if not complete_cell then
    -- rewind, this is not a valid table row
    self.pos = startpos
    for i = orig_matches,#self.matches do
      self.matches[i] = nil
    end
    return false
  else
    self:add_match(self.pos, self.pos, "-row")
    self.pos = self.starteol
    self.finished_line = true
    return true
  end
end

function Parser:specs()
  return {
    { name = "para",
      is_para = true,
      content = "inline",
      continue = function()
        if self:find("^%S") then
          return true
        else
          return false
        end
      end,
      open = function(spec)
        self:add_container(Container:new(spec,
            { inline_parser =
                InlineParser:new(self.subject, self.warn) }))
        self:add_match(self.pos, self.pos, "+para")
        return true
      end,
      close = function()
        self:get_inline_matches()
        local last = self.matches[#self.matches] or {self.pos, self.pos, ""}
        local sp, ep, annot = unpack(last)
        self:add_match(ep + 1, ep + 1, "-para")
        self.containers[#self.containers] = nil
      end
    },

    { name = "caption",
      is_para = false,
      content = "inline",
      continue = function()
        return self:find("^%S")
      end,
      open = function(spec)
        local _, ep = self:find("^%^[ \t]+")
        if ep then
          self.pos = ep + 1
          self:add_container(Container:new(spec,
            { inline_parser =
                InlineParser:new(self.subject, self.warn) }))
          self:add_match(self.pos, self.pos, "+caption")
          return true
        end
      end,
      close = function()
        self:get_inline_matches()
        self:add_match(self.pos - 1, self.pos - 1, "-caption")
        self.containers[#self.containers] = nil
      end
    },

    { name = "blockquote",
      content = "block",
      continue = function()
        if self:find("^%>%s") then
          self.pos = self.pos + 1
          return true
        else
          return false
        end
      end,
      open = function(spec)
        if self:find("^%>%s") then
          self:add_container(Container:new(spec))
          self:add_match(self.pos, self.pos, "+blockquote")
          self.pos = self.pos + 1
          return true
        end
      end,
      close = function()
        self:add_match(self.pos, self.pos, "-blockquote")
        self.containers[#self.containers] = nil
      end
    },

    -- should go before reference definitions
    { name = "footnote",
      content = "block",
      continue = function(container)
        if self.indent > container.indent or self:find("^[\r\n]") then
          return true
        else
          return false
        end
      end,
      open = function(spec)
        local sp, ep, label = self:find("^%[%^([^]]+)%]:%s")
        if not sp then
          return nil
        end
        -- adding container will close others
        self:add_container(Container:new(spec, {note_label = label,
                                                indent = self.indent}))
        self:add_match(sp, sp, "+footnote")
        self:add_match(sp + 2, ep - 3, "note_label")
        self.pos = ep
        return true
      end,
      close = function(_container)
        self:add_match(self.pos, self.pos, "-footnote")
        self.containers[#self.containers] = nil
      end
    },

    -- should go before list_item_spec
    { name = "thematic_break",
      content = nil,
      continue = function()
        return false
      end,
      open = function(spec)
        local sp, ep = self:find("^[-*][ \t]*[-*][ \t]*[-*][-* \t]*[\r\n]")
        if ep then
          self:add_container(Container:new(spec))
          self:add_match(sp, ep, "thematic_break")
          self.pos = ep
          return true
        end
      end,
      close = function(_container)
        self.containers[#self.containers] = nil
      end
    },

    { name = "list_item",
      content = "block",
      continue = function(container)
        if self.indent > container.indent or self:find("^[\r\n]") then
          return true
        else
          return false
        end
      end,
      open = function(spec)
        local sp, ep = self:find("^[-*+:]%s")
        if not sp then
          sp, ep = self:find("^%d+[.)]%s")
        end
        if not sp then
          sp, ep = self:find("^%(%d+%)%s")
        end
        if not sp then
          sp, ep = self:find("^[ivxlcdmIVXLCDM]+[.)]%s")
        end
        if not sp then
          sp, ep = self:find("^%([ivxlcdmIVXLCDM]+%)%s")
        end
        if not sp then
          sp, ep = self:find("^%a[.)]%s")
        end
        if not sp then
          sp, ep = self:find("^%(%a%)%s")
        end
        if not sp then
          return nil
        end
        local marker = sub(self.subject, sp, ep - 1)
        local checkbox = nil
        if self:find("^[*+-] %[[Xx ]%]%s", sp + 1) then -- task list
          marker = sub(self.subject, sp, sp + 4)
          checkbox = sub(self.subject, sp + 3, sp + 3)
        end
        -- some items have ambiguous style
        local styles = get_list_styles(marker)
        if #styles == 0 then
          return nil
        end
        local data = { styles = styles,
                       indent = self.indent }
        -- adding container will close others
        self:add_container(Container:new(spec, data))
        local annot = "+list_item"
        for i=1,#styles do
          annot = annot .. "|" .. styles[i]
        end
        self:add_match(sp, ep - 1, annot)
        self.pos = ep
        if checkbox then
          if checkbox == " " then
            self:add_match(sp + 2, sp + 4, "checkbox_unchecked")
          else
            self:add_match(sp + 2, sp + 4, "checkbox_checked")
          end
          self.pos = sp + 5
        end
        return true
      end,
      close = function(_container)
        self:add_match(self.pos, self.pos, "-list_item")
        self.containers[#self.containers] = nil
      end
    },

    { name = "reference_definition",
      content = nil,
      continue = function(container)
        if container.indent >= self.indent then
          return false
        end
        local _, ep, rest = self:find("^(%S+)")
        if ep and self.starteol == ep + 1 then
          self:add_match(ep - #rest + 1, ep, "reference_value")
          self.pos = ep + 1
          return true
        else
          return false
        end
      end,
      open = function(spec)
        local sp, ep, label, rest = self:find("^%[([^]\r\n]*)%]:[ \t]*(%S*)")
        if ep and self.starteol == ep + 1 then
          self:add_container(Container:new(spec,
             { key = label,
               indent = self.indent }))
          self:add_match(sp, sp, "+reference_definition")
          self:add_match(sp, sp + #label + 1, "reference_key")
          if #rest > 0 then
            self:add_match(ep - #rest + 1, ep, "reference_value")
          end
          self.pos = ep + 1
          return true
        end
      end,
      close = function(_container)
        self:add_match(self.pos, self.pos, "-reference_definition")
        self.containers[#self.containers] = nil
      end
    },

    { name = "heading",
      content = "inline",
      continue = function(container)
        local sp, ep = self:find("^%#+%s")
        if sp and ep and container.level == ep - sp then
          self.pos = ep
          return true
        else
          return false
        end
      end,
      open = function(spec)
        local sp, ep = self:find("^#+")
        if ep and find(self.subject, "^%s", ep + 1) then
          local level = ep - sp + 1
          self:add_container(Container:new(spec, {level = level,
               inline_parser = InlineParser:new(self.subject, self.warn) }))
          self:add_match(sp, ep, "+heading")
          self.pos = ep + 1
          return true
        end
      end,
      close = function(_container)
        self:get_inline_matches()
        local last = self.matches[#self.matches] or {self.pos, self.pos, ""}
        local sp, ep, annot = unpack(last)
        self:add_match(ep + 1, ep + 1, "-heading")
        self.containers[#self.containers] = nil
      end
    },

    { name = "code_block",
      content = "text",
      continue = function(container)
        local char = sub(container.border, 1, 1)
        local sp, ep, border = self:find("^(" .. container.border ..
                                 char .. "*)[ \t]*[\r\n]")
        if ep then
          container.end_fence_sp = sp
          container.end_fence_ep = sp + #border - 1
          self.pos = ep -- before newline
          self.finished_line = true
          return false
        else
          return true
        end
      end,
      open = function(spec)
        local sp, ep, border, ws, lang =
          self:find("^(~~~~*)([ \t]*)(%S*)[ \t]*[\r\n]")
        if not ep then
          sp, ep, border, ws, lang =
            self:find("^(````*)([ \t]*)([^%s`]*)[ \t]*[\r\n]")
        end
        if border then
          local is_raw = find(lang, "^=") and true or false
          self:add_container(Container:new(spec, {border = border,
                                                  indent = self.indent }))
          self:add_match(sp, sp + #border - 1, "+code_block")
          if #lang > 0 then
            local langstart = sp + #border + #ws
            if is_raw then
              self:add_match(langstart, langstart + #lang - 1, "raw_format")
            else
              self:add_match(langstart, langstart + #lang - 1, "code_language")
            end
          end
          self.pos = ep  -- before newline
          self.finished_line = true
          return true
        end
      end,
      close = function(container)
        local sp = container.end_fence_sp or self.pos
        local ep = container.end_fence_ep or self.pos
        self:add_match(sp, ep, "-code_block")
        if sp == ep then
          self.warn({ pos = self.pos, message = "Unclosed code block" })
        end
        self.containers[#self.containers] = nil
      end
    },

    { name = "fenced_div",
      content = "block",
      continue = function(container)
        if self.containers[#self.containers].name == "code_block" then
          return true -- see #109
        end
        local sp, ep, equals = self:find("^(::::*)[ \t]*[\r\n]")
        if ep and #equals >= container.equals then
          container.end_fence_sp = sp
          container.end_fence_ep = sp + #equals - 1
          self.pos = ep -- before newline
          return false
        else
          return true
        end
      end,
      open = function(spec)
        local sp, ep1, equals = self:find("^(::::*)[ \t]*")
        if not ep1 then
          return false
        end
        local clsp, ep = find(self.subject, "^[%w_-]*", ep1 + 1)
        local _, eol = find(self.subject, "^[ \t]*[\r\n]", ep + 1)
        if eol then
          self:add_container(Container:new(spec, {equals = #equals}))
          self:add_match(sp, ep, "+div")
          if ep >= clsp then
            self:add_match(clsp, ep, "class")
          end
          self.pos = eol + 1
          self.finished_line = true
          return true
        end
      end,
      close = function(container)
        local sp = container.end_fence_sp or self.pos
        local ep = container.end_fence_ep or self.pos
        -- check to make sure the match is in order
        self:add_match(sp, ep, "-div")
        if sp == ep then
          self.warn({pos = self.pos, message = "Unclosed div"})
        end
        self.containers[#self.containers] = nil
      end
    },

    { name = "table",
      content = "cells",
      continue = function(_container)
        local sp, ep = self:find("^|[^\r\n]*|")
        local eolsp = ep and find(self.subject, "^[ \t]*[\r\n]", ep + 1);
        if eolsp then
          return self:parse_table_row(sp, ep)
        end
      end,
      open = function(spec)
        local sp, ep = self:find("^|[^\r\n]*|")
        local eolsp = " *[\r\n]" -- make sure at end of line
        if sp and eolsp then
          self:add_container(Container:new(spec, { columns = 0 }))
          self:add_match(sp, sp, "+table")
          if self:parse_table_row(sp, ep) then
            return true
          else
            self.containers[#self.containers] = nil
            return false
          end
        end
     end,
      close = function(_container)
        self:add_match(self.pos, self.pos, "-table")
        self.containers[#self.containers] = nil
      end
    },

    { name = "attributes",
      content = "attributes",
      open = function(spec)
        if self:find("^%{") then
          local attribute_parser =
                  attributes.AttributeParser:new(self.subject)
          local status, ep =
                 attribute_parser:feed(self.pos, self.endeol)
          if status == 'fail' or ep + 1 < self.endeol then
            return false
          else
            self:add_container(Container:new(spec,
                               { status = status,
                                 indent = self.indent,
                                 startpos = self.pos,
                                 slices = {},
                                 attribute_parser = attribute_parser }))
            local container = self.containers[#self.containers]
            container.slices = { {self.pos, self.endeol } }
            self.pos = self.starteol
            return true
          end

        end
      end,
      continue = function(container)
        if self.indent > container.indent then
          table.insert(container.slices, { self.pos, self.endeol })
          local status, ep =
            container.attribute_parser:feed(self.pos, self.endeol)
          container.status = status
          if status ~= 'fail' or ep + 1 < self.endeol then
            self.pos = self.starteol
            return true
          end
        end
        -- if we get to here, we don't continue; either we
        -- reached the end of indentation or we failed in
        -- parsing attributes
        if container.status == 'done' then
          return false
        else -- attribute parsing failed; convert to para and continue
             -- with that
          local para_spec = self:specs()[1]
          local para = Container:new(para_spec,
                        { inline_parser =
                           InlineParser:new(self.subject, self.warn) })
          self:add_match(container.startpos, container.startpos, "+para")
          self.containers[#self.containers] = para
          -- reparse the text we couldn't parse as a block attribute:
          para.inline_parser.attribute_slices = container.slices
          para.inline_parser:reparse_attributes()
          self.pos = para.inline_parser.lastpos + 1
          return true
        end
      end,
      close = function(container)
        local attr_matches = container.attribute_parser:get_matches()
        self:add_match(container.startpos, container.startpos, "+block_attributes")
        for i=1,#attr_matches do
          self:add_match(unpack(attr_matches[i]))
        end
        self:add_match(self.pos, self.pos, "-block_attributes")
        self.containers[#self.containers] = nil
      end
    }
  }
end

function Parser:get_inline_matches()
  local matches =
    self.containers[#self.containers].inline_parser:get_matches()
  for i=1,#matches do
    self.matches[#self.matches + 1] = matches[i]
  end
end

function Parser:find(patt)
  return find(self.subject, patt, self.pos)
end

function Parser:add_match(startpos, endpos, annotation)
  self.matches[#self.matches + 1] = {startpos, endpos, annotation}
end

function Parser:add_container(container)
  local last_matched = self.last_matched_container
  while #self.containers > last_matched or
         (#self.containers > 0 and
          self.containers[#self.containers].content ~= "block") do
    self.containers[#self.containers]:close()
  end
  self.containers[#self.containers + 1] = container
end

function Parser:skip_space()
  local newpos, _ = find(self.subject, "[^ \t]", self.pos)
  if newpos then
    self.indent = newpos - self.startline
    self.pos = newpos
  end
end

function Parser:get_eol()
  local starteol, endeol = find(self.subject, "[\r]?[\n]", self.pos)
  if not endeol then
    starteol, endeol = #self.subject, #self.subject
  end
  self.starteol = starteol
  self.endeol = endeol
end

-- Returns an iterator over events.  At each iteration, the iterator
-- returns three values: start byte position, end byte position,
-- and annotation.
function Parser:events()
  local specs = self:specs()
  local para_spec = specs[1]
  local subjectlen = #self.subject

  return function()  -- iterator

    while self.pos <= subjectlen do

      -- return any accumulated matches
      if self.returned < #self.matches then
        self.returned = self.returned + 1
        return unpack(self.matches[self.returned])
      end

      self.indent = 0
      self.startline = self.pos
      self.finished_line = false
      self:get_eol()

      -- check open containers for continuation
      self.last_matched_container = 0
      local idx = 0
      while idx < #self.containers do
        idx = idx + 1
        local container = self.containers[idx]
        -- skip any indentation
        self:skip_space()
        if container:continue() then
          self.last_matched_container = idx
        else
          break
        end
      end

      -- if we hit a close fence, we can move to next line
      if self.finished_line then
        while #self.containers > self.last_matched_container do
          self.containers[#self.containers]:close()
        end
      end

      if not self.finished_line then
        -- check for new containers
        self:skip_space()
        local is_blank = (self.pos == self.starteol)

        local new_starts = false
        local last_match = self.containers[self.last_matched_container]
        local check_starts = not is_blank and
                            (not last_match or last_match.content == "block") and
                              not self:find("^%a+%s") -- optimization
        while check_starts do
          check_starts = false
          for i=1,#specs do
            local spec = specs[i]
            if not spec.is_para then
              if spec:open() then
                self.last_matched_container = #self.containers
                if self.finished_line then
                  check_starts = false
                else
                  self:skip_space()
                  new_starts = true
                  check_starts = spec.content == "block"
                end
                break
              end
            end
          end
        end

        if not self.finished_line then
          -- handle remaining content
          self:skip_space()

          is_blank = (self.pos == self.starteol)

          local is_lazy = not is_blank and
                          not new_starts and
                          self.last_matched_container < #self.containers and
                          self.containers[#self.containers].content == 'inline'

          local last_matched = self.last_matched_container
          if not is_lazy then
            while #self.containers > 0 and #self.containers > last_matched do
              self.containers[#self.containers]:close()
            end
          end

          local tip = self.containers[#self.containers]

          -- add para by default if there's text
          if not tip or tip.content == 'block' then
            if is_blank then
              if not new_starts then
                -- need to track these for tight/loose lists
                self:add_match(self.pos, self.endeol, "blankline")
              end
            else
              para_spec:open()
            end
            tip = self.containers[#self.containers]
          end

          if tip then
            if tip.content == "text" then
              local startpos = self.pos
              if tip.indent and self.indent > tip.indent then
                -- get back the leading spaces we gobbled
                startpos = startpos - (self.indent - tip.indent)
              end
              self:add_match(startpos, self.endeol, "str")
            elseif tip.content == "inline" then
              if not is_blank then
                tip.inline_parser:feed(self.pos, self.endeol)
              end
            end
          end
        end
      end

      self.pos = self.endeol + 1

    end

    -- close unmatched containers
    while #self.containers > 0 do
      self.containers[#self.containers]:close()
    end
    -- return any accumulated matches
    if self.returned < #self.matches then
      self.returned = self.returned + 1
      return unpack(self.matches[self.returned])
    end

  end

end

return { Parser = Parser,
         Container = Container }
