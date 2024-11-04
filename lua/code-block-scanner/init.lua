local M = {}

-- Default configuration
M.defaults = {
    -- Enable automatic scanning on file load and save
    auto_scan = true,

    -- Default highlight group for virtual text
    highlight_group = "Comment",

    -- Virtual text positioning
    virt_text_pos = 'above',

    -- Block type handlers - only these blocks will be processed
    block_types = {
        -- Image blocks only by default
        img = function(content)
            return "🖼 Image: " .. content:gsub("-", " ")
        end,
    },

    -- Events that trigger auto-scan
    events = { "BufEnter", "BufWritePost" },

    -- File patterns to scan
    patterns = { "*.md", "*.txt" },
}

-- Internal namespace for virtual text
local ns = vim.api.nvim_create_namespace('code_block_scanner')

-- Setup function
function M.setup(opts)
    -- Merge user config with defaults
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

-- Process block text based on type
local function process_block_text(block_type, content)
    -- Only process if there's a handler function for this block type
    if M.options.block_types[block_type] and type(M.options.block_types[block_type]) == "function" then
        return M.options.block_types[block_type](content)
    end
    -- Return nil if no handler found (block will be skipped)
    return nil
end

-- Main scanning function
function M.scan_code_blocks()
    -- Clear existing virtual text
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local in_block = false
    local block_type = nil
    local block_start = nil
    local block_content = {}

    for i, line in ipairs(lines) do
        if line:match("^```(.*)$") then
            if not in_block then
                in_block = true
                block_type = line:match("^```(.*)$")
                block_start = i
                block_content = {}
            else
                in_block = false

                if #block_content > 0 then
                    local processed_text = process_block_text(block_type, table.concat(block_content, "\n"))
                    -- Only add virtual text if the block was processed
                    if processed_text then
                        vim.api.nvim_buf_set_extmark(0, ns, block_start - 1, 0, {
                            virt_lines = { {
                                { processed_text, M.options.highlight_group }
                            } },
                            virt_lines_above = M.options.virt_text_pos == 'above',
                        })
                    end
                end
            end
        elseif in_block then
            table.insert(block_content, line)
        end
    end
end

-- Create commands and set up autocommands
local function create_commands()
    -- Create the scan command
    vim.api.nvim_create_user_command('ScanCodeBlocks', function()
        M.scan_code_blocks()
    end, {})

    -- Create command to toggle auto-scan
    vim.api.nvim_create_user_command('ToggleCodeBlockScan', function()
        M.options.auto_scan = not M.options.auto_scan
        print("Auto-scan " .. (M.options.auto_scan and "enabled" or "disabled"))
    end, {})

    -- Set up auto-scan if enabled
    if M.options.auto_scan then
        vim.api.nvim_create_autocmd(M.options.events, {
            pattern = M.options.patterns,
            callback = function()
                M.scan_code_blocks()
            end,
        })
    end
end

-- Initialize the plugin
function M.init()
    create_commands()
end

return M
