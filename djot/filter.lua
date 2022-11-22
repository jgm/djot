-- support filters that walk the AST and transform a
-- document between parsing and rendering, like pandoc Lua filters.

-- example: This filter uppercases all str elements.
-- return {
--   str = function(e)
--     e.string = e.string:upper()
--    end
-- }
--
-- A filter may define functions for as many different tag types
-- as it likes.  applyFilter will walk the AST and apply matching
-- functions to each node.
--
-- to load a filter:
-- local filter = dostring(contents) or
-- local filters = load_filter(path)
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
-- A single file may return a table with multiple filters, which will be
-- applied sequentially.
--
-- TODO: Should we automatically make available djot.ast functions like
-- mknode and add_child into the filter environment?
-- TODO: Filter tests/examples.
-- TODO: Filter documentation
--
local function handle_node(node, filter)
  local action = filter[node.t]
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
      handle_node(child, filter, topdown)
    end
  end
  if node.footnotes then
    for _, note in pairs(node.footnotes) do
      handle_node(note, filter, topdown)
    end
  end
  if action_out then
    action_out(node)
  end
end

local function traverse(node, filter)
  handle_node(node, filter)
  return node
end

-- Returns a table containing the filters defined in fp.
-- fp will be sought using 'require', so it may occur anywhere
-- on the LUA_PATH, or in the working directory.
local function load_filter(fp)
  local oldpackagepath = package.path
  package.path = "./?.lua;" .. package.path
  -- allow omitting or providing the .lua extension:
  local filter = require(fp:gsub("%.lua$",""))
  package.path = oldpackagepath
  if #filter == 0 then -- just a single filter given
    return {filter}
  else
    return filter
  end
end

return {
  traverse = traverse,
  load_filter = load_filter
}
