MySQL.ready(function ()
    TriggerEvent('deleteAllYP')
end)

ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local callID = nil

--[[ Twitter Stuff ]]
RegisterNetEvent('GetTweets')
AddEventHandler('GetTweets', function(onePlayer)
    local source = source
    -- MySQL.Async.fetchAll('SELECT * FROM tweets', {}, function(tweets)
    MySQL.Async.fetchAll('SELECT * FROM (SELECT * FROM tweets ORDER BY `time` DESC LIMIT 50) sub ORDER BY time ASC', {}, function(tweets) -- Get most recent 100 tweets
        if onePlayer then
            TriggerClientEvent('Client:UpdateTweets', source, tweets)
        else
            TriggerClientEvent('Client:UpdateTweets', source, tweets)
        end
    end)
end)

RegisterNetEvent('Tweet')
AddEventHandler('Tweet', function(handle, data, time)
    local handle = handle
    local src = source

    MySQL.Async.execute('INSERT INTO tweets (handle, message, time) VALUES (@handle, @message, @time)', {
        ['@handle'] = handle,
        ['@message'] = data,
        ['@time'] = time
    }, function(result)
        TriggerClientEvent('Client:UpdateTweet', -1, data, handle)
        TriggerEvent('GetTweets', true, src)
    end)
end)

RegisterNetEvent('Server:GetHandle')
AddEventHandler('Server:GetHandle', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = xPlayer.identifier
    local name = getIdentity(src)	
    fal = "@" .. name.firstname .. "_" .. name.lastname
    local handle = fal
    TriggerClientEvent('givemethehandle', src, handle)
end)

function getIdentity(target)
	local identifier = GetPlayerIdentifiers(target)[1]
	local result = MySQL.Sync.fetchAll("SELECT * FROM users WHERE identifier = @identifier", {['@identifier'] = identifier})
	if result[1] ~= nil then
		local identity = result[1]

		return {
			firstname = identity['firstname'],
			lastname = identity['lastname'],
		}
	else
		return nil
	end
end

--[[ Contacts stuff ]]

RegisterNetEvent('phone:addContact')
AddEventHandler('phone:addContact', function(name, number)
    local xPlayer = ESX.GetPlayerFromId(source)
    local handle = handle
    local src = source

    MySQL.Async.execute('INSERT INTO phone_contacts (identifier, name, number) VALUES (@identifier, @name, @number)', {
        ['@identifier'] = xPlayer.getIdentifier(),
        ['@name'] = name,
        ['@number'] = number
    }, function(result)
        TriggerEvent('getContacts', true, src)
        TriggerClientEvent('refreshContacts', src)
    end)
end)

RegisterNetEvent('getContacts')
AddEventHandler('getContacts', function(cursource)
    local src = source
	if src == nil then
		src = cursource
	end
	
    local xPlayer = ESX.GetPlayerFromId(src)
	if xPlayer then
		MySQL.Async.fetchAll('SELECT * FROM phone_contacts WHERE identifier = @identifier', { ['@identifier'] = xPlayer.identifier }, function(contacts)
			TriggerClientEvent('phone:loadContacts', src, contacts)
		end)
		
		MySQL.Async.fetchAll('SELECT * FROM conx_gangs_members WHERE identifier = @identifier', { ['@identifier'] = xPlayer.identifier }, function(result)
			if result[1] ~= nil then
				local data = { gang = result[1].gangName, gang_pos = result[1].gangPosition }
				TriggerClientEvent('conx_gangs:SetGang', xPlayer.source, data)
			else
				local data = { gang = nil, gang_pos = nil }
				TriggerClientEvent('conx_gangs:SetGang', xPlayer.source, data)
			end
		end)
	end
end)

RegisterNetEvent('deleteContact')
AddEventHandler('deleteContact', function(name, number)
    local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
    MySQL.Async.execute('DELETE FROM phone_contacts WHERE identifier = @identifier AND name = @name AND number = @number LIMIT 1', {
        ['@identifier'] = xPlayer.getIdentifier(),
        ['@name'] = name,
        ['@number'] = number
    }, function (result)
        TriggerClientEvent('refreshContacts', src)
        TriggerEvent('getContacts', true, src)
    end)
end)

--[[ Phone calling stuff ]]

function getNumberPhone(identifier)
    local result = MySQL.Sync.fetchAll("SELECT users.phone_number FROM users WHERE users.identifier = @identifier", {
        ['@identifier'] = identifier
    })
    if result[1] ~= nil then
        return result[1].phone_number
    end
    return nil
end
function getIdentifierByPhoneNumber(phone_number) 
    local result = MySQL.Sync.fetchAll("SELECT users.identifier FROM users WHERE users.phone_number = @phone_number", {
        ['@phone_number'] = phone_number
    })
    if result[1] ~= nil then
        return result[1].identifier
    end
    return nil
end

RegisterNetEvent('phone:callContact')
AddEventHandler('phone:callContact', function(targetnumber, toggle)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local targetIdentifier = getIdentifierByPhoneNumber(targetnumber)
	local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
    local xPlayers = ESX.GetPlayers()
    local srcIdentifier = xPlayer.getIdentifier()
    local srcPhone = getNumberPhone(srcIdentifier)

	TriggerClientEvent('phone:initiateCall', src, src)

	local found = false
	for i=1, #xPlayers, 1 do
		local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
		if xPlayer.identifier == targetIdentifier then
			found = true
			break
		end
	end
	
	if found then
		TriggerClientEvent('phone:receiveCall', xTarget.source, targetnumber, src, srcPhone)
	else
		TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'error', text = 'Phone number is not available.', length = 7000})
	end
end)

RegisterNetEvent('phone:getSMS')
AddEventHandler('phone:getSMS', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local mynumber = getNumberPhone(xPlayer.identifier)
    
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_messages WHERE receiver = @mynumber OR sender = @mynumber ORDER BY id DESC", {['@mynumber'] = mynumber})

    local numbers ={}
    local convos = {}
    local valid
    
    for k, v in pairs(result) do
        valid = true
        if v.sender == mynumber then
            for i=1, #numbers, 1 do
                if v.receiver == numbers[i] then
                    valid = false
                end
            end
            if valid then
                table.insert(numbers, v.receiver)
            end
        elseif v.receiver == mynumber then
            for i=1, #numbers, 1 do
                if v.sender == numbers[i] then
                    valid = false
                end
            end
            if valid then
                table.insert(numbers, v.sender)
            end
        end
    end
    
    for i, j in pairs(numbers) do
        for g, f in pairs(result) do
            if j == f.sender or j == f.receiver then
                table.insert(convos, {
                    id = f.id,
                    sender = f.sender,
                    receiver = f.receiver,
                    message = f.message,
                    date = f.date
                })
                break
            end
        end
    end
    
    local data = ReverseTable(convos)
    TriggerClientEvent('phone:loadSMS', src, data, mynumber)
end)

function ReverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

RegisterNetEvent('phone:sendSMS')
AddEventHandler('phone:sendSMS', function(receiver, message)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local mynumber = getNumberPhone(xPlayer.identifier)
    
    local target = getIdentifierByPhoneNumber(receiver)
    
    local xPlayers = ESX.GetPlayers()
    --if receiver ~= mynumber then
    MySQL.Async.execute('INSERT INTO phone_messages (sender, receiver, message) VALUES (@sender, @receiver, @message)', {
        ['@sender'] = mynumber,
        ['@receiver'] = receiver,
        ['@message'] = message
    }, function(result)
    end)
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer then
            if xPlayer.identifier == target then
                local receiverID = xPlayer.source
                TriggerClientEvent('phone:newSMS', receiverID, 1, mynumber)
                --TriggerClientEvent('refreshSMS', receiverID)
            end
        end
    end
    --else
    -- Mythic notify the source that they cannot text themselves
    --end
end)

RegisterNetEvent('phone:serverGetMessagesBetweenParties')
AddEventHandler('phone:serverGetMessagesBetweenParties', function(sender, receiver, displayName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local mynumber = getNumberPhone(xPlayer.identifier)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_messages WHERE (sender = @sender AND receiver = @receiver) OR (sender = @receiver AND receiver = @sender) ORDER BY id ASC", {['@sender'] = sender, ['@receiver'] = receiver})

    TriggerClientEvent('phone:clientGetMessagesBetweenParties', src, result, displayName, mynumber)
end)

RegisterNetEvent('phone:StartCallConfirmed')
AddEventHandler('phone:StartCallConfirmed', function(mySourceID)
    local channel = math.random(10000, 99999)
    local src = source

    TriggerClientEvent('phone:callFullyInitiated', mySourceID, mySourceID, src)
    TriggerClientEvent('phone:callFullyInitiated', src, src, mySourceID)

    -- After add them to the same channel or do it from server.
    TriggerClientEvent('phone:addToCall', source, channel)
    TriggerClientEvent('phone:addToCall', mySourceID, channel)

    TriggerClientEvent('phone:id', src, channel)
    TriggerClientEvent('phone:id', mySourceID, channel)
end)

RegisterNetEvent('phone:EndCall')
AddEventHandler('phone:EndCall', function(mySourceID, stupidcallnumberidk, somethingextra)
    local src = source
    TriggerClientEvent('phone:removefromToko', src, stupidcallnumberidk)

    if mySourceID ~= 0 or mySourceID ~= nil then
        TriggerClientEvent('phone:removefromToko', mySourceID, stupidcallnumberidk)
        TriggerClientEvent('phone:otherClientEndCall', mySourceID)
    end

    if somethingextra then
        TriggerClientEvent('phone:otherClientEndCall', src)
    end
end)

RegisterCommand("ans", function(source, args, rawCommand)
    local src = source
    TriggerClientEvent('phone:answercall', src)
end, false)

RegisterCommand("h", function(source, args, rawCommand)
    local src = source
    TriggerClientEvent('phone:endCalloncommand', src)
end, false)
--[[
RegisterCommand("lawyer", function(source, args, rawCommand)
    local src = source
    TriggerClientEvent('yellowPages:retrieveLawyersOnline', src, true)
end, false)

RegisterCommand("ph", function(source, args, rawCommand)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = xPlayer.getIdentifier()
    local srcPhone = getNumberPhone(identifier)


    TriggerClientEvent('sendMessagePhoneN', src, srcPhone)
end, false)

RegisterCommand("test", function(source, args, rawCommand)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
	
end, false)]]

RegisterNetEvent('phone:sendMailToNonWhitelist')
AddEventHandler('phone:sendMailToNonWhitelist', function(subject, message)
	local xPlayers = ESX.GetPlayers()
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer.job.name ~= 'police' and xPlayer.job.name ~= 'ambulance' and xPlayer.job.name ~= 'lawyer' and xPlayer.job.name ~= 'mayor' and xPlayer.job.name ~= 'judge' and xPlayer.job.name ~= 'mechanic' then
			TriggerClientEvent('phone:addnotification', xPlayer.source, subject, message)
		end
    end
end)


function getPlayerID(source)
    local identifiers = GetPlayerIdentifiers(source)
    local player = getIdentifiant(identifiers)
    return player
end
function getIdentifiant(id)
    for _, v in ipairs(id) do
        return v
    end
end

AddEventHandler('es:playerLoaded',function(source)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(source)
    getOrGeneratePhoneNumber(sourcePlayer, identifier, function (myPhoneNumber)
        --[[TriggerClientEvent("gcPhone:myPhoneNumber", sourcePlayer, myPhoneNumber)
        TriggerClientEvent("gcPhone:contactList", sourcePlayer, getContacts(identifier))
        TriggerClientEvent("gcPhone:allMessage", sourcePlayer, getMessages(identifier))]]
    end)
end)

function getOrGeneratePhoneNumber (sourcePlayer, identifier, cb)
    local sourcePlayer = sourcePlayer
    local identifier = identifier
    local myPhoneNumber = getNumberPhone(identifier)
    if myPhoneNumber == '0' or myPhoneNumber == nil then
        repeat
            myPhoneNumber = getPhoneRandomNumber()
            local id = getIdentifierByPhoneNumber(myPhoneNumber)
        until id == nil
        MySQL.Async.insert("UPDATE users SET phone_number = @myPhoneNumber WHERE identifier = @identifier", {
            ['@myPhoneNumber'] = myPhoneNumber,
            ['@identifier'] = identifier
        }, function ()
            cb(myPhoneNumber)
        end)
    else
        cb(myPhoneNumber)
    end
end

function getPhoneRandomNumber()
    local numBase0 = 4
    local numBase1 = math.random(10,99)
    local numBase2 = math.random(100,999)
    local numBase3 = math.random(1000,9999)
    local num = string.format(numBase0 .. "" .. numBase1 .. "" .. numBase2 .. "" .. numBase3)
    return num
end

RegisterNetEvent('phone:UseSimCard')
AddEventHandler('phone:UseSimCard', function()
	local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
	local myPhoneNumber = getNumberPhone(xPlayer.identifier)
	
	if myPhoneNumber ~= nil then
		repeat
			myPhoneNumber = getPhoneRandomNumber()
            local id = getIdentifierByPhoneNumber(myPhoneNumber)
        until id == nil
		
		MySQL.Async.insert("UPDATE users SET phone_number = @myPhoneNumber WHERE identifier = @identifier", {
            ['@myPhoneNumber'] = myPhoneNumber,
            ['@identifier'] = xPlayer.identifier
        }, function ()
			TriggerClientEvent("inventory:removeItem", xPlayer.source, 'simcard', 1)
			TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = 'You\'ve changed your phone number to '..myPhoneNumber..'', length = 7000})
        end)
	end
end)

RegisterNetEvent('message:inDistanceZone')
AddEventHandler('message:inDistanceZone', function(somethingsomething, messagehueifh)
    local src = source		
    local first = messagehueifh:sub(1, 3)
    local second = messagehueifh:sub(4, 6)
    local third = messagehueifh:sub(7, 11)

    local msg = first .. "-" .. second .. "-" .. third
	TriggerClientEvent('chat:addMessage', somethingsomething, {
		template = '<div style = "display: inline-block !important;padding: 0.6vw;padding-top: 0.6vw;padding-bottom: 0.7vw;margin: 0.1vw;margin-left: 0.4vw;border-radius: 10px;background-color: #be6112d9;width: fit-content;max-width: 100%;overflow: hidden;word-break: break-word;"><b>Phone</b>: #{1}</div>',
		args = { fal, msg }
	})
end)

RegisterNetEvent('message:tome')
AddEventHandler('message:tome', function(messagehueifh)
    local src = source		
    local first = messagehueifh:sub(1, 3)
    local second = messagehueifh:sub(4, 6)
    local third = messagehueifh:sub(7, 11)

    local msg = first .. "-" .. second .. "-" .. third
	TriggerClientEvent('chat:addMessage', src, {
		template = '<div style = "display: inline-block !important;padding: 0.6vw;padding-top: 0.6vw;padding-bottom: 0.7vw;margin: 0.1vw;margin-left: 0.4vw;border-radius: 10px;background-color: #be6112d9;width: fit-content;max-width: 100%;overflow: hidden;word-break: break-word;"><b>Phone</b>: #{1}</div>',
		args = { fal, msg }
	})
end)


RegisterNetEvent('phone:getServerTime')
AddEventHandler('phone:getServerTime', function()
    local hours, minutes, seconds = Citizen.InvokeNative(0x50C7A99057A69748, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
    TriggerClientEvent('timeheader', -1, hours, minutes)
end)

function getIdentity(target)
	local identifier = GetPlayerIdentifiers(target)[1]
	local result = MySQL.Sync.fetchAll("SELECT * FROM users WHERE identifier = @identifier", {['@identifier'] = identifier})
	if result[1] ~= nil then
		local identity = result[1]

		return {
			firstname = identity['firstname'],
			lastname = identity['lastname'],
		}
	else
		return nil
	end
end

--[[ Others ]]

RegisterNetEvent('getAccountInfo')
AddEventHandler('getAccountInfo', function()
    local src = source
    local player = ESX.GetPlayerFromId(source)

    local money = player.getMoney()
    local inbank = player.getBank()
    local licenceTable = {}

    TriggerEvent('esx_license:getLicenses', source, function(licenses)
        licenceTable = licenses
    end)

    Citizen.Wait(100)

    -- print(licenceTable)
    
    TriggerClientEvent('getAccountInfo', src, money, inbank, licenceTable)
end)


--[[ Yellow Pages ]]

RegisterNetEvent('getYP')
AddEventHandler('getYP', function()
    local source = source
    MySQL.Async.fetchAll('SELECT * FROM phone_yp LIMIT 30', {}, function(yp)
        local deorencoded = json.encode(yp)
        TriggerClientEvent('YellowPageArray', source, yp)
    end)
end)

RegisterNetEvent('phone:updatePhoneJob')
AddEventHandler('phone:updatePhoneJob', function(advert)
    --local handle = handle
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local mynumber = getNumberPhone(xPlayer.identifier)
    local name = getIdentity(src)

    fal = name.firstname .. " " .. name.lastname

    MySQL.Async.execute('INSERT INTO phone_yp (name, advert, phoneNumber) VALUES (@name, @advert, @phoneNumber)', {
        ['@name'] = fal,
        ['@advert'] = advert,
        ['@phoneNumber'] = mynumber
    }, function(result)
        TriggerClientEvent('refreshYP', src)
    end)
end)

RegisterNetEvent('phone:foundLawyer')
AddEventHandler('phone:foundLawyer', function(name, phoneNumber)
    TriggerClientEvent('chat:addMessage', -1, {
        template = '<div style = "display: inline-block !important;padding: 0.6vw;padding-top: 0.6vw;padding-bottom: 0.7vw;margin: 0.1vw;margin-left: 0.4vw;border-radius: 10px;background-color: #1e2dff9c;width: fit-content;max-width: 100%;overflow: hidden;word-break: break-word;"><b>YP</b>: ⚖️ {0} ☎️ {1}</div>',
        args = { name, phoneNumber }
    })
end)

RegisterNetEvent('phone:foundLawyerC')
AddEventHandler('phone:foundLawyerC', function(name, phoneNumber)
    local src = source
    TriggerClientEvent('chat:addMessage', src, {
        template = '<div style = "display: inline-block !important;padding: 0.6vw;padding-top: 0.6vw;padding-bottom: 0.7vw;margin: 0.1vw;margin-left: 0.4vw;border-radius: 10px;background-color: #1e2dff9c;width: fit-content;max-width: 100%;overflow: hidden;word-break: break-word;"><b>YP</b>: ⚖️ {0} ☎️ {1}</div>',
        args = { name, phoneNumber }
    })
end)

RegisterNetEvent('deleteAllYP')
AddEventHandler('deleteAllYP', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local src = source
    MySQL.Async.execute('DELETE FROM phone_yp', {}, function (result) end)
end)

RegisterServerEvent('tp:checkPhoneCount')
AddEventHandler('tp:checkPhoneCount', function()
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	if xPlayer.getInventoryItem('phone').count >= 1 then
		TriggerClientEvent('tp:heHasPhone', _source)
	else 
		TriggerClientEvent('mythic_notify:client:SendAlert', source, { type = 'error', text = 'You dont have a phone, Buy one at your local store', length = 7000})
	end
end)

RegisterCommand("payphone", function(source, args, raw)
    local src = source
    local pnumber = args[1]
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.get('money') >= 25 then
        TriggerClientEvent('phone:makepayphonecall', src, pnumber)
        xPlayer.removeMoney(25)
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', source, { type = 'error', text = 'You dont have $25 for the payphone', length = 7000})
    end
end, false)

RegisterNetEvent("phone:getVehicles")
AddEventHandler("phone:getVehicles", function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = xPlayer.identifier
    
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @identifier AND job = @job', { ['@identifier'] = identifier, ['@job'] = 'civ' }, function(vehicles)
        TriggerClientEvent('phone:Garage', src, vehicles)
    end)
end)

RegisterServerEvent('phone:pingContact')
AddEventHandler('phone:pingContact', function(name , number , coords)
    local src = source
    local awesome = ESX.GetPlayerFromId(src)
    local targetIdentifier = getIdentifierByPhoneNumber(number)
    local xPlayers = ESX.GetPlayers()
    local mynumber = getNumberPhone(awesome.identifier)
    for i=1, #xPlayers, 1 do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer then
            if xPlayer.identifier == targetIdentifier then
                local receiverID = xPlayer.source
                TriggerClientEvent('phone:sendPing' , receiverID , coords , name , mynumber)
                TriggerClientEvent('mythic_notify:client:SendAlert', receiverID, { type = 'inform', text = 'You have recive a ping from ' ..mynumber })
            end
        end
    end

end)

RegisterNetEvent('phone:PromoteEmployee')
AddEventHandler('phone:PromoteEmployee', function(identifier, name, job, grade)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.job.grade_name == 'boss'
	
	if isBoss then
		local xTarget = ESX.GetPlayerFromIdentifier(identifier)
		if xTarget then
			local currentJobGrade = xTarget.job.grade
			xTarget.setJob(job, currentJobGrade + 1)
			TriggerClientEvent('mythic_notify:client:SendAlert', xTarget.source, { type = 'success', text = 'You\'ve been promoted from '..grade..'.', length = 7000})
			TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'success', text = 'You\'ve promoted '..name..' from '..grade..'', length = 7000})
		else
			MySQL.Async.execute('UPDATE users SET job = @job, job_grade = job_grade + @job_grade WHERE identifier = @identifier', {
				['@job']        = job,
				['@job_grade']  = 1,
				['@identifier'] = identifier
			}, function(rowsChanged)
				TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'success', text = 'You\'ve promoted '..name..'', length = 7000})
			end)
		end
	end
end)

RegisterNetEvent('phone:FireEmployee')
AddEventHandler('phone:FireEmployee', function(identifier, name, job, grade)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.job.grade_name == 'boss'
	
	if isBoss then
		local xTarget = ESX.GetPlayerFromIdentifier(identifier)
		if xTarget then
			xTarget.setJob('unemployed', 0)
			TriggerClientEvent('mythic_notify:client:SendAlert', xTarget.source, { type = 'success', text = 'You\'ve been fired', length = 7000})
			TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'success', text = 'You fired '..name..'', length = 7000})
		else
			MySQL.Async.execute('UPDATE users SET job = @job, job_grade = job_grade + @job_grade WHERE identifier = @identifier', {
				['@job']        = 'unemployed',
				['@job_grade']  = 0,
				['@identifier'] = identifier
			}, function(rowsChanged)
				TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'success', text = 'You fired '..name..'.', length = 7000})
			end)
		end
	end
end)

RegisterNetEvent('phone:RecruitEmployee')
AddEventHandler('phone:RecruitEmployee', function(target, newJob)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.job.grade_name == 'boss'
	
	if isBoss then
		local xTarget = ESX.GetPlayerFromId(target)
		if xTarget ~= nil then
			xTarget.setJob(newJob, 0)
			TriggerClientEvent('mythic_notify:client:SendAlert', xTarget.source, { type = 'success', text = 'You\'ve been hired.', length = 7000})
		else
			TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'error', text = 'Target not found.', length = 7000})
		end
	end
end)

---------------- BOOMBACKS

local ServerBoombacks = {}

RegisterNetEvent('phone:PlaceBoombox')
AddEventHandler('phone:PlaceBoombox', function(deviceId)
	ServerBoombacks[deviceId] = {
		ytlink = nil,
		playing = false,
		volume = 20,
		connected = nil
	}
	TriggerClientEvent('phone:UpdateBoomboxList', -1, ServerBoombacks)
end)

RegisterNetEvent('phone:PairDevice')
AddEventHandler('phone:PairDevice', function(deviceId, ytLink, volume)
	local xPlayer = ESX.GetPlayerFromId(source)
	TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = 'You have successfully paired your phone to Bluetooth ID: '..deviceId..'', length = 7000})
	ServerBoombacks[deviceId] = {
		ytlink = ytLink,
		playing = false,
		volume = volume,
		connected = xPlayer.source
	}
	TriggerClientEvent('phone:UpdateBoomboxList', -1, ServerBoombacks)
end)

RegisterNetEvent('phone:UnpairDevice')
AddEventHandler('phone:UnpairDevice', function(deviceId)
	local xPlayer = ESX.GetPlayerFromId(source)
	ServerBoombacks[deviceId] = {
		ytlink = nil,
		playing = false,
		volume = 20,
		connected = nil
	}
	TriggerClientEvent('phone:UpdateBoomboxList', -1, ServerBoombacks)
end)

RegisterNetEvent('phone:PickupBoombox')
AddEventHandler('phone:PickupBoombox', function(deviceId, giveItem)
	local xPlayer = ESX.GetPlayerFromId(source)
	
	if ServerBoombacks[deviceId] == nil then
		TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = 'Nice try homie!', length = 7000})
		return
	end
	
	ServerBoombacks[deviceId] = nil
	TriggerClientEvent('phone:DeleteBoombox', -1, deviceId)
	
	if giveItem then
		TriggerClientEvent('player:receiveItem', xPlayer.source, 'boombox', 1, false)
	end
end)

-------------- GANG

ESX.RegisterServerCallback('phone:getGangInfo', function(source, cb, gangName)
	local conx = source
	local xPlayer = ESX.GetPlayerFromId(conx)
	MySQL.Async.fetchAll('SELECT * FROM conx_gangs WHERE gangName = @gangName', { ['@gangName'] = gangName }, function(result)
		if result[1] ~= nil then
			cb(result[1].gangFunds, result[1].gangResources, result[1].gangWeapons)
		end
	end)
end)

RegisterNetEvent('phone:RejectClientOffer')
AddEventHandler('phone:RejectClientOffer', function()
	local conx = source
	local xPlayer = ESX.GetPlayerFromId(conx)
	
	TriggerClientEvent('conx_crafting:rejectClientOffer', xPlayer.source)
	
	
end)



































