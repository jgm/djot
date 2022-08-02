-- custom writer for pandoc

local unpack = unpack or table.unpack
local format = string.format
local layout = pandoc.layout
local literal, empty, cr, concat, blankline, chomp, space, cblock, rblock,
  prefixed, nest, hang, nowrap =
  layout.literal, layout.empty, layout.cr, layout.concat, layout.blankline,
  layout.chomp, layout.space, layout.cblock, layout.rblock,
  layout.prefixed, layout.nest, layout.hang, layout.nowrap
local to_roman = pandoc.utils.to_roman_numeral

local footnotes = {}

-- Escape special characters
local function escape(s)
  return (s:gsub("[][\\`{}_*<>~^'\"]", function(s) return "\\" .. s end))
end

local format_number = {}
format_number.Decimal = function(n)
  return format("%d", n)
end
format_number.Example = format_number.Decimal
format_number.DefaultStyle = format_number.Decimal
format_number.LowerAlpha = function(n)
  return string.char(96 + (n % 26))
end
format_number.UpperAlpha = function(n)
  return string.char(64 + (n % 26))
end
format_number.UpperRoman = function(n)
  return to_roman(n)
end
format_number.LowerRoman = function(n)
  return string.lower(to_roman(n))
end

local function is_tight_list(el)
  if not (el.tag == "BulletList" or el.tag == "OrderedList" or
          el.tag == "DefinitionList") then
    return false
  end
  for i=1,#el.content do
    if #el.content[i] == 1 and el.content[i][1].tag == "Plain" then
      -- no change
    elseif #el.content[i] == 2 and el.content[i][1].tag == "Plain" and
           el.content[i][2].tag:match("List") then
      -- no change
    else
      return false
    end
  end
  return true
end

local function has_attributes(el)
  return el.attr and
    (#el.attr.identifier > 0 or #el.attr.classes > 0 or #el.attr.attributes > 0)
end

local function render_attributes(el, isblock)
  if not has_attributes(el) then
    return empty
  end
  local attr = el.attr
  local buff = {"{"}
  if #attr.identifier > 0 then
    buff[#buff + 1] = "#" .. attr.identifier
  end
  for i=1,#attr.classes do
    if #buff > 1 then
      buff[#buff + 1] = space
    end
    buff[#buff + 1] = "." .. attr.classes[i]
  end
  for k,v in pairs(attr.attributes) do
    if #buff > 1 then
      buff[#buff + 1] = space
    end
    buff[#buff + 1] = k .. '="' .. v:gsub('"', '\\"') .. '"'
  end
  buff[#buff + 1] = "}"
  if isblock then
    return rblock(nowrap(concat(buff)), PANDOC_WRITER_OPTIONS.columns)
  else
    return concat(buff)
  end
end

Blocks = {}
Blocks.mt = {}
Blocks.mt.__index = function(tbl,key)
  return function() io.stderr:write("Unimplemented " .. key .. "\n") end
end
setmetatable(Blocks, Blocks.mt)

Inlines = {}
Inlines.mt = {}
Inlines.mt.__index = function(tbl,key)
  return function() io.stderr:write("Unimplemented " .. key .. "\n") end
end
setmetatable(Inlines, Inlines.mt)

local function inlines(ils)
  local buff = {}
  for i=1,#ils do
    local el = ils[i]
    buff[#buff + 1] = Inlines[el.tag](el)
  end
  return concat(buff)
end

local function blocks(bs, sep)
  local dbuff = {}
  for i=1,#bs do
    local el = bs[i]
    dbuff[#dbuff + 1] = Blocks[el.tag](el)
  end
  return concat(dbuff, sep)
end

Blocks.Para = function(el)
  return inlines(el.content)
end

Blocks.Plain = function(el)
  return inlines(el.content)
end

Blocks.BlockQuote = function(el)
  return prefixed(nest(blocks(el.content, blankline), 1), ">")
end

Blocks.Header = function(el)
  local attr = render_attributes(el, true)
  local result = {attr, cr, (string.rep("#", el.level)), space, inlines(el.content)}
  return concat(result)
end

Blocks.Div = function(el)
  local attr = render_attributes(el, true)
  return concat{attr, cr, ":::", cr, blocks(el.content, blankline), cr, ":::"}
end

Blocks.RawBlock = function(el)
  if el.format == "djot" then
    return concat{el.text, cr}
  else
    local ticks = 3
    el.text:gsub("(`+)", function(s) if #s >= ticks then ticks = #s + 1 end end)
    local fence = string.rep("`", ticks)
    return concat{fence, " =" .. el.format, cr,
                  el.text, cr, fence, cr}
  end
end

Blocks.Null = function(el)
  return empty
end

Blocks.LineBlock = function(el)
  local result = {}
  for i=1,#el.content do
    result[#result + 1] = inlines(el.content[i])
  end
  return concat(result, concat{"\\", cr})
end

Blocks.Table = function(el)
  local attr = render_attributes(el, true)
  local tbl = pandoc.utils.to_simple_table(el)
  -- sanity check to make sure a pipe table will work:
  for i=1,#tbl.rows do
    for j=1,#tbl.rows[i] do
      local cell = tbl.rows[i][j]
      if not (#cell == 0 or
              (#cell == 1 and (cell.tag == "Plain" or cell.tag == "Para"))) then
        -- can't be pipe table, so return a code block with plain table
        local plaintable = pandoc.write(pandoc.Pandoc({el}), "plain")
        return Blocks.CodeBlock(pandoc.CodeBlock(plaintable))
      end
    end
  end
  local cellsep = " | "
  local rows = {}
  local hdrcells = {}
  for j=1, #tbl.headers do
    local cell = tbl.headers[j]
    hdrcells[#hdrcells + 1] = blocks(cell, blankline)
  end
  if #hdrcells > 0 then
    rows[#rows + 1] =
      concat{"| ", concat(hdrcells, cellsep), " |", cr}
    local bordercells = {}
    for j=1, #hdrcells do
      local w = layout.offset(hdrcells[j])
      local lm, rm = "-", "-"
      local align = tbl.aligns[j]
      if align == "AlignLeft" or align == "AlignCenter" then
        lm = ":"
      end
      if align == "AlignRight" or align == "AlignCenter" then
        rm = ":"
      end
      bordercells[#bordercells + 1] = lm .. string.rep("-", w) .. rm
    end
    rows[#rows + 1] =
      nowrap(concat{"|", concat(bordercells, "|"), "|", cr})
  end
  for i=1, #tbl.rows do
    local cells = {}
    local row = tbl.rows[i]
    for j=1, #row do
      local cell = row[j]
      cells[#cells + 1] = blocks(cell, blankline)
    end
    rows[#rows + 1] =
      nowrap(concat{"| ", concat(cells, cellsep), " |", cr})
  end
  local caption = empty
  if #tbl.caption > 0 then
    caption = concat{blankline, "^ ", inlines(tbl.caption), cr}
  end
  return concat{attr, concat(rows), caption}
end

Blocks.DefinitionList = function(el)
  local result = {}
  for i=1,#el.content do
    local term , defs = unpack(el.content[i])
    local inner = empty
    for j=1,#defs do
      inner = concat{inner, blankline, blocks(defs[j], blankline)}
    end
    result[#result + 1] =
      hang(inner, 2, concat{ ":", space, inlines(term), cr })
  end
  return concat(result, blankline)
end

Blocks.BulletList = function(el)
  local attr = render_attributes(el, true)
  local result = {attr, cr}
  for i=1,#el.content do
    result[#result + 1] = hang(blocks(el.content[i], blankline), 2, concat{"-",space})
  end
  local sep = blankline
  if is_tight_list(el) then
    sep = cr
  end
  return concat(result, sep)
end

Blocks.OrderedList = function(el)
  local attr = render_attributes(el, true)
  local result = {attr, cr}
  local num = el.start
  local width = 3
  local maxnum = num + #el.content
  if maxnum > 9 then
    width = 4
  end
  local delimfmt = "%s."
  if el.delimiter == "OneParen" then
    delimfmt = "%s)"
  elseif el.delimiter == "TwoParens" then
    delimfmt = "(%s)"
  end
  local sty = el.style
  for i=1,#el.content do
    local barenum = format_number[sty](num)
    local numstr = format(delimfmt, barenum)
    local sps = width - #numstr
    local numsp
    if sps < 1 then
      numsp = space
    else
      numsp = string.rep(" ", sps)
    end
    result[#result + 1] = hang(blocks(el.content[i], blankline), width, concat{numstr,numsp})
    num = num + 1
  end
  local sep = blankline
  if is_tight_list(el) then
    sep = cr
  end
  return concat(result, sep)
end

Blocks.CodeBlock = function(el)
  local ticks = 3
  el.text:gsub("(`+)", function(s) if #s >= ticks then ticks = #s + 1 end end)
  local fence = string.rep("`", ticks)
  local lang = empty
  if #el.classes > 0 then
    lang = " " .. el.classes[1]
    table.remove(el.classes, 1)
  end
  local attr = render_attributes(el, true)
  local result = { attr, cr, fence, lang, cr, el.text, cr, fence, cr }
  return concat(result)
end

Blocks.HorizontalRule = function(el)
  return cblock("* * * * *", PANDOC_WRITER_OPTIONS.columns)
end

Inlines.Str = function(el)
  return escape(el.text)
end

Inlines.Space = function(el)
  return space
end

Inlines.SoftBreak = function(el)
  if PANDOC_WRITER_OPTIONS.wrap_text == "wrap-preserve" then
    return cr
  else
    return space
  end
end

Inlines.LineBreak = function(el)
  return concat{ "\\", cr }
end

Inlines.RawInline = function(el)
  if el.format == "djot" then
    return el.text
  else
    return concat{Inlines.Code(el), "{=", el.format, "}"}
  end
end

Inlines.Code = function(el)
  local ticks = 0
  el.text:gsub("(`+)", function(s) if #s > ticks then ticks = #s end end)
  local use_spaces = el.text:match("^`") or el.text:match("`$")
  local start = string.rep("`", ticks + 1) .. (use_spaces and " " or "")
  local finish = (use_spaces and " " or "") .. string.rep("`", ticks + 1)
  local attr = render_attributes(el)
  local result = { start, el.text, finish, attr }
  return concat(result)
end

Inlines.Emph = function(el)
  return concat{ "_", inlines(el.content), "_" }
end

Inlines.Strong = function(el)
  return concat{ "*", inlines(el.content), "*" }
end

Inlines.Strikeout = function(el)
  return concat{ "{-", inlines(el.content), "-}"}
end

Inlines.Subscript = function(el)
  return concat{ "{~", inlines(el.content), "~}"}
end

Inlines.Superscript = function(el)
  return concat{ "{^", inlines(el.content), "^}"}
end

Inlines.SmallCaps = function(el)
  return concat{ "[", inlines(el.content), "]{.smallcaps}"}
end

Inlines.Underline = function(el)
  return concat{ "[", inlines(el.content), "]{.underline}"}
end

Inlines.Cite = function(el)
  return inlines(el.content)
end

Inlines.Math = function(el)
  local marker
  if el.mathtype == "DisplayMath" then
    marker = "$$"
  else
    marker = "$"
  end
  return concat{ marker, Inlines.Code(el) }
end

Inlines.Span = function(el)
  local attr = render_attributes(el)
  return concat{"[", inlines(el.content), "]", attr}
end

Inlines.Link = function(el)
  if el.title and #el.title > 0 then
    el.attributes.title = el.title
    el.title = nil
  end
  local attr = render_attributes(el)
  local result = {"[", inlines(el.content), "](",
                  el.target, ")", attr}
  return concat(result)
end

Inlines.Image = function(el)
  if el.title and #el.title > 0 then
    el.attributes.title = el.title
    el.title = nil
  end
  local attr = render_attributes(el)
  local result = {"![", inlines(el.caption), "](",
                  el.src, ")", attr}
  return concat(result)
end

Inlines.Quoted = function(el)
  if el.quotetype == "DoubleQuote" then
    return concat{'"', inlines(el.content), '"'}
  else
    return concat{"'", inlines(el.content), "'"}
  end
end

Inlines.Note = function(el)
  footnotes[#footnotes + 1] = el.content
  local num = #footnotes
  return literal(format("[^%d]", num))
end

function Writer (doc, opts)
  local d = blocks(doc.blocks, blankline)
  local notes = {}
  for i=1,#footnotes do
    local note = hang(blocks(footnotes[i], blankline), 4, concat{format("[^%d]:",i),space})
    table.insert(notes, note)
  end
  return layout.render(concat{d, blankline, concat(notes, blankline)}, PANDOC_WRITER_OPTIONS.columns)
end
