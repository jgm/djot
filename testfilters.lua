return function(tests)
package.path = "./?.lua;" .. package.path

local djot=require("djot")
local filter=require("djot.filter")

local test = function(name, func, expected)
  local ok, result = pcall(func)
  if ok then
    if result == expected then
      tests.passed = tests.passed + 1
      if tests.verbose then
        print("[PASS]  " .. name)
      end
    else
      tests.failed = tests.failed + 1
      print("[FAIL]  " .. name .. "\n")
      print("Expected:\n" .. expected .. "Got:\n" .. result)
    end
  else
    tests.errored = tests.errored + 1
    print("[ERROR] " .. name .. "\n" .. result)
  end
end

test("caps",
  function()
    local f = filter.load_filter[[
return {
  str = function(e)
    e.text = e.text:upper()
  end
}
    ]]
    return djot.parse("*Hello* world `code`"):apply_filter(f):render_ast()
  end, [[
doc
  para
    strong
      str text="HELLO"
    str text=" WORLD "
    verbatim text="code"
references = {
}
footnotes = {
}
]])

test("caps inside emph only",
  function()
    local f = filter.load_filter[[
local capitalize = 0
return {
   emph = {
     enter = function(e)
       capitalize = capitalize + 1
     end,
     exit = function(e)
       capitalize = capitalize - 1
     end,
   },
   str = function(e)
     if capitalize > 0 then
       e.text = e.text:upper()
      end
   end
}
    ]]
    return djot.parse("_Hello *world*_ outside"):apply_filter(f):render_ast()
  end, [[
doc
  para
    emph
      str text="HELLO "
      strong
        str text="WORLD"
    str text=" outside"
references = {
}
footnotes = {
}
]])

test("caps except in footnotes",
  function()
    local f = filter.load_filter[[
return {
  str = function(e)
    e.text = e.text:upper()
  end,
  footnote = {
    enter = function(e)
      return true  -- prevent traversing into children
    end
  }
}
    ]]
    return djot.parse("Hello[^1].\n\n[^1]: This is a note."):apply_filter(f):render_ast()
  end, [[
doc
  para
    str text="HELLO"
    footnote_reference text="1"
    str text="."
references = {
}
footnotes = {
  ["1"] =
    footnote
      para
        str text="This is a note."
}
]])


end
