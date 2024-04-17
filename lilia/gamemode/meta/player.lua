﻿--[[--
Physical representation of connected player.

`Player`s are a type of `Entity`. They are a physical representation of a `Character` - and can possess at most one `Character`
object at a time that you can interface with.

See the [Garry's Mod Wiki](https://wiki.garrysmod.com/page/Category:Player) for all other methods that the `Player` class has.
]]
-- @classmod Player
local playerMeta = FindMetaTable("Player")
local vectorMeta = FindMetaTable("Vector")
--- Checks if the player belongs to the "user" user group.
-- @function playerMeta:isUser
-- @realm shared
-- @treturn bool Whether the player belongs to the "user" user group.
function playerMeta:isUser()
    return self:IsUserGroup("user")
end

--- Checks if the player is a staff member.
-- @function playerMeta:isStaff
-- @realm shared
-- @treturn bool Whether the player is a staff member.
function playerMeta:isStaff()
    return CAMI.PlayerHasAccess(self, "UserGroups - Staff Group", nil) or self:IsSuperAdmin()
end

--- Checks if the player is a VIP.
-- @function playerMeta:isVIP
-- @realm shared
-- @treturn bool Whether the player is a VIP.
function playerMeta:isVIP()
    return CAMI.PlayerHasAccess(self, "UserGroups - VIP Group", nil)
end

--- Checks if the staff member is currently on duty (FACTION_STAFF).
-- @function playerMeta:isStaffOnDuty
-- @realm shared
-- @treturn bool Whether the staff member is currently on duty.
function playerMeta:isStaffOnDuty()
    return self:Team() == FACTION_STAFF
end

--- Checks if the player is currently observing.
-- @function playerMeta:isObserving
-- @realm shared
-- @treturn bool Whether the player is currently observing.
function playerMeta:isObserving()
    if self:GetMoveType() == MOVETYPE_NOCLIP and not self:InVehicle() then
        return true
    else
        return false
    end
end

--- Checks if the player is currently moving.
-- @function playerMeta:isMoving
-- @realm shared
-- @treturn bool Whether the player is currently moving.
function playerMeta:isMoving()
    if not IsValid(self) or not self:Alive() then return false end
    local keydown = self:KeyDown(IN_FORWARD) or self:KeyDown(IN_BACK) or self:KeyDown(IN_MOVELEFT) or self:KeyDown(IN_MOVERIGHT)
    return keydown and self:OnGround()
end

--- Checks if the player is currently outside (in the sky).
-- @function playerMeta:isOutside
-- @realm shared
-- @treturn bool Whether the player is currently outside (in the sky).
function playerMeta:isOutside()
    local trace = util.TraceLine({
        start = self:GetPos(),
        endpos = self:GetPos() + self:GetUp() * 9999999999,
        filter = self
    })
    return trace.HitSky
end

--- Checks if the player is currently in noclip mode.
-- @function playerMeta:isNoClipping
-- @realm shared
-- @treturn bool Whether the player is in noclip mode.
function playerMeta:isNoClipping()
    return self:GetMoveType() == MOVETYPE_NOCLIP
end

--- Checks if the player is stuck.
-- @function playerMeta:isStuck
-- @realm shared
-- @treturn bool Whether the player is stuck.
function playerMeta:isStuck()
    return util.TraceEntity({
        start = self:GetPos(),
        endpos = self:GetPos(),
        filter = self
    }, self).StartSolid
end

--- Calculates the squared distance from the player to the specified entity.
-- @function playerMeta:squaredDistanceFromEnt
-- @realm shared
-- @param entity The entity to calculate the distance to.
-- @treturn number The squared distance from the player to the entity.
function playerMeta:squaredDistanceFromEnt(entity)
    return self:GetPos():DistToSqr(entity)
end

--- Calculates the distance from the player to the specified entity.
-- @function playerMeta:distanceFromEnt
-- @realm shared
-- @param entity The entity to calculate the distance to.
-- @treturn number The distance from the player to the entity.
function playerMeta:distanceFromEnt(entity)
    return self:GetPos():Distance(entity)
end

--- Checks if the player is near another entity within a specified radius.
-- @function playerMeta:isNearPlayer
-- @realm shared
-- @param radius The radius within which to check for proximity.
-- @param entity The entity to check proximity to.
-- @treturn bool Whether the player is near the specified entity within the given radius.
function playerMeta:isNearPlayer(radius, entity)
    local squaredRadius = radius * radius
    local squaredDistance = self:GetPos():DistToSqr(entity:GetPos())
    return squaredDistance <= squaredRadius
end

--- Retrieves entities near the player within a specified radius.
-- @function playerMeta:entitiesNearPlayer
-- @realm shared
-- @param radius The radius within which to search for entities.
-- @param playerOnly (Optional) If true, only return player entities.
-- @treturn table A table containing the entities near the player.
function playerMeta:entitiesNearPlayer(radius, playerOnly)
    local nearbyEntities = {}
    for _, v in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
        if playerOnly and not v:IsPlayer() then continue end
        table.insert(nearbyEntities, v)
    end
    return nearbyEntities
end

--- Retrieves the active weapon item of the player.
-- @function playerMeta:getItemWeapon
-- @realm shared
-- @treturn Entity|nil The active weapon entity of the player, or nil if not found.
function playerMeta:getItemWeapon()
    local character = self:getChar()
    local inv = character:getInv()
    local items = inv:getItems()
    local weapon = self:GetActiveWeapon()
    if not IsValid(weapon) then return false end
    for _, v in pairs(items) do
        if v.class then
            if v.class == weapon:GetClass() and v:getData("equip", false) then
                return weapon, v
            else
                return false
            end
        end
    end
end

--- Adds money to the player's character.
-- @function playerMeta:addMoney
-- @realm shared
-- @param amount The amount of money to add.
function playerMeta:addMoney(amount)
    local character = self:getChar()
    if not character then return end
    local currentMoney = character:getMoney()
    local maxMoneyLimit = lia.config.MoneyLimit or 0
    if hook.Run("WalletLimit", self) ~= nil then maxMoneyLimit = hook.Run("WalletLimit", self) end
    if maxMoneyLimit > 0 then
        local totalMoney = currentMoney + amount
        if totalMoney > maxMoneyLimit then
            local remainingMoney = totalMoney - maxMoneyLimit
            character:giveMoney(maxMoneyLimit)
            local money = lia.currency.spawn(self:getItemDropPos(), remainingMoney)
            money.client = self
            money.charID = character:getID()
        else
            character:giveMoney(amount)
        end
    else
        character:giveMoney(amount)
    end
end

--- Takes money from the player's character.
-- @function playerMeta:takeMoney
-- @realm shared
-- @param amt The amount of money to take.
function playerMeta:takeMoney(amt)
    local character = self:getChar()
    if character then character:giveMoney(-amt) end
end

--- Retrieves the amount of money owned by the player's character.
-- @function playerMeta:getMoney
-- @realm shared
-- @treturn number The amount of money owned by the player's character.
function playerMeta:getMoney()
    local character = self:getChar()
    return character and character:getMoney() or 0
end

--- Checks if the player's character can afford a specified amount of money.
-- @function playerMeta:canAfford
-- @realm shared
-- @param amount The amount of money to check.
-- @treturn bool Whether the player's character can afford the specified amount of money.
function playerMeta:canAfford(amount)
    local character = self:getChar()
    return character and character:hasMoney(amount)
end

--- Checks if the player is running.
-- @function playerMeta:isRunning
-- @realm shared
-- @treturn bool Whether the player is running.
function playerMeta:isRunning()
    return vectorMeta.Length2D(self:GetVelocity()) > (self:GetWalkSpeed() + 10)
end

--- Checks if the player's character is female based on the model.
-- @function playerMeta:isFemale
-- @realm shared
-- @treturn bool Whether the player's character is female.
function playerMeta:isFemale()
    local model = self:GetModel():lower()
    return model:find("female") or model:find("alyx") or model:find("mossman") or lia.anim.getModelClass(model) == "citizen_female"
end

--- Calculates the position to drop an item from the player's inventory.
-- @function playerMeta:getItemDropPos
-- @realm shared
-- @treturn Vector The position to drop an item from the player's inventory.
function playerMeta:getItemDropPos()
    local data = {}
    data.start = self:GetShootPos()
    data.endpos = self:GetShootPos() + self:GetAimVector() * 86
    data.filter = self
    local trace = util.TraceLine(data)
    data.start = trace.HitPos
    data.endpos = data.start + trace.HitNormal * 46
    data.filter = {}
    trace = util.TraceLine(data)
    return trace.HitPos
end

--- Checks if the player has whitelisted access to a faction.
-- @function playerMeta:hasWhitelist
-- @realm shared
-- @param faction The faction to check for whitelisting.
-- @treturn bool Whether the player has whitelisted access to the specified faction.
function playerMeta:hasWhitelist(faction)
    local data = lia.faction.indices[faction]
    if data then
        if data.isDefault then return true end
        local liaData = self:getLiliaData("whitelists", {})
        return liaData[SCHEMA.folder] and liaData[SCHEMA.folder][data.uniqueID] == true or false
    end
    return false
end

--- Retrieves the items of the player's character inventory.
-- @function playerMeta:getItems
-- @realm shared
-- @treturn table|nil A table containing the items in the player's character inventory, or nil if not found.
function playerMeta:getItems()
    local character = self:getChar()
    if character then
        local inv = character:getInv()
        if inv then return inv:getItems() end
    end
end

--- Retrieves the class of the player's character.
-- @function playerMeta:getClass
-- @realm shared
-- @treturn string|nil The class of the player's character, or nil if not found.
function playerMeta:getClass()
    local character = self:getChar()
    if character then return character:getClass() end
end

--- Retrieves the entity traced by the player's aim.
-- @function playerMeta:getTracedEntity
-- @realm shared
-- @treturn Entity|nil The entity traced by the player's aim, or nil if not found.
function playerMeta:getTracedEntity()
    local data = {}
    data.start = self:GetShootPos()
    data.endpos = data.start + self:GetAimVector() * 96
    data.filter = self
    local target = util.TraceLine(data).Entity
    return target
end

--- Performs a trace from the player's view.
-- @function playerMeta:getTrace
-- @realm shared
-- @treturn table A table containing the trace result.
function playerMeta:getTrace()
    local data = {}
    data.start = self:GetShootPos()
    data.endpos = data.start + self:GetAimVector() * 200
    data.filter = {self, self}
    data.mins = -Vector(4, 4, 4)
    data.maxs = Vector(4, 4, 4)
    local trace = util.TraceHull(data)
    return trace
end

--- Retrieves the data of the player's character class.
-- @function playerMeta:getClassData
-- @realm shared
-- @treturn table|nil A table containing the data of the player's character class, or nil if not found.
function playerMeta:getClassData()
    local character = self:getChar()
    if character then
        local class = character:getClass()
        if class then
            local classData = lia.class.list[class]
            return classData
        end
    end
end

--- Checks if the player has a skill level equal to or greater than the specified level.
-- @function playerMeta:hasSkillLevel
-- @realm shared
-- @param skill The skill to check.
-- @param level The required skill level.
-- @treturn bool Whether the player's skill level meets or exceeds the specified level.
function playerMeta:hasSkillLevel(skill, level)
    local currentLevel = self:getChar():getAttrib(skill, 0)
    return currentLevel >= level
end

--- Checks if the player meets the required skill levels.
-- @function playerMeta:meetsRequiredSkills
-- @realm shared
-- @param requiredSkillLevels A table containing the required skill levels.
-- @treturn bool Whether the player meets all the required skill levels.
function playerMeta:meetsRequiredSkills(requiredSkillLevels)
    if not requiredSkillLevels then return true end
    for skill, level in pairs(requiredSkillLevels) do
        if not self:hasSkillLevel(skill, level) then return false end
    end
    return true
end

--- Retrieves the entity within the player's line of sight.
-- @function playerMeta:getEyeEnt
-- @realm shared
-- @param[opt=150] distance The maximum distance to consider.
-- @treturn Entity|nil The entity within the player's line of sight, or nil if not found.
function playerMeta:getEyeEnt(distance)
    distance = distance or 150
    local e = self:GetEyeTrace().Entity
    return e:GetPos():Distance(self:GetPos()) <= distance and e or nil
end

--- Requests a string input from the player.
-- @function playerMeta:RequestString
-- @realm shared
-- @param title The title of the request.
-- @param subTitle The subtitle of the request.
-- @param callback The function to call upon receiving the string input.
-- @param default The default value for the string input.
function playerMeta:RequestString(title, subTitle, callback, default)
    local time = math.floor(os.time())
    self.StrReqs = self.StrReqs or {}
    self.StrReqs[time] = callback
    net.Start("StringRequest")
    net.WriteUInt(time, 32)
    net.WriteString(title)
    net.WriteString(subTitle)
    net.WriteString(default)
    net.Send(self)
end

if SERVER then
    --- Loads Lilia data for the player from the database.
    -- @function playerMeta:loadLiliaData
    -- @param callback[opt=nil] Function to call after the data is loaded, passing the loaded data as an argument.
    -- @realm server
    function playerMeta:loadLiliaData(callback)
        local name = self:steamName()
        local steamID64 = self:SteamID64()
        local timeStamp = os.date("%Y-%m-%d %H:%M:%S", os.time())
        lia.db.query("SELECT _data, _firstJoin, _lastJoin FROM lia_players WHERE _steamID = " .. steamID64, function(data)
            if IsValid(self) and data and data[1] and data[1]._data then
                lia.db.updateTable({
                    _lastJoin = timeStamp,
                }, nil, "players", "_steamID = " .. steamID64)

                self.firstJoin = data[1]._firstJoin or timeStamp
                self.lastJoin = data[1]._lastJoin or timeStamp
                self.liaData = util.JSONToTable(data[1]._data)
                if callback then callback(self.liaData) end
            else
                lia.db.insertTable({
                    _steamID = steamID64,
                    _steamName = name,
                    _firstJoin = timeStamp,
                    _lastJoin = timeStamp,
                    _data = {}
                }, nil, "players")

                if callback then callback({}) end
            end
        end)
    end

    --- Saves the player's Lilia data to the database.
    -- @function playerMeta:saveLiliaData
    -- @realm server
    function playerMeta:saveLiliaData()
        local name = self:steamName()
        local steamID64 = self:SteamID64()
        local timeStamp = os.date("%Y-%m-%d %H:%M:%S", os.time())
        lia.db.updateTable({
            _steamName = name,
            _lastJoin = timeStamp,
            _data = self.liaData
        }, nil, "players", "_steamID = " .. steamID64)
    end

    --- Sets a key-value pair in the player's Lilia data.
    -- @function playerMeta:setLiliaData
    -- @param key The key for the data.
    -- @param value The value to set.
    -- @param noNetworking[opt=false] If true, suppresses network broadcasting of the update.
    -- @realm server
    function playerMeta:setLiliaData(key, value, noNetworking)
        self.liaData = self.liaData or {}
        self.liaData[key] = value
        if not noNetworking then netstream.Start(self, "liaData", key, value) end
    end

    --- Retrieves a value from the player's Lilia data.
    -- @function playerMeta:getLiliaData
    -- @param key The key for the data.
    -- @param default[opt=nil] The default value to return if the key does not exist.
    -- @realm server
    -- @treturn any The value corresponding to the key, or the default value if the key does not exist.
    function playerMeta:getLiliaData(key, default)
        if key == true then return self.liaData end
        local data = self.liaData and self.liaData[key]
        if data == nil then
            return default
        else
            return data
        end
    end
--- Sets an action bar for the player.
-- @function playerMeta:setAction
-- @param text The text to display on the action bar.
-- @param[opt] time The duration for the action bar to display, defaults to 5 seconds. Set to 0 or nil to remove the action bar immediately.
-- @param[opt] callback Function to execute when the action bar timer expires.
-- @param[opt] startTime The start time of the action bar, defaults to the current time.
-- @param[opt] finishTime The finish time of the action bar, defaults to startTime + time.
-- @realm server
    function playerMeta:setAction(text, time, callback, startTime, finishTime)
        if time and time <= 0 then
            if callback then callback(self) end
            return
        end

        time = time or 5
        startTime = startTime or CurTime()
        finishTime = finishTime or (startTime + time)
        if text == false then
            timer.Remove("liaAct" .. self:UniqueID())
            netstream.Start(self, "actBar")
            return
        end

        netstream.Start(self, "actBar", startTime, finishTime, text)
        if callback then timer.Create("liaAct" .. self:UniqueID(), time, 1, function() if IsValid(self) then callback(self) end end) end
    end
--- Retrieves the player's permission flags.
-- @function playerMeta:getPermFlags
-- @realm server
-- @treturn string The player's permission flags.

    function playerMeta:getPermFlags()
        return self:getLiliaData("permflags", "")
    end
--- Sets the player's permission flags.
-- @function playerMeta:setPermFlags
-- @param flags The permission flags to set.
-- @realm server

    function playerMeta:setPermFlags(val)
        self:setLiliaData("permflags", val or "")
        self:saveLiliaData()
    end
--- Grants permission flags to the player.
-- @function playerMeta:givePermFlags
-- @param flags The permission flags to grant.
-- @realm server

    function playerMeta:givePermFlags(flags)
        local curFlags = self:getPermFlags()
        for i = 1, #flags do
            local flag = flags[i]
            if not self:hasPermFlag(flag) and not self:hasFlagBlacklist(flag) then curFlags = curFlags .. flag end
        end

        self:setPermFlags(curFlags)
        if self.liaCharList then
            for _, v in pairs(self.liaCharList) do
                local char = lia.char.loaded[v]
                if char then char:giveFlags(flags) end
            end
        end
    end
--- Revokes permission flags from the player.
-- @function playerMeta:takePermFlags
-- @param flags The permission flags to revoke.
-- @realm server
    function playerMeta:takePermFlags(flags)
        local curFlags = self:getPermFlags()
        for i = 1, #flags do
            curFlags = curFlags:gsub(flags[i], "")
        end

        self:setPermFlags(curFlags)
        if self.liaCharList then
            for _, v in pairs(self.liaCharList) do
                local char = lia.char.loaded[v]
                if char then char:takeFlags(flags) end
            end
        end
    end
--- Checks if the player has a specific permission flag.
-- @function playerMeta:hasPermFlag
-- @param flag The permission flag to check.
-- @realm server
-- @treturn bool Whether or not the player has the permission flag.

    function playerMeta:hasPermFlag(flag)
        if not flag or #flag ~= 1 then return end
        local curFlags = self:getPermFlags()
        for i = 1, #curFlags do
            if curFlags[i] == flag then return true end
        end
        return false
    end
--- Retrieves the player's flag blacklist.
-- @function playerMeta:getFlagBlacklist
-- @realm server
-- @treturn string The player's flag blacklist.

    function playerMeta:getFlagBlacklist()
        return self:getLiliaData("flagblacklist", "")
    end
--- Sets the player's flag blacklist.
-- @function playerMeta:setFlagBlacklist
-- @param flags The flag blacklist to set.
-- @realm server

    function playerMeta:setFlagBlacklist(flags)
        self:setLiliaData("flagblacklist", flags)
        self:saveLiliaData()
    end
--- Adds flags to the player's flag blacklist.
-- @function playerMeta:addFlagBlacklist
-- @param flags The flags to add to the blacklist.
-- @param[opt] blacklistInfo Additional information about the blacklist entry.
-- @realm server

    function playerMeta:addFlagBlacklist(flags, blacklistInfo)
        local curBlack = self:getFlagBlacklist()
        for i = 1, #flags do
            local curFlag = flags[i]
            if not self:hasFlagBlacklist(curFlag) then curBlack = curBlack .. flags[i] end
        end

        self:setFlagBlacklist(curBlack)
        self:takePermFlags(flags)
        if blacklistInfo then
            local blacklistLog = self:getLiliaData("flagblacklistlog", {})
            blacklistInfo.starttime = os.time()
            blacklistInfo.time = blacklistInfo.time or 0
            blacklistInfo.endtime = blacklistInfo.time <= 0 and 0 or (os.time() + blacklistInfo.time)
            blacklistInfo.admin = blacklistInfo.admin or "N/A"
            blacklistInfo.adminsteam = blacklistInfo.adminsteam or "N/A"
            blacklistInfo.active = true
            blacklistInfo.flags = blacklistInfo.flags or ""
            blacklistInfo.reason = blacklistInfo.reason or "N/A"
            table.insert(blacklistLog, blacklistInfo)
            self:setLiliaData("flagblacklistlog", blacklistLog)
            self:saveLiliaData()
        end
    end

    --- Removes flags from the player's flag blacklist.
    -- @function playerMeta:removeFlagBlacklist
    -- @realm server
    -- @param flags A table containing the flags to remove from the blacklist.
    function playerMeta:removeFlagBlacklist(flags)
        local curBlack = self:getFlagBlacklist()
        for i = 1, #flags do
            local curFlag = flags[i]
            curBlack = curBlack:gsub(curFlag, "")
        end

        self:setFlagBlacklist(curBlack)
    end

    --- Checks if the player has a specific flag blacklisted.
    -- @function playerMeta:hasFlagBlacklist
    -- @realm server
    -- @param flag The flag to check for in the blacklist.
    -- @treturn bool Whether the player has the specified flag blacklisted.
    function playerMeta:hasFlagBlacklist(flag)
        local flags = self:getFlagBlacklist()
        for i = 1, #flags do
            if flags[i] == flag then return true end
        end
        return false
    end

    --- Checks if the player has any of the specified flags blacklisted.
    -- @function playerMeta:hasAnyFlagBlacklist
    -- @realm server
    -- @param flags A table containing the flags to check for in the blacklist.
    -- @treturn bool Whether the player has any of the specified flags blacklisted.
    function playerMeta:hasAnyFlagBlacklist(flags)
        for i = 1, #flags do
            if self:hasFlagBlacklist(flags[i]) then return true end
        end
        return false
    end

    --- Plays a sound for the player.
    -- @function playerMeta:playSound
    -- @realm client
    -- @param sound The sound to play.
    -- @param[opt=100] pitch The pitch of the sound.
    function playerMeta:playSound(sound, pitch)
        net.Start("LiliaPlaySound")
        net.WriteString(tostring(sound))
        net.WriteUInt(tonumber(pitch) or 100, 7)
        net.Send(self)
    end

    --- Opens a VGUI panel for the player.
    -- @function playerMeta:openUI
    -- @realm client
    -- @param panel The name of the VGUI panel to open.
    function playerMeta:openUI(panel)
        net.Start("OpenVGUI")
        net.WriteString(panel)
        net.Send(self)
    end

    playerMeta.OpenUI = playerMeta.openUI
    --- Opens a web page for the player.
    -- @function playerMeta:openPage
    -- @realm client
    -- @param url The URL of the web page to open.
    function playerMeta:openPage(url)
        net.Start("OpenPage")
        net.WriteString(url)
        net.Send(self)
    end

    --- Retrieves the player's total playtime.
    -- @function playerMeta:getPlayTime
    -- @realm shared
    -- @treturn number The total playtime of the player.
    function playerMeta:getPlayTime()
        local diff = os.time(lia.util.dateToNumber(self.lastJoin)) - os.time(lia.util.dateToNumber(self.firstJoin))
        return diff + (RealTime() - (self.liaJoinTime or RealTime()))
    end

    playerMeta.GetPlayTime = playerMeta.getPlayTime
    --- Creates a ragdoll entity for the player on the server.
    -- @function playerMeta:createServerRagdoll
    -- @realm server
    -- @param[opt=false] DontSetPlayer Determines whether to associate the player with the ragdoll.
    -- @treturn Entity The created ragdoll entity.
    function playerMeta:createServerRagdoll(DontSetPlayer)
        local entity = ents.Create("prop_ragdoll")
        entity:SetPos(self:GetPos())
        entity:SetAngles(self:EyeAngles())
        entity:SetModel(self:GetModel())
        entity:SetSkin(self:GetSkin())
        for _, v in ipairs(self:GetBodyGroups()) do
            entity:SetBodygroup(v.id, self:GetBodygroup(v.id))
        end

        entity:Spawn()
        if not DontSetPlayer then entity:SetNetVar("player", self) end
        entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        entity:Activate()
        hook.Run("OnCreatePlayerServerRagdoll", self)
        local velocity = self:GetVelocity()
        for i = 0, entity:GetPhysicsObjectCount() - 1 do
            local physObj = entity:GetPhysicsObjectNum(i)
            if IsValid(physObj) then
                physObj:SetVelocity(velocity)
                local index = entity:TranslatePhysBoneToBone(i)
                if index then
                    local position, angles = self:GetBonePosition(index)
                    physObj:SetPos(position)
                    physObj:SetAngles(angles)
                end
            end
        end
        return entity
    end

    --- Performs a stared action towards an entity for a certain duration.
    -- @function playerMeta:doStaredAction
    -- @realm server
    -- @param entity The entity towards which the player performs the stared action.
    -- @param callback The function to call when the stared action is completed.
    -- @param[opt] time The duration of the stared action in seconds.
    -- @param[opt] onCancel The function to call if the stared action is canceled.
    -- @param[opt] distance The maximum distance for the stared action.
    function playerMeta:doStaredAction(entity, callback, time, onCancel, distance)
        local uniqueID = "liaStare" .. self:UniqueID()
        local data = {}
        data.filter = self
        timer.Create(uniqueID, 0.1, time / 0.1, function()
            if IsValid(self) and IsValid(entity) then
                data.start = self:GetShootPos()
                data.endpos = data.start + self:GetAimVector() * (distance or 96)
                local targetEntity = util.TraceLine(data).Entity
                if IsValid(targetEntity) and targetEntity:GetClass() == "prop_ragdoll" and IsValid(targetEntity:getNetVar("player")) then targetEntity = targetEntity:getNetVar("player") end
                if targetEntity ~= entity then
                    timer.Remove(uniqueID)
                    if onCancel then onCancel() end
                elseif callback and timer.RepsLeft(uniqueID) == 0 then
                    callback()
                end
            else
                timer.Remove(uniqueID)
                if onCancel then onCancel() end
            end
        end)
    end

    --- Notifies the player with a message.
    -- @function playerMeta:notify
    -- @realm shared
    -- @param message The message to notify the player.
    function playerMeta:notify(message)
        lia.util.notify(message, self)
    end

    --- Notifies the player with a localized message.
    -- @function playerMeta:notifyLocalized
    -- @realm shared
    -- @param message The key of the localized message to notify the player.
    -- @param ... Additional arguments to format the localized message.
    function playerMeta:notifyLocalized(message, ...)
        lia.util.notifyLocalized(message, self, ...)
    end

    --- Requests a string input from the player.
    -- @function playerMeta:requestString
    -- @realm shared
    -- @param title The title of the string input dialog.
    -- @param subTitle The subtitle or description of the string input dialog.
    -- @param callback The function to call with the entered string.
    -- @param[opt] default The default value for the string input.
    -- @treturn Promise A promise object resolving with the entered string.
    function playerMeta:requestString(title, subTitle, callback, default)
        local d
        if not isfunction(callback) and default == nil then
            default = callback
            d = deferred.new()
            callback = function(value) d:resolve(value) end
        end

        self.liaStrReqs = self.liaStrReqs or {}
        local id = table.insert(self.liaStrReqs, callback)
        net.Start("liaStringReq")
        net.WriteUInt(id, 32)
        net.WriteString(title)
        net.WriteString(subTitle)
        net.WriteString(default or "")
        net.Send(self)
        return d
    end

    --- Creates a ragdoll entity for the player.
    -- @function playerMeta:createRagdoll
    -- @realm server
    -- @param freeze Whether to freeze the ragdoll initially.
    -- @treturn Entity The created ragdoll entity.
    function playerMeta:createRagdoll(freeze)
        local entity = ents.Create("prop_ragdoll")
        entity:SetPos(self:GetPos())
        entity:SetAngles(self:EyeAngles())
        entity:SetModel(self:GetModel())
        entity:SetSkin(self:GetSkin())
        entity:Spawn()
        entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        entity:Activate()
        local velocity = self:GetVelocity()
        for i = 0, entity:GetPhysicsObjectCount() - 1 do
            local physObj = entity:GetPhysicsObjectNum(i)
            if IsValid(physObj) then
                local index = entity:TranslatePhysBoneToBone(i)
                if index then
                    local position, angles = self:GetBonePosition(index)
                    physObj:SetPos(position)
                    physObj:SetAngles(angles)
                end

                if freeze then
                    physObj:EnableMotion(false)
                else
                    physObj:SetVelocity(velocity)
                end
            end
        end
        return entity
    end

    --- Sets the player to a ragdolled state or removes the ragdoll.
    -- @function playerMeta:setRagdolled
    -- @realm server
    -- @param state Whether to set the player to a ragdolled state (`true`) or remove the ragdoll (`false`).
    -- @param[opt] time The duration for which the player remains ragdolled.
    -- @param[opt] getUpGrace The grace period for the player to get up before the ragdoll is removed.
    function playerMeta:setRagdolled(state, time, getUpGrace)
        getUpGrace = getUpGrace or time or 5
        if state then
            if IsValid(self.liaRagdoll) then self.liaRagdoll:Remove() end
            local entity = self:createRagdoll()
            entity:setNetVar("player", self)
            entity:CallOnRemove("fixer", function()
                if IsValid(self) then
                    self:setLocalVar("blur", nil)
                    self:setLocalVar("ragdoll", nil)
                    if not entity.liaNoReset then self:SetPos(entity:GetPos()) end
                    self:SetNoDraw(false)
                    self:SetNotSolid(false)
                    self:Freeze(false)
                    self:SetMoveType(MOVETYPE_WALK)
                    self:SetLocalVelocity(IsValid(entity) and entity.liaLastVelocity or vector_origin)
                end

                if IsValid(self) and not entity.liaIgnoreDelete then
                    if entity.liaWeapons then
                        for _, v in ipairs(entity.liaWeapons) do
                            self:Give(v)
                            if entity.liaAmmo then
                                for k2, v2 in ipairs(entity.liaAmmo) do
                                    if v == v2[1] then self:SetAmmo(v2[2], tostring(k2)) end
                                end
                            end
                        end

                        for _, v in ipairs(self:GetWeapons()) do
                            v:SetClip1(0)
                        end
                    end

                    if self:isStuck() then
                        entity:DropToFloor()
                        self:SetPos(entity:GetPos() + Vector(0, 0, 16))
                        local positions = lia.util.findEmptySpace(self, {entity, self})
                        for _, v in ipairs(positions) do
                            self:SetPos(v)
                            if not self:isStuck() then return end
                        end
                    end
                end
            end)

            self:setLocalVar("blur", 25)
            self.liaRagdoll = entity
            entity.liaWeapons = {}
            entity.liaAmmo = {}
            entity.liaPlayer = self
            if getUpGrace then entity.liaGrace = CurTime() + getUpGrace end
            if time and time > 0 then
                entity.liaStart = CurTime()
                entity.liaFinish = entity.liaStart + time
                self:setAction("@wakingUp", nil, nil, entity.liaStart, entity.liaFinish)
            end

            for _, v in ipairs(self:GetWeapons()) do
                entity.liaWeapons[#entity.liaWeapons + 1] = v:GetClass()
                local clip = v:Clip1()
                local reserve = self:GetAmmoCount(v:GetPrimaryAmmoType())
                local ammo = clip + reserve
                entity.liaAmmo[v:GetPrimaryAmmoType()] = {v:GetClass(), ammo}
            end

            self:GodDisable()
            self:StripWeapons()
            self:Freeze(true)
            self:SetNoDraw(true)
            self:SetNotSolid(true)
            self:SetMoveType(MOVETYPE_NONE)
            if time then
                local uniqueID = "liaUnRagdoll" .. self:SteamID()
                timer.Create(uniqueID, 0.33, 0, function()
                    if IsValid(entity) and IsValid(self) then
                        local velocity = entity:GetVelocity()
                        entity.liaLastVelocity = velocity
                        self:SetPos(entity:GetPos())
                        if velocity:Length2D() >= 8 then
                            if not entity.liaPausing then
                                self:setAction()
                                entity.liaPausing = true
                            end
                            return
                        elseif entity.liaPausing then
                            self:setAction("@wakingUp", time)
                            entity.liaPausing = false
                        end

                        time = time - 0.33
                        if time <= 0 then entity:Remove() end
                    else
                        timer.Remove(uniqueID)
                    end
                end)
            end

            self:setLocalVar("ragdoll", entity:EntIndex())
            hook.Run("OnCharFallover", self, entity, true)
        elseif IsValid(self.liaRagdoll) then
            self.liaRagdoll:Remove()
            hook.Run("OnCharFallover", self, nil, false)
        end
    end

    --- Sets whether the player is whitelisted for a faction.
    -- @function playerMeta:setWhitelisted
    -- @realm server
    -- @param faction The faction ID.
    -- @param whitelisted Whether the player should be whitelisted for the faction.
    -- @treturn bool Whether the operation was successful.
    function playerMeta:setWhitelisted(faction, whitelisted)
        if not whitelisted then whitelisted = nil end
        local data = lia.faction.indices[faction]
        if data then
            local whitelists = self:getLiliaData("whitelists", {})
            whitelists[SCHEMA.folder] = whitelists[SCHEMA.folder] or {}
            whitelists[SCHEMA.folder][data.uniqueID] = whitelisted and true or nil
            self:setLiliaData("whitelists", whitelists)
            self:saveLiliaData()
            return true
        end
        return false
    end

    --- Synchronizes networked variables with the player.
    -- @function playerMeta:syncVars
    -- @realm server
    function playerMeta:syncVars()
        for entity, data in pairs(lia.net) do
            if entity == "globals" then
                for k, v in pairs(data) do
                    netstream.Start(self, "gVar", k, v)
                end
            elseif IsValid(entity) then
                for k, v in pairs(data) do
                    netstream.Start(self, "nVar", entity:EntIndex(), k, v)
                end
            end
        end
    end

    --- Sets a local variable for the player.
    -- @function playerMeta:setLocalVar
    -- @realm server
    -- @param key The key of the variable.
    -- @param value The value of the variable.
    function playerMeta:setLocalVar(key, value)
        if checkBadType(key, value) then return end
        lia.net[self] = lia.net[self] or {}
        lia.net[self][key] = value
        netstream.Start(self, "nLcl", key, value)
    end

    playerMeta.SetLocalVar = playerMeta.setLocalVar
    --- Notifies the player with a message and prints the message to their chat.
    -- @function playerMeta:notifyP
    -- @realm server
    -- @param text The message to notify and print.
    function playerMeta:notifyP(text)
        self:notify(text)
        self:ChatPrint(text)
    end

    --- Sends a message to the player.
    -- @function playerMeta:sendMessage
    -- @realm server
    -- @param ... The message(s) to send.
    function playerMeta:sendMessage(...)
        net.Start("SendMessage")
        net.WriteTable({...} or {})
        net.Send(self)
    end

    --- Sends a message to the player to be printed.
    -- @function playerMeta:sendPrint
    -- @realm server
    -- @param ... The message(s) to print.
    function playerMeta:sendPrint(...)
        net.Start("SendPrint")
        net.WriteTable({...} or {})
        net.Send(self)
    end

    --- Sends a table to the player to be printed.
    -- @function playerMeta:sendPrintTable
    -- @realm server
    -- @param ... The table(s) to print.
    function playerMeta:sendPrintTable(...)
        net.Start("SendPrintTable")
        net.WriteTable({...} or {})
        net.Send(self)
    end
else
    --- Retrieves the player's total playtime.
    -- @function playerMeta:getPlayTime
    -- @realm client
    -- @treturn number The total playtime of the player.
    function playerMeta:getPlayTime()
        local diff = os.time(lia.util.dateToNumber(lia.lastJoin)) - os.time(lia.util.dateToNumber(lia.firstJoin))
        return diff + (RealTime() - lia.joinTime or 0)
    end

    playerMeta.GetPlayTime = playerMeta.getPlayTime
    --- Opens a UI panel for the player.
    -- @function playerMeta:openUI
    -- @param panel The panel type to create.
    -- @realm client
    -- @treturn Panel The created UI panel.
    function playerMeta:openUI(panel)
        return vgui.Create(panel)
    end

    playerMeta.OpenUI = playerMeta.openUI
    --- Sets a waypoint for the player.
    -- @function playerMeta:setWeighPoint
    -- @param name The name of the waypoint.
    -- @param vector The position vector of the waypoint.
    -- @param OnReach[opt=nil] Function to call when the player reaches the waypoint.
    -- @realm client
    function playerMeta:setWeighPoint(name, vector, OnReach)
        hook.Add("HUDPaint", "WeighPoint", function()
            local dist = self:GetPos():Distance(vector)
            local spos = vector:ToScreen()
            local howclose = math.Round(math.floor(dist) / 40)
            if not spos then return end
            render.SuppressEngineLighting(true)
            surface.SetFont("WB_Large")
            draw.DrawText(name .. "\n" .. howclose .. " Meters\n", "CenterPrintText", spos.x, spos.y, Color(123, 57, 209), TEXT_ALIGN_CENTER)
            render.SuppressEngineLighting(false)
            if howclose <= 3 then RunConsoleCommand("weighpoint_stop") end
        end)

        concommand.Add("weighpoint_stop", function()
            hook.Add("HUDPaint", "WeighPoint", function() end)
            if IsValid(OnReach) then OnReach() end
        end)
    end

    --- Retrieves a value from the local Lilia data.
    -- @function playerMeta:getLiliaData
    -- @param key The key for the data.
    -- @param default[opt=nil] The default value to return if the key does not exist.
    -- @realm client
    -- @treturn any The value corresponding to the key, or the default value if the key does not exist.
    function playerMeta:getLiliaData(key, default)
        local data = lia.localData and lia.localData[key]
        if data == nil then
            return default
        else
            return data
        end
    end
end

playerMeta.IsUser = playerMeta.isUser
playerMeta.IsStaff = playerMeta.isStaff
playerMeta.IsVIP = playerMeta.isVIP
playerMeta.IsStaffOnDuty = playerMeta.isStaffOnDuty
playerMeta.IsObserving = playerMeta.isObserving
playerMeta.IsOutside = playerMeta.isOutside
playerMeta.IsNoClipping = playerMeta.isNoClipping
playerMeta.SquaredDistanceFromEnt = playerMeta.squaredDistanceFromEnt
playerMeta.DistanceFromEnt = playerMeta.distanceFromEnt
playerMeta.IsNearPlayer = playerMeta.isNearPlayer
playerMeta.EntitiesNearPlayer = playerMeta.entitiesNearPlayer
playerMeta.GetItemWeapon = playerMeta.getItemWeapon
playerMeta.AddMoney = playerMeta.addMoney
playerMeta.TakeMoney = playerMeta.takeMoney
playerMeta.GetMoney = playerMeta.getMoney
playerMeta.CanAfford = playerMeta.canAfford
playerMeta.IsRunning = playerMeta.isRunning
playerMeta.IsFemale = playerMeta.isFemale
playerMeta.GetItemDropPos = playerMeta.getItemDropPos
playerMeta.HasWhitelist = playerMeta.hasWhitelist
playerMeta.GetTracedEntity = playerMeta.getTracedEntity
playerMeta.GetTrace = playerMeta.getTrace
playerMeta.GetClassData = playerMeta.getClassData
playerMeta.HasSkillLevel = playerMeta.hasSkillLevel
playerMeta.MeetsRequiredSkills = playerMeta.meetsRequiredSkills
playerMeta.GetEyeEnt = playerMeta.getEyeEnt
playerMeta.SetAction = playerMeta.setAction
playerMeta.GetPermFlags = playerMeta.getPermFlags
playerMeta.SetPermFlags = playerMeta.setPermFlags
playerMeta.GivePermFlags = playerMeta.givePermFlags
playerMeta.TakePermFlags = playerMeta.takePermFlags
playerMeta.HasPermFlag = playerMeta.hasPermFlag
playerMeta.GetFlagBlacklist = playerMeta.getFlagBlacklist
playerMeta.SetFlagBlacklist = playerMeta.setFlagBlacklist
playerMeta.AddFlagBlacklist = playerMeta.addFlagBlacklist
playerMeta.RemoveFlagBlacklist = playerMeta.removeFlagBlacklist
playerMeta.HasFlagBlacklist = playerMeta.hasFlagBlacklist
playerMeta.HasAnyFlagBlacklist = playerMeta.hasAnyFlagBlacklist
playerMeta.PlaySound = playerMeta.playSound
playerMeta.OpenPage = playerMeta.openPage
playerMeta.CreateServerRagdoll = playerMeta.createServerRagdoll
playerMeta.DoStaredAction = playerMeta.doStaredAction
playerMeta.Notify = playerMeta.notify
playerMeta.NotifyLocalized = playerMeta.notifyLocalized
playerMeta.SetRagdolled = playerMeta.setRagdolled
playerMeta.SetWhitelisted = playerMeta.setWhitelisted
playerMeta.SyncVars = playerMeta.syncVars
playerMeta.NotifyP = playerMeta.notifyP
playerMeta.SendMessage = playerMeta.sendMessage
playerMeta.SendPrint = playerMeta.sendPrint
playerMeta.SendPrintTable = playerMeta.sendPrintTable
playerMeta.SetWeighPoint = playerMeta.setWeighPoint
