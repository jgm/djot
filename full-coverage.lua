package.path = "./?.lua;" .. package.path
-- Full coverage test
--
-- This test is similar to fuzz.lua, but, rather than generating
-- random strings, we exhaustively enumerate short strings.

local djot = require("djot")
local to_html = function(s)
  local doc = djot.parse(s)
  return djot.render_html(doc)
end

local function combinations(alpha, n)
  if n == 0 then
    return {""}
  end
  if alpha == "" then
    return {}
  end
  local res = {}
  local first = alpha:sub(1, 1)
  local rest = alpha:sub(2)
  for _, s in ipairs(combinations(rest, n)) do
    res[#res + 1] = s
  end
  for _, s in ipairs(combinations(rest, n - 1)) do
    res[#res + 1] = first .. s
  end
  return res
end


local n = 4 -- We select n interesting characters
local m = 6 -- and generate every string of length m.
local swarm = combinations(" -*|[]{}()_`:ai\n", n)

local iter = 0
for _, alphabet in ipairs(swarm) do
  iter = iter + 1
  if iter % 10 == 0 then
    print(iter, "of", #swarm)
  end

  -- Tricky bit: we essentially want to write m nested
  -- 'for i=1,m' loops. We can't do that, so instead we
  -- track `m` loop variables in `ii` manually.
  --
  -- That is, `ii` is "vector of `i`s".
  local ii = {}
  for i=1,m do
    ii[i] = 1
  end

  local done = false
  while not done do
    local s = ""
    for i=1,m do
      s = s .. alphabet:sub(ii[i], ii[i])
    end

    to_html(s)

    -- Increment the innermost index, reset others to 1.
    done = true
    for i=m,1,-1 do
      if ii[i] ~= #alphabet then
        ii[i] = ii[i] + 1
        for j=i+1,m do
          ii[j] = 1
        end
        done = false
        break
      end
    end

  end
end
