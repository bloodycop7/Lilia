﻿--- Helper library for managing database.
-- @module lia.db
lia.db = lia.db or {}
lia.db.queryQueue = lia.db.queue or {}
lia.db.prepared = lia.db.prepared or {}
MYSQLOO_QUEUE = MYSQLOO_QUEUE or {}
PREPARE_CACHE = {}
MYSQLOO_INTEGER = 0
MYSQLOO_STRING = 1
MYSQLOO_BOOL = 2
local modules = {}
local function ThrowQueryFault(query, fault)
    MsgC(Color(255, 0, 0), "* " .. query .. "\n")
    MsgC(Color(255, 0, 0), fault .. "\n")
end

local function ThrowConnectionFault(fault)
    MsgC(Color(255, 0, 0), "Lilia has failed to connect to the database.\n")
    MsgC(Color(255, 0, 0), fault .. "\n")
    setNetVar("dbError", fault)
end

local function promisifyIfNoCallback(queryHandler)
    return function(query, callback)
        local d
        local function throw(err)
            if d then
                d:reject(err)
            else
                ThrowQueryFault(query, err)
            end
        end

        if not isfunction(callback) then
            d = deferred.new()
            callback = function(results, lastID)
                d:resolve({
                    results = results,
                    lastID = lastID
                })
            end
        end

        queryHandler(query, callback, throw)
        return d
    end
end

modules.sqlite = {
    query = promisifyIfNoCallback(function(query, callback, throw)
        local data = sql.Query(query)
        local err = sql.LastError()
        if data == false then throw(err) end
        if callback then
            local lastID = tonumber(sql.QueryValue("SELECT last_insert_rowid()"))
            callback(data, lastID)
        end
    end),
    escape = function(value) return sql.SQLStr(value, true) end,
    connect = function(callback)
        lia.db.query = modules.sqlite.query
        if callback then callback() end
    end
}

modules.mysqloo = {
    query = promisifyIfNoCallback(function(query, callback, throw)
        if lia.db.getObject and lia.db.getObject() then
            local object = lia.db.getObject():query(query)
            if callback then
                function object:onSuccess(data)
                    callback(data, self:lastInsert())
                end
            end

            function object:onError(fault)
                if lia.db.getObject():status() == mysqloo.DATABASE_NOT_CONNECTED then
                    lia.db.queryQueue[#lia.db.queryQueue + 1] = {query, callback}
                    lia.db.connect(nil, true)
                    return
                end

                throw(fault)
            end

            object:start()
        else
            lia.db.queryQueue[#lia.db.queryQueue + 1] = {query, callback}
        end
    end),
    escape = function(value)
        local object = lia.db.getObject and lia.db.getObject()
        if object then
            return object:escape(value)
        else
            return sql.SQLStr(value, true)
        end
    end,
    queue = function()
        local count = 0
        for _, v in pairs(lia.db.pool) do
            count = count + v:queueSize()
        end
        return count
    end,
    abort = function()
        for _, v in pairs(lia.db.pool) do
            v:abortAllQueries()
        end
    end,
    getObject = function()
        local lowest = nil
        local lowestCount = 0
        local lowestIndex = 0
        for k, db in pairs(lia.db.pool) do
            local queueSize = db:queueSize()
            if not lowest or queueSize < lowestCount then
                lowest = db
                lowestCount = queueSize
                lowestIndex = k
            end
        end

        if not lowest then error("failed to find database in the pool") end
        return lowest, lowestIndex
    end,
    connect = function(callback)
        if not pcall(require, "mysqloo") then return setNetVar("dbError", system.IsWindows() and "Server is missing VC++ redistributables! " or "Server is missing binaries for mysqloo! ") end
        if mysqloo.VERSION ~= "9" or not mysqloo.MINOR_VERSION or tonumber(mysqloo.MINOR_VERSION) < 1 then
            MsgC(Color(255, 0, 0), "You are using an outdated mysqloo version\n")
            MsgC(Color(255, 0, 0), "Download the latest mysqloo9 from here\n")
            MsgC(Color(86, 156, 214), "https://github.com/syl0r/MySQLOO/releases")
            return
        end

        local hostname = lia.db.hostname
        local username = lia.db.username
        local password = lia.db.password
        local database = lia.db.database
        local port = lia.db.port
        mysqloo.connect(hostname, username, password, database, port)
        lia.db.pool = {}
        local poolNum = 6
        local connectedPools = 0
        for i = 1, poolNum do
            lia.db.pool[i] = mysqloo.connect(hostname, username, password, database, port)
            local pool = lia.db.pool[i]
            pool:setAutoReconnect(true)
            pool:connect()
            function pool:onConnectionFailed(fault)
                ThrowConnectionFault(fault)
            end

            function pool:onConnected()
                pool:setCharacterSet("utf8")
                connectedPools = connectedPools + 1
                if connectedPools == poolNum then
                    lia.db.escape = modules.mysqloo.escape
                    lia.db.query = modules.mysqloo.query
                    lia.db.prepare = modules.mysqloo.prepare
                    lia.db.abort = modules.mysqloo.abort
                    lia.db.queue = modules.mysqloo.queue
                    lia.db.getObject = modules.mysqloo.getObject
                    lia.db.preparedCall = modules.mysqloo.preparedCall
                    if callback then callback() end
                    hook.Run("OnMySQLOOConnected")
                end
            end

            timer.Create("liaMySQLWakeUp" .. i, 600 + i, 0, function() pool:query("SELECT 1 + 1") end)
        end

        lia.db.object = lia.db.pool
    end,
    prepare = function(key, str, values)
        lia.db.prepared[key] = {
            query = str,
            values = values,
        }
    end,
    preparedCall = function(key, callback, ...)
        local preparedStatement = lia.db.prepared[key]
        if preparedStatement then
            local _, freeIndex = lia.db.getObject()
            PREPARE_CACHE[key] = PREPARE_CACHE[key] or {}
            PREPARE_CACHE[key][freeIndex] = PREPARE_CACHE[key][freeIndex] or lia.db.getObject():prepare(preparedStatement.query)
            local prepObj = PREPARE_CACHE[key][freeIndex]
            function prepObj:onSuccess(data)
                if callback then callback(data, self:lastInsert()) end
            end

            function prepObj:onError(err)
                ServerLog(err)
            end

            local arguments = {...}
            if table.Count(arguments) == table.Count(preparedStatement.values) then
                local index = 1
                for _, type in pairs(preparedStatement.values) do
                    if type == MYSQLOO_INTEGER then
                        prepObj:setNumber(index, arguments[index])
                    elseif type == MYSQLOO_STRING then
                        prepObj:setString(index, lia.db.convertDataType(arguments[index], true))
                    elseif type == MYSQLOO_BOOL then
                        prepObj:setBoolean(index, arguments[index])
                    end

                    index = index + 1
                end
            end

            prepObj:start()
        else
            MsgC(Color(255, 0, 0), "INVALID PREPARED STATEMENT : " .. key .. "\n")
        end
    end
}

lia.db.escape = lia.db.escape or modules.sqlite.escape
lia.db.query = lia.db.query or function(...) lia.db.queryQueue[#lia.db.queryQueue + 1] = {...} end

--- Establishes a connection to the database using the configured database module.
-- @realm server
-- If a callback function is provided, it will be called upon successful connection.
-- If 'reconnect' is set to true or the database is not currently connected, it attempts to reconnect.
-- @param callback (function) A function to execute upon successful connection. (Optional)
-- @param reconnect (boolean) Whether to force a reconnection even if the database is already connected. (Optional)


function lia.db.connect(callback, reconnect)
    local dbModule = modules[lia.db.module]
    if dbModule then
        if (reconnect or not lia.db.connected) and not lia.db.object then
            dbModule.connect(function()
                lia.db.connected = true
                if isfunction(callback) then callback() end
                for i = 1, #lia.db.queryQueue do
                    lia.db.query(unpack(lia.db.queryQueue[i]))
                end

                lia.db.queryQueue = {}
            end)
        end

        lia.db.escape = dbModule.escape
        lia.db.query = dbModule.query
    else
        ErrorNoHalt("[Lilia] '" .. (lia.db.module or "Unavailable") .. "' is not a valid data storage method! \n")
    end
end

--- Wipes all data from the database tables.
-- @realm server
-- This function is typically used for resetting the database to its initial state.
-- @param callback (function) A function to execute after wiping the tables. (Optional)


function lia.db.wipeTables(callback)
    local function realCallback()
        lia.db.query("SET FOREIGN_KEY_CHECKS = 1;", function()
            MsgC(Color(255, 0, 0), "[Lilia] ALL LILIA DATA HAS BEEN WIPED\n")
            if isfunction(callback) then callback() end
        end)
    end

    if lia.db.object then
        local function startDeleting()
            local queries = string.Explode(";", MySQLTableDrop)
            local done = 0
            for i = 1, #queries do
                queries[i] = string.Trim(queries[i])
                if queries[i] == "" then
                    done = done + 1
                    continue
                end

                lia.db.query(queries[i], function()
                    done = done + 1
                    if done >= #queries then realCallback() end
                end)
            end
        end

        lia.db.query("SET FOREIGN_KEY_CHECKS = 0;", startDeleting)
    else
        lia.db.query(SqlLiteTableDrop, realCallback)
    end
end

--- Loads database tables into memory.
-- @realm server
-- This function is typically used during server startup to ensure that all required tables are available.


function lia.db.loadTables()
    local function done()
        lia.db.tablesLoaded = true
        hook.Run("LiliaTablesLoaded")
    end

    if lia.db.module == "sqlite" then
        lia.db.query(SqlLiteTableCreate, done)
    else
        local queries = string.Explode(";", MySQLTableCreate)
        local i = 1
        local function doNextQuery()
            if i > #queries then return done() end
            local query = string.Trim(queries[i])
            if query == "" then
                i = i + 1
                return doNextQuery()
            end

            lia.db.query(query, function()
                i = i + 1
                doNextQuery()
            end)
        end

        doNextQuery()
    end

    hook.Run("OnLoadTables")
end

--- Waits for database tables to finish loading.
-- @realm server
-- This function is used to ensure that code requiring loaded tables does not execute prematurely.
-- @return (deferred) A deferred object representing the completion of table loading.


function lia.db.waitForTablesToLoad()
    TABLE_WAIT_ID = TABLE_WAIT_ID or 0
    local d = deferred.new()
    if lia.db.tablesLoaded then
        d:resolve()
    else
        hook.Add("LiliaTablesLoaded", tostring(TABLE_WAIT_ID), function() d:resolve() end)
    end

    TABLE_WAIT_ID = TABLE_WAIT_ID + 1
    return d
end

--- Converts a Lua value into a format suitable for database storage.
-- @realm server
-- This function handles different data types and escapes strings as needed.
-- @param value The value to convert.
-- @param noEscape (boolean) Whether to skip escaping for strings. (Optional)
-- @return The converted value.


function lia.db.convertDataType(value, noEscape)
    if isstring(value) then
        if noEscape then
            return value
        else
            return "'" .. lia.db.escape(value) .. "'"
        end
    elseif istable(value) then
        if noEscape then
            return util.TableToJSON(value)
        else
            return "'" .. lia.db.escape(util.TableToJSON(value)) .. "'"
        end
    elseif value == NULL then
        return "NULL"
    end
    return value
end

local function genInsertValues(value, dbTable)
    local query = "lia_" .. (dbTable or "characters") .. " ("
    local keys = {}
    local values = {}
    for k, v in pairs(value) do
        keys[#keys + 1] = k
        values[#keys] = k:find("steamID") and v or lia.db.convertDataType(v)
    end
    return query .. table.concat(keys, ", ") .. ") VALUES (" .. table.concat(values, ", ") .. ")"
end

local function genUpdateList(value)
    local changes = {}
    for k, v in pairs(value) do
        changes[#changes + 1] = k .. " = " .. (k:find("steamID") and v or lia.db.convertDataType(v))
    end
    return table.concat(changes, ", ")
end

--- Inserts data into a database table.
-- @realm server
-- @param value The Lua table containing data to insert.
-- @param callback (function) A function to execute after the insert operation. (Optional)
-- @param dbTable The name of the database table. (Optional)


function lia.db.insertTable(value, callback, dbTable)
    local query = "INSERT INTO " .. genInsertValues(value, dbTable)
    lia.db.query(query, callback)
end

--- Updates data in a database table.
-- @realm server
-- @param value The Lua table containing data to update.
-- @param callback (function) A function to execute after the update operation. (Optional)
-- @param dbTable The name of the database table. (Optional)
-- @param condition The condition to filter the update operation. (Optional)


function lia.db.updateTable(value, callback, dbTable, condition)
    local query = "UPDATE " .. ("lia_" .. (dbTable or "characters")) .. " SET " .. genUpdateList(value) .. (condition and " WHERE " .. condition or "")
    lia.db.query(query, callback)
end

--- Selects data from a database table.
-- @realm server
-- @param fields The fields to select, can be either a string or a table of strings
-- @param dbTable The name of the database table
-- @param condition The condition for the selection query
-- @param limit The limit for the number of results to be returned
-- @return A deferred object that resolves to a table containing the results and last inserted ID

function lia.db.select(fields, dbTable, condition, limit)
    local d = deferred.new()
    local from = istable(fields) and table.concat(fields, ", ") or tostring(fields)
    local tableName = "lia_" .. (dbTable or "characters")
    local query = "SELECT " .. from .. " FROM " .. tableName
    if condition then query = query .. " WHERE " .. tostring(condition) end
    if limit then query = query .. " LIMIT " .. tostring(limit) end
    lia.db.query(query, function(results, lastID)
        d:resolve({
            results = results,
            lastID = lastID
        })
    end)
    return d
end
--- Selects data from a database table.
-- @realm server
-- @param fields The fields to select. Can be a string or a table of field names.
-- @param dbTable The name of the database table. (Optional)
-- @param condition The condition to filter the select operation. (Optional)
-- @param limit The maximum number of rows to select. (Optional)
-- @return (deferred) A deferred object representing the select operation.

function lia.db.upsert(value, dbTable)
    local query
    if lia.db.object then
        query = "INSERT INTO " .. genInsertValues(value, dbTable) .. " ON DUPLICATE KEY UPDATE " .. genUpdateList(value)
    else
        query = "INSERT OR REPLACE INTO " .. genInsertValues(value, dbTable)
    end

    local d = deferred.new()
    lia.db.query(query, function(results, lastID)
        d:resolve({
            results = results,
            lastID = lastID
        })
    end)
    return d
end

--- Inserts or updates data in a database table.
-- @realm server
-- If a record with the same primary key exists, it updates the record. Otherwise, it inserts a new record.
-- @param value The Lua table containing data to insert or update.
-- @param dbTable The name of the database table. (Optional)
-- @return (deferred) A deferred object representing the upsert operation.


function lia.db.delete(dbTable, condition)
    local query
    dbTable = "lia_" .. (dbTable or "character")
    if condition then
        query = "DELETE FROM " .. dbTable .. " WHERE " .. condition
    else
        query = "DELETE * FROM " .. dbTable
    end

    local d = deferred.new()
    lia.db.query(query, function(results, lastID)
        d:resolve({
            results = results,
            lastID = lastID
        })
    end)
    return d
end