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
-- The traversal will be bottom-up by default, but top-down
-- if
-- traversal = 'topdown'
-- is set.

-- to load a filter:
-- local filter = dostring(contents) or
-- local filter = dofile(path)

local function handle_node(node, filter, topdown)
  local action = filter[node.t]
  -- top down: nodes are processed when entering
  if action ~= nil and topdown then
    action(node)
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
  local action = filter[node.t]
  -- bottom up: nodes are processed when exiting
  if action ~= nil and not topdown then
    action(node)
  end
end

local function traverse(node, filter)
  local topdown = filter.traversal == 'topdown'
  handle_node(node, filter, topdown)
  return node
end

local function load_filter(s)
  return dostring(s)
end

return {
  traverse = traverse,
  load_filter = load_filter
}
