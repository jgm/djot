-- support filters that walk the AST and transform a
-- document between parsing and rendering, like pandoc Lua filters.

-- example: This filter uppercases all str elements.
-- return {
--   str = function(e)
--     e.text = e.text:upper()
--    end
-- }
--
-- A filter may define functions for as many different tag types
-- as it likes.  traverse will walk the AST and apply matching
-- functions to each node.
--
-- to load a filter:
-- local filter = require_filter(path)
-- or
-- local filter = load_filter(string)
--
-- By default filters do a bottom-up traversal; that is, the
-- filter for a node is run after its children have been processed.
-- It is possible to do a top-down travel, though, and even
-- to run separate actions on entering a node (before processing the
-- children) and on exiting (after processing the children). To do
-- this, associate the node's tag with a table containing 'enter' and/or
-- 'exit' functions.  The following filter will capitalize text
-- that is nested inside emphasis, but not other text:
--
-- local capitalize = 0
-- return {
--    emph = {
--      enter = function(e)
--        capitalize = capitalize + 1
--      end,
--      exit = function(e)
--        capitalize = capitalize - 1
--      end,
--    },
--    str = function(e)
--      if capitalize > 0 then
--        e.text = e.text:upper()
--       end
--    end
-- }
--
-- For a top-down traversal, you'd just use the 'enter' functions.
-- If the tag is associated directly with a function, as in the
-- first example above, it is treated as an 'exit' function.
--
-- It is possible to inhibit traversal into the children of a node,
-- by having the 'enter' function return the value true (or any truish
-- value, say 'stop').  This can be used, for example, to prevent
-- the contents of a footnote from being processed:
--
--return {
--  footnote = {
--    enter = function(e)
--      return true
--    end
--   }
-- }
--
-- A single filter may return a table with multiple tables, which will be
-- applied sequentially.
--
-- TODO: Should we automatically make available djot.ast functions like
-- mknode and add_child into the filter environment?
-- TODO: Filter tests/examples.
-- TODO: Filter documentation
--
local function handle_node(node, filterpart)
  local action = filterpart[node.t]
  local action_in, action_out
  if type(action) == "table" then
    action_in = action.enter
    action_out = action.exit
  elseif type(action) == "function" then
    action_out = action
  end
  if action_in then
    local stop_traversal = action_in(node)
    if stop_traversal then
      return
    end
  end
  if node.c then
    for _,child in ipairs(node.c) do
      handle_node(child, filterpart, topdown)
    end
  end
  if node.footnotes then
    for _, note in pairs(node.footnotes) do
      handle_node(note, filterpart, topdown)
    end
  end
  if action_out then
    action_out(node)
  end
end

local function traverse(node, filterpart)
  handle_node(node, filterpart)
  return node
end

local function apply_filter(node, filter)
  for _,filterpart in ipairs(filter) do
    traverse(node, filterpart)
  end
end

-- Returns a table containing the filter defined in fp.
-- fp will be sought using 'require', so it may occur anywhere
-- on the LUA_PATH, or in the working directory. On error,
-- returns nil and an error message.
local function require_filter(fp)
  local oldpackagepath = package.path
  -- allow omitting or providing the .lua extension:
  local ok, filter = pcall(function()
                         package.path = "./?.lua;" .. package.path
                         local f = require(fp:gsub("%.lua$",""))
                         package.path = oldpackagepath
                         return f
                      end)
  if not ok then
    return nil, filter
  elseif type(filter) ~= "table" then
    return nil,  "filter must be a table"
  end
  if #filter == 0 then -- just a single filter part given
    return {filter}
  else
    return filter
  end
end

-- Load filter from a string, which should have the
-- form 'return { ... }'.  On error, return nil and an
-- error message.
local function load_filter(s)
  local fn, err = load(s)
  if fn then
    local filter = fn()
    if type(filter) ~= "table" then
      return nil,  "filter must be a table"
    end
    if #filter == 0 then -- just a single filter given
      return {filter}
    else
      return filter
    end
  else
    return nil, err
  end
end

return {
  apply_filter = apply_filter,
  require_filter = require_filter,
  load_filter = load_filter
}
