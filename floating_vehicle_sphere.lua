--@name Floating Vehicle
--@author Lil'Tugboat
--@include libs/criticalpd.txt
--@shared
    

if SERVER then
    
    local targetHeight = 50
    local translationGain = 100 -- Set to desired stiffness
    local rotationGain = 100 -- Set to desired rotational stiffness
    
    local sensorDensity = 50
    local sensorRadius = 70
    
    local holoVisual = false
    
    ---------------------------------------------------------
    
    -- helpers
    local EntityCriticalPD = require("libs/criticalpd.txt")
    
        //async checks
    local function checkQ(n)
        return quotaAverage() < quotaMax()*n
    end
    
    local function yieldCheck()
        if not checkQ(0.95) then
            coroutine.yield()
        end
    end
    
    //Spawn things
    local chair = prop.createSeat(chip():localToWorld(Vector(0, 0, 100)), Angle(0, 0, 0), "models/props_interiors/furniture_couch02a.mdl", false)
        -- Makes calculating from chair center easier    
    local holoProxy = holograms.create(
        chair:obbCenterW(),
        chair:getAngles(),
        "models/sprops/misc/axis_plane.mdl",
        Vector(0, 0, 0)
    )
    holoProxy:setParent(chair)
    
--[[
    local moveVisHolo = holograms.create(
        chair:obbCenterW(),
        Angle(),
        "models/sprops/misc/axis_plane.mdl",
        Vector(1, 1, 1)
    )
]]
    
    -- Sets up Physics stuff
    local physObj = chair:getPhysicsObject()
    local pdController = EntityCriticalPD:new(physObj, translationGain, rotationGain)
    
    -- sets up visualization
    local hitHolos = {}
    
    local function spawnSensorHolos()
       
        return coroutine.create(function()
            for index = 1, sensorDensity, 1 do
                
                local hitHolo = holograms.create(
                    holoProxy:getPos(),
                    holoProxy:getAngles(),
                    "models/sprops/misc/cube_from_x.mdl",
                    Vector(0.01, 1, 1)
                )
                hitHolo:setParent(holoProxy)
                table.insert(hitHolos, hitHolo)
                yieldCheck()
            end
        end)
    end
    
    local initHolos = spawnSensorHolos()
    if holoVisual then
        hook.add("think", "initHolos", function ()
            if coroutine.status(initHolos) ~= "dead" then
            
                    coroutine.resume(initHolos)
            else 
                hook.remove("think", "initHolos")
            end 
        end)
    end
    
    -- setup Sensors
    local averageSensorVector = Vector()
    local minSensorLength = Vector()
    local spinItteration = 0
    local function useSensors()
        return coroutine.create(function()
        
            local goldenAngle = 2.399963229728653
            local offset = 2 / sensorDensity
            
            
            while true do
                local localMinSensorLength = 99999
                local localAverageSensorVector = Vector()
                spinItteration = spinItteration + 0.1
                for index = 1, sensorDensity, 1 do
                    local y = ((index - 1) * offset - 1) + offset / 2
                    local r = math.sqrt(1 - y * y)
                    local phi = ((index - 1) % sensorDensity) * goldenAngle
                    
                    local localVector = Vector(
                        math.cos(phi + spinItteration) * r,
                        math.sin(phi + spinItteration) * r,
                        y
                    )
                    
                    localVector:mul(sensorRadius)
                    
                    local t = trace.line(holoProxy:getPos(), holoProxy:localToWorld(localVector), chair, MASK.ALL)
                    
                    rayOut = t.HitPos - holoProxy:getPos()
                    localMinSensorLength = math.min(localMinSensorLength, math.abs(rayOut:getLength()))
                    localAverageSensorVector = localAverageSensorVector + rayOut
                    
                    if holoVisual and hitHolos[index] then 
                        hitHolos[index]:setPos(t.HitPos)
                        
                        hitHolos[index]:setAngles(rayOut:getAngle())
                    end
                    yieldCheck()
                    
                end
                averageSensorVector = localAverageSensorVector
                minSensorLength = localMinSensorLength
                coroutine.yield()
            end
        end)
    end
    
    local sense = useSensors()
    hook.add("think", "sensors", function ()
        if coroutine.status(sense) ~= "dead" then
                coroutine.resume(sense)
        end 
    end)
    
    --movements
    hook.add("think", "movements", function ()
        local newMagnitude = sensorRadius - minSensorLength
        local sensorVectorNormal = averageSensorVector:getNormalized()
        sensorVectorNormal:mul(newMagnitude)
        
        
        local targetVector = holoProxy:getPos() +  sensorVectorNormal
        
        --moveVisHolo:setPos(targetVector)
        
        if minSensorLength < sensorRadius * 0.99 then 
            pdController:setTarget(targetVector, Angle())
            pdController:simulate()
        end
    end)
    

    local driver

    local function set_driver(ply, vehicle, role)
        if vehicle ~= chair then return end 
        driver = role and ply
    end

    hook.add("PlayerEnteredVehicle", "SetDriver", set_driver)
    hook.add("PlayerLeaveVehicle", "SetDriver", set_driver)
    
    
    local velocity = 0
    local acceleration = 0
    
    -- Map of inputs and their acceleration values / forces
    local inputs = {
        [IN_KEY.FORWARD] = 10,
        [IN_KEY.BACK] = -8,
    }
    
    
    hook.add("KeyPress", "KeyPress", function(ply, key)
        if ply ~= driver then return end 
        if inputs[key] then
        end
    end)
    
    hook.add("KeyRelease", "KeyRelease", function(ply, key)
        if ply ~= driver then return end 
        if inputs[key] then 
        end
    end)
    
    
    hook.add("Tick", "Update", function()
    end)

    
else



end



