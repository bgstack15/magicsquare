-- Magic Square Config

return {
    -- Toggle pickup features
    enable_block_pickup = true,
    enable_mob_pickup = true,

    -- Blacklisted blocks (uncapturable)
    blacklisted_blocks = {
        --"default:lava_source",
        --"default:chest",
        --"mcl_core:dirt",
        -- Add more as needed
    },

    -- Blacklisted mobs (uncapturable)
    blacklisted_mobs = {
        --"mobs_mc:pig",
        --"mobs:monster",
        -- Add more as needed
    },

    -- Forcibly drop item if magic square is deselected
    drop_on_deselect = true,
    -- Forcibly drop item if the player quits
    drop_on_logout = true,
}

