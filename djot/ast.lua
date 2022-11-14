if not utf8 then
  -- this is needed for the __pairs metamethod, used below
  require("compat53") -- luarocks install compat53
  utf8 = require("utf8") -- luarocks install utf8
end
local match = require("djot.match")
local emoji -- require this later, only if emoji encountered

local find, lower, sub, gsub, rep, format =
  string.find, string.lower, string.sub, string.gsub, string.rep, string.format

local unpack_match, get_length, matches_pattern =
  match.unpack_match, match.get_length, match.matches_pattern

-- Creates a sparse array whose indices are byte positions.
-- sourcepos_map[bytepos] = "line:column:charpos"
local function make_sourcepos_map(input)
  local sourcepos_map = {}
  local line = 1
  local col = 0
  local charpos = 0
  for bytepos, codepoint in utf8.codes(input) do
    charpos = charpos + 1
    if codepoint == 10 then -- newline
      line = line + 1
      col = 0
    else
      col = col + 1
    end
    sourcepos_map[bytepos] = string.pack("=I4I4I4", line, col, charpos)
  end
  return sourcepos_map
end

local function format_sourcepos(s)
  if s then
    local line, col, charpos = string.unpack("=I4I4I4", s)
    return string.format("%d:%d:%d", line, col, charpos)
  end
end

local function get_string_content(node)
  local buffer = {}
  if node.s then
    buffer[#buffer + 1] = node.s
  elseif node.t == "softbreak" then
    buffer[#buffer + 1] = "\n"
  elseif node.c then
    for i=1, #node.c do
      buffer[#buffer + 1] = get_string_content(node.c[i])
    end
  end
  return table.concat(buffer)
end

local roman_digits = {
  i = 1,
  v = 5,
  x = 10,
  l = 50,
  c = 100,
  d = 500,
  m = 1000 }

local function roman_to_number(s)
  -- go backwards through the digits
  local total = 0
  local prevdigit = 0
  local i=#s
  while i > 0 do
    local c = lower(sub(s,i,i))
    local n = roman_digits[c]
    if n < prevdigit then -- e.g. ix
      total = total - n
    else
      total = total + n
    end
    assert(n ~= nil, "Encountered bad character in roman numeral " .. s)
    prevdigit = n
    i = i - 1
  end
  return total
end

local function get_list_start(marker, style)
  local numtype = string.gsub(style, "%p", "")
  local s = string.gsub(marker, "%p", "")
  if numtype == "1" then
    return tonumber(s)
  elseif numtype == "A" then
    return (string.byte(s) - string.byte("A") + 1)
  elseif numtype == "a" then
    return (string.byte(s) - string.byte("a") + 1)
  elseif numtype == "I" then
    return roman_to_number(s)
  elseif numtype == "i" then
    return roman_to_number(s)
  elseif numtype == "" then
    return nil
  end
end

local ignorable = {
  image_marker = true,
  escape = true,
  blankline = true,
  checkbox_checked = true,
  checkbox_unchecked = true
}

local function is_tight(matches, startidx, endidx, is_last_item)
  -- see if there are any blank lines between blocks in a list item.
  local blanklines = 0
  -- we don't care about blank lines at very end of list
  for i=startidx, endidx do
    local _, _, x = unpack_match(matches[i])
    if x == "blankline" then
      if not ((matches_pattern(matches[i+1], "%+list_item") or
              (matches_pattern(matches[i+1], "%-list_item") and
               (is_last_item or
                 matches_pattern(matches[i+2], "%-list_item"))))) then
        -- don't count blank lines before list starts
        -- don't count blank lines at end of nested lists or end of last item
        blanklines = blanklines + 1
      end
    end
  end
  return (blanklines == 0)
end

local function sortedpairs(compare_function, to_displaykey)
  return function(tbl)
    local keys = {}
    local k
    k = next(tbl, k)
    while k do
      keys[#keys + 1] = k
      k = next(tbl, k)
    end
    table.sort(keys, compare_function)
    local keyindex = 0
    local function ordered_next(tbl,_)
      keyindex = keyindex + 1
      local key = keys[keyindex]
      -- use canonical names
      local displaykey = to_displaykey(key)
      if key then
        return displaykey, tbl[key]
      else
        return nil
      end
    end
    -- Return an iterator function, the table, starting point
    return ordered_next, tbl, nil
  end
end

-- provide children, tag, and text as aliases of c, t, s,
-- which we use above for better performance:
local mt = {}
local special = {
    children = 'c',
    text = 's',
    tag = 't' }
local displaykeys = {
    c = 'children',
    s = 'text',
    t = 'tag' }
mt.__index = function(table, key)
  local k = special[key]
  if k then
    return rawget(table, k)
  else
    return rawget(table, key)
  end
end
mt.__newindex = function(table, key, val)
  local k = special[key]
  if k then
    rawset(table, k, val)
  else
    rawset(table, key, val)
  end
end
mt.__pairs = sortedpairs(function(a,b)
    if a == "t" then -- t is always first
      return true
    elseif a == "s" then -- s is always second
      return (b ~= "t")
    elseif a == "c" then -- c only before references, footnotes
      return (b == "references" or b == "footnotes")
    elseif a == "references" then
      return (b == "footnotes")
    elseif a == "footnotes" then
      return false
    elseif b == "t" or b == "s" then
      return false
    elseif b == "c" or b == "references" or b == "footnotes" then
      return true
    else
      return (a < b)
    end
  end, function(k) return displaykeys[k] or k end)


local function mknode(tag)
  local node = { t = tag, c = nil }
  setmetatable(node, mt)
  return node
end

local function add_child(node, child)
  if (not node.c) then
    node.c = {}
  end
  node.c[#node.c + 1] = child
end

local function has_children(node)
  return (node.c and #node.c > 0)
end

local function mkattributes(tbl)
  local attr = tbl or {}
  -- ensure deterministic order of iteration
  setmetatable(attr, {__pairs = sortedpairs(function(a,b) return a < b end,
                                            function(k) return k end)})
  return attr
end

local function insert_attribute(attr, key, val)
  if key == "class" then
    if attr.class then
      attr.class = attr.class .. " " .. val
    else
      attr.class = val
    end
  else
    attr[key] = val
  end
end

local function copy_attributes(target, source)
  if source then
    for k,v in pairs(source) do
      insert_attribute(target, k, v)
    end
  end
end

local function insert_attributes_from_nodes(targetnode, cs)
  targetnode.attr = targetnode.attr or mkattributes()
  local i=1
  while i <= #cs do
    local x, y = cs[i].t, cs[i].s
    if x == "id" or x == "class" then
      insert_attribute(targetnode.attr, x, y)
    elseif x == "key" then
      local valnode = cs[i + 1]
      if valnode.t == "value" then
        -- resolve backslash escapes
        insert_attribute(targetnode.attr, y, valnode.s:gsub("\\(%p)", "%1"))
      end
      i = i + 1
    end
    i = i + 1
  end
end

local function make_definition_list_item(result)
  result.t = "definition_list_item"
  if not has_children(result) then
    result.c = {}
  end
  if result.c[1] and result.c[1].t == "para" then
    result.c[1].t = "term"
  else
    table.insert(result.c, 1, mknode("term"))
  end
  if result.c[2] then
    local defn = mknode("definition")
    defn.c = {}
    for i=2,#result.c do
      defn.c[#defn.c + 1] = result.c[i]
      result.c[i] = nil
    end
    result.c[2] = defn
  end
end

-- create an abstract syntax tree based on an event
-- stream and references. returns the ast and the
-- source position map.
local function to_ast(subject, matches, sourcepos, warn)
  if not warn then
    warn = function() end
  end
  local idx = 1
  local matcheslen = #matches
  local sourceposmap
  if sourcepos then
    sourceposmap = make_sourcepos_map(subject)
  end
  local references = {}
  local footnotes = {}
  local identifiers = {} -- identifiers used (to ensure uniqueness)

  -- generate auto identifier for heading
  local function get_identifier(s)
    local base = s:gsub("[][~!@#$%^&*(){}`,.<>\\|=+/?]","")
                  :gsub("^%s+",""):gsub("%s+$","")
                  :gsub("%s+","-")
    local i = 0
    local ident = base
    -- generate unique id
    while identifiers[ident] do
      i = i + 1
      ident = base .. tostring(i)
    end
    identifiers[ident] = true
    return ident
  end

  local function set_checkbox(node, startidx)
    -- determine if checked or unchecked
    local _,_,ann = unpack_match(matches[startidx + 1])
    if ann == "checkbox_checked" then
      node.checkbox = "checked"
    elseif ann == "checkbox_unchecked" then
      node.checkbox = "unchecked"
    end
  end

  local function get_node(maintag)
    local node = mknode(maintag)
    local stopper
    local block_attributes = nil
    if maintag then
      -- strip off data (e.g. for list_items)
      stopper = "^%-" .. gsub(maintag, "%[.*$", "")
    end
    while idx <= matcheslen do
      local matched = matches[idx]
      local startpos, endpos, annot = unpack_match(matched)
      if stopper and find(annot, stopper) then
        idx = idx + 1
        if sourcepos then
          node.pos = {nil, format_sourcepos(sourceposmap[endpos])}
          -- startpos filled in below under "+"
        end
        return node
      else
        local mod, tag = string.match(annot, "^([-+]?)(.*)")
        if ignorable[tag] then
          idx = idx + 1 -- skip
        elseif mod == "+" then -- open
          local startidx = idx
          idx = idx + 1
          local result = get_node(tag)
          if tag == "list_item[X]" then
            set_checkbox(result, startidx)
          end
          if sourcepos then
             result.pos[1] = format_sourcepos(sourceposmap[startpos])
             -- endpos is given at the top
          end
          if block_attributes and tag ~= "block_attributes" then
            for i=1,#block_attributes do
              insert_attributes_from_nodes(result, block_attributes[i])
            end
            if result.attr and result.attr.id then
              identifiers[result.attr.id] = true
            end
            block_attributes = nil
          end
          if tag == "verbatim" then
            local s = get_string_content(result)
            -- trim space next to ` at beginning or end
            if find(s, "^ +`") then
              s = s:sub(2)
            end
            if find(s, "` +$") then
              s = s:sub(1, #s - 1)
            end
            result.t = "verbatim"
            result.s = s
            result.c = nil
            -- check for raw_format, which makes this a raw node
            local sp,ep,ann = unpack_match(matches[idx])
            if ann == "raw_format" then
              local s = get_string_content(result)
              result.t = "raw_inline"
              result.s = s
              result.c = nil
              result.format = sub(subject, sp + 2, ep - 1)
              idx = idx + 1 -- skip the raw_format
            end
          elseif tag == "caption" then
            local prevnode = has_children(node) and node.c[#node.c]
            if prevnode and prevnode.t == "table" then
              -- move caption in table node
              table.insert(prevnode.c, 1, result)
            end
            result = nil
          elseif tag == "reference_definition" then
            local dest = ""
            local key
            for i=1,#result.c do
              if result.c[i].t == "reference_key" then
                key = result.c[i].s
              end
              if result.c[i].t == "reference_value" then
                dest = dest .. result.c[i].s
              end
            end
            references[key] = { destination = dest }
             if result.attr then
               references[key].attributes = result.attr
             end
          elseif tag == "footnote" then
            local label
            if result.c[1].t == "note_label" then
              label = result.c[1].s
              table.remove(result.c, 1)
            end
            if label then
              footnotes[label] = result
            end
            result = nil
          elseif tag == "inline_math" then
            result.t = "math"
            result.attr = mkattributes{class = "math inline"}
          elseif tag == "display_math" then
            result.t = "math"
            result.attr = mkattributes{class = "math display"}
          elseif tag == "url" then
            result.t = "url"
            result.destination = get_string_content(result)
          elseif tag == "email" then
            result.t = "email"
            result.destination = "mailto:" .. get_string_content(result)
          elseif tag == "imagetext" or tag == "linktext" then
            -- gobble destination or reference
            local nextmatch = matches[idx]
            local _, _, nextannot = unpack_match(nextmatch)
            if nextannot == "+destination" then
              idx = idx + 1
              local dest = get_node("destination")
              result.destination = get_string_content(dest):gsub("\r?\n", "")
            elseif nextannot == "+reference" then
              idx = idx + 1
              local ref = get_node("reference")
              if ref.t == "reference" and has_children(ref) then
                result.reference = get_string_content(ref):gsub("\r?\n", " ")
              else
                result.reference = get_string_content(result):gsub("\r?\n", " ")
              end
            end
            result.t = result.t:gsub("text","")
          elseif tag == "heading" then
            result.level = get_length(matched)
            local heading_str = get_string_content(result)
                                 :gsub("^%s+",""):gsub("%s+$","")
            if not result.attr then
              result.attr = mkattributes{}
            end
            if not result.attr.id then
              insert_attribute(result.attr, "id", get_identifier(heading_str))
            end
            -- insert into references unless there's a same-named one already:
            if not references[heading_str] then
              references[heading_str] = {destination = "#" .. result.attr.id}
            end
          elseif tag == "table" then
            -- look for a separator line
            -- if found, make the preceding rows headings
            -- and set attributes for column alignments on the table
            local i=1
            local aligns = {}
            while i <= #result.c do
              local found, align
              if result.c[i].t == "row" then
                local row = result.c[i].c
                for j=1,#row do
                  found, _, align = find(row[j].t, "^separator_(.*)")
                  if not found then
                    break
                  end
                  aligns[j] = align
                end
                if found and #aligns > 0 then
                  -- set previous row to head and adjust aligns
                  local prevrow = result.c[i - 1]
                  if prevrow and prevrow.t == "row" then
                    prevrow.head = true
                    for k=1,#prevrow.c do
                      -- set head on cells too
                      prevrow.c[k].head = true
                      if aligns[k] ~= "default" then
                        prevrow.c[k].align = aligns[k]
                      end
                    end
                  end
                  table.remove(result.c, i) -- remove sep line
                  -- we don't need to increment i because we removed ith elt
                else
                  if #aligns > 0 then
                    for l=1,#result.c[i].c do
                      if aligns[l] ~= "default" then
                        result.c[i].c[l].align = aligns[l]
                      end
                    end
                  end
                  i = i + 1
                end
              end
            end
            result.level = get_length(matched)
          elseif tag == "div" then
            result.c = result.c or {}
            if result.c[1] and result.c[1].t == "class" then
              result.attr = mkattributes(result.attr)
              insert_attribute(result.attr, "class", get_string_content(result.c[1]))
              table.remove(result.c, 1)
            end
          elseif tag == "code_block" then
            if has_children(result) then
              if result.c[1].t == "code_language" then
                result.lang = result.c[1].s
                table.remove(result.c, 1)
              elseif result.c[1].t == "raw_format" then
                local fmt = result.c[1].s:sub(2)
                table.remove(result.c, 1)
                result.t = "raw_block"
                result.format = fmt
              end
            end
            result.s = get_string_content(result)
            result.c = nil
          elseif tag == "block_attributes" then
            if block_attributes then
              block_attributes[#block_attributes + 1] = result.c
            else
              block_attributes = mkattributes{result.c}
            end
            result = nil
          elseif tag == "attributes" then
            -- parse attributes, add to last node
            local prevnode = has_children(node) and node.c[#node.c]
            local endswithspace = false
            if type(prevnode) == "table" then
              if prevnode.t == "str" then
                -- split off last consecutive word of string
                -- to which to attach attributes
                local lastwordpos = string.find(prevnode.s, "[^%s]+$")
                if not lastwordpos then
                  endswithspace = true
                elseif lastwordpos > 1 then
                  local newnode = {t = "str",
                                   s = sub(prevnode.s, lastwordpos, -1)}
                  prevnode.s = sub(prevnode.s, 1, lastwordpos - 1)
                  add_child(node, newnode)
                  prevnode = newnode
                end
              end
              if has_children(result) and not endswithspace then
                insert_attributes_from_nodes(prevnode, result.c)
              else
                warn({message = "Ignoring unattached attribute", pos = startpos})
              end
            end
            result = nil
          elseif find(tag, "^list_item") then
            local marker = string.match(subject, "^%S+", startpos)
            local styles = {}
            gsub(tag, "%[([^]]*)%]", function(x) styles[#styles + 1] = x end)
            -- create a list node with the consecutive list items
            -- of the same kind
            local list = mknode("list")
            list.c = {result}
            -- put the attributes from the first item on the list itself:
            list.attr = result.attr
            result.attr = nil
            result.t = "list_item"
            if marker == ":" then
              make_definition_list_item(result)
            end
            if sourcepos then
              list.pos = {result.pos[1], result.pos[2]}
            end
            -- now get remaining items
            local nextitem = matches[idx]
            while nextitem do
              local sp, ep, ann = unpack_match(nextitem)
              if not find(ann, "^%+list_item") then
                break
              end
              -- check which of the styles this item matches
              local newstyles = {}
              gsub(ann, "%[([^]]*)%]",
                          function(x) newstyles[x] = true end)
              local matched_styles = {}
              for _,x in ipairs(styles) do
                if newstyles[x] then
                  matched_styles[#matched_styles + 1] = x
                end
              end
              if #styles > 0 and #matched_styles == 0 then
                break  -- does not match any styles
              end
              styles = matched_styles
              -- at this point styles contains the styles that match all items
              -- in the list so far...

              if #list.c > 0 then
                list.c[#list.c].tight =
                  is_tight(matches, startidx, idx - 1, false)
              end
              startidx = idx
              idx = idx + 1
              local item = get_node(tag)
              if tag == "list_item[X]" then
                set_checkbox(item, startidx)
              end
              item.t = "list_item"
              if sourcepos then
                item.pos = {format_sourcepos(sourceposmap[sp])}
                if has_children(item) then
                  item.pos[2] = item.c[#item.c].pos[2]
                else
                  item.pos[2] = format_sourcepos(sourceposmap[ep])
                end
                list.pos[2] = item.pos[2]
              end
              if marker == ":" then
                make_definition_list_item(item)
              end
              list.c[#list.c + 1] = item
              nextitem = matches[idx]
            end
            if #list.c > 0 then
              list.c[#list.c].tight =
                is_tight(matches, startidx, idx - 1, true)
            end
            local tight = true
            for i=1,#list.c do
              tight = tight and list.c[i].tight
              list.c[i].tight = nil
            end
            list.list_style = styles[1] -- resolve, if still ambiguous
            list.tight = tight
            list.start = get_list_start(marker, list.list_style)
            result = list
          end
          add_child(node, result)
        elseif mod == "-" then -- close
          assert(false, "unmatched " .. annot .. " encountered at byte " ..
                   startpos)
          idx = idx + 1
          return nil
        elseif tag == "reference_key" then
          local key = sub(subject, startpos + 1, endpos - 1)
          local result = mknode("reference_key")
          result.s = key
          idx = idx + 1
          add_child(node, result)
        elseif tag == "reference_value" then
          local val = sub(subject, startpos, endpos)
          local result = mknode("reference_value")
          result.s = val
          idx = idx + 1
          add_child(node, result)
        else -- leaf
          local result
          if tag == "softbreak" then
            result = mknode(tag)
          elseif tag == "footnote_reference" then
            result = mknode(tag)
            result.s = sub(subject, startpos + 2, endpos - 1)
          elseif tag == "emoji" then
            result = mknode("emoji")
            result.alias = sub(subject, startpos + 1, endpos - 1)
            emoji = require("djot.emoji")
            local found = emoji[result.alias]
            result.s = found
          else
            result = mknode(tag)
            result.s = sub(subject, startpos, endpos)
          end
          if sourcepos then
            result.pos = {format_sourcepos(sourceposmap[startpos]),
                          format_sourcepos(sourceposmap[endpos])}
          end
          if block_attributes then
            for i=1,#block_attributes do
              insert_attributes_from_nodes(result, block_attributes[i])
            end
            block_attributes = nil
          end
          idx = idx + 1
          if result then
            add_child(node, result)
          end
        end
      end
    end
    return node
  end

  local doc = get_node("doc")
  doc.references = references
  doc.footnotes = footnotes

  return doc, sourceposmap
end

local function render_node(node, handle, indent)
  indent = indent or 0
  handle:write(rep(" ", indent))
  if node.t then
    handle:write(node.t)
    if node.pos then
      handle:write(format(" (%s-%s)", node.pos[1], node.pos[2]))
    end
    for k,v in pairs(node) do
      if type(k) == "string" and k ~= "children" and
          k ~= "tag" and k ~= "pos" and k ~= "attr"  and
          k ~= "references" and k ~= "footnotes" then
        handle:write(format(" %s=%q", k, tostring(v)))
      end
    end
    if node.attr then
      for k,v in pairs(node.attr) do
        handle:write(format(" %s=%q", k, v))
      end
    end
  else
    io.stderr:write("Encountered node without tag:\n" ..
                      require'inspect'(node))
    os.exit(1)
  end
  handle:write("\n")
  if node.c then
    for _,v in ipairs(node.c) do
      render_node(v, handle, indent + 2)
    end
  end
end

local function render(doc, handle)
  render_node(doc, handle, 0)
  if doc.references then
    handle:write("references = {\n")
    for k,v in pairs(doc.references) do
      handle:write(format("  [%q] = %q,\n", k, v.destination))
    end
    handle:write("}\n")
  end
  if doc.footnotes then
    handle:write("footnotes = {\n")
    for k,v in pairs(doc.footnotes) do
      handle:write(format("  [%q] =\n", k))
      render_node(v, handle, 4)
    end
    handle:write("}\n")
  end
end

return { to_ast = to_ast,
         render = render,
         insert_attribute = insert_attribute,
         copy_attributes = copy_attributes,
         mkattributes = mkattributes,
         mknode = mknode,
         add_child = add_child }
