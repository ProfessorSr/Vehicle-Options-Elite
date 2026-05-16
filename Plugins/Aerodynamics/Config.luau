-- Config ModuleScript
local Config = {}

-- [[Editable Values]]
Config.UseWeight = false      -- If true, does not use body parts to apply drag and downforce.
Config.UseSlipstream = false  -- Slipstream may lag on larger maps

Config.Drag = 0.38           -- Drag coefficient of the car.
Config.DragMult = 1.5        -- Multiplier for drag. This is so that the Drag value is accurate to your car. This value will need trial and error.
Config.Slipstream = 70       -- How much drag is reduced in slipstream (in percent)
Config.SlipstreamTime = 0.7  -- Maximum amount of time you can be behind a car to gain slipstream.
Config.DownforceF = 73       -- Front downforce in kgf at 200 km/h. 
Config.DownforceR = 106      -- Rear downforce in kgf at 200 km/h. 

return Config