local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Load config
local config = dofile(modpath .. "/magicsquare_config.lua")

-- Load modules
local magicmob = dofile(modpath .. "/magicmob.lua")
local magicblock = dofile(modpath .. "/magicblock.lua")

-- Pass config to modules
magicmob.set_config(config)
magicblock.set_config(config)

-- Empty Magic Square: capture mob or block
minetest.register_tool(modname .. ":magic_square_empty", {
    description = "Magic Square",
    inventory_image = "magicsquare_empty.png",
    stack_max = 1,

    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "object" then
            return magicmob.capture_mob(itemstack, user, pointed_thing)
        elseif pointed_thing.type == "node" then
            return magicblock.capture_block(itemstack, user, pointed_thing)
        end
        return itemstack
    end,
})

-- Full Magic Square: release mob or block
minetest.register_tool(modname .. ":magic_square_full", {
    description = "Magic Square (full)",
    inventory_image = "magicsquare_full.png",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},

    on_place = function(itemstack, placer, pointed_thing)
        local meta = itemstack:get_meta()
        local type = meta:get_string("type")

        if type == "mob" then
            return magicmob.release_mob(itemstack, placer, pointed_thing)
        elseif type == "block" then
            return magicblock.release_block(itemstack, placer, pointed_thing)
        else
            -- No valid type stored — revert to empty
            local empty = ItemStack(modname .. ":magic_square_empty")
            placer:set_wielded_item(empty)
            return empty
        end
    end,
})


-- Suppress punch damage for both tools
minetest.override_item(modname .. ":magic_square_empty", {
    on_punch = function(_, _, _, _, _)
        return true
    end,
})

minetest.override_item(modname .. ":magic_square_full", {
    on_punch = function(_, _, _, _, _)
        return true
    end,
})

-- Crafting recipe
minetest.register_craft({
    output = modname .. ":magic_square_empty",
    recipe = {
        {"default:stick", "default:stick", "default:stick"},
        {"default:stick", "",              "default:stick"},
        {"default:stick", "default:stick", "default:stick"},
    }
})

