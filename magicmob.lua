local modname = minetest.get_current_modname()
local phased_mobs = {}
local last_wielded = {}
local active_slot = {}

local M = {}
local config = {}

function M.set_config(cfg)
    config = cfg
end

local function is_blacklisted(name)
    for _, v in ipairs(config.blacklisted_mobs or {}) do
        if v == name then return true end
    end
    return false
end

-- Capture mob and tether it to player
function M.capture_mob(itemstack, user, pointed_thing)
    if not config.enable_mob_pickup then return itemstack end

    local obj = pointed_thing.ref
    if not obj or not obj:get_luaentity() then return itemstack end

    local mobname = obj:get_luaentity().name
    if is_blacklisted(mobname) then return itemstack end

    local name = user:get_player_name()
    local pos = obj:get_pos()

    obj:set_velocity({x = 0, y = 0, z = 0})
    obj:set_properties({collide_with_objects = false})

    phased_mobs[name] = {
        obj = obj,
        pos = vector.round(pos),
        mobname = mobname
    }

    local full = ItemStack(modname .. ":magic_square_full")
    local meta = full:get_meta()
    meta:set_string("type", "mob")
    meta:set_string("mobname", mobname)
    meta:set_string("description", "Magic Square (contains mob)")

    user:set_wielded_item(full)

    -- Track the exact slot used
    active_slot[name] = user:get_wield_index()

    return full
end

-- Release mob and restore collision
function M.release_mob(itemstack, placer, pointed_thing)
    local name = placer:get_player_name()
    local data = phased_mobs[name]
    if not data or not data.obj then return itemstack end

    local pos = pointed_thing.above
    data.obj:set_pos(pos)
    data.obj:set_properties({collide_with_objects = true})
    phased_mobs[name] = nil
    active_slot[name] = nil

    local empty = ItemStack(modname .. ":magic_square_empty")
    placer:set_wielded_item(empty)
    return empty
end

-- Globalstep: float mob above player or auto-release on deselect
minetest.register_globalstep(function(dtime)
    for name, data in pairs(phased_mobs) do
        local player = minetest.get_player_by_name(name)
        if player and data and data.obj then
            local item = player:get_wielded_item()
            local item_name = item:get_name()

            -- Auto-release if deselected
            if last_wielded[name] == modname .. ":magic_square_full" and item_name ~= modname .. ":magic_square_full" then
                data.obj:set_pos(data.pos)
                data.obj:set_properties({collide_with_objects = true})
                phased_mobs[name] = nil

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

            -- Float mob if still selected
            if item_name == modname .. ":magic_square_full" then
                local pos = player:get_pos()
                local target_pos = vector.add(pos, {x = 0, y = 5, z = 0})
                data.obj:set_velocity({x = 0, y = 0, z = 0})
                data.obj:set_pos(target_pos)
                data.pos = target_pos
            end

            last_wielded[name] = item_name
        end
    end
end)

-- Restore mob on logout
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local data = phased_mobs[name]
    if data and data.obj then
        data.obj:set_pos(data.pos)
        data.obj:set_properties({collide_with_objects = true})
        phased_mobs[name] = nil
        active_slot[name] = nil

        -- Clear metadata from full square
        local inv = player:get_inventory()
        for i = 1, inv:get_size("main") do
            local stack = inv:get_stack("main", i)
            if stack:get_name() == modname .. ":magic_square_full" then
                local meta = stack:get_meta()
                meta:set_string("type", "")
                meta:set_string("mobname", "")
                meta:set_string("description", "")
                inv:set_stack("main", i, stack)
            end
        end

        local wielded = player:get_wielded_item()
        if wielded:get_name() == modname .. ":magic_square_full" then
            local meta = wielded:get_meta()
            meta:set_string("type", "")
            meta:set_string("mobname", "")
            meta:set_string("description", "")
            player:set_wielded_item(ItemStack(modname .. ":magic_square_empty"))
        end
    end
end)

return M

