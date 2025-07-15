return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
  opts = {
    providers = {
      ollama = {
        endpoint = "http://127.0.0.1:11435",
        -- model = "qwen2.5-coder",
        -- model = "llama3.3",
        -- model = "codellama:13b",
        -- model = "deepseek-coder-v2",
        -- model = "gemma3:12b",
        model = "gemma_3_coder_12b",
        disable_tools = true,
        extra_request_body = {
          options = {
            num_ctx = 8192,
            temperature = 0,
          },
        },
        stream = true,
      },
      ollama_dev_desk = {
        __inherited_from = "openai",
        api_key_name = "",
        endpoint = "http://127.0.0.1:11434/v1",
        -- model = "qwen2.5-coder",
        model = "llama3.2",
        -- model = "codellama:13b",
        -- model = "deepseek-coder-v2",
        -- model = "codegemma",
        disable_tools = true
      },
    },
    -- provider = "ollama_dev_desk",
    -- auto_suggestions_provider = "ollama_dev_desk",
    provider = "ollama",
    auto_suggestions_provider = "ollama",
    mappings = {
      ask = "<leader>ma",
      edit = "<leader>me",
      refresh = "<leader>mr",
      focus = "<leader>mf",
      toggle = {
        default = "<leader>mt",
        debug = "<leader>md",
        hint = "<leader>mh",
        suggestion = "<leader>ms",
        repomap = "<leader>mR",
      },
      files = {
        add_current = "<leader>mc", -- Add current buffer to selected files
      },
    },
    behaviour = {
      auto_set_keymaps = true
    },
    file_selector = {
      provider = "telescope"
    },
    hints = { enabled = false }
  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    {
      "stevearc/dressing.nvim",
      opts = {
        select = {
          enabled = true,
          telescope = require "telescope.themes".get_dropdown({
            previewer = false,
            layout_config = {
              width = function(_, max_columns, _)
                return math.floor(max_columns * 0.65)
              end
            }
          })

        }
      }
    },
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp",
    "nvim-tree/nvim-web-devicons",   -- or echasnovski/mini.icons
  },
}
