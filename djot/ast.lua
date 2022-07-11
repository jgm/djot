local match = require("djot.match")
local unpack = unpack or table.unpack

local find, lower, sub, gsub, rep, format =
  string.find, string.lower, string.sub, string.gsub, string.rep, string.format

local unpack_match, get_length, matches_pattern =
  match.unpack_match, match.get_length, match.matches_pattern

local function get_string_content(node)
  local buffer = {}
  for i=2,#node do
    local n = node[i]
    if type(n) ~= "table" then
      break
    elseif n[1] == "str" or n[1] == "nbsp" then
      buffer[#buffer + 1] = n[2]
    elseif n[1] == "softbreak" then
      buffer[#buffer + 1] = "\n"
    else
      buffer[#buffer + 1] = get_string_content(n)
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

local function insert_attributes(targetnode, attrnode)
  targetnode.attr = targetnode.attr or {_keys = {}}
  local i=2
  while i <= #attrnode do
    local x,y = unpack(attrnode[i])
    if x == "id" or x == "class" then
      insert_attribute(targetnode.attr, x, y)
    elseif x == "key" then
      local valnode = attrnode[i + 1]
      if valnode[1] == "value" then
        -- resolve backslash escapes
        insert_attribute(targetnode.attr, y, valnode[2]:gsub("\\(%p)", "%1"))
      end
      i = i + 1
    end
    i = i + 1
  end
end

local function make_definition_list_item(result)
  assert(result[1] and result[1][1] ~= "list_item", "sanity check")
  result[1] = "definition_list_item"
  if result[2] and result[2][1] == "para" then
    result[2][1] = "term"
  else
    table.insert(result, 2, {"term"})
  end
  if result[3] then
    local defn = {"definition"}
    for i=3,#result do
      defn[#defn + 1] = result[i]
      result[i] = nil
    end
    result[3] = defn
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
    local nodes = {maintag}
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
        return nodes
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
          end
          if tag == "verbatim" then
            if #result >= 3 then
              -- trim space next to ` at beginning or end
              local a, b, c, d = result[2], result[3],
                                 result[#result - 1], result[#result]
              if b[1] == "str" and find(b[2], "^`") and
                 ((a[1] == "str" and find(a[2], "^ *$"))
                  or a[1] == "softbreak") then
                 table.remove(result, 2)
              end
              if c[1] == "str" and find(c[2], "^`") and
                 ((d[1] == "str" and find(d[2], "^ *$"))
                  or d[1] == "softbreak") then
                 table.remove(result, #result)
              end
            end
            -- check for raw_format, which makes this a raw node
            local sp,ep,ann = unpack_match(matches[idx])
            if ann == "raw_format" then
              local s = get_string_content(result)
              result = {"raw_inline", s}
              result.format = sub(subject, sp + 2, ep - 1)
              idx = idx + 1 -- skip the raw_format
            end
          elseif tag == "caption" then
            if nodes[#nodes][1] == "table" then
              -- move caption in table node
              table.insert(nodes[#nodes], 2, result)
              result = nil
            end
          elseif tag == "reference_definition" then
            local dest = ""
            local key
            for i=2,#result do
              if result[i][1] == "reference_key" then
                key = result[i][2]
              end
              if result[i][1] == "reference_value" then
                dest = dest .. result[i][2]
              end
            end
            references[key] = { destination = dest,
                                attributes = result.attr }
          elseif tag == "footnote" then
            local label
            if result[2][1] == "note_label" then
              label = result[2][2]
            end
            if label then
              table.remove(result,2)
              footnotes[label] = result
            end
            result = nil
          elseif tag == "inline_math" then
            result[1] = "math"
            result.attr = {class = "math inline", _keys={"class"}}
          elseif tag == "display_math" then
            result[1] = "math"
            result.attr = {class = "math display", _keys={"class"}}
          elseif tag == "url" then
            result[1] = "link"
            result.destination = get_string_content(result)
          elseif tag == "email" then
            result[1] = "link"
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
              if #ref == 1 then -- []
                result.reference = get_string_content(result):gsub("\r?\n", " ")
              else
                result.reference = get_string_content(ref):gsub("\r?\n", " ")
              end
            end
            result[1] = result[1]:gsub("text","")
          elseif tag == "heading" then
            result.level = get_length(match)
            local heading_str = get_string_content(result)
                                 :gsub("^%s+",""):gsub("%s+$","")
            if not (result.attr and result.attr.id) then
              local ident = get_identifier(heading_str)
              insert_attributes(result, {nil,{"id", ident}})
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
            local i=2
            local aligns = {}
            while i <= #result do
              local found, align
              if result[i][1] == "row" then
                local row = result[i]
                for j=2,#row do
                  found, _, align = find(row[j][1], "^separator_(.*)")
                  if not found then
                    break
                  end
                  aligns[j - 1] = align
                end
                if found and #aligns > 0 then
                  -- set previous row to head and adjust aligns
                  local prevrow = result[i - 1]
                  if prevrow[1] == "row" then
                    prevrow.head = true
                    for k=2,#prevrow do
                      -- set head on cells too
                      prevrow[k].head = true
                      if aligns[k - 1] ~= "default" then
                        prevrow[k].align = aligns[k - 1]
                      end
                    end
                  end
                  table.remove(result,i) -- remove sep line
                  -- we don't need to increment i because we removed ith elt
                else
                  if #aligns > 0 then
                    for l=2,#result[i] do
                      if aligns[l - 1] ~= "default" then
                        result[i][l].align = aligns[l - 1]
                      end
                    end
                  end
                  i = i + 1
                end
              end
            end
            result.level = get_length(match)
          elseif tag == "div" then
            if result[2] and result[2][1] == "class" then
              result.attr = result.attr or {_keys = {}}
              insert_attribute(result.attr, "class", result[2][2])
              table.remove(result, 2)
            end
          elseif tag == "code_block" then
            if result[2] then
              if result[2][1] == "code_language" then
                result.lang = result[2][2]
                table.remove(result, 2)
              elseif result[2][1] == "raw_format" then
                local fmt = result[2][2]:sub(2)
                local s = get_string_content(result)
                result = {"raw_block", s}
                result.format = fmt
              end
            end
          elseif tag == "block_attributes" then
            if block_attributes then
              block_attributes[#block_attributes + 1] = result
            else
              block_attributes = {result}
            end
            result = nil
          elseif tag == "attributes" then
            -- parse attributes, add to last node
            local prevnode = nodes[#nodes]
            local endswithspace = false
            if type(prevnode) == "table" then
              if prevnode[1] == "str" then
                -- split off last consecutive word of string
                -- to which to attach attributes
                local lastwordpos = string.find(prevnode[2], "%w+$")
                if not lastwordpos then
                  endswithspace = true
                elseif lastwordpos > 1 then
                  local newnode = {"str", sub(prevnode[2], lastwordpos, -1)}
                  prevnode[2] = sub(prevnode[2], 1, lastwordpos - 1)
                  nodes[#nodes + 1] = newnode
                  prevnode = newnode
                end
              end
              if not endswithspace then
                insert_attributes(prevnode, result)
              end
            end
            result = nil
          elseif find(tag, "^list_item") then
            local marker = string.match(subject, "^%S+", startpos)
            local styles = {}
            gsub(tag, "%[([^]]*)%]", function(x) styles[#styles + 1] = x end)
            -- create a list node with the consecutive list items
            -- of the same kind
            local list = {"list", result}
            -- put the attributes from the first item on the list itself:
            list.attr = result.attr
            result.attr = nil
            result[1] = "list_item"
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

              list[#list].tight = is_tight(matches, startidx, idx - 1, false)
              startidx = idx
              idx = idx + 1
              local item = get_node(tag)
              if tag == "list_item[X]" then
                set_checkbox(item, startidx)
              end
              item[1] = "list_item"
              if sourcepos then
                item.pos = {sp, finalpos}
                list.pos[2] = item.pos[2]
              end
              if marker == ":" then
                make_definition_list_item(item)
              end
              list[#list + 1] = item
              nextitem = matches[idx]
            end
            list[#list].tight = is_tight(matches, startidx, idx - 1, true)
            local tight = true
            for i=2,#list do
              tight = tight and list[i].tight
              list[i].tight = nil
            end
            list.list_style = styles[1] -- resolve, if still ambiguous
            list.tight = tight
            list.start = get_list_start(marker, list.list_style)
            result = list
          end
          nodes[#nodes + 1] = result
        elseif mod == "-" then -- close
          assert(false, "unmatched " .. annot .. " encountered at byte " ..
                   startpos)
          idx = idx + 1
          return nil
        elseif tag == "reference_key" then
          local key = sub(subject, startpos + 1, endpos - 1)
          local result = {tag, key}
          idx = idx + 1
          nodes[#nodes + 1] = result
        elseif tag == "reference_value" then
          local val = sub(subject, startpos, endpos)
          local result = {tag, val}
          idx = idx + 1
          nodes[#nodes + 1] = result
        else -- leaf
          local result
          if tag == "softbreak" then
            result = {tag}
          elseif tag == "footnote_reference" then
            result = {tag, sub(subject, startpos + 2, endpos - 1)}
          else
            result = {tag, sub(subject, startpos, endpos)}
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
            nodes[#nodes + 1] = result
          end
        end
      end
    end
    return nodes
  end

  local doc = get_node("doc")
  doc.references = references
  doc.footnotes = footnotes
  return doc
end

local function render_nodes(nodes, handle, init, indent)
  indent = indent or 0
  init = init or 1
  for i=init,#nodes do
    local node = nodes[i]
    handle:write(rep(" ", indent))
    if type(node) == "string" then
      handle:write(format("%q",node))
    else
      handle:write(node[1])
      if node.pos then
        handle:write(format(" (%d-%d)", node.pos[1], node.pos[2]))
      end
      for k,v in pairs(node) do
        if type(k) == "string" and k ~= "pos" and k ~= "attr" then
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
    end
    handle:write("\n")
    if node[2] then -- children
      render_nodes(node, handle, 2, indent + 2)
    end
  end
end

local function render(doc, handle)
  render_nodes(doc, handle, 2, 0)
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
      render_nodes(v, handle, 2, 4)
    end
    handle:write("}\n")
  end
end

return { to_ast = to_ast,
         render = render,
         insert_attribute = insert_attribute,
         copy_attributes = copy_attributes }
