function pipe_through(command, input)
    local tmp = os.tmpname()
    local tmpfile = io.open(tmp, "w")
    tmpfile:write(input)
    tmpfile:close()

    local handle = io.popen(command .. " < " .. tmp, "r")
    local output = handle:read("*a")
    handle:close()

    os.remove(tmp)
    return output
end

function CodeBlock(el)
  local rendered = pipe_through('djot', el.text)
  return {
    pandoc.Div(
    { pandoc.Div({pandoc.CodeBlock(el.text)}, {class="djot"}),
      pandoc.Div({pandoc.CodeBlock(rendered)}, {class="html"})
    }, {class="example"})
  }
end
