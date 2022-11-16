if not utf8 then
  -- this is needed for the __pairs metamethod, used below
  require("compat53") -- luarocks install compat53
  utf8 = require("utf8") -- luarocks install utf8
end
local match = require("djot.match")
local emoji -- require this later, only if emoji encountered

local find, lower, sub, rep, format =
  string.find, string.lower, string.sub, string.rep, string.format

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
  blankline = true
}

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

local function make_definition_list_item(node)
  node.t = "definition_list_item"
  if not has_children(node) then
    node.c = {}
  end
  if node.c[1] and node.c[1].t == "para" then
    node.c[1].t = "term"
  else
    table.insert(node.c, 1, mknode("term"))
  end
  if node.c[2] then
    local defn = mknode("definition")
    defn.c = {}
    for i=2,#node.c do
      defn.c[#defn.c + 1] = node.c[i]
      node.c[i] = nil
    end
    node.c[2] = defn
  end
end

local function resolve_style(list)
  local style = nil
  for k,i in pairs(list.styles) do
    if not style or i < style.priority then
      style = {name = k, priority = i}
    end
  end
  list.list_style = style.name
  list.styles = nil
  list.start = get_list_start(list.startmarker, list.list_style)
  list.startmarker = nil
end


-- create an abstract syntax tree based on an event
-- stream and references. returns the ast and the
-- source position map.
local function to_ast(tokenizer, sourcepos)
  local subject = tokenizer.subject
  local warn = tokenizer.warn
  if not warn then
    warn = function() end
  end
  local idx = 1
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

  local function set_startpos(node, pos)
    if sourceposmap then
      if not node.pos then
        node.pos = {}
      end
      node.pos[1] = format_sourcepos(sourceposmap[pos])
    end
  end

  local function set_endpos(node, pos)
    if sourceposmap and node.pos then
      if not node.pos then
        node.pos = {}
      end
      node.pos[2] = format_sourcepos(sourceposmap[pos])
    end
  end

  local blocktag = {
    heading = true,
    div = true,
    list = true,
    list_item = true,
    code_block = true,
    para = true,
    blockquote = true,
    table = true,
    thematic_break = true,
    raw_block = true,
    reference_definition = true
  }

  local block_attributes = nil
  local function add_block_attributes(node)
    if block_attributes and blocktag[node.t:gsub("%[.*%]","")] then
      for i=1,#block_attributes do
        insert_attributes_from_nodes(node, block_attributes[i])
      end
      -- add to identifiers table so we don't get duplicate auto-generated ids
      if node.attr and node.attr.id then
        identifiers[node.attr.id] = true
      end
      block_attributes = nil
    end
  end

  -- two variables used for tight/loose list determination:
  local tags = {} -- used to keep track of blank lines
  local matchidx = 0 -- keep track of the index of the match

  local function is_tight(startidx, endidx, is_last_item)
    -- see if there are any blank lines between blocks in a list item.
    local blanklines = 0
    -- we don't care about blank lines at very end of list
    for i=startidx, endidx do
      local tag = tags[i]
      if tag == "blankline" then
        if not ((string.find(tags[i+1], "%+list_item") or
                (string.find(tags[i+1], "%-list_item") and
                 (is_last_item or
                   string.find(tags[i+2], "%-list_item"))))) then
          -- don't count blank lines before list starts
          -- don't count blank lines at end of nested lists or end of last item
          blanklines = blanklines + 1
        end
      end
    end
    return (blanklines == 0)
  end

  local function add_child_to_tip(containers, child)
    if containers[#containers].t == "list" and
        not (child.t == "list_item" or child.t == "definition_list_item") then
      -- close list
      local oldlist = table.remove(containers)
      add_child_to_tip(containers, oldlist)
    end
    if child.t == "list" then
      if child.pos then
        child.pos[2] = child.c[#child.c].pos[2]
      end
      -- calculate tightness (TODO not quite right)
      local tight = true
      for i=1,#child.c do
        tight = tight and is_tight(child.c[i].startidx,
                                     child.c[i].endidx, i == #child.c)
        child.c[i].startidx = nil
        child.c[i].endidx = nil
      end
      child.tight = tight

      -- resolve style if still ambiguous
      resolve_style(child)
    end
    add_child(containers[#containers], child)
  end


  -- process a match:
  -- containers is the stack of containers, with #container
  -- being the one that would receive a new node
  local function handle_match(match, containers)
    matchidx = matchidx + 1
    local startpos, endpos, annot = unpack_match(match)
    local mod, tag = string.match(annot, "^([-+]?)(.+)")
    tags[matchidx] = annot
    if ignorable[tag] then
      return
    end
    if mod == "+" then
      -- process open match:
      -- * open a new node and put it at end of containers stack
      -- * depending on the tag name, do other things
      local node = mknode(tag)
      set_startpos(node, startpos)

      -- add block attributes if any have accumulated:
      add_block_attributes(node)

      if tag == "heading" then
         node.level = get_length(match)

      elseif find(tag, "^list_item") then
        node.t = "list_item"
        node.startidx = matchidx -- for tight/loose determination
        local _, _, style_marker = string.find(tag, "(%[.*)")
        local styles = {}
        if style_marker then
          local i=1
          for sty in string.gmatch(style_marker, "%[([^]]*)%]") do
            styles[sty] = i
            i = i + 1
          end
        end
        node.style_marker = style_marker

        local marker = string.match(subject, "^%S+", startpos)

        -- adjust container stack so that the tip can accept this
        -- kind of list item, adding a list if needed and possibly
        -- closing an existing list

        local tip = containers[#containers]
        if tip.t ~= "list" then
          -- container is not a list ; add one
          local list = mknode("list")
          set_startpos(list, startpos)
          list.styles = styles
          list.attr = node.attr
          list.startmarker = marker
          node.attr = nil
          containers[#containers + 1] = list
        else
          -- it's a list, but is it the right kind?
          local matched_styles = {}
          local has_match = false
          for k,_ in pairs(styles) do
            if tip.styles[k] then
              has_match = true
              matched_styles[k] = styles[k]
            end
          end
          if has_match then
            -- yes, list can accept this item
            tip.styles = matched_styles
          else
            -- no, list can't accept this item ; close it
            local oldlist = table.remove(containers)
            add_child_to_tip(containers, oldlist)
            -- add a new sibling list node with the right style
            local list = mknode("list")
            set_startpos(list, startpos)
            list.styles = styles
            list.attr = node.attr
            list.startmarker = marker
            node.attr = nil
            containers[#containers + 1] = list
          end
        end


      end

      -- add to container stack
      containers[#containers + 1] = node

    elseif mod == "-" then
      -- process close match:
      -- * check end of containers stack; if tag matches, add
      --   end position, pop the item off the stack, and add
      --   it as a child of the next container on the stack
      -- * if it doesn't match, issue a warning and ignore this tag

      if containers[#containers].t == "list" then
        local listnode = table.remove(containers)
        add_child_to_tip(containers, listnode)
      end

      if tag == containers[#containers].t then
        local node = table.remove(containers)
        set_endpos(node, endpos)

        if node.t == "block_attributes" then
          if not block_attributes then
            block_attributes = {}
          end
          block_attributes[#block_attributes + 1] = node.c
          return -- we don't add this to parent; instead we store
          -- the block attributes and add them to the next block

        elseif node.t == "attributes" then
          -- parse attributes, add to last node
          local tip = containers[#containers]
          local prevnode = has_children(tip) and tip.c[#tip.c]
          if prevnode then
            local endswithspace = false
            if prevnode.t == "str" then
              -- split off last consecutive word of string
              -- to which to attach attributes
              local lastwordpos = string.find(prevnode.s, "[^%s]+$")
              if not lastwordpos then
                endswithspace = true
              elseif lastwordpos > 1 then
                local newnode = mknode("str")
                newnode.s = sub(prevnode.s, lastwordpos, -1)
                prevnode.s = sub(prevnode.s, 1, lastwordpos - 1)
                add_child_to_tip(containers, newnode)
                prevnode = newnode
              end
            end
            if has_children(node) and not endswithspace then
              insert_attributes_from_nodes(prevnode, node.c)
            end
          else
            warn({message = "Ignoring unattached attribute", pos = startpos})
          end
          return -- don't add the attribute node to the tree

        elseif tag == "reference_definition" then
          local dest = ""
          local key
          for i=1,#node.c do
            if node.c[i].t == "reference_key" then
              key = node.c[i].s
            end
            if node.c[i].t == "reference_value" then
              dest = dest .. node.c[i].s
            end
          end
          references[key] = { destination = dest }
          if node.attr then
            references[key].attributes = node.attr
          end

        elseif tag == "footnote" then
          local label
          if has_children(node) and node.c[1].t == "note_label" then
            label = node.c[1].s
            table.remove(node.c, 1)
          end
          if label then
            footnotes[label] = node
          end
          return -- don't include in tree


        elseif tag == "table" then

          -- Children are the rows. Look for a separator line:
          -- if found, make the preceding rows headings
          -- and set attributes for column alignments on the table.

          local i=1
          local aligns = {}
          while i <= #node.c do
            local found, align
            if node.c[i].t == "row" then
              local row = node.c[i].c
              for j=1,#row do
                found, _, align = find(row[j].t, "^separator_(.*)")
                if not found then
                  break
                end
                aligns[j] = align
              end
              if found and #aligns > 0 then
                -- set previous row to head and adjust aligns
                local prevrow = node.c[i - 1]
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
                table.remove(node.c, i) -- remove sep line
                -- we don't need to increment i because we removed ith elt
              else
                if #aligns > 0 then
                  for l=1,#node.c[i].c do
                    if aligns[l] ~= "default" then
                      node.c[i].c[l].align = aligns[l]
                    end
                  end
                end
                i = i + 1
              end
            end
          end

        elseif tag == "code_block" then
          if has_children(node) then
            if node.c[1].t == "code_language" then
              node.lang = node.c[1].s
              table.remove(node.c, 1)
            elseif node.c[1].t == "raw_format" then
              local fmt = node.c[1].s:sub(2)
              table.remove(node.c, 1)
              node.t = "raw_block"
              node.format = fmt
            end
          end
          node.s = get_string_content(node)
          node.c = nil

        elseif find(tag, "^list_item") then
          node.t = "list_item"
          node.endidx = matchidx -- for tight/loose determination

          if node.style_marker == "[:]" then
            make_definition_list_item(node)
          end

          if node.style_marker == "[X]" and has_children(node) then
            if node.c[1].t == "checkbox_checked" then
              node.checkbox = "checked"
              table.remove(node.c, 1)
            elseif node.c[1].t == "checkbox_unchecked" then
              node.checkbox = "unchecked"
              table.remove(node.c, 1)
            end
          end

          node.style_marker = nil

        elseif tag == "inline_math" then
          node.t = "math"
          node.attr = mkattributes{class = "math inline"}

        elseif tag == "display_math" then
          node.t = "math"
          node.attr = mkattributes{class = "math display"}

        elseif tag == "imagetext" then
          node.t = "image"

        elseif tag == "linktext" then
          node.t = "link"

        elseif tag == "div" then
          node.c = node.c or {}
          if node.c[1] and node.c[1].t == "class" then
            node.attr = mkattributes(node.attr)
            insert_attribute(node.attr, "class", get_string_content(node.c[1]))
            table.remove(node.c, 1)
          end

        elseif tag == "verbatim" then
          local s = get_string_content(node)
          -- trim space next to ` at beginning or end
          if find(s, "^ +`") then
            s = s:sub(2)
          end
          if find(s, "` +$") then
            s = s:sub(1, #s - 1)
          end
          node.s = s
          node.c = nil

        elseif tag == "url" then
          node.destination = get_string_content(node)

        elseif tag == "email" then
          node.destination = "mailto:" .. get_string_content(node)

        elseif tag == "caption" then
          local tip = containers[#containers]
          local prevnode = has_children(tip) and tip.c[#tip.c]
          if prevnode and prevnode.t == "table" then
            -- move caption in table node
            table.insert(prevnode.c, 1, node)
          else
            warn({ message = "Ignoring caption without preceding table",
                   pos = startpos })
          end
          return

        elseif tag == "heading" then
          local heading_str =
                 get_string_content(node):gsub("^%s+",""):gsub("%s+$","")
          if not node.attr then
            node.attr = mkattributes{}
          end
          if not node.attr.id then  -- generate id attribute from heading
            insert_attribute(node.attr, "id", get_identifier(heading_str))
          end
          -- insert into references unless there's a same-named one already:
          if not references[heading_str] then
            references[heading_str] = {destination = "#" .. node.attr.id}
          end

        elseif tag == "destination" then
           local tip = containers[#containers]
           local prevnode = has_children(tip) and tip.c[#tip.c]
           assert(prevnode and (prevnode.t == "image" or prevnode.t == "link"),
                  "destination with no preceding link or image")
           prevnode.destination = get_string_content(node):gsub("\r?\n", "")
           return  -- do not put on container stack

        elseif tag == "reference" then
           local tip = containers[#containers]
           local prevnode = has_children(tip) and tip.c[#tip.c]
           assert(prevnode and (prevnode.t == "image" or prevnode.t == "link"),
                 "reference with no preceding link or image")
           if has_children(node) then
             prevnode.reference = get_string_content(node):gsub("\r?\n", " ")
           else
             prevnode.reference = get_string_content(prevnode):gsub("\r?\n", " ")
           end
           return  -- do not put on container stack
        end

        add_child_to_tip(containers, node)
      else
        assert(false, "unmatched " .. annot .. " encountered at byte " ..
                  startpos)
        return
      end
    else
      -- process leaf node:
      -- * add position info
      -- * special handling depending on tag type
      -- * add node as child of container at end of containers stack
      local node = mknode(tag)
      add_block_attributes(node)
      set_startpos(node, startpos)
      set_endpos(node, endpos)

      -- special handling:
      if tag == "softbreak" then
        node.s = nil
      elseif tag == "reference_key" then
        node.s = sub(subject, startpos + 1, endpos - 1)
      elseif tag == "footnote_reference" then
        node.s = sub(subject, startpos + 2, endpos - 1)
      elseif tag == "emoji" then
        node.alias = sub(subject, startpos + 1, endpos - 1)
        emoji = require("djot.emoji")
        local found = emoji[node.alias]
        node.s = found
      elseif tag == "raw_format" then
        local tip = containers[#containers]
        local prevnode = has_children(tip) and tip.c[#tip.c]
        if prevnode and prevnode.t == "verbatim" then
          local s = get_string_content(prevnode)
          prevnode.t = "raw_inline"
          prevnode.s = s
          prevnode.c = nil
          prevnode.format = sub(subject, startpos + 2, endpos - 1)
          return  -- don't add this node to containers
        else
          node.s = sub(subject, startpos, endpos)
        end
      else
        node.s = sub(subject, startpos, endpos)
      end

      add_child_to_tip(containers, node)

    end
  end

  local idx = 1
  local doc = mknode("doc")
  local containers = {doc}
  for match in tokenizer:tokenize() do
    handle_match(match, containers)
  end
  -- close any open containers
  while #containers > 1 do
    local node = table.remove(containers)
    add_child_to_tip(containers, node)
    if sourceposmap then
      containers[#containers].pos[2] = node.pos[2]
    end
  end

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
