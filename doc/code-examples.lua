local djot = require("djot")

function renderdjot(txt)
  local parser = djot.Parser:new(txt)
  parser:parse()
  return parser:render_html()
end

function CodeBlock(el)
  local rendered = renderdjot(el.text)
  return {
    pandoc.Div(
    { pandoc.Div({pandoc.CodeBlock(el.text)}, {class="djot"}),
      pandoc.Div({pandoc.CodeBlock(rendered)}, {class="html"})
    }, {class="example"})
  }
end
