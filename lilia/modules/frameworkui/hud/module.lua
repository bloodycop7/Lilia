﻿MODULE.name = "HUD"
MODULE.author = "76561198312513285"
MODULE.discord = "@liliaplayer"
MODULE.version = "Stock"
MODULE.desc = "Implements Lilia HUD Elements."
MODULE.Dependencies = {
    {
        File = MODULE.path .. "/skins/cl_legacy.lua",
    },
    {
        File = MODULE.path .. "/skins/cl_dark.lua",
    },
}

if CLIENT then
    function MODULE:LoadFonts()
        surface.CreateFont("WB_Small", {
            font = "Product Sans",
            size = 17
        })

        surface.CreateFont("WB_Medium", {
            font = "Product Sans",
            size = 20
        })

        surface.CreateFont("WB_Large", {
            font = "Product Sans",
            size = 24,
            weight = 800
        })

        surface.CreateFont("WB_XLarge", {
            font = "Product Sans",
            size = 35,
            weight = 800
        })

        surface.CreateFont("WB_Enormous", {
            font = "Product Sans",
            size = 54
        })

        surface.CreateFont("wolficon_enormous", {
            font = "wolficonfont",
            size = 50,
            weight = 400,
            antialias = true
        })

        surface.CreateFont("wolficon_big", {
            font = "wolficonfont",
            size = 34,
            weight = 400,
            antialias = true
        })

        surface.CreateFont("wolficon_normal", {
            font = "wolficonfont",
            size = 25,
            weight = 400,
            antialias = true
        })

        surface.CreateFont("wolficon_small", {
            font = "wolficonfont",
            size = 18,
            weight = 400,
            antialias = true
        })

        surface.CreateFont("FPSFont", {
            font = "mailart rubberstamp",
            size = 27,
            weight = 500,
            antialias = true,
        })
    end
end
