local match = require("djot.match")
local unpack = unpack or table.unpack

local find, lower, sub, gsub, rep, format =
  string.find, string.lower, string.sub, string.gsub, string.rep, string.format

local unpack_match, get_length, matches_pattern =
  match.unpack_match, match.get_length, match.matches_pattern

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
      if matches_pattern(matches[i+1], "%+list_item") then
        -- don't count blank lines before list starts
      elseif matches_pattern(matches[i+1], "%-list_item") and
        (is_last_item or matches_pattern(matches[i+2], "%-list_item")) then
        -- don't count blank lines at end of nested lists
        -- or end of last item
      else
        blanklines = blanklines + 1
      end
    end
  end
  return (blanklines == 0)
end

local function insert_attribute(attr, key, val)
  if not attr._keys then
    attr._keys = {}
  end
  local function add_key(k)
    local keys = attr._keys
    for i=1,#keys do
      if keys[i] == k then
        return
      end
    end
    keys[#keys + 1] = k
  end
  -- _keys records order of key insertion for deterministic output
  if key == "id" then
    attr.id = val
    add_key("id")
  elseif key == "class" then
    if attr.class then
      attr.class =
        attr.class .. " " .. val
    else
      attr.class = val
      add_key("class")
    end
  else
    attr[key] = val
    add_key(key)
  end
end

local function copy_attributes(target, source)
  if source then
    for k,v in pairs(source) do
      if k ~= "_keys" then
        insert_attribute(target, k, v)
      end
    end
  end
end

local function insert_attributes(targetnode, cs)
  targetnode.attr = targetnode.attr or {_keys = {}}
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
  if result.c and #result.c > 0 and
     result.c[1].t == "para" then
    result.c[1].t = "term"
  else
    table.insert(result.c, 1, {t = "term", c = {}})
  end
  if result.c[2] then
    local defn = {t = "definition", c = {}}
    for i=2,#result.c do
      defn.c[#defn.c + 1] = result.c[i]
      result.c[i] = nil
    end
    result.c[2] = defn
  end
end

-- create an abstract syntax tree based on an event
-- stream and references
local function to_ast(subject, matches, options)
  if not options then
    options = {}
  end
  local idx = 1
  local matcheslen = #matches
  local sourcepos = options.sourcepos
  local references = {}
  local footnotes = {}
  local identifiers = {} -- identifiers used (to ensure uniqueness)

  -- generate auto identifier for heading
  local function get_identifier(s)
    local base = s:gsub("[][~!@#$%^&*(){}`,.<>\\|=+/?]","")
                  :gsub("^%s+",""):gsub("%s+$","")
                  :gsub("%s+","-")
    local suffix = ""
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
    local node = { t = maintag, c = {} }
    local stopper
    local block_attributes = nil
    if maintag then
      -- strip off data (e.g. for list_items)
      stopper = "^%-" .. gsub(maintag, "%[.*$", "")
    end
    while idx <= matcheslen do
      local match = matches[idx]
      local startpos, endpos, annot = unpack_match(match)
      if stopper and find(annot, stopper) then
        idx = idx + 1
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
          local _, finalpos = unpack_match(matches[idx - 1])
          if sourcepos then
            result.pos = {startpos, finalpos}
          end
          if block_attributes and tag ~= "block_attributes" then
            for i=1,#block_attributes do
              insert_attributes(result, block_attributes[i])
            end
            if result.attr and result.attr.id then
              identifiers[result.attr.id] = true
            end
            block_attributes = nil
            -- TODO where do we ever set this to true??
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
            result = {t = "verbatim", s = s}
            -- check for raw_format, which makes this a raw node
            local sp,ep,ann = unpack_match(matches[idx])
            if ann == "raw_format" then
              local s = get_string_content(result)
              result.t = "raw_inline"
              result.s = s
              result.format = sub(subject, sp + 2, ep - 1)
              idx = idx + 1 -- skip the raw_format
            end
          elseif tag == "caption" then
            local prevnode = node.c[#node.c]
            if prevnode.t == "table" then
              -- move caption in table node
              table.insert(prevnode.c, 1, result)
              result = nil
            end
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
            references[key] = { destination = dest,
                                attributes = result.attr }
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
            result.attr = {class = "math inline", _keys={"class"}}
          elseif tag == "display_math" then
            result.t = "math"
            result.attr = {class = "math display", _keys={"class"}}
          elseif tag == "url" then
            result.t = "link"
            result.destination = get_string_content(result)
          elseif tag == "email" then
            result.t = "link"
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
              if ref.t == "reference" and #ref.c > 0 then
                result.reference = get_string_content(ref):gsub("\r?\n", " ")
              else
                result.reference = get_string_content(result):gsub("\r?\n", " ")
              end
            end
            result.t = result.t:gsub("text","")
          elseif tag == "heading" then
            result.level = get_length(match)
            local heading_str = get_string_content(result)
                                 :gsub("^%s+",""):gsub("%s+$","")
            if not (result.attr and result.attr.id) then
              local ident = get_identifier(heading_str)
              insert_attributes(result, {{t = "id", s = ident}})
            end
            -- insert into references unless there's a same-named one already:
            if not references[heading_str] then
              references[heading_str] =
                {destination = "#" .. result.attr.id, attributes = {_keys={}}}
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
            result.level = get_length(match)
          elseif tag == "div" then
            if result.c[1] and result.c[1].t == "class" then
              result.attr = result.attr or {_keys = {}}
              insert_attribute(result.attr, "class", get_string_content(result.c[1]))
              table.remove(result.c, 1)
            end
          elseif tag == "code_block" then
            if result.c[1] then
              if result.c[1].t == "code_language" then
                result.lang = result.c[1].s
                table.remove(result.c, 1)
              end
              if result.c[1].t == "raw_format" then
                local fmt = result.c[1].s:sub(2)
                table.remove(result.c, 1)
                result.t = "raw_block"
                result.format = fmt
              end
              result.s = get_string_content(result)
              result.c = nil
            end
          elseif tag == "block_attributes" then
            if block_attributes then
              block_attributes[#block_attributes + 1] = result.c
            else
              block_attributes = {result.c}
            end
            result = nil
          elseif tag == "attributes" then
            -- parse attributes, add to last node
            local prevnode = node.c[#node.c]
            local endswithspace = false
            if type(prevnode) == "table" then
              if prevnode.t == "str" then
                -- split off last consecutive word of string
                -- to which to attach attributes
                local lastwordpos = string.find(prevnode.s, "%w+$")
                if not lastwordpos then
                  endswithspace = true
                elseif lastwordpos > 1 then
                  local newnode = {t = "str",
                                   s = sub(prevnode.s, lastwordpos, -1)}
                  prevnode.s = sub(prevnode.s, 1, lastwordpos - 1)
                  node.c[#node.c + 1] = newnode
                  prevnode = newnode
                end
              end
              if not endswithspace then
                insert_attributes(prevnode, result.c)
              end
            end
            result = nil
          elseif find(tag, "^list_item") then
            local marker = string.match(subject, "^%S+", startpos)
            local styles = {}
            gsub(tag, "%[([^]]*)%]", function(x) styles[#styles + 1] = x end)
            -- create a list node with the consecutive list items
            -- of the same kind
            local list = {t = "list", c = {result}}
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
              local sp, _, ann = unpack_match(nextitem)
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
                item.pos = {sp, finalpos}
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
          node.c[#node.c + 1] = result
        elseif mod == "-" then -- close
          assert(false, "unmatched " .. annot .. " encountered at byte " ..
                   startpos)
          idx = idx + 1
          return nil
        elseif tag == "reference_key" then
          local key = sub(subject, startpos + 1, endpos - 1)
          local result = {t = "reference_key", s = key}
          idx = idx + 1
          node.c[#node.c + 1] = result
        elseif tag == "reference_value" then
          local val = sub(subject, startpos, endpos)
          local result = {t = "reference_value", s = val}
          idx = idx + 1
          node.c[#node.c + 1] = result
        else -- leaf
          local result
          if tag == "softbreak" then
            result = {t = tag}
          elseif tag == "footnote_reference" then
            result = {t = tag, s = sub(subject, startpos + 2, endpos - 1)}
          else
            result = {t = tag, s = sub(subject, startpos, endpos)}
          end
          if sourcepos then
            result.pos = {startpos, endpos}
          end
          if block_attributes then
            for i=1,#block_attributes do
              insert_attributes(result, block_attributes[i])
            end
            block_attributes = nil
          end
          idx = idx + 1
          if result then
            node.c[#node.c + 1] = result
          end
        end
      end
    end
    return node
  end

  local doc = get_node("doc")
  doc.references = references
  doc.footnotes = footnotes
  return doc
end

local function render_node(node, handle, init, indent)
  indent = indent or 0
  init = init or 1
  handle:write(rep(" ", indent))
  if node.t then
    handle:write(node.t)
    if node.pos then
      handle:write(format(" (%d-%d)", node.pos[1], node.pos[2]))
    end
    for k,v in pairs(node) do
      if type(k) == "string" and k ~= "c" and
          k ~= "type" and k ~= "pos" and k ~= "attr"  and
          k ~= "references" and k ~= "footnotes" then
        handle:write(format(" %s=%q", k, tostring(v)))
      end
    end
    if node.attr then
      local keys = node.attr._keys
      for j=1,#keys do
        local k = keys[j]
        handle:write(format(" %s=%q", k, node.attr[k]))
      end
    end
  else
    print("UNKNOWN:")
    print(require'inspect'(node))
    os.exit(1)
  end
  handle:write("\n")
  if node.c then
    for _,v in ipairs(node.c) do
      render_node(v, handle, 2, indent + 2)
    end
  end
end

local function render(doc, handle)
  handle:write(require'djot.json'.encode(doc) .. "\n")
  render_node(doc, handle, 2, 0)
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
      render_node(v, handle, 2, 4)
    end
    handle:write("}\n")
  end
end

return { to_ast = to_ast,
         render = render,
         insert_attribute = insert_attribute,
         copy_attributes = copy_attributes }
