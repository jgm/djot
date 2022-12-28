local ast = require("djot.ast")
local new_node = ast.new_node
local new_attributes = ast.new_attributes
local add_child = ast.add_child
local unpack = unpack or table.unpack
local insert_attribute, copy_attributes =
  ast.insert_attribute, ast.copy_attributes
local format = string.format
local find, gsub = string.find, string.gsub

-- Produce a copy of a table.
local function copy(tbl)
  local result = {}
  if tbl then
    for k,v in pairs(tbl) do
      local newv = v
      if type(v) == "table" then
        newv = copy(v)
      end
      result[k] = newv
    end
  end
  return result
end

local function to_text(node)
  local buffer = {}
  if node.t == "str" then
    buffer[#buffer + 1] = node.s
  elseif node.t == "nbsp" then
    buffer[#buffer + 1] = "\160"
  elseif node.t == "softbreak" then
    buffer[#buffer + 1] = " "
  elseif node.c and #node.c > 0 then
    for i=1,#node.c do
      buffer[#buffer + 1] = to_text(node.c[i])
    end
  end
  return table.concat(buffer)
end

local Renderer = {}

function Renderer:new()
  local state = {
    out = function(s)
      io.stdout:write(s)
    end,
    tight = false,
    footnote_index = {},
    next_footnote_index = 1,
    references = nil,
    footnotes = nil }
  setmetatable(state, self)
  self.__index = self
  return state
end

Renderer.html_escapes =
   { ["<"] = "&lt;",
     [">"] = "&gt;",
     ["&"] = "&amp;",
     ['"'] = "&quot;" }

function Renderer:escape_html(s)
  if find(s, '[<>&]') then
    return (gsub(s, '[<>&]', self.html_escapes))
  else
    return s
  end
end

function Renderer:escape_html_attribute(s)
  if find(s, '[<>&"]') then
    return (gsub(s, '[<>&"]', self.html_escapes))
  else
    return s
  end
end

function Renderer:render(doc, handle)
  self.references = doc.references
  self.footnotes = doc.footnotes
  if handle then
    self.out = function(s)
      handle:write(s)
    end
  end
  self[doc.t](self, doc)
end


function Renderer:render_children(node)
  -- trap stack overflow
  local ok, err = pcall(function ()
    if node.c and #node.c > 0 then
      local oldtight
      if node.tight ~= nil then
        oldtight = self.tight
        self.tight = node.tight
      end
      for i=1,#node.c do
        self[node.c[i].t](self, node.c[i])
      end
      if node.tight ~= nil then
        self.tight = oldtight
      end
    end
  end)
  if not ok and err:find("stack overflow") then
    self.out("(((DEEPLY NESTED CONTENT OMITTED)))\n")
  end
end

function Renderer:render_attrs(node)
  if node.attr then
    for k,v in pairs(node.attr) do
      self.out(" " .. k .. "=" .. '"' ..
            self:escape_html_attribute(v) .. '"')
    end
  end
  if node.pos then
    local sp, ep = unpack(node.pos)
    self.out(' data-startpos="' .. tostring(sp) ..
      '" data-endpos="' .. tostring(ep) .. '"')
  end
end

function Renderer:render_tag(tag, node)
  self.out("<" .. tag)
  self:render_attrs(node)
  self.out(">")
end

function Renderer:add_backlink(nodes, i)
  local backlink = new_node("link")
  backlink.destination = "#fnref" .. tostring(i)
  backlink.attr = ast.new_attributes({role = "doc-backlink"})
  local arrow = new_node("str")
  arrow.s = "↩︎︎"
  add_child(backlink, arrow)
  if nodes.c[#nodes.c].t == "para" then
    add_child(nodes.c[#nodes.c], backlink)
  else
    local para = new_node("para")
    add_child(para, backlink)
    add_child(nodes, para)
  end
end

function Renderer:doc(node)
  self:render_children(node)
  -- render notes
  if self.next_footnote_index > 1 then
    local ordered_footnotes = {}
    for k,v in pairs(self.footnotes) do
      if self.footnote_index[k] then
        ordered_footnotes[self.footnote_index[k]] = v
      end
    end
    self.out('<section role="doc-endnotes">\n<hr>\n<ol>\n')
    for i=1,#ordered_footnotes do
      local note = ordered_footnotes[i]
      if note then
        self.out(format('<li id="fn%d">\n', i))
        self:add_backlink(note,i)
        self:render_children(note)
        self.out('</li>\n')
      end
    end
    self.out('</ol>\n</section>\n')
  end
end

function Renderer:raw_block(node)
  if node.format == "html" then
    self.out(node.s)  -- no escaping
  end
end

function Renderer:para(node)
  if not self.tight then
    self:render_tag("p", node)
  end
  self:render_children(node)
  if not self.tight then
    self.out("</p>")
  end
  self.out("\n")
end

function Renderer:blockquote(node)
  self:render_tag("blockquote", node)
  self.out("\n")
  self:render_children(node)
  self.out("</blockquote>\n")
end

function Renderer:div(node)
  self:render_tag("div", node)
  self.out("\n")
  self:render_children(node)
  self.out("</div>\n")
end

function Renderer:section(node)
  self:render_tag("section", node)
  self.out("\n")
  self:render_children(node)
  self.out("</section>\n")
end

function Renderer:heading(node)
  self:render_tag("h" .. node.level , node)
  self:render_children(node)
  self.out("</h" .. node.level .. ">\n")
end

function Renderer:thematic_break(node)
  self:render_tag("hr", node)
  self.out("\n")
end

function Renderer:code_block(node)
  self:render_tag("pre", node)
  self.out("<code")
  if node.lang and #node.lang > 0 then
    self.out(" class=\"language-" .. node.lang .. "\"")
  end
  self.out(">")
  self.out(self:escape_html(node.s))
  self.out("</code></pre>\n")
end

function Renderer:table(node)
  self:render_tag("table", node)
  self.out("\n")
  self:render_children(node)
  self.out("</table>\n")
end

function Renderer:row(node)
  self:render_tag("tr", node)
  self.out("\n")
  self:render_children(node)
  self.out("</tr>\n")
end

function Renderer:cell(node)
  local tag
  if node.head then
    tag = "th"
  else
    tag = "td"
  end
  local attr = copy(node.attr)
  if node.align then
    insert_attribute(attr, "style", "text-align: " .. node.align .. ";")
  end
  self:render_tag(tag, {attr = attr})
  self:render_children(node)
  self.out("</" .. tag .. ">\n")
end

function Renderer:caption(node)
  self:render_tag("caption", node)
  self:render_children(node)
  self.out("</caption>\n")
end

function Renderer:list(node)
  local sty = node.style
  if sty == "*" or sty == "+" or sty == "-" then
    self:render_tag("ul", node)
    self.out("\n")
    self:render_children(node)
    self.out("</ul>\n")
  elseif sty == "X" then
    local attr = copy(node.attr)
    if attr.class then
      attr.class = "task-list " .. attr.class
    else
      insert_attribute(attr, "class", "task-list")
    end
    self:render_tag("ul", {attr = attr})
    self.out("\n")
    self:render_children(node)
    self.out("</ul>\n")
  elseif sty == ":" then
    self:render_tag("dl", node)
    self.out("\n")
    self:render_children(node)
    self.out("</dl>\n")
  else
    self.out("<ol")
    if node.start and node.start > 1 then
      self.out(" start=\"" .. node.start .. "\"")
    end
    local list_type = gsub(node.style, "%p", "")
    if list_type ~= "1" then
      self.out(" type=\"" .. list_type .. "\"")
    end
    self:render_attrs(node)
    self.out(">\n")
    self:render_children(node)
    self.out("</ol>\n")
  end
end

function Renderer:list_item(node)
  if node.checkbox then
     if node.checkbox == "checked" then
       self.out('<li class="checked">')
     elseif node.checkbox == "unchecked" then
       self.out('<li class="unchecked">')
     end
  else
    self:render_tag("li", node)
  end
  self.out("\n")
  self:render_children(node)
  self.out("</li>\n")
end

function Renderer:term(node)
  self:render_tag("dt", node)
  self:render_children(node)
  self.out("</dt>\n")
end

function Renderer:definition(node)
  self:render_tag("dd", node)
  self.out("\n")
  self:render_children(node)
  self.out("</dd>\n")
end

function Renderer:definition_list_item(node)
  self:render_children(node)
end

function Renderer:reference_definition()
end

function Renderer:footnote_reference(node)
  local label = node.s
  local index = self.footnote_index[label]
  if not index then
    index = self.next_footnote_index
    self.footnote_index[label] = index
    self.next_footnote_index = self.next_footnote_index + 1
  end
  self.out(format('<a id="fnref%d" href="#fn%d" role="doc-noteref"><sup>%d</sup></a>', index, index, index))
end

function Renderer:raw_inline(node)
  if node.format == "html" then
    self.out(node.s)  -- no escaping
  end
end

function Renderer:str(node)
  -- add a span, if needed, to contain attribute on a bare string:
  if node.attr then
    self:render_tag("span", node)
    self.out(self:escape_html(node.s))
    self.out("</span>")
  else
    self.out(self:escape_html(node.s))
  end
end

function Renderer:softbreak()
  self.out("\n")
end

function Renderer:hardbreak()
  self.out("<br>\n")
end

function Renderer:nbsp()
  self.out("&nbsp;")
end

function Renderer:verbatim(node)
  self:render_tag("code", node)
  self.out(self:escape_html(node.s))
  self.out("</code>")
end

function Renderer:link(node)
  local attrs = new_attributes{}
  if node.reference then
    local ref = self.references[node.reference]
    if ref then
      if ref.attr then
        copy_attributes(attrs, ref.attr)
      end
      insert_attribute(attrs, "href", ref.destination)
    end
  elseif node.destination then
    insert_attribute(attrs, "href", node.destination)
  end
  -- link's attributes override reference's:
  copy_attributes(attrs, node.attr)
  self:render_tag("a", {attr = attrs})
  self:render_children(node)
  self.out("</a>")
end

Renderer.url = Renderer.link

Renderer.email = Renderer.link

function Renderer:image(node)
  local attrs = new_attributes{}
  local alt_text = to_text(node)
  if #alt_text > 0 then
    insert_attribute(attrs, "alt", to_text(node))
  end
  if node.reference then
    local ref = self.references[node.reference]
    if ref then
      if ref.attr then
        copy_attributes(attrs, ref.attr)
      end
      insert_attribute(attrs, "src", ref.destination)
    end
  elseif node.destination then
    insert_attribute(attrs, "src", node.destination)
  end
  -- image's attributes override reference's:
  copy_attributes(attrs, node.attr)
  self:render_tag("img", {attr = attrs})
end

function Renderer:span(node)
  self:render_tag("span", node)
  self:render_children(node)
  self.out("</span>")
end

function Renderer:mark(node)
  self:render_tag("mark", node)
  self:render_children(node)
  self.out("</mark>")
end

function Renderer:insert(node)
  self:render_tag("ins", node)
  self:render_children(node)
  self.out("</ins>")
end

function Renderer:delete(node)
  self:render_tag("del", node)
  self:render_children(node)
  self.out("</del>")
end

function Renderer:subscript(node)
  self:render_tag("sub", node)
  self:render_children(node)
  self.out("</sub>")
end

function Renderer:superscript(node)
  self:render_tag("sup", node)
  self:render_children(node)
  self.out("</sup>")
end

function Renderer:emph(node)
  self:render_tag("em", node)
  self:render_children(node)
  self.out("</em>")
end

function Renderer:strong(node)
  self:render_tag("strong", node)
  self:render_children(node)
  self.out("</strong>")
end

function Renderer:double_quoted(node)
  self.out("&ldquo;")
  self:render_children(node)
  self.out("&rdquo;")
end

function Renderer:single_quoted(node)
  self.out("&lsquo;")
  self:render_children(node)
  self.out("&rsquo;")
end

function Renderer:left_double_quote()
  self.out("&ldquo;")
end

function Renderer:right_double_quote()
  self.out("&rdquo;")
end

function Renderer:left_single_quote()
  self.out("&lsquo;")
end

function Renderer:right_single_quote()
  self.out("&rsquo;")
end

function Renderer:ellipses()
  self.out("&hellip;")
end

function Renderer:em_dash()
  self.out("&mdash;")
end

function Renderer:en_dash()
  self.out("&ndash;")
end

function Renderer:symbol(node)
  self.out(":" .. node.alias .. ":")
end

function Renderer:math(node)
  local math_t = "inline"
  if find(node.attr.class, "display") then
    math_t = "display"
  end
  self:render_tag("span", node)
  if math_t == "inline" then
    self.out("\\(")
  else
    self.out("\\[")
  end
  self.out(self:escape_html(node.s))
  if math_t == "inline" then
    self.out("\\)")
  else
    self.out("\\]")
  end
  self.out("</span>")
end

return { Renderer = Renderer }
