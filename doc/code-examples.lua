local djot = require("djot")

function renderdjot(txt)
  return djot.render_html(djot.parse(txt))
end

function CodeBlock(el)
  local lang = el.attr.classes[1]
  if lang then
    return {
      pandoc.Div(
      { pandoc.Div({pandoc.CodeBlock(el.text)}, {class=lang})
      }, {class="example"})
    }
  end
  local rendered = renderdjot(el.text)
  return {
    pandoc.Div(
    { pandoc.Div({pandoc.CodeBlock(el.text)}, {class="djot"}),
      pandoc.Div({pandoc.CodeBlock(rendered)}, {class="html"})
    }, {class="example"})
  }
end
