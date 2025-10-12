local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Load config from Lua file
local config = {}
local config_path = modpath .. "/magicsquare_config.lua"
local ok, conf = pcall(dofile, config_path)
if ok and type(conf) == "table" then
    config = conf
else
    minetest.log("warning", "[MagicSquare] Failed to load config: " .. tostring(conf))
end

-- Extract block list from config
local blacklisted_blocks = config.blacklisted_blocks or {}

-- Convert list to set for fast lookup
local blacklisted_set = {}
for _, name in ipairs(blacklisted_blocks) do
    blacklisted_set[name] = true
end

-- HUD notification helper
local function show_notification(player, message)
    if not player or not player:is_player() then return end
    local id = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.2},
        offset = {x = 0, y = 0},
        text = message,
        alignment = {x = 0, y = 0},
        scale = {x = 100, y = 20},
        number = 0xFFFFFF,
    })
    minetest.after(2.5, function()
        if player and player:is_player() then
            player:hud_remove(id)
        end
    end)
end

-- Empty Magic Square
minetest.register_tool(modname .. ":magic_square_empty", {
    description = "Magic Square",
    inventory_image = "magicsquare_empty.png",
    wield_image = "magicsquare_empty.png",
    stack_max = 1,

    on_use = function(itemstack, user, pointed_thing)
        if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end

        local meta = itemstack:get_meta()
        if meta:get_string("stored_node") ~= "" then
            return itemstack
        end

        local pos = pointed_thing.under
        local node = minetest.get_node(pos)

        if blacklisted_set[node.name] then
            show_notification(user, "This block cannot be captured.")
            return itemstack
        end

        local def = minetest.registered_nodes[node.name]
        if not def or not def.tiles then return itemstack end

        local tile = def.tiles[1]
        if type(tile) == "table" then tile = tile.name end
        if not tile then return itemstack end

        local lightened = tile .. "^[multiply:#FFFFFF^[opacity:150"

        -- Capture inventory contents
        local node_meta = minetest.get_meta(pos)
        local inv = node_meta:get_inventory()
        local all_lists = inv:get_lists()
        local saved_inventories = {}

        for list_name, list in pairs(all_lists) do
            saved_inventories[list_name] = {}
            for i = 1, inv:get_size(list_name) do
                local stack = inv:get_stack(list_name, i)
                saved_inventories[list_name][i] = stack:to_string()
            end
        end

        -- Create full square itemstack
        local full_square = ItemStack(modname .. ":magic_square_full")
        local full_meta = full_square:get_meta()
        full_meta:set_string("stored_node", node.name)
        full_meta:set_string("stored_texture", lightened)
        full_meta:set_string("description", "Magic Square (contains " .. node.name .. ")")
        full_meta:set_string("stored_inventories", minetest.serialize(saved_inventories))

        minetest.remove_node(pos)
        user:set_wielded_item(full_square)
        return full_square
    end,
})

-- Full Magic Square (hidden from Creative)
minetest.register_tool(modname .. ":magic_square_full", {
    description = "Magic Square (full)",
    inventory_image = "magicsquare_full.png",
    wield_image = "magicsquare_full.png",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},

    on_place = function(itemstack, placer, pointed_thing)
        local meta = itemstack:get_meta()
        local stored = meta:get_string("stored_node")
        if stored == "" then return itemstack end

        if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
        local pos = pointed_thing.above

        if minetest.is_protected(pos, placer:get_player_name()) then return itemstack end

        minetest.set_node(pos, {name = stored})

        -- Restore inventory contents
        local stored_data = meta:get_string("stored_inventories")
        if stored_data ~= "" then
            local restored = minetest.deserialize(stored_data)
            local new_meta = minetest.get_meta(pos)
            local new_inv = new_meta:get_inventory()

            for list_name, items in pairs(restored) do
                new_inv:set_size(list_name, #items)
                for i, item in ipairs(items) do
                    new_inv:set_stack(list_name, i, ItemStack(item))
                end
            end
        end

        -- Create empty square itemstack
        local empty_square = ItemStack(modname .. ":magic_square_empty")
        local empty_meta = empty_square:get_meta()
        empty_meta:set_string("stored_node", "")
        empty_meta:set_string("stored_texture", "")
        empty_meta:set_string("description", "Magic Square")

        placer:set_wielded_item(empty_square)
        return empty_square
    end,
})

-- Crafting recipe for the empty square
minetest.register_craft({
    output = modname .. ":magic_square_empty",
    recipe = {
        {"default:stick", "default:stick", "default:stick"},
        {"default:stick", "",              "default:stick"},
        {"default:stick", "default:stick", "default:stick"},
    }
})

