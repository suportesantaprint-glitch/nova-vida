-- Webhook for instapic posts, recommended to be a public channel
INSTAPIC_WEBHOOK = "https://discord.com/api/webhooks/1412255544806342696/BUyY0TlHoDnYStv9ophRg2-X7naCCs5b2_Kb-Yhrv4x-vRAAxFZKG_DaJ1pjkugyxD6U"
-- Webhook for birdy posts, recommended to be a public channel
BIRDY_WEBHOOK = "https://discord.com/api/webhooks/1412255584035536997/NGawcKyLxP8pFMAIRtajKsJezkMlUa-_YzIHGg_LGZ8CwX6ivHKCR8ZgJr-JNMP8MTh7 "

-- Discord webhook or API key for server logs
-- We recommend https://fivemanage.com/ for logs. Use code "LBLOGS" for 20% off the Logs Pro plan
LOGS = {
    Default = "https://discord.com/api/webhooks/1415141128101036146/v7kCcq3HfCGOeTxRNtDRLapHGOIvXuoAQJhQqGaEdtDrg25kmixFFR0rKGHZxuQDPB7_", -- set to false to disable
    Calls = "https://discord.com/api/webhooks/1412254371185557584/yQgCJQGD0GCjLynsR19u15UiDYDixHMqCG285_AQvHzVs9rtCi5fLGqRMqSpoUYtEyUn",
    Messages = "https://discord.com/api/webhooks/1412254740301221888/9GUlVd1vL72c-pVObquMWR6dF-MqyDDb_6jbps9IqRSGseKeZpCx_7vy6hV8aioanHMH",
    InstaPic = "https://discord.com/api/webhooks/1412254779593461871/FPydSlz9VQGD94KMrF8rSkcV5stKXPZowHsQFGwoNYaLmytAXTCizBi2_fgLhUrWT078",
    Birdy = "https://discord.com/api/webhooks/1412254860052664460/tVeKLf6Owelq3gQ4XA8nsyias5OXDj-rjBBJfeh0JSzHcJZhy1TLJfVp7UCsRSaykblp",
    YellowPages = "https://discord.com/api/webhooks/1412254946333561007/E1bjcywhNp2ZIkhFcBAmgg-nsCSUp26n-WGd-wbdktqYL9f6NSruZ7DXOHR7hpdJ1ivc",
    Marketplace = "https://discord.com/api/webhooks/1412254990503903393/gf5PLzlvX7WWwEDmaYSYzFQjEQABnYSaBLuyVqT9nZrPX5Q4h9MqfbKXSVzK5SN7olO1",
    Mail = "https://discord.com/api/webhooks/1412255025782329344/_3itij1pYPLhaVXFpD6UXw6lnLWVFe5T2kmv9-8_lHIgkay-ZhnGKD3uKN869pd7RqZ4",
    Wallet = "https://discord.com/api/webhooks/1412255071684788224/3XuaUcRCdwVLnqagxvROvnVqBbgYrJhm7Us8CdzxUViJcY0QRfKjIdKn9mVrsBZP21rx",
    DarkChat = "https://discord.com/api/webhooks/1412255108560850954/CaVSbndKAHiEoMGcX0QMnouA0cPTva6G-cjsfubc1W4S01BWsld3uudwCxpwDGER0nez",
    Services = "https://discord.com/api/webhooks/1412255145470988288/IFoHZ7XbntSsls10qDXAW1gbFpyRKmD1UiiFh3pcoeri1-F3b9Q-dY2-CbekY4YcTPEi",
    Crypto = "https://discord.com/api/webhooks/1412255254799712286/BaeX7Tr_BJesXcMJS0Bg5eGcV8ipsyc-vPnmGq_JOyOjcNzKNOI742v8xKPFOKpJFz9B",
    Trendy = "https://discord.com/api/webhooks/1412255289251594282/tibvp5JXh4uyJejx2LvwEiVV0Daexy39GNPMJEhdNGBsO2DbJDBqy1ke_Jv0QX4XWEOL",
    Uploads = "https://discord.com/api/webhooks/1412255326237102140/Zs5QIs2Qi_sLGN2XS9TUwpy1iSC7yX-uoHtGztch3_fZREIGG9LB-keNlBpBDTKoPo_W" -- all camera uploads will go here
}

DISCORD_TOKEN = nil -- you can set a discord bot token here to get the players discord avatar for logs

-- Set your API keys for uploading media here.
-- Please note that the API key needs to match the correct upload method defined in Config.UploadMethod.
-- The default upload method is Fivemanage
-- You can get your API keys from https://fivemanage.com/
-- Use code LBPHONE10 for 10% off on Fivemanage
-- A video tutorial for how to set up Fivemanage can be found here: https://www.youtube.com/watch?v=y3bCaHS6Moc
API_KEYS = {
    Video = "JAdx1lhbOcOn67bTXTNegLL2Gm6DZhFk",
    Image = "JAdx1lhbOcOn67bTXTNegLL2Gm6DZhFk",
    Audio = "JAdx1lhbOcOn67bTXTNegLL2Gm6DZhFk",
}

-- Here you can set your credentials for Config.DynamicWebRTC
-- This is needed if video calls or InstaPic live streams are not working
-- You can get your credentials from https://dash.cloudflare.com/?to=/:account/realtime/turn/overview
WEBRTC = {
    TokenID = nil,
    APIToken = nil,
}
