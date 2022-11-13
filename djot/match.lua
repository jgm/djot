local unpack = unpack or table.unpack

local make_match = function(startpos, endpos, annotation)
  return {startpos, endpos, annotation}
end

local unpack_match = unpack

local get_length = function(match)
  local startpos, endpos = unpack_match(match)
  return 1 + (endpos - startpos)
end

local format_match = function(match)
  local startpos, endpos, annotation = unpack_match(match)
  return string.format("%-s %d-%d\n", annotation, startpos, endpos)
end

local function matches_pattern(match, patt)
  if match then
    local _, _, annot = unpack_match(match)
    return string.find(annot, patt)
  end
end

return {
  make_match = make_match,
  unpack_match = unpack_match,
  get_length = get_length,
  format_match = format_match,
  matches_pattern = matches_pattern
}
