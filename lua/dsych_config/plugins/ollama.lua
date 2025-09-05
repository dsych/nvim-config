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
      bedrock = {
        model = "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        -- model = "us.anthropic.claude-opus-4-1-20250805-v1:0",
        -- model = "us.anthropic.claude-opus-4-20250514-v1:0",
        aws_profile = "personal_bedrock",
        aws_region = "us-east-1",
        disabled_tools = {
          "bash",
          "web_search",
          "fetch",
          "delete_path",
          "move_path",
          "copy_path",
          "create_dir",
          "write_to_file",
          "run_python",
          "rag_search"
        }
      },
    },
    -- provider = "ollama_dev_desk",
    -- auto_suggestions_provider = "ollama_dev_desk",
    provider = "bedrock",
    auto_suggestions_provider = "bedrock",
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
          }),
        },
        input = {
          enabled = false
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
