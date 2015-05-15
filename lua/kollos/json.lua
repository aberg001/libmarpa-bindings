require 'os'

-- kollos paths
package.path =
  ';?.lua;../?.lua;../lua/?.lua;' ..
  '../../build/main/?.lua;' ..
  '../../../kollos/build/main/?.lua;' ..
  package.path

package.cpath =
  ';../../build/main/lib?.so;../../build/main/cyg?.dll;' ..
  ';../../../kollos/build/main/lib?.so;../../../kollos/build/main/cyg?.dll;' ..
  package.cpath

local kollos_external = require "kollos"
local _klol = kollos_external._klol

local dumper = require 'dumper'

-- JSON grammar specification
-- only symbols in quotes: no literals or regexes
--[[
  lhs = 'rhs' -- lexical rules, rhs can be a string or a Lua pattern or (in future) a regex
  lhs = {
    { 'rhs1', ... }
    { 'rhs2', ... { adverb = value, ... } }
  }
   events
    predicted
    completed
    expected
    nulled
--]]

--[[
  JSON LUIF grammar for Kollos,
  https://github.com/jeffreykegler/kollos/blob/master/working/json.luif

    json         ::= object
                   | array
    object       ::= [lcurly rcurly]
                   | [lcurly] members [rcurly]
    members      ::= pair+ % comma
    pair         ::= string [colon] value
    value        ::= string
                   | object
                   | number
                   | array
                   | json_true
                   | json_false
                   | null
    array        ::= [lsquare rsquare]
                   | [lsquare] elements [rsquare]
    elements     ::= value+ % comma
    string       ::= lstring
--]]

local jg = {
  parser = {
    _start_symbol = 'json',
    json = {
      { 'object' },
      { 'array' }
    },
    object = {
      { 'lcurly', 'rcurly' },
      { 'lcurly', 'members', 'rcurly' },
    },
    members = {
      { 'pair', { proper = true, quantifier = '+', separator = 'comma' } }
    },
    pair = {
      { 'string', 'colon', 'value' }
    },
    value = {
      { 'string' },
      { 'object' },
      { 'number' },
      { 'array' },
      { 'true' },
      { 'false' },
      { 'null' },
    },
    array = {
      { 'lsquare', 'rsquare' },
      { 'lsquare', 'elements', 'rsquare' },
    },
    elements = {
      { 'value', { proper = true, quantifier = '+', separator = 'comma' } },
    },
  },
  -- lexer rules (order is important)
  lexer = {
    { [[\{]], "lcurly" },
    { [[\}]], "rcurly" },
    { [[\[]], "lsquare" },
    { '\\]',  "rsquare" },
    { ',',    "comma" },
    { ':',    "colon" },

    { [["(?:(?:[^"\\]|\\[\\"/bfnrt]|\\u\d{4})*)"]],     "string", 8 },
    { [[-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?]],  "number", 9 },

    { [[\btrue\b]],  "true" },
    { [[\bfalse\b]], "false" },
    { [[\bnull\b]],  "null" },

    { '[ \t]+', 'WHITESPACE' },  -- Skip over spaces and tabs
    { "\n", 'NEWLINE' },  -- Line endings
    { '.', 'MISMATCH' }   -- Any other character
  },
  actions = {
    --[[ 'lhs1, lhs2, lhs3' = function(span, literal) end
    --]]
  }
}

local symbols = {} -- symbol table
-- add symbol s to grammar g avoiding duplication via symbols table
-- if symbol exists, return its id
local function symbol_new(s, g)
  assert(type(s) == "string", "symbol must be a string")
  assert(type(g) == "table", "grammar must be table")
  local s_id = symbols[s]
  if s_id == nil then
    s_id = g:symbol_new (g)
    assert(s_id >= 0, "symbol_new failed: " .. s)
    symbols[tostring(s_id)] = s
    symbols[s]    = s_id
  else
    s_id = symbols[s]
  end
  return s_id
end

g = _klol.grammar()

-- parser rules
assert( type(jg["lexer"]) == "table", [[Grammar spec must have a table under "parser" key]])
for lhs, rhs in pairs(jg["parser"]) do
  -- handle start symbol
  if lhs == '_start_symbol' then
    local S_start = symbol_new(rhs, g)
    lib.assert( C.marpa_g_start_symbol_set(g, S_start), "marpa_g_start_symbol_set", g )
  else
    -- d.pt(lhs, ':=', d.s(rhs))
    -- add lhs symbol to the grammar
    local S_lhs = symbol_new(lhs, g)
    -- add rhs symbol to grammar
    assert( type(rhs) == "table", "rhs must be a table of strings representing symbols")
    for _, rhs_alternative in ipairs(rhs) do
      assert( type(rhs_alternative) == "table", "rhs_alternative must be a table of strings representing symbols")
      -- extract rule's adverbs, if any
      local adverbs = {}
      if type(rhs_alternative[#rhs_alternative]) == "table" then
        adverbs = table.remove(rhs_alternative)
      end
      -- add rule's rhs symbols to the grammar
      local S_rhs_symbol = {}
      for ix, rhs_symbol in pairs(rhs_alternative) do
        S_rhs_symbol[ix] = symbol_new(rhs_symbol, g)
      end
      -- add rule to the grammar
      -- d.pt(lhs, ':=', d.s(rhs_alternative))
      if next(adverbs) ~= nil then
        -- based on adverbs
        if adverbs["quantifier"] == "+" or adverbs["quantifier"] == "*" then

          -- d.pt("# sequence rule")
          -- d.pt(d.i(adverbs))

          -- todo: implement keep (separator) adverb, off by default

          -- add separator symbol
          local S_separator = symbol_new(adverbs["separator"], g)
          -- add item symbol
          assert( #rhs_alternative == 1, "sequence rule must have only 1 symbol on its RHS" )
          local S_item = S_rhs_symbol[1]
          -- d.pt(d.i(S_separator, S_item))
          lib.assert(
            C.marpa_g_sequence_new (
              g, S_lhs, S_item, S_separator,
              adverbs["quantifier"] == "+" and 1 or adverbs["quantifier"] == "*" and 0 or -1,
              C.MARPA_PROPER_SEPARATION
            ), "marpa_g_sequence_new", g
          )
        else
          -- other rule types based on adverbs
          -- ...
        end
      else -- normal rule
        -- d.pt("# normal rule")
        local rhs = ffi.new("int[" .. #rhs_alternative .. "]")
        for ix = 1, #rhs_alternative do
          rhs[ix-1] = S_rhs_symbol[ix]
        end
        lib.assert( C.marpa_g_rule_new (g, S_lhs, rhs, #rhs_alternative), "marpa_g_rule_new", g )
      end
    end
  end
end
-- d.pt(d.i(token_spec))

-- todo:
-- sanity check: all parser's terminals must exist as lexer rule's token_symbol's

-- lexer rules
local token_spec = {}
assert( type(jg["lexer"]) == "table", [[Grammar spec must have a table under "lexer" key]])
for _, rule in ipairs(jg["lexer"]) do
    -- d.pt("# lexer rule")
    local token_pattern = rule[1]
    local token_symbol  = rule[2]
    -- token lhs must exist in the grammar after adding parser rules
    local S_token = symbols[token_symbol] or -1
    -- add to token_spec
    table.insert( token_spec, { token_pattern, token_symbol, S_token } )
end

-- d.pt(d.i(token_spec))

lib.assert( C.marpa_g_precompute(g), "marpa_g_precompute", g )

--[[
todo: more specific error handling/sanity check
  MARPA_ERR_NO_RULES: The grammar has no rules.
  MARPA_ERR_NO_START_SYMBOL: No start symbol was specified.
  MARPA_ERR_INVALID_START_SYMBOL: A start symbol ID was specified, but it is not the ID of a valid symbol.
  MARPA_ERR_START_NOT_LHS: The start symbol is not on the LHS of any rule.
  MARPA_ERR_UNPRODUCTIVE_START: The start symbol is not productive.
  MARPA_ERR_COUNTED_NULLABLE: A symbol on the RHS of a sequence rule is nullable. Libmarpa does not allow this.
  MARPA_ERR_NULLING_TERMINAL: A terminal is also a nulling symbol. Libmarpa does not allow this.
  MARPA_ERR_GRAMMAR_HAS_CYCLE
    marpa_g_has_cycle()
    marpa_g_rule_is_loop()
11.4 Symbols
  unproductive and inaccessible symbols
    marpa_g_symbol_is_accessible()
    marpa_g_symbol_is_productive()
  marpa_g_symbol_is_nullable()
  marpa_g_symbol_is_nulling()

marpa_g_is_precomputed()

--]]

local r = ffi.gc( C.marpa_r_new(g), C.marpa_r_unref )
lib.assert( r, "marpa_r_new", g )

lib.assert( C.marpa_r_start_input(r), "marpa_r_start_input", g )

-- read input from file, if specified on the command line, or set to default value
local input = ''
if table.getn(arg) > 0 then
  local f = io.open( arg[1], "r")
  if f ~= nil then
    input = f:read("*a")
    io.close(f)
  end
end
if input == '' then
  input = '[1,"abc\ndef",-2.3,null,[],[1,2,3],{},{"a":1,"b":2}]'
end

-- lexing

-- return terminals expected at current earleme
local expected = ffi.new("Marpa_Symbol_ID[" .. #token_spec .. "]")
local function expected_terminals(r)
  local count_of_expected = C.marpa_r_terminals_expected (r, expected)
  lib.assert( count_of_expected, "marpa_r_terminals_expected", g )
  -- these terminals must always be matched
  -- once the grammar is represented as BNF + regexes text
  -- these terminals will be added as symbols to Marpa grammar
  -- and this initialization must become {}
  local result = { WHITESPACE = 1, NEWLINE = 1, MISMATCH = 1 }
  for i = 0, count_of_expected do
    result[symbols[tostring(expected[i])]] = 1
  end
  return result
end

require 'lexer'
local lex = lexer.new{tokens = token_spec, input = input }
local token_values = {}

while true do

  local et = expected_terminals(r)
  local token_symbol, token_symbol_id, token_start, token_length, line, column = lex(et)
  if token_symbol == nil then break end

  if token_symbol == 'MISMATCH' then
    print(string.format("Invalid symbol '%s' at %d:%d", input:sub(token_start, token_length - 1), line, column ));
  elseif token_symbol_id >= 0 then
    -- todo: events. if handlers are specified in the grammar
    local status = C.marpa_r_alternative (r, token_symbol_id, token_start, 1)
    if status ~= C.MARPA_ERR_NONE then
      lib.assert( status, 'marpa_r_alternative', g )
    else
      --[[
      todo:
      recovery
        Several error codes leave the recognizer in a fully recoverable state, allowing the
        application to retry the marpa_r_alternative() method. Retry is efficient, and quite useable
        as a parsing technique. The error code of primary interest from this point of view is
        MARPA_ERR_UNEXPECTED_TOKEN_ID, which indicates that the token was not accepted because
        of its token ID. Retry after this condition is used in several applications, and is called
        “the Ruby Slippers technique”.

        The error codes MARPA_ERR_DUPLICATE_TOKEN, MARPA_ERR_NO_TOKEN_EXPECTED_HERE and
        MARPA_ERR_INACCESSIBLE_TOKEN also leave the recognizer in a fully recoverable state, and may
        also be useable for the Ruby Slippers or similar techniques. At this writing, the author
        knows of no applications which attempt to recover from these errors.
      --]]
    end
    status = C.marpa_r_earleme_complete (r)
    lib.assert( status, 'marpa_r_earleme_complete', g )
    token_values[token_start .. ""] = token_length
  end
end

-- pi(token_values)

-- valuation
--[[
  bocage order (next_)tree value steps
  valuator
    init
    tree
      value
        steps(value)
--]]
local bocage = ffi.gc( C.marpa_b_new (r, -1), C.marpa_b_unref )
lib.assert( bocage, "marpa_b_new", g )

local order  = ffi.gc( C.marpa_o_new (bocage), C.marpa_o_unref )
lib.assert( order, "marpa_o_new", g )

local tree   = ffi.gc( C.marpa_t_new (order), C.marpa_t_unref )
lib.assert( tree, "marpa_t_new", g )

local tree_status = C.marpa_t_next (tree)
lib.assert( tree_status, "marpa_t_next", g )

local value = ffi.gc( C.marpa_v_new (tree), marpa_v_unref )
lib.assert( value, "marpa_v_new", g )

--[[
  todo:
    build the json tree
--]]

local stack = {}
local got_json = ''
-- stepping
column = 0
while true do
  local step_type = C.marpa_v_step (value)
  lib.assert( step_type, "marpa_v_step", g )
  if step_type == C.MARPA_STEP_INACTIVE then
    -- d.pt( "The valuator has gone through all of its steps" )
    break
  elseif step_type == C.MARPA_STEP_RULE then
    local first_child_ix = value.t_arg_0
    local last_child_ix  = value.t_arg_n
    local rule_value_ix  = value.t_result -- rule value must go to that ix
    local rule_id = value.t_rule_id
    local rule_lhs_id = C.marpa_g_rule_lhs(g, rule_id)
--    io.stderr:write( sf( "R%-2d: %-10s stack[%2d:%2d] -> [%d]", rule_id, symbols[tostring(rule_lhs_id)], first_child_ix, last_child_ix, rule_value_ix ), "\n" )
  elseif step_type == C.MARPA_STEP_TOKEN then

    local token_id = value.t_token_id
    -- we called _alternative with token_start as the value,
    -- hence the value is the start position of the token
    local token_value = value.t_token_value
    local token_value_ix = value.t_result
--    io.stderr:write( sf( "T%-2d: %-10s %d -> stack[%d]", token_id, symbols[tostring(token_id)], token_value, token_value_ix), "\n")

    local token_start = token_value
    local token_end = token_start + token_values[token_start .. ""] - 1
    local token = input:sub(token_start, token_end)
    -- got_json = got_json .. token
    column = column + string.len(token)
    if column > 60 then column = 0 io.write("\n") end
    io.write(token)

  end
end

io.write("\n")
os.exit()

-- test
local expected_json = string.gsub(input, ' ', '')
if expected_json == got_json then
  print("json parsed ok")
else
  print("json parsed not ok:")
  print("expected: ", expected_json)
  print("got     : ", got_json)
end