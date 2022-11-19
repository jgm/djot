local djot = require("djot")

local n = 500

local deeplynested = {}
for i = 1,n do
  deeplynested[#deeplynested + 1] = string.rep(" ", i) .. "* a\n"
end

local backticks  = {}
for i = 1, 5 * n do
  backticks[#backticks + 1] = "e" .. string.rep("`", i)
end

local tests = {
  ["nested strong emph"] =
    string.rep("_a *a ", 65*n) .. "b" .. string.rep(" a* a_", 65*n),
  ["many emph closers with no openers"] =
    string.rep("a_ ", 65*n),
  ["many emph openers with no closers"] =
    string.rep("_a ", 65*n),
  ["many link closers with no openers"] =
    string.rep("a]", 65*n),
  ["many link openers with no closers"] =
    string.rep("[a", 65*n),
  ["mismatched openers and closers"] =
    string.rep("*a_ ", 50*n),
  ["issue cmark#389"] =
    string.rep("*a ", 20*n) .. string.rep("_a*_ ", 20*n),
  ["openers and closers multiple of 3"] =
    "a**b" .. string.rep("8* ", 50 * n),
  ["link openers and emph closers"] =
    string.rep("[ a_", 50 * n),
  ["pattern [ (]( repeated"] =
    string.rep("[ (](", 80 * n),
  ["nested brackets"] =
    string.rep("[", 50 * n) .. "a" .. string.rep("]", 50*n),
  ["nested block quotes"] =
    string.rep("> ", 50*n) .. "a",
  ["deeply nested lists"] =
    table.concat(deeplynested),
  ["backticks"] =
    table.concat(backticks),
  ["unclosed links"] =
    string.rep("[a](<b", 30 * n),
  ["unclosed attributes"] =
    string.rep("a{#id k=", 30 * n),
}

for name,test in pairs(tests) do
  io.stdout:write(string.format("%-40s ", name))
  io.stdout:flush()
  local before = os.clock()
  djot.parse(test)
  local elapsed = os.clock() - before
  local kb_per_second = math.floor((#test / 1000) /  elapsed)
  io.stdout:write(string.format("%6d KB/s\n", kb_per_second))
end
