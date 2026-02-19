local modname = minetest.get_current_modname()

local M = {}
local config = {}
local phased_blocks = {}
local last_wielded = {}
local active_slot = {}

local ignored_meta_values = {
    --"infotext",
    "formspec",
    "inventory",
}

local function table_contains(intable, key)
    return intable[key] ~= nil
end

-- Because I want to check either key or value.
local function list_has_item(intable, value)
    if intable[value] ~= nil then return true end
    for _, v in pairs(intable) do
        if v == value then return true end
    end
    return false
end

function M.set_config(cfg)
    config = cfg
end

local function is_blacklisted(name)
    for _, v in ipairs(config.blacklisted_blocks or {}) do
        if v == name then return true end
    end
    return false
end

function M.capture_block(itemstack, user, pointed_thing)
    if not config.enable_block_pickup then return itemstack end

    local pos = pointed_thing.under
    local node = minetest.get_node(pos)
    local def = minetest.registered_nodes[node.name]
    if not def or not def.tiles then return itemstack end
    if is_blacklisted(node.name) then return itemstack end

    local tile = def.tiles[1]
    if type(tile) == "table" then tile = tile.name end
    local lightened = tile .. "^[multiply:#FFFFFF^[opacity:150"

    local node_meta = minetest.get_meta(pos)
    local inv = node_meta:get_inventory()
    local all_lists = inv:get_lists()
    local saved_inventories = {}
    local meta_table = node_meta:to_table().fields

    for list_name, list in pairs(all_lists) do
        saved_inventories[list_name] = {}
        for i = 1, inv:get_size(list_name) do
            local stack = inv:get_stack(list_name, i)
            saved_inventories[list_name][i] = stack:to_string()
        end
    end
    local full = ItemStack(modname .. ":magic_square_full")
    local meta = full:get_meta()
    local added_items = {}
    for i, j in pairs(meta_table) do
        if not list_has_item(ignored_meta_values, i) then
            meta:set_string(i,j)
            added_items[i] = j
        end
    end

    phased_blocks[user:get_player_name()] = {
        pos = pos,
        node = node.name,
        inventories = saved_inventories,
        added_items = added_items,
        param1 = node.param1,
        param2 = node.param2,
    }

    meta:set_string("type", "block")
    meta:set_string("stored_node", node.name)
    meta:set_string("stored_texture", lightened)
    meta:set_string("stored_inventories", minetest.serialize(saved_inventories))
    meta:set_string("description", "Magic Square (contains " .. node.name .. ")")
    meta:set_string("param1", node.param1)
    meta:set_string("param2", node.param2)

    minetest.remove_node(pos)
    user:set_wielded_item(full)

    -- Track the exact slot used
    active_slot[user:get_player_name()] = user:get_wield_index()

    return full
end

function M.release_block(itemstack, placer, pointed_thing)
    local meta = itemstack:get_meta()
    local stored = meta:get_string("stored_node")
    if stored == "" then return itemstack end

    local pos = pointed_thing.above
    local name = placer:get_player_name()
    if minetest.is_protected(pos, name) then return itemstack end

    minetest.set_node(pos, {name = stored, param1 = meta:get_string("param1"), param2 = meta:get_string("param2")})

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
    local new_meta = minetest.get_meta(pos)
    local meta_table = meta:to_table().fields
    for i, j in pairs(meta_table) do
        if not list_has_item(ignored_meta_values, i) then
            new_meta:set_string(i,j)
        end
    end

    phased_blocks[name] = nil
    active_slot[name] = nil

    local empty = ItemStack(modname .. ":magic_square_empty")
    placer:set_wielded_item(empty)
    return empty
end

-- Globalstep: auto-release block on deselect
if config.drop_on_deselect then
    minetest.register_globalstep(function(dtime)
        for name, data in pairs(phased_blocks) do
            local player = minetest.get_player_by_name(name)
            if player and data then
                local item = player:get_wielded_item()
                local item_name = item:get_name()

                -- Auto-release if deselected
                if last_wielded[name] == modname .. ":magic_square_full" and item_name ~= modname .. ":magic_square_full" then
                    minetest.set_node(data.pos, {name = data.node, param1 = data.param1, param2 = data.param2})

                    local meta = minetest.get_meta(data.pos)
                    local inv = meta:get_inventory()
                    for list_name, items in pairs(data.inventories or {}) do
                        inv:set_size(list_name, #items)
                        for i, item in ipairs(items) do
                            inv:set_stack(list_name, i, ItemStack(item))
                        end
                    end
                    -- restore metadata
                    local new_meta = minetest.get_meta(data.pos)
                    local meta_table = item:get_meta():to_table().fields
                    for i, j in pairs(data["added_items"]) do
                        if not list_has_item(ignored_meta_values, i) then
                            new_meta:set_string(i,j)
                        end
                    end

                    phased_blocks[name] = nil

                    -- Replace the exact slot with empty square
                    local slot = active_slot[name]
                    if slot then
                        local inv = player:get_inventory()
                        local stack = inv:get_stack("main", slot)
                        if stack:get_name() == modname .. ":magic_square_full" then
                            inv:set_stack("main", slot, ItemStack(modname .. ":magic_square_empty"))
                        end
                        active_slot[name] = nil
                    end
                end

                last_wielded[name] = item_name
            end
        end
    end)
end

-- Restore block on logout
if config.drop_on_logout then
    minetest.register_on_leaveplayer(function(player)
        local name = player:get_player_name()
        local data = phased_blocks[name]
        if data then
            minetest.set_node(data.pos, {name = data.node, param1 = data.param1, param2 = data.param2})

            local meta = minetest.get_meta(data.pos)
            local inv = meta:get_inventory()
            for list_name, items in pairs(data.inventories or {}) do
                inv:set_size(list_name, #items)
                for i, item in ipairs(items) do
                    inv:set_stack(list_name, i, ItemStack(item))
                end
            end
            -- restore metadata
            local new_meta = minetest.get_meta(data.pos)
            local meta_table = item:get_meta():to_table().fields
            for i, j in pairs(data["added_items"]) do
                if not list_has_item(ignored_meta_values, i) then
                    new_meta:set_string(i,j)
                end
            end

            phased_blocks[name] = nil
            active_slot[name] = nil

            -- Clear metadata from full square
            local inv = player:get_inventory()
            for i = 1, inv:get_size("main") do
                local stack = inv:get_stack("main", i)
                if stack:get_name() == modname .. ":magic_square_full" then
                    local meta = stack:get_meta()
                    meta:set_string("type", "")
                    meta:set_string("stored_node", "")
                    meta:set_string("stored_texture", "")
                    meta:set_string("stored_inventories", "")
                    meta:set_string("description", "")
                    inv:set_stack("main", i, stack)
                end
            end

            local wielded = player:get_wielded_item()
            if wielded:get_name() == modname .. ":magic_square_full" then
                local meta = wielded:get_meta()
                meta:set_string("type", "")
                meta:set_string("stored_node", "")
                meta:set_string("stored_texture", "")
                meta:set_string("stored_inventories", "")
                meta:set_string("description", "")
                player:set_wielded_item(ItemStack(modname .. ":magic_square_empty"))
            end
        end
    end)
end

return M

