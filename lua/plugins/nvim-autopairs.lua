---@type LazySpec
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    local npairs = require("nvim-autopairs")
    local Rule = require("nvim-autopairs.rule")
    local cond = require("nvim-autopairs.conds")

    npairs.setup({})

    -- auto-pair <> for generics but not as greater-than/less-than operators
    npairs.add_rule(
      Rule("<", ">")
      :with_pair(cond.not_after_regex("[%a%d]", 1))
      :with_pair(cond.before_regex("%a+:?:?$", 3))
      :with_move(function(opts)
        return opts.char == ">"
      end)
    )

    -- auto-pair [] only outside of quotes and never before a word or number
    npairs.remove_rule("[")
    npairs.add_rule(
      Rule("[", "]")
      :with_pair(cond.not_inside_quote())
      :with_pair(cond.not_after_regex("[%a%d]", 1))
      :with_move(function(opts)
        return opts.char == "]"
      end)
    )
  end,
}
