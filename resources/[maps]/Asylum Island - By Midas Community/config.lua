config = {}
secretRoom = {}

-- SECRET ROOM || DOOR CAN BE OPENED?
secretRoom.DoorCanBeOpened = true -- false for block the secret room

-- ENABLE JUST ONE:
secretRoom.Weed = false
secretRoom.Meth = false
secretRoom.Money = false
secretRoom.Weapon = false
secretRoom.Stock = true

-- Enable elevator? if false, elevator don't spawn.
config.elevator = true

-- Enable elevator marker on the ground?
config.drawElevatorMarker = true

config.visual = {
    -- Here you can change the color of elevator NUI.
    name_color = 'rgb(255,0,0)',
    text_color = 'rgb(255,255,255)',
    floors_color = 'rgb(255,0,0)'
}

config.lang = {
    -- Here you can change all texts of elevator NUI.
    name = 'Asylum',
    mainText = 'Available Floors',
    
    floors = {
        ['4th'] = '4th Floor',
        ['3rd'] = '3rd Floor',
        ['2nd'] = '2nd Floor',
        ['1st'] = '1st Floor',
        ['ground'] = 'Basement',
    }
}