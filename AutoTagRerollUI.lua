--- STEAMODDED HEADER
--- MOD_NAME: Auto Tag Reroll UI
--- MOD_ID: UltraSimpleAnteUI
--- MOD_AUTHOR: [BaalWasTaken]
--- MOD_DESCRIPTION: UI for ante tags with auto-reroll capability
----------------------------------------------

-- This is a minimal UI test for Balatro
local mod = {}

-- Rendering variables
local ui_visible = true
local stored_tags = {}
local tag_count = 0 -- Explicit counter since # operator is unreliable with tables as maps
local debug_info = {} -- Store debug info for display (not shown in UI)
local last_ante_check = 0 -- Used to avoid checking too frequently
local last_screen_check = 0 -- Track when we last checked screen
local last_screen = "" -- Track last known screen
local last_restart_time = 0 -- Track when we last restarted to avoid spam

-- Reroll variables
local reroll_active = false
local target_tag = nil
local reroll_count = 0
local all_tags = {}
local dropdown_open = false
local max_visible_items = 24 -- Set to max number of tags to display all
local min_restart_interval = 3 -- Minimum seconds between restarts
local restarting = false -- Track if we're in the process of restarting

-- Helper to get tag name
local function get_tag_name(tag_key)
    if not tag_key then return "None" end
    if not _G.G.P_TAGS then return "Unknown" end
    local tag_def = _G.G.P_TAGS[tag_key]
    return tag_def and tag_def.name or "Unknown Tag: " .. tag_key
end

-- Populate all tags from the game
local function populate_all_tags()
    -- Clear existing tags
    all_tags = {}
    
    -- First add the tags directly from the Balatro tag list
    -- These are the tags from the wiki: https://balatrogame.fandom.com/wiki/Tags
    local wiki_tags = {
        -- Add all tags from the Balatro Wiki to ensure none are missed
        {key = "tag_uncommon", name = "Uncommon Tag"},
        {key = "tag_rare", name = "Rare Tag"},
        {key = "tag_negative", name = "Negative Tag"},
        {key = "tag_foil", name = "Foil Tag"},
        {key = "tag_holo", name = "Holographic Tag"},
        {key = "tag_polychrome", name = "Polychrome Tag"},
        {key = "tag_investment", name = "Investment Tag"},
        {key = "tag_voucher", name = "Voucher Tag"},
        {key = "tag_boss", name = "Boss Tag"},
        {key = "tag_standard", name = "Standard Tag"},
        {key = "tag_charm", name = "Charm Tag"},
        {key = "tag_meteor", name = "Meteor Tag"},
        {key = "tag_buffoon", name = "Buffoon Tag"},
        {key = "tag_handy", name = "Handy Tag"},
        {key = "tag_garbage", name = "Garbage Tag"},
        {key = "tag_ethereal", name = "Ethereal Tag"},
        {key = "tag_coupon", name = "Coupon Tag"},
        {key = "tag_double", name = "Double Tag"},
        {key = "tag_juggle", name = "Juggle Tag"},
        {key = "tag_d_six", name = "D6 Tag"},
        {key = "tag_top_up", name = "Top-up Tag"},
        {key = "tag_skip", name = "Skip Tag"},
        {key = "tag_orbital", name = "Orbital Tag"},
        {key = "tag_economy", name = "Economy Tag"}
    }
    
    -- First add all the wiki tags to ensure they're included
    for _, tag in ipairs(wiki_tags) do
        table.insert(all_tags, tag)
    end
    
    -- Then try to get tags from the game to ensure we catch any that might be added in updates
    if _G.G and _G.G.P_TAGS then
        for tag_key, tag_data in pairs(_G.G.P_TAGS) do
            if tag_data.name then
                -- Check if this tag is already in our list
                local found = false
                for _, existing_tag in ipairs(all_tags) do
                    if existing_tag.key == tag_key then
                        found = true
                        break
                    end
                end
                
                -- If not already in the list, add it
                if not found then
                    table.insert(all_tags, {key = tag_key, name = tag_data.name})
                end
            end
        end
    end
    
    -- Sort the tags by name
    table.sort(all_tags, function(a, b) return a.name < b.name end)
    
    add_debug("Found " .. #all_tags .. " tags")
end

-- Check if current tags contain the target tag
local function check_for_target_tag()
    if not target_tag then return false end
    
    if _G.G and _G.G.GAME and _G.G.GAME.round_resets and _G.G.GAME.round_resets.blind_tags then
        local small_tag = _G.G.GAME.round_resets.blind_tags.Small
        local big_tag = _G.G.GAME.round_resets.blind_tags.Big
        
        if small_tag == target_tag or big_tag == target_tag then
            add_debug("Found target tag: " .. get_tag_name(target_tag) .. "!")
            reroll_active = false
            return true
        end
    end
    
    return false
end

-- Handle auto-restarting by calling the game's built-in restart functionality
local function trigger_restart()
    add_debug("trigger_restart called")
    
    if not reroll_active then
        add_debug("Reroll not active, skipping")
        return
    end
    
    if not target_tag then
        add_debug("No target tag set, skipping")
        return
    end
    
    -- Check if we found our target tag
    if check_for_target_tag() then
        add_debug("Target tag already found, stopping reroll")
        return
    end
    
    -- Don't restart again if we're already in the process
    if restarting then
        add_debug("Already in restart process, skipping")
        return
    end
    
    -- Enforce minimum time between restarts
    if (_G.G.TIMERS.REAL - last_restart_time) < min_restart_interval then
        add_debug("Minimum interval not reached, skipping: " .. 
                 tostring(min_restart_interval - (_G.G.TIMERS.REAL - last_restart_time)) .. " seconds left")
        return
    end
    
    -- Increment reroll count
    reroll_count = reroll_count + 1
    last_restart_time = _G.G.TIMERS.REAL
    restarting = true
    
    add_debug("Rerolling run #" .. reroll_count .. " using key_press_update")
    
    -- Use the game's built-in key hold function directly
    if _G.G and _G.G.CONTROLLER then
        -- Set up a timer to hold "r" for more than 0.7 seconds (the game's threshold)
        _G.G.CONTROLLER.held_key_times = _G.G.CONTROLLER.held_key_times or {}
        _G.G.CONTROLLER.held_key_times["r"] = 0.8 -- Set higher than the game's 0.7 second threshold
        
        -- Manually call the key hold update function
        if _G.G.CONTROLLER.key_hold_update then
            add_debug("Calling key_hold_update directly")
            _G.G.CONTROLLER:key_hold_update("r", 0.8)
            
            -- Set up a timer to clear the restarting flag after a delay
            if _G.G.FUNCS and _G.G.FUNCS.add_event then
                _G.G.FUNCS.add_event({
                    func = function()
                        restarting = false
                        return true
                    end,
                    delay = 2
                })
            else
                -- If add_event not available, just set a timer
                last_restart_time = _G.G.TIMERS.REAL
                restarting = false
            end
        else
            add_debug("key_hold_update not available")
            restarting = false
        end
    else
        add_debug("G.CONTROLLER not available")
        restarting = false
    end
end

-- Draw dropdown menu
local function draw_dropdown(g, dropdown_x, dropdown_y)
    if not dropdown_open then return end
    
    -- Ensure we have tags populated
    if #all_tags == 0 then
        populate_all_tags()
    end
    
    -- Calculate dropdown dimensions - show all tags without scrolling
    local dropdown_width = 160 -- Match the tag selector width exactly
    local item_height = 20 -- Smaller item height
    local dropdown_height = math.min(#all_tags * item_height, 300) -- Cap height
    
    -- Draw dropdown background with proper position
    g.setColor(0.1, 0.1, 0.1, 0.9)
    g.rectangle("fill", dropdown_x, dropdown_y, dropdown_width, dropdown_height)
    g.setColor(1, 1, 1, 0.7)
    g.rectangle("line", dropdown_x, dropdown_y, dropdown_width, dropdown_height)
    
    -- Draw a message for empty list (shouldn't happen with our implementation)
    if #all_tags == 0 then
        g.setColor(0.7, 0.7, 0.7, 1)
        g.print("No tags found", dropdown_x + 10, dropdown_y + 5)
    else
        -- Draw all items
        for i, item in ipairs(all_tags) do
            -- Only draw visible items
            if (i-1) * item_height < dropdown_height then
                local y_pos = dropdown_y + (i - 1) * item_height
                
                -- Highlight selected item
                if target_tag and item.key == target_tag then
                    g.setColor(0.3, 0.7, 0.3, 0.5)
                    g.rectangle("fill", dropdown_x, y_pos, dropdown_width, item_height)
                end
                
                -- Draw item text
                g.setColor(1, 1, 1, 1)
                local text = item.name
                g.print(text, dropdown_x + 10, y_pos + (item_height - g.getFont():getHeight()) / 2)
            end
        end
    end
end

-- Draw UI function
function draw_ui()
    -- Early returns
    if not ui_visible then return end
    if not _G.love or not _G.love.graphics then return end
    
    -- Get graphics module
    local g = _G.love.graphics
    
    -- Ensure we have tags populated
    if #all_tags == 0 then
        populate_all_tags()
    end
    
    -- Only show UI if we're in a run or have tags stored
    local in_run = _G.G and _G.G.GAME and _G.G.GAME.current_screen == "playing"
    if not in_run and tag_count == 0 then
        return -- Don't show UI in main menu if no tags stored
    end
    
    -- Calculate fixed sizes for UI elements
    local panel_w = 180
    local button_w = 160
    local button_h = 25
    local padding = 10
    local fixed_tag_area = tag_count > 0 and math.min(tag_count * 55, 100) or 40
    local panel_h = 40 + fixed_tag_area + 130 + (reroll_active and 35 or 0)
    
    -- Position panel
    local panel_x = g.getWidth() - panel_w - padding
    local panel_y = padding
    
    -- Background
    g.setColor(0, 0, 0, 0.8)
    g.rectangle("fill", panel_x, panel_y, panel_w, panel_h)
    g.setColor(1, 1, 1, 0.5)
    g.rectangle("line", panel_x, panel_y, panel_w, panel_h)
    
    -- Title
    g.setColor(1, 1, 0, 1)
    g.print("AUTO TAG REROLL", panel_x + (panel_w - g.getFont():getWidth("AUTO TAG REROLL")) / 2, panel_y + 10)
    
    -- Tags list
    local y = panel_y + 35
    g.setColor(1, 1, 1, 1)
    
    if tag_count == 0 then
        g.print("No tags stored yet", panel_x + (panel_w - g.getFont():getWidth("No tags stored yet")) / 2, y)
        y = y + 20
    else
        -- Sort before display to keep ante order
        local antes = {}
        for ante, _ in pairs(stored_tags) do
            table.insert(antes, ante)
        end
        table.sort(antes)
        
        for _, ante in ipairs(antes) do
            local tags = stored_tags[ante]
            g.print("Ante " .. ante .. ":", panel_x + 10, y)
            y = y + 15
            g.print("  Small: " .. tags.small_name, panel_x + 15, y)
            y = y + 15
            g.print("  Big: " .. tags.big_name, panel_x + 15, y)
            y = y + 20
        end
    end
    
    -- Reroll UI
    y = panel_y + 35 + fixed_tag_area + 10
    if reroll_active then
        g.setColor(0.8, 0.3, 0.3, 1) -- Red when active
    else
        g.setColor(0.3, 0.3, 0.8, 1) -- Blue when inactive
    end
    g.rectangle("fill", panel_x + (panel_w - button_w) / 2, y, button_w, button_h)
    g.setColor(1, 1, 1, 1)
    local reroll_text = reroll_active and "STOP REROLLING" or "START REROLLING"
    g.print(reroll_text, panel_x + (panel_w - g.getFont():getWidth(reroll_text)) / 2, y + (button_h - g.getFont():getHeight()) / 2)
    
    -- Target tag selector
    y = y + button_h + 15
    g.setColor(0.7, 0.7, 0.7, 1)
    g.print("Target Tag:", panel_x + 10, y)
    
    y = y + 20
    g.setColor(0.2, 0.2, 0.2, 1)
    g.rectangle("fill", panel_x + (panel_w - button_w) / 2, y, button_w, button_h)
    g.setColor(1, 1, 1, 1)
    g.rectangle("line", panel_x + (panel_w - button_w) / 2, y, button_w, button_h)
    
    -- Display selected tag or prompt
    local tag_text = target_tag and get_tag_name(target_tag) or "Select a tag..."
    g.setColor(target_tag and 1 or 0.7, target_tag and 1 or 0.7, target_tag and 1 or 0.7, 1)
    g.print(tag_text, panel_x + (panel_w - g.getFont():getWidth(tag_text)) / 2, y + (button_h - g.getFont():getHeight()) / 2)
    
    -- Reroll status
    if reroll_active then
        y = y + button_h + 15
        g.setColor(1, 0.6, 0, 1)
        local status_text = "Reroll count: " .. reroll_count
        g.print(status_text, panel_x + (panel_w - g.getFont():getWidth(status_text)) / 2, y)
    end
    
    -- Help text
    y = panel_y + panel_h - 20
    g.setColor(0.7, 0.7, 0.7, 1)
    local help_text = "Press T to toggle UI"
    g.print(help_text, panel_x + (panel_w - g.getFont():getWidth(help_text)) / 2, y)
    
    -- Draw dropdown last (after everything else) so it appears on top
    if dropdown_open then
        local dropdown_y = panel_y + 35 + fixed_tag_area + 10 + button_h + 15 + 20 + button_h
        draw_dropdown(g, panel_x + (panel_w - button_w) / 2, dropdown_y)
    end
end

-- Add a debug message (only logged to console, not displayed in UI)
function add_debug(msg)
    table.insert(debug_info, msg)
    if #debug_info > 6 then
        table.remove(debug_info, 1) -- Keep only the last 6 messages
    end
    print("DEBUG: " .. msg)
end

-- Reset stored tags when returning to title or new run
function reset_stored_tags()
    stored_tags = {}
    tag_count = 0
    add_debug("Tags reset")
end

-- Force check of blind tags for current ante
function force_check_blind_tags()
    if not _G.G or not _G.G.GAME or not _G.G.GAME.round_resets then
        add_debug("No game state to check")
        return
    end
    
    local ante = _G.G.GAME.round_resets.ante or 0
    if ante <= 0 then
        add_debug("Invalid ante: " .. ante)
        return
    end
    
    add_debug("Checking blind tags for ante " .. ante)
    
    -- If we already have tags for this ante, don't overwrite
    if stored_tags[ante] then
        add_debug("Already have tags for ante " .. ante)
        return
    end
    
    -- Check if blind_tags exists
    if not _G.G.GAME.round_resets.blind_tags then
        add_debug("No blind_tags in round_resets")
        return
    end
    
    -- Store the tags
    stored_tags[ante] = {
        small = _G.G.GAME.round_resets.blind_tags.Small,
        small_name = get_tag_name(_G.G.GAME.round_resets.blind_tags.Small),
        big = _G.G.GAME.round_resets.blind_tags.Big,
        big_name = get_tag_name(_G.G.GAME.round_resets.blind_tags.Big)
    }
    
    tag_count = tag_count + 1
    
    add_debug("Added tags for ante " .. ante)
    add_debug("Small: " .. stored_tags[ante].small_name)
    add_debug("Big: " .. stored_tags[ante].big_name)
    
    -- Check if we found our target tag
    if reroll_active and check_for_target_tag() then
        add_debug("TARGET TAG FOUND!")
    end
end

-- Check for screen transitions that should trigger a reset
function check_screen_transition()
    -- Skip if no game state
    if not _G.G or not _G.G.GAME then
        return false
    end
    
    -- Only check every 1 second to reduce overhead
    if (_G.G.TIMERS.REAL - last_screen_check) < 1 then
        return false
    end
    
    last_screen_check = _G.G.TIMERS.REAL
    
    local current_screen = _G.G.GAME.current_screen or ""
    
    -- Check for transitions that should trigger reset
    if (last_screen ~= "title" and current_screen == "title") or 
       (last_screen ~= "setup" and current_screen == "setup") then
        add_debug("Screen changed to " .. current_screen .. ", resetting tags")
        last_screen = current_screen
        return true
    end
    
    -- Update last screen
    last_screen = current_screen
    return false
end

-- Continuous monitor of game state
function monitor_game_state()
    -- Skip if we're not in game
    if not _G.G or not _G.G.GAME then
        return
    end
    
    -- Check for screen transitions that should reset
    if check_screen_transition() then
        reset_stored_tags()
        return
    end
    
    -- Only check for new tags every 2 seconds at most to avoid overhead
    if (_G.G.TIMERS.REAL - last_ante_check) < 2 then
        return
    end
    
    last_ante_check = _G.G.TIMERS.REAL
    
    -- Track the actual current screen for debugging
    local current_screen = "unknown"
    if _G.G.GAME.current_screen then
        current_screen = _G.G.GAME.current_screen
    end
    
    -- Check for reroll condition
    if reroll_active and not restarting then
        add_debug("Reroll condition check - active: " .. tostring(reroll_active) .. ", screen: " .. current_screen)
        
        -- If we're in a run and we have blind tags, check if they match our target
        if _G.G.GAME.round_resets and _G.G.GAME.round_resets.blind_tags then
            add_debug("Blind tags found, checking for target tag")
            
            -- If we don't have our target tag, trigger restart (after appropriate delay)
            if not check_for_target_tag() then
                add_debug("Target tag not found")
                if (_G.G.TIMERS.REAL - last_restart_time) >= min_restart_interval then
                    add_debug("Time interval passed, triggering restart")
                    trigger_restart()
                else
                    add_debug("Waiting for interval: " .. tostring(min_restart_interval - (_G.G.TIMERS.REAL - last_restart_time)) .. " seconds left")
                end
            else
                add_debug("Target tag found, stopping reroll")
            end
        else
            add_debug("No blind tags available yet")
        end
    else
        local reasons = {}
        if not reroll_active then table.insert(reasons, "reroll not active") end
        if not _G.G.GAME or _G.G.GAME.current_screen ~= "playing" then table.insert(reasons, "not on playing screen") end
        if restarting then table.insert(reasons, "already in restart process") end
        if #reasons > 0 then add_debug("Reroll conditions not met: " .. table.concat(reasons, ", ")) end
    end
    
    -- Check if we're in a run
    if not _G.G.GAME.round_resets then return end
    
    local ante = _G.G.GAME.round_resets.ante or 0
    if ante <= 0 then return end
    
    -- If this is a new ante we haven't seen, check its blind tags
    if ante > 0 and not stored_tags[ante] and _G.G.GAME.round_resets.blind_tags then
        force_check_blind_tags()
    end
end

-- Handle mouse click for UI interactions
function handle_mouse_click(x, y)
    if not ui_visible then return end
    
    -- Only process clicks if we're in a run or have tags stored
    local in_run = _G.G and _G.G.GAME and _G.G.GAME.current_screen == "playing"
    if not in_run and tag_count == 0 then
        return false -- Don't process clicks in main menu when no tags
    end
    
    -- Get graphics module
    local g = _G.love.graphics
    
    -- Calculate fixed sizes for UI elements (same as in draw_ui)
    local panel_w = 180
    local button_w = 160
    local button_h = 25
    local padding = 10
    local fixed_tag_area = tag_count > 0 and math.min(tag_count * 55, 100) or 40
    local panel_h = 40 + fixed_tag_area + 130 + (reroll_active and 35 or 0)
    
    -- Position panel
    local panel_x = g.getWidth() - panel_w - padding
    local panel_y = padding
    
    -- Define buttons with their positions
    local reroll_button_y = panel_y + 35 + fixed_tag_area + 10
    local reroll_button_x = panel_x + (panel_w - button_w) / 2
    
    local tag_selector_y = reroll_button_y + button_h + 35
    local tag_selector_x = panel_x + (panel_w - button_w) / 2
    
    -- Check if reroll button was clicked
    if x >= reroll_button_x and x <= reroll_button_x + button_w and
       y >= reroll_button_y and y <= reroll_button_y + button_h then
        reroll_active = not reroll_active
        if reroll_active then
            if not target_tag then
                add_debug("No target tag selected!")
                reroll_active = false
                return true
            end
            
            reroll_count = 0
            add_debug("Reroll started! Target: " .. (target_tag and get_tag_name(target_tag) or "None"))
        else
            add_debug("Reroll stopped")
        end
        return true
    end
    
    -- Check if tag selector was clicked
    if x >= tag_selector_x and x <= tag_selector_x + button_w and
       y >= tag_selector_y and y <= tag_selector_y + button_h then
        dropdown_open = not dropdown_open
        
        -- Make sure we've populated the tags
        if dropdown_open and #all_tags == 0 then
            populate_all_tags()
        end
        
        return true
    end
    
    -- Check if dropdown item was clicked
    if dropdown_open then
        local dropdown_x = tag_selector_x
        local dropdown_y = tag_selector_y + button_h
        local item_height = 20
        local dropdown_height = math.min(#all_tags * item_height, 300)
        
        if x >= dropdown_x and x <= dropdown_x + button_w and
           y >= dropdown_y and y <= dropdown_y + dropdown_height then
            -- Calculate which item was clicked
            local item_index = math.floor((y - dropdown_y) / item_height) + 1
            if item_index >= 1 and item_index <= #all_tags then
                target_tag = all_tags[item_index].key
                add_debug("Selected tag: " .. all_tags[item_index].name)
                dropdown_open = false
                return true
            end
        else
            -- Close dropdown if clicked outside
            dropdown_open = false
            return true
        end
    end
    
    return false
end

-- Store original LÖVE functions
local original_love_draw = nil
local original_love_mousepressed = nil
local original_love_wheelmoved = nil

-- Init function - sets up mod
function mod:init()
    print("UltraSimpleAnteUI loaded!")
    debug_info = {}
    add_debug("Mod initialized")
    
    -- Make sure to populate tags before they're needed
    populate_all_tags()

    -- Draw hook - direct override of love.draw
    if _G.love and _G.love.draw then
        original_love_draw = _G.love.draw
        _G.love.draw = function()
            -- Call original first
            if original_love_draw then original_love_draw() end
            
            -- Monitor game state each frame
            monitor_game_state()
            
            -- Draw our UI on top
            draw_ui()
        end
        add_debug("Draw hook installed")
    else
        add_debug("Failed to hook draw function")
    end
    
    -- Try to find reset_run function
    if _G.G and _G.G.FUNCS then
        if not _G.G.FUNCS.reset_run and _G.G.FUNCS.restart_run then
            add_debug("Found restart_run instead of reset_run, aliasing it")
            _G.G.FUNCS.reset_run = _G.G.FUNCS.restart_run
        end
        
        -- Log all available G.FUNCS for debugging
        local funcs_list = {}
        for k, _ in pairs(_G.G.FUNCS) do
            table.insert(funcs_list, k)
        end
        
        if #funcs_list > 0 then
            add_debug("Available G.FUNCS: " .. table.concat(funcs_list, ", "))
        end
    end
    
    -- Hook keypressed for toggles and to detect native R key press
    if _G.love and _G.love.keypressed then
        local orig_keypressed = _G.love.keypressed
        _G.love.keypressed = function(key, scancode, isrepeat)
            -- Toggle UI with T key
            if key == "t" then
                ui_visible = not ui_visible
                add_debug("UI " .. (ui_visible and "shown" or "hidden"))
                return
            end
            
            -- Detect when user presses R so we don't interfere with manual rerolls
            if key == "r" and not restarting then
                add_debug("User pressed R key - waiting for next check")
                last_restart_time = _G.G.TIMERS.REAL -- Reset our timer
            end
            
            -- Call original
            return orig_keypressed(key, scancode, isrepeat)
        end
        add_debug("Key hook installed")
    end
    
    -- Hook mousepressed for UI interactions
    if _G.love and _G.love.mousepressed then
        original_love_mousepressed = _G.love.mousepressed
        _G.love.mousepressed = function(x, y, button, istouch, presses)
            if button == 1 and handle_mouse_click(x, y) then
                return
            end
            return original_love_mousepressed(x, y, button, istouch, presses)
        end
        add_debug("Mouse hook installed")
    end
    
    -- No need for wheel event handler since we're showing all tags
    
    -- Hook directly into start_run for better restarts
    if _G.G then
        if not _G.G.start_run and _G.G.GAME and _G.G.GAME.start_run then
            add_debug("Detected start_run on G.GAME object")
            _G.G.start_run = function(args)
                return _G.G.GAME:start_run(args)
            end
        end
        
        if _G.G.start_run then
            local orig_start_run = _G.G.start_run
            _G.G.start_run = function(...)
                add_debug("New run starting, resetting tags")
                reset_stored_tags()
                return orig_start_run(...)
            end
            add_debug("Hooked start_run function")
        end
    end
    
    -- Also hook main menu return
    if _G.G and _G.G.FUNCS and _G.G.FUNCS.goto_menu then
        local orig_goto_menu = _G.G.FUNCS.goto_menu
        _G.G.FUNCS.goto_menu = function(...)
            add_debug("Returning to menu, resetting tags")
            reset_stored_tags()
            return orig_goto_menu(...)
        end
        add_debug("Hooked goto_menu function")
    end
    
    -- Hook the blind_choice function - crucial moment when blind tags are assigned
    if _G.G and _G.G.blind_choice then
        local orig_blind_choice = _G.G.blind_choice
        _G.G.blind_choice = function(choice, ...)
            add_debug("Blind choice detected: " .. tostring(choice))
            
            -- Call original function first
            local result = orig_blind_choice(choice, ...)
            
            -- Post-blind choice tag check
            if _G.G.GAME and _G.G.GAME.round_resets then
                local ante = _G.G.GAME.round_resets.ante or 1
                
                -- Schedule multiple checks with delays
                if _G.G.FUNCS and _G.G.FUNCS.add_event then
                    for i = 1, 5 do
                        _G.G.FUNCS.add_event({
                            func = function()
                                force_check_blind_tags()
                                return true
                            end,
                            cleanup = function() end,
                            delay = 0.5 * i -- 0.5, 1.0, 1.5, 2.0, 2.5 seconds
                        })
                    end
                end
            end
            
            return result
        end
        add_debug("Hooked blind_choice function")
    end
    
    -- Hook the start_ante function - when a new ante begins
    if _G.G and _G.G.start_ante then
        local orig_start_ante = _G.G.start_ante
        _G.G.start_ante = function(ante, ...)
            add_debug("Ante " .. ante .. " starting")
            
            -- Run original function first
            local result = orig_start_ante(ante, ...)
            
            -- After ante starts, check for tags with delay
            if _G.G.FUNCS and _G.G.FUNCS.add_event then
                for i = 1, 5 do
                    _G.G.FUNCS.add_event({
                        func = function()
                            force_check_blind_tags()
                            return true
                        end,
                        cleanup = function() end,
                        delay = 0.5 * i -- 0.5, 1.0, 1.5, 2.0, 2.5 seconds
                    })
                end
            end
            
            return result
        end
        add_debug("Hooked start_ante function")
    end
    
    -- Hook into the function that sets Blind objects, crucial for tag detection
    if _G.G and _G.Blind and _G.Blind.set_blind then
        local orig_set_blind = _G.Blind.set_blind
        _G.Blind.set_blind = function(self, blind, reset, silent, ...)
            add_debug("Blind.set_blind called")
            
            -- Call original function first
            local result = orig_set_blind(self, blind, reset, silent, ...)
            
            -- Schedule multiple checks after blind is set
            if _G.G.FUNCS and _G.G.FUNCS.add_event then
                for i = 1, 5 do
                    _G.G.FUNCS.add_event({
                        func = function()
                            force_check_blind_tags()
                            return true
                        end,
                        cleanup = function() end,
                        delay = 0.5 * i -- 0.5, 1.0, 1.5, 2.0, 2.5 seconds
                    })
                end
            end
            
            return result
        end
        add_debug("Hooked Blind.set_blind function")
    end
    
    return self
end

-- Return mod
return mod:init() 