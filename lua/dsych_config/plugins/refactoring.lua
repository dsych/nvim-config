return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  lazy = false,
  config = function()
    require("refactoring").setup({

    })

    local map_key = require("dsych_config.utils").map_key
    map_key("x", "<leader>lm", function() require('refactoring').refactor('Extract Function') end)
    map_key("n", "<leader>lM", function() require('refactoring').refactor('Inline Function') end)
    map_key("x", "<leader>rf", function() require('refactoring').refactor('Extract Function To File') end)
    map_key("x", "<leader>le", function() require('refactoring').refactor('Extract Variable') end)
    map_key({ "n", "x" }, "<leader>lE", function() require('refactoring').refactor('Inline Variable') end)

    map_key(
        {"n", "x"},
        "<leader>ls",
        function() require('refactoring').select_refactor() end
    )
    map_key(
      "n",
      "<leader>lp",
      function() require('refactoring').debug.printf({below = false}) end
    )
    map_key({"x", "n"}, "<leader>lpv", function() require('refactoring').debug.print_var() end)
    map_key("n", "<leader>lpc", function() require('refactoring').debug.cleanup({}) end)

  end,
}
