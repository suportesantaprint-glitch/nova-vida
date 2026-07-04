local identifier = "lb-phone-bank"

while GetResourceState("lb-phone") ~= "started" do
    Wait(500)
end

local function addApp()
    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = identifier,

        name = "Banco Fleeca",
        description = "Aplicativo do Banco Fleeca",
        developer = "Lil",

        defaultApp = true, --  set to true, the app will automatically be added to the player's phone
        size = 59812, -- the app size in kb
        -- price = 0, -- OPTIONAL make players pay with in-game money to download the app

        images = { -- OPTIONAL array of screenshots of the app, used for showcasing the app
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-1.jpg",
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-2.jpg",
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-3.jpg",
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-4.jpg",
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-5.jpg",
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-6.jpg",
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/screenshot-7.jpg"
        },

        ui = GetCurrentResourceName() .. "/web-side/index.html",

        icon = "https://cfx-nui-" .. GetCurrentResourceName() .. "/web-side/images/app-icon.jpg",
        fixBlur = true, -- set to true if you use em, rem etc instead of px in your css
    })

    if not added then
        print("Could not add app:", errorMessage)
    end
end

addApp()

AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        addApp()
    end
end)