------------------------------------------------------------------------------------------------------------------------------
-- => GLOBAL OVERLOADS
------------------------------------------------------------------------------------------------------------------------------
local utils = require("dsych_config.utils")
utils.source_all_additional_files(vim.fn.stdpath("config") .. "/additional/host")

------------------------------------------------------------------------------------------------------------------------------
-- => General
------------------------------------------------------------------------------------------------------------------------------
require("dsych_config.general")

------------------------------------------------------------------------------------------------------------------------------
-- => Custom commands
------------------------------------------------------------------------------------------------------------------------------
require("dsych_config.commands")

------------------------------------------------------------------------------------------------------------------------------
-- => Key maps
------------------------------------------------------------------------------------------------------------------------------
require("dsych_config.mappings")

------------------------------------------------------------------------------------------------------------------------------
-- => Autocommands
------------------------------------------------------------------------------------------------------------------------------
require("dsych_config.autocommands")

------------------------------------------------------------------------------------------------------------------------------
-- => Plugins
------------------------------------------------------------------------------------------------------------------------------
require("dsych_config.plugins")

--------------------------------------------------------
-- Additional runtime path and script locations
--------------------------------------------------------
-- source any additional configuration files that i don't want to check in git
utils.source_all_additional_files(vim.fn.stdpath("config") .. "/additional")
vim.opt.runtimepath:append("$HOME/.config/nvim/additional")
