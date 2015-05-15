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

luif_err_none = _klol.error.code['LUIF_ERR_NONE']
luif_err_unexpected_token = _klol.error.code['LUIF_ERR_UNEXPECTED_TOKEN_ID']

g = _klol.grammar()
top = g:symbol_new()
seq = g:symbol_new()
item = g:symbol_new()
item = g:symbol_new()
prefix = g:symbol_new()
body = g:symbol_new()
a = g:symbol_new()
start_rule = g:rule_new(top, seq)
seq_rule1 = g:rule_new(seq, item)
seq_rule2 = g:rule_new(seq, seq, item)
item_rule = g:rule_new(item, prefix, body)
body_rule = g:rule_new(body, a, a)
g:start_symbol_set(top)
g:precompute()

pass_count = 0
max_pass = arg[1] or 10000
for pass = 1,max_pass do

  r = _klol.recce(g)
  r:start_input()

  result = r:alternative(prefix, 1, 1)
  result = r:earleme_complete()

  while r:is_exhausted() ~= 1 do
    result = r:alternative(a, 1, 1)
    if (not result) then
      -- print("reached earley set " .. r:latest_earley_set())
      break
    end
    result = r:earleme_complete()
    if (result < 0) then
      error("result of earleme_complete = " .. result)
    end
  end
  pass_count = pass_count + 1;

end

print("completed " .. pass_count .. " passes")


g = nil
r = nil
