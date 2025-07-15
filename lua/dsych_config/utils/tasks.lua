local utils = require("dsych_config.utils")
local success, Path  = pcall(require, "pathlib")

if not success then
    vim.notify("Unable to load 'pathlib', tasks integration is going to be disabled", vim.log.levels.WARN)
    return
end

local M = {}

local running_processes = {}
local currently_running_num_of_tasks = 0

local tasks = {}
local total_num_of_tasks = 0

local last_executed_task = nil
local path_to_tasks_file = nil

local add_running_task = vim.schedule_wrap(function(item_id, process_ref)
    running_processes[item_id] = process_ref
    currently_running_num_of_tasks = currently_running_num_of_tasks + 1
end)

local remove_running_task = vim.schedule_wrap(function(item_id)
    running_processes[item_id] = nil
    currently_running_num_of_tasks = currently_running_num_of_tasks - 1
end)

local get_output_found_callback = function(value)
    local callback = value.output_found_callback
    if value.once then
        local old = value.output_found_callback
        callback = function()
            if not value.triggered_output_callback then
                value.triggered_output_callback = true
                if old then
                    old()
                end
            end
        end
    end
    return callback
end

local on_item_selection = function(item)
    last_executed_task = item

    local on_output = function(item)
        return function(_, data)
            if data then
                if type(data) == "string" then
                    data = { data }
                end
                for _, line in ipairs(data) do
                    -- if item.print_out then
                    --     vim.api.nvim_buf_set_lines(buffer, -1, -1, false, line)
                    -- end

                    if string.gmatch(line, item.wait_for_output)() then
                        item.output_found_callback()
                    end
                end
            end
        end
    end

    local cmd = item.command

    -- if type(cmd) == "string" then
    --     cmd = vim.fn.split(cmd)
    -- end
    local item_id = tostring(vim.fn.rand())

    local cwd = vim.fs.joinpath(vim.fn.getcwd(), item.cwd)

    local term_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(term_buffer, true, {
        split = "below",
        vertical = true,
        height = 25
    })

    -- move window to the bottom of viewport
    vim.api.nvim_input("<C-W>J")

    local output_wrapper = on_output(item)
    vim.api.nvim_buf_attach(term_buffer, false, {
        on_lines = function(_, bufnr, _, first, _, last_new)
            local new_lines = vim.api.nvim_buf_get_lines(bufnr, first, last_new, false)
            output_wrapper(nil, new_lines)
        end
    })

    item.triggered_output_callback = false

    local job_id = vim.fn.jobstart(cmd, {
        -- text = true,
        clean_env = false,
        cwd = cwd,
        on_stdout = on_output(item),
        on_stderr = on_output(item),
        stdout_buffered = false,
        stderr_buffered = false,
        -- detach = true,
        on_exit = function(_, code)
            remove_running_task(item_id)
            if code ~= 0 then
                vim.notify(string.format("%s has failed with exit code %d", item.name, code))
            end
            if item.on_exit then
                item.on_exit(code)
            end
        end,
        term = true
    })

    -- enter insert mode to follow buffer
    vim.api.nvim_input("i")

    add_running_task(item_id, {
        task_def = item,
        job_id = job_id,
    })
end

M.run_last_task = function()
    if not last_executed_task then
        vim.notify("No tasks executed, yet!")
        return
    end
    on_item_selection(last_executed_task)
end

M.get_total_num_of_tasks = function()
    return total_num_of_tasks
end
M.get_currently_running_num_of_tasks = function()
    return currently_running_num_of_tasks
end

M.open_tasks_file = function ()
    vim.cmd.edit(path_to_tasks_file)
end

M.refresh = function (path_to_tasks_file)
    tasks = dofile(path_to_tasks_file)

    tasks = vim.tbl_map(function(value)
        value.output_found_callback = get_output_found_callback(value)
        value.triggered_output_callback = false

        return value
    end, tasks)

    total_num_of_tasks = #tasks
end

M.setup = function()
    local matches = vim.fs.find({ ".nvim" }, { type = "directory", upward = true })
    if #matches == 0 then
        return
    end

    local path_to_nvim_dir = matches[1]

    path_to_tasks_file = vim.fs.joinpath(path_to_nvim_dir, "tasks.lua")
    if not utils.does_file_exist(path_to_tasks_file) then
        return
    end

    Path.new(path_to_tasks_file):register_watcher("dsych_tasks", function (file, args)
        if args.events.change then
            M.refresh(path_to_tasks_file)
        elseif args.events.rename then
            path_to_tasks_file = file:realpath()
        end
    end)


    utils.map_key("n", "<leader>ta", M.display_tasks)
    utils.map_key("n", "<leader>tr", M.show_running_tasks)
    utils.map_key("n", "<leader>tl", M.run_last_task)
    utils.map_key("n", "<leader>tc", M.open_tasks_file)

    M.refresh(path_to_tasks_file)
end

M.show_running_tasks = function()
    local on_exit = function(item)
        if item then
            vim.notify("Killing " .. item.task_def.name)
            vim.fn.jobstop(item.job_id)
        end
    end

    local processes = vim.tbl_filter(function(item)
        return item ~= nil
    end, running_processes)

    vim.ui.select(processes, {
        prompt = "Select running task for termination",
        format_item = function(item)
            return item.task_def.name .. ": " .. item.task_def.command
        end
    }, on_exit)
end


M.display_tasks = function()
    vim.ui.select(tasks, {
        prompt = "Available tasks",
        format_item = function(item)
            return item.name .. ": " .. item.command
        end
    }, function(item)
        if item then
            on_item_selection(item)
        end
    end)
end

return M
