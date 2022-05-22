local guiEnabled = false
local hasOpened = false
local lstMsgs = {}
local lstContacts = {}
local inPhone = false
local radioChannel = math.random(1,999)
local usedFingers = false
local dead = false
local onhold = false
local YellowPageArray = {}
local YellowPages = {}
local PhoneBooth = GetEntityCoords(PlayerPedId())
local AnonCall = false
local phoneNotifications = true
local insideDelivers = false
local curhrs = 9
local curmins = 2
local allowpopups = true
local vehicles = {}
local isDead = false
local isNotInCall, isDialing, isReceivingCall, isCallInProgress = 0, 1, 2, 3
local callStatus = isNotInCall

ESX = nil

Citizen.CreateThread(function()
  	while ESX == nil do
    	TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    	Citizen.Wait(250)
  	end

  	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(250)
	end
	
  ESX.PlayerData = ESX.GetPlayerData()
  
  TriggerServerEvent('Server:GetHandle')
  TriggerServerEvent('getYP')
  Citizen.Wait(200)
  --TriggerEvent("YPUpdatePhone")
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
	Citizen.Wait(5000)
end)

local gang_data = {}

RegisterNetEvent('conx_gangs:SetGang')
AddEventHandler('conx_gangs:SetGang', function(data)
	gang_data = data
end)

RegisterNUICallback('btnNotifyToggle', function(data, cb)
    allowpopups = not allowpopups
    if allowpopups then
		exports['mythic_notify']:DoLongHudText('success', 'Popups Enabled')
    else
		exports['mythic_notify']:DoLongHudText('error', 'Popups Disabled')
    end
end)

activeNumbersClient = {}

RegisterNetEvent('phone:reset')
AddEventHandler('phone:reset', function(cidsent)
  if guiEnabled then
    closeGui2()
  end
  guiEnabled = false
  hasOpened = false
  lstMsgs = {}
  lstContacts = {}
  vehicles = {}
  radioChannel = math.random(1,999)
  dead = false
  onhold = false
  inPhone = false
end)

local vpnConnected = false

RegisterNetEvent('Yougotpaid')
AddEventHandler('Yougotpaid', function(cidsent)
    --local cid = exports["isPed"]:isPed("cid")
    if tonumber(cid) == tonumber(cidsent) then
        TriggerEvent("DoLongHudText","Life Invader Payslip Generated.")
    end
end)
           
RegisterNetEvent('Payment:Successful')
AddEventHandler('Payment:Successful', function()
    SendNUIMessage({
        openSection = "error",
        textmessage = "Payment Processed.",
    })     
end)

RegisterNetEvent('warrants:AddInfo')
AddEventHandler('warrants:AddInfo', function(name, charges)

    openGuiNow()

    SendNUIMessage({
      openSection = "enableoutstanding",
    })
    for i = 1, #charges do

      SendNUIMessage({
        openSection = "inputoutstanding",
        textmessage = charges[i],
      })
    end
    
end)

RegisterNetEvent("phone:activeNumbers")
AddEventHandler("phone:activeNumbers", function(activePhoneNumbers)
  activeNumbersClient = activePhoneNumbers
  hasOpened = false
end)


RegisterNetEvent("gangTasks:updateClients")
AddEventHandler("gangTasks:updateClients", function(newTasks)
  activeTasks = newTasks
end)

TaskState = {
  [1] = "Ready For Pickup",
  [2] = "In Process",
  [3] = "Successful",
  [4] = "Failed",
  [5] = "Delivered with Damaged Goods",
}

TaskTitle = {
  [1] = "Ordering 'Take-Out'",
  [2] = "Ordering 'Disposal Service'",
  [3] = "Ordering 'Postal Delivery'",
  [4] = "Ordering 'Hot Food Room Service'",
}

function findTaskIdFromBlockChain(blockchain)
  local retnum = 1
  for i = 1, #activeTasks do
    if activeTasks[i]["BlockChain"] == blockchain then
      retnum = i
    end
  end
  return retnum
end

-- real estate nui app responses

function loading()
    SendNUIMessage({
        openSection = "error",
        textmessage = "Loading, please wait.",
    })  
end
local ownedkeys = {}
local sharedkeys = {}

RegisterNetEvent("phone:setServerTime")
AddEventHandler("phone:setServerTime", function(time)
  SendNUIMessage({
    openSection = "server-time",
    serverTime = time
  })
end)

RegisterNetEvent("timeheader")
AddEventHandler("timeheader", function(hrs,mins)

  curhrs = hrs
  curmins = mins

  local timesent = curhrs .. ":" .. curmins
  if guiEnabled then
    SendNUIMessage({
      openSection = "timeheader",
      timestamp = timesent,
    })   
  end
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(250)
    if guiEnabled then
      CalculateTimeToDisplay()
    end
  end
end)

function CalculateTimeToDisplay()
  hour = GetClockHours()
  minute = GetClockMinutes()

  local obj = {}

  if hour <= 12 then
      obj.ampm = 'AM'
  elseif hour >= 13 then
      obj.ampm = 'PM'
      hour = hour - 12
  end

  if minute <= 9 then
      minute = "0" .. minute
  end

  obj.hour = hour
  obj.minute = minute

  TriggerEvent('timeheader', hour, minute)

  return obj
end
RegisterNUICallback('btnGiveKey', function(data, cb)
  print("Hennesy")
  TriggerEvent("houses:GiveKey")
end)
RegisterNetEvent("returnPlayerKeys")
AddEventHandler("returnPlayerKeys", function(ownedkeys,sharedkeys)

  
      if not guiEnabled then
        return
      end

      SendNUIMessage({
        openSection = "keys",
        keys = {
          sharedKeys = sharedkeys,
          ownedKeys = ownedkeys
        }
      })
end)

function CellFrontCamActivate(activate)
	return Citizen.InvokeNative(0x2491A93618B7D838, activate)
end

local selfieMode = false
RegisterNUICallback('phone:selfie', function()
  selfieMode = not selfieMode
  if selfieMode then
    closeGui()
    DestroyMobilePhone()
    CreateMobilePhone(4)
    CellCamActivate(true, true)
    CellFrontCamActivate(true)
  else
    closeGui()
    CellCamActivate(false, false)
    CellFrontCamActivate(false)
    DestroyMobilePhone()
    selfieMode = false
  end
end)

RegisterNUICallback('trackTaskLocation', function(data, cb)
    local taskID = findTaskIdFromBlockChain(data.TaskIdentifier)
    TriggerEvent("DoLongHudText","Location Set",15)

    SetNewWaypoint(activeTasks[taskID]["Location"]["x"],activeTasks[taskID]["Location"]["y"])
end)

function GroupName(groupid)
  local name = "Error Retrieving Name"
  --local mypasses = exports["isPed"]:isPed("passes")
  for i=1, #mypasses do
    if mypasses[i]["pass_type"] == groupid then
      name = mypasses[i]["business_name"]
    end 
  end
  return name
end

function GroupRank(groupid)
  local rank = 0
  --local mypasses = exports["isPed"]:isPed("passes")
  for i=1, #mypasses do
    if mypasses[i]["pass_type"] == groupid then
      rank = mypasses[i]["rank"]
    end 
  end
  return rank
end

RegisterNUICallback('bankGroup', function(data)
    local gangid = data.gangid
    local cashamount = data.cashamount
    TriggerServerEvent("server:gankGroup", gangid,cashamount)
end)

RegisterNUICallback('payGroup', function(data)
    local gangid = data.gangid
    local cid = data.cid
    local cashamount = data.cashamount
    TriggerServerEvent("server:givepayGroup", gangid,cashamount,cid)
end)

RegisterNUICallback('promoteGroup', function(data)
    local gangid = data.gangid
    local cid = data.cid
    local newrank = data.newrank
    SendNUIMessage({
        openSection = "error",
        textmessage = "Loading, please wait.",
    })
    TriggerServerEvent("server:givepass", gangid,newrank,cid)
end)


RegisterNUICallback('callNumber', function(data)
    closeGui()
    local number = data.callnum
    local callTo = getContactName(number)
    TriggerServerEvent("phone:callContact",number,true)
    recentcalls[#recentcalls + 1] = { ["type"] = 2, ["number"] = number, ["name"] = callTo }
end)

RegisterNUICallback('manageGroup', function(data)

    TriggerServerEvent('duty:onoff')
    closeGui()
end)

RegisterNUICallback('911distress', function(data)
	closeGui()
	TriggerEvent('esx_outlawalert:911Alerts', data.job, '10-78', 'Need Assistance')

	exports['mythic_notify']:DoCustomHudText ('inform', 'You have sent a distress.', 5000)  
	PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
end)

RegisterNUICallback('btn911', function()
  local coords = GetEntityCoords(PlayerPedId())
  local loler = {
    x = coords.x,
    y = coords.y,
    z = coords.z
  }
  SendNUIMessage({
    openSection = "emergencyCall",
    coords = loler
  })
end)

RegisterNUICallback('btnBilling', function()

  ESX.TriggerServerCallback('esx_billing:getBills', function(bills)
    ESX.UI.Menu.CloseAll()
    local billings = {}

    for i=1, #bills, 1 do
      table.insert(billings, {
        label  = bills[i].label,
        billAmount = ESX.Math.GroupDigits(bills[i].amount),
        billID = bills[i].id
      })
    end

    SendNUIMessage({
      openSection = "invoices",
      billings = billings
    })    

  end)

end)

RegisterNUICallback('payInvoice', function(data)

    ESX.TriggerServerCallback('esx_billing:payBill', function()
      closeGui()
    end, data.billID)

end)

RegisterNetEvent("phone:error")
AddEventHandler("phone:error", function()
      SendNUIMessage({
        openSection = "error",
        textmessage = "<b>Network Error</b> <br><br> Please contact support if this error persists, thank you for using TPRP Phone Services.",
      })   
end)



RegisterNetEvent("group:fullList")
AddEventHandler("group:fullList", function(result,bank,groupid)

    -- group-manage
    local groupname = GroupName(groupid)
    SendNUIMessage({
      openSection = "groupManage",
      groupData = {
        groupName = groupname,
        bank = bank,
        groupId = groupid,
        employees = result
      }
    })

end)

-- associate is a legal worker
-- manager is a legal management worker, can pay / hire / remove below.
-- Partner is associated with "other" business activities and can not alter legal workers.
-- Part-Time Manager is associated with "other" business activites but can also manage legal workers, can pay / hire / remove below.
-- CEO runs that shit dawg, can pay / hire / remove below.


local recentcalls = {}

RegisterNUICallback('getCallHistory', function()
  SendNUIMessage({
    openSection = "callHistory",
    callHistory = recentcalls
  })
end)



--[[
RegisterNUICallback('btnTaskGroups', function()
    local jobgrade = ESX.PlayerData.job.grade
    local rankConverted = ESX.PlayerData.job.grade_label


    local groupObject = {}

    table.insert(groupObject, {
        namesent = ESX.PlayerData.job.label,
        ranksent = rankConverted,
        idsent = 1
    })

    SendNUIMessage({
      openSection = "groups",
      groups = groupObject
    })
end)
]]

RegisterNUICallback('btnTaskGroups', function()
    local jobgrade = ESX.PlayerData.job.grade
    local rankConverted = ESX.PlayerData.job.grade_label
    local rankname = ESX.PlayerData.job.grade_name

    local groupObject = {
        namesent = ESX.PlayerData.job.label,
        ranksent = rankConverted,
        rankname = rankname,
        society = ESX.PlayerData.job.name,
        idsent = 1,
        gang = gang_data.gang,
        gang_position = gang_data.gang_pos
    }

    SendNUIMessage({
      openSection = "groups",
      groups = groupObject
    })
end)

RegisterNUICallback('bossMngEmployee', function(data)
  ESX.TriggerServerCallback('esx_society:getEmployees', function(employees)
    SendNUIMessage({
      openSection = "employeeList",
      employees = employees
    })    
  end, data.society) 
end)

RegisterNUICallback('gangInfo', function(data)
  ESX.TriggerServerCallback('phone:getGangInfo', function(gang_funds, gang_itemstock, gang_weaponstock)
    local gangInfo = {
      gang_funds = ESX.Math.GroupDigits(gang_funds),
      gang_itemstock = gang_itemstock,
      gang_weaponstock = gang_weaponstock,
      gang_name = data.gang,
      gang_position = data.position     
    }

    SendNUIMessage({
      openSection = "gangInfo",
      info = gangInfo
    })  

  end, data.gang) 
end)

RegisterNUICallback('gangMngMembers', function(data)
  ESX.TriggerServerCallback('conx_gangs:getGangMembers', function(members)
    SendNUIMessage({
      openSection = "memberList",
      members = members
    })    
  end, data.gang) 
end)

RegisterNUICallback('kickGangMember', function(data)
  closeGui()

  if gang_data.gang_pos ~= "Boss" then
    exports['mythic_notify']:DoCustomHudText ('error', 'You are not authorized to kick gang members.', 5000)  
    return
  end

  TriggerServerEvent('conx_gangs:KickMember', data.identifier, data.name)
end)

RegisterNUICallback('promoteGangMember', function(data)
  closeGui()

  if gang_data.gang_pos ~= "Boss" then
    exports['mythic_notify']:DoCustomHudText ('error', 'You are not authorized to promote gang members.', 5000)  
    return
  end

  TriggerServerEvent('conx_gangs:SetLeader', gang_data.gang, data.identifier, data.name)
end)

RegisterNUICallback('recruitGangMember', function(data)

  if gang_data.gang_pos ~= "Boss" and gang_data.gang_pos ~= "Leader"  then
    exports['mythic_notify']:DoCustomHudText ('error', 'You are not authorized to recruit new gang members.', 5000)  
    return
  end

  TriggerServerEvent('conx_gangs:AddNewMember', data.targetid, gang_data.gang)
end)

RegisterNUICallback('gangRestock', function(data)
  if gang_data.gang_pos ~= "Boss" then
    exports['mythic_notify']:DoCustomHudText ('error', 'You are not authorized to buy gang weapon stock and resources.', 5000)  
    return
  end

  closeGui()
  if data.restocktype == "resources" then
    TriggerServerEvent('conx_gangs:buyStocks', data.gang, 'Items', 50000)
  elseif data.restocktype == "weapon" then
    TriggerServerEvent('conx_gangs:buyStocks', data.gang, 'Weapons', 100000)
  end
end)

RegisterNUICallback('btnGangLeave', function()
  closeGui()
  TriggerServerEvent('conx_gangs:LeaveGang')
end)

RegisterNUICallback('promoteEmploee', function(data)
  TriggerServerEvent('phone:PromoteEmployee', data.identifier, data.name, data.job, data.grade)
end)

RegisterNUICallback('fireEmployee', function(data)
  TriggerServerEvent('phone:FireEmployee', data.identifier, data.name, data.job, data.grade) 
end)

RegisterNUICallback('recruitEmployee', function(data)
  local myJob = ESX.PlayerData.job.name

  TriggerServerEvent('phone:RecruitEmployee', data.targetid, myJob) 
end)



RegisterNUICallback('btnTaskGang', function()
  TriggerEvent("gangTasks:updated")
end)



local pcs = {
  [1] = 1333557690,
  [2] = -1524180747, 
}

RegisterNetEvent("open:deepweb")
AddEventHandler("open:deepweb", function()
  SetNuiFocus(false,false)
  SetNuiFocus(true,true)
  guiEnabled = true
  SendNUIMessage({
    openSection = "deepweb" 
  })
end)

RegisterNetEvent("gangTasks:updated")
AddEventHandler("gangTasks:updated", function()
  --[[local gang = exports["isPed"]:isPed("gang")
  local cid = tonumber(exports["isPed"]:isPed("cid"))]]

  local taskObject = {}
  for i = 1, #activeTasks do

    if activeTasks[i]["Gang"] ~= 0 and gang ~= 0 and tonumber(activeTasks[i]["taskOwnerCid"]) ~= cid then
      if gang == activeTasks[i]["Gang"] then
        taskObject[#taskObject + 1 ] = {
          name = TaskTitle[activeTasks[i]["TaskType"]],
          assignedTo = activeTasks[i]["taskOwnerCid"],
          status = TaskState[activeTasks[i]["TaskState"]],
          identifier = activeTasks[i]["BlockChain"],
          groupId = gang,
          retrace = 0,
        }
      end
    elseif activeTasks[i]["Gang"] == 0 and tonumber(activeTasks[i]["taskOwnerCid"]) ~= cid then

      --local passes = exports["isPed"]:isPed("passes")
      for z = 1, #passes do

        local passType = activeTasks[i]["Group"]
        if passes[z].pass_type == passType and (passes[z].rank == 2 or passes[z].rank > 3) then
          taskObject[#taskObject + 1 ] = {
            name = activeTasks[i]["TaskNameGroup"],
            assignedTo = activeTasks[i]["taskOwnerCid"],
            status = TaskState[activeTasks[i]["TaskState"]],
            identifier = activeTasks[i]["BlockChain"],
            groupId = passType,
            retrace = 0,
          }
        end

      end

    else
      if tonumber(activeTasks[i]["taskOwnerCid"]) == cid then

        local TaskName = ""
        if activeTasks[i]["Gang"] == 0 then
          TaskName = activeTasks[i]["TaskNameGroup"]
        else
          TaskName = TaskTitle[activeTasks[i]["TaskType"]]
        end
        taskObject[#taskObject + 1 ] = {
          name = TaskName,
          assignedTo = activeTasks[i]["taskOwnerCid"],
          status = TaskState[activeTasks[i]["TaskState"]],
          identifier = activeTasks[i]["BlockChain"],
          groupId = gang,
          retrace = 1
        }
      end
    end
  end

  SendNUIMessage({
    openSection = "addTasks",
    tasks = taskObject
  })
end)

RegisterNetEvent("purchasePhone")
AddEventHandler("purchasePhone", function()
  TriggerServerEvent("purchasePhone")
end)

RegisterNUICallback('btnMute', function()
  if phoneNotifications then
    exports['mythic_notify']:DoLongHudText('error', 'Notifications Disabled.')
  else
    exports['mythic_notify']:DoLongHudText('success', 'Notifications Enabled.')
  end
  phoneNotifications = not phoneNotifications
end)

RegisterNetEvent("tryTweet")
AddEventHandler("tryTweet", function(tweetinfo,message,user)
  if hasPhone() then
    TriggerServerEvent("AllowTweet",tweetinfo,message)
  end
end)

RegisterNUICallback('btnDecrypt', function()
  TriggerEvent("secondaryjob:accepttask")
end)



RegisterNUICallback('btnGarage', function()
  TriggerServerEvent("phone:getVehicles")
end)

RegisterNUICallback('btnHelp', function()
  closeGui()
  TriggerEvent("openWiki")
end)

RegisterNUICallback('carpaymentsowed', function()
  TriggerEvent("car:carpaymentsowed")
end)

RegisterNUICallback('vehspawn', function(data)
  findVehFromPlateAndSpawn(data.vehplate)
end)

RegisterNUICallback('vehtrack', function(data)
  --exports['mythic_notify']:SendAlert('inform', 'Coming soon.', 2500)
  findVehFromPlateAndLocate(data.vehplate)
end)

RegisterNUICallback('vehiclePay', function(data)
  TriggerEvent('car:dopayment', data.vehiclePlate)
end)

function findVehFromPlateAndLocate(plate)


  local gameVehicles = ESX.Game.GetVehicles()
  local vehicle = nil
  local found = false

  for i = 1, #gameVehicles do
      local curVehicle = gameVehicles[i]

      if DoesEntityExist(curVehicle) then
          if Trim(GetVehicleNumberPlateText(curVehicle)) == plate then
              found = true
              vehicle = curVehicle
              break
          end
      end
  end

  if found then
    local vehCoords = GetEntityCoords(vehicle)

    if phoneNotifications then
      exports['mythic_notify']:DoLongHudText('inform', 'Your vehicle has been marked on your GPS.')
      PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
    end
    SetNewWaypoint(vehCoords.x, vehCoords.y)
  else
    exports['mythic_notify']:DoLongHudText('inform', 'Your vehicle is in impound.')
  end
  
end

function Trim(value)
	if value then
		return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
	else
		return nil
	end
end


local recentspawnrequest = false
function findVehFromPlateAndSpawn(plate)

  if IsPedInAnyVehicle(PlayerPedId(), false) then
    return
  end

  for ind, value in pairs(vehicles) do

    vehPlate = value.license_plate
    if vehPlate == plate then
      state = value.vehicle_state
      coordlocation = value.coords

      if #(vector3(coordlocation[1],coordlocation[2],coordlocation[3]) - GetEntityCoords(PlayerPedId())) < 10.0 and state == "Out" then

        local DoesVehExistInProximity = CheckExistenceOfVehWithPlate(vehPlate)

        if not DoesVehExistInProximity and not recentspawnrequest then
          recentspawnrequest = true
          TriggerServerEvent("garages:phonespawn",vehPlate)
          Wait(10000)
          recentspawnrequest = false
        else
          print("Found vehicle already existing!")
        end

      end

    end

  end

end

RegisterNetEvent("phone:SpawnVehicle")
AddEventHandler('phone:SpawnVehicle', function(vehicle, plate, customized, state, Fuel, coordlocation)
  TriggerEvent("garages:SpawnVehicle", vehicle, plate, customized, state, Fuel, coordlocation)
end)



Citizen.CreateThread(function()
    local invehicle = false
    local plateupdate = "None"
    local vehobj = 0
    while true do
        Wait(1000)
        if not invehicle and IsPedInAnyVehicle(PlayerPedId(), false) then
          local playerPed = PlayerPedId()
          local veh = GetVehiclePedIsIn(playerPed, false)
            if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
              vehobj = veh
              local checkplate = GetVehicleNumberPlateText(veh)
              invehicle = true
              plateupdate = checkplate
              local coords = GetEntityCoords(vehobj)
              coords = { coords["x"], coords["y"], coords["z"] }
              TriggerServerEvent("vehicle:coords",plateupdate,coords)
            end
        end
        if invehicle and not IsPedInAnyVehicle(PlayerPedId(), false) then
          local coords = GetEntityCoords(vehobj)
          coords = { coords["x"], coords["y"], coords["z"] }
          TriggerServerEvent("vehicle:coords",plateupdate,coords)
          invehicle = false
          plateupdate = "None"
          vehobj = 0
        end  
    end
end)


function CheckExistenceOfVehWithPlate(platesent)
    local playerped = PlayerPedId()
    local playerCoords = GetEntityCoords(playerped)
    local handle, scannedveh = FindFirstVehicle()
    local success
    local rped = nil
    local distanceFrom
    repeat
        local pos = GetEntityCoords(scannedveh)
        local distance = #(playerCoords - pos)
          if distance < 50.0 then
            local checkplate = GetVehicleNumberPlateText(scannedveh)
            if checkplate == platesent then
              return true
            end
          end
        success, scannedveh = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return false
end

local currentVehicles = {}
--[[
RegisterNetEvent("phone:Garage")
AddEventHandler("phone:Garage", function(vehs)
  vehicles = vehs
  local showCarPayments = false

  local parsedVehicleData = {}
  for ind, value in pairs(vehs) do
	local jsonraw = value.vehicle
    local jsonparse = json.decode(jsonraw)
    local model = jsonparse["model"]
	
	if model ~= nil then
		local somethingfinal = GetDisplayNameFromVehicleModel(model)
		vehName = somethingfinal
    end
	
    vehName =  vehName 
    vehPlate = value.plate
    currentGarage = "Garage #" .. value.garageId
    transmission = value.transmission ..'/100'
    radiator = value.radiator ..'/100'
    clutch = value.clutch ..'/100'
    brakes = value.brakes ..'/100'
    axle = value.axle ..'/100'
    allowspawnattempt = 0

    table.insert(parsedVehicleData, {
      name = vehName,
      plate = vehPlate,
      garage = currentGarage,
	  transmission = transmission,
	  radiator = radiator,
	  clutch = clutch,
	  brakes = brakes,
	  axle = axle,
      canSpawn = allowspawnattempt
    })
  end
  
  SendNUIMessage({ openSection = "Garage", showCarPaymentsOwed = showCarPayments, vehicleData = parsedVehicleData})
end)
]]

local garageNames = {
  [1] = "Pillbox Hill",
  [2] = "Sandy Shore",
  [3] = "Rockford Hills",
  [4] = "Paleto Bay",
  [6] = "Vinewood Racetrack",
  [7] = "Alta",
  [8] = "Grand Senora Desert",
  [9] = "Del Perro",
  [10] = "Paleto Forest",
}

RegisterNetEvent("phone:Garage")
AddEventHandler("phone:Garage", function(vehs)

  for k, v in pairs(vehs) do
	local jsonraw = v.vehicle
    local jsonparse = json.decode(jsonraw)
    local model = jsonparse["model"]
  
  
   if model ~= nil then
		local somethingfinal = GetDisplayNameFromVehicleModel(model)
		vehName = somethingfinal
    end

    vehs[k].vehName = vehName
	
	if garageNames[vehs[k].garageId] == nil then
      vehs[k].garageId = "Garage " .. vehs[k].garageId
    else
      vehs[k].garageId = garageNames[vehs[k].garageId] .. " Garage"
    end

  end

  SendNUIMessage({ openSection = "Garage", vehicleData = vehs})
end)

--- PING PING PING
local currentPing = nil
local pingSender = nil
local myPings = {}
local pingIds

RegisterNUICallback('pingContact', function(data, cb)
  local pedCoords = GetEntityCoords(PlayerPedId())
  closeGui()
  exports['mythic_notify']:DoLongHudText('inform', 'You have sent a ping to ' .. data.name)
  TriggerServerEvent('phone:pingContact', data.name, data.number, pedCoords)
  cb('ok')
end)

RegisterNetEvent('phone:sendPing')
AddEventHandler('phone:sendPing', function(coords, name, sender) 
  local newSender = getContactName(sender)
  local pingId = math.random(999999)

  if hasPhone() then
    TriggerEvent('InteractSound_CL:PlayOnOne', 'demo', 0.70)
    SendNUIMessage({openSection = "newping"})
  end

  myPings[pingId] = {
    pingId = pingId,
    sender = newSender,
    coords = {coords.x, coords.y, coords.z},
    time = GetGameTimer(),
    received = nil
  }

end)

RegisterNUICallback('myPings', function(data, cb)

  for k, v in pairs(myPings) do
    local received = ( GetGameTimer() - v.time ) / 1000
    local text = nil
    if received >= 60 then
      text = math.ceil((received) / 60) .. " mins ago"
    else
      if received < 10 then
        text = "just now"
      else
        text = math.ceil(received) .. " secs ago"
      end
    end

    v.received = text
  end

  SendNUIMessage({
    openSection = "openPings",
    myPings = myPings
  })

  cb('ok')
end)

RegisterNUICallback('acceptPing', function(data, cb)
  closeGui()
  local sender = myPings[data.pingId].sender
  local x = myPings[data.pingId].coords[1]
  local y = myPings[data.pingId].coords[2]

  exports['mythic_notify']:DoLongHudText('inform', 'You have accepted the ping from ' .. sender)
  ClearGpsPlayerWaypoint()
  SetNewWaypoint(x, y)
  cb('ok')
end)

local pickuppoints = {
  [1] =  { ['x'] = 923.94,['y'] = -3037.88,['z'] = 5.91,['h'] = 270.81, ['info'] = ' Shipping Container BMZU 822693' },
  [2] =  { ['x'] = 938.02,['y'] = -3026.28,['z'] = 5.91,['h'] = 265.85, ['info'] = ' Shipping Container BMZU 822693' },
  [3] =  { ['x'] = 1006.17,['y'] = -3028.94,['z'] = 5.91,['h'] = 269.31, ['info'] = ' Shipping Container BMZU 822693' },
  [4] =  { ['x'] = 1020.42,['y'] = -3044.91,['z'] = 5.91,['h'] = 87.37, ['info'] = ' Shipping Container BMZU 822693' },
  [5] =  { ['x'] = 1051.75,['y'] = -3045.09,['z'] = 5.91,['h'] = 268.37, ['info'] = ' Shipping Container BMZU 822693' },
  [6] =  { ['x'] = 1134.92,['y'] = -2992.22,['z'] = 5.91,['h'] = 87.9, ['info'] = ' Shipping Container BMZU 822693' },
  [7] =  { ['x'] = 1149.1,['y'] = -2976.06,['z'] = 5.91,['h'] = 93.23, ['info'] = ' Shipping Container BMZU 822693' },
  [8] =  { ['x'] = 1121.58,['y'] = -3042.39,['z'] = 5.91,['h'] = 88.49, ['info'] = ' Shipping Container BMZU 822693' },
  [9] =  { ['x'] = 830.58,['y'] = -3090.46,['z'] = 5.91,['h'] = 91.15, ['info'] = ' Shipping Container BMZU 822693' },
  [10] =  { ['x'] = 830.81,['y'] = -3082.63,['z'] = 5.91,['h'] = 271.61, ['info'] = ' Shipping Container BMZU 822693' },
  [11] =  { ['x'] = 909.91,['y'] = -2976.51,['z'] = 5.91,['h'] = 271.02, ['info'] = ' Shipping Container BMZU 822693' },
}


function DrawText3Ds(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 370
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 41, 11, 41, 68)
end
blip = 0

function CreateBlip(location)
    DeleteBlip()
    blip = AddBlipForCoord(location["x"],location["y"],location["z"])
    SetBlipSprite(blip, 514)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Pick Up")
    EndTextCommandSetBlipName(blip)
end
function DeleteBlip()
  if DoesBlipExist(blip) then
    RemoveBlip(blip)
  end
end

function refreshmail()
    lstnotifications = {}
    for i = 1, #curNotifications do

        local message2 = {
          id = tonumber(i),
          name = curNotifications[tonumber(i)].name,
          message = curNotifications[tonumber(i)].message
        }
        lstnotifications[#lstnotifications+1]= message2
    end
    SendNUIMessage({openSection = "notifications", list = lstnotifications})
end

RegisterNUICallback('btnDelivery', function()
  TriggerEvent("trucker:confirmation")
end)

RegisterNUICallback('btnPackages', function()
  TriggerServerEvent("esx_cargodelivery:GetTruckDeliveries")
end)

RegisterNUICallback('btnTrucker', function()
  TriggerEvent('esx_cargodelivery:TriggerTrucking')
end)

RegisterNetEvent("phone:trucker")
AddEventHandler("phone:trucker", function(jobList)

  for k, v in pairs(jobList) do
    local currentStreetHash, intersectStreetHash = GetStreetNameAtCoord(v.jobData.x, v.jobData.y, v.jobData.z, currentStreetHash, intersectStreetHash)
    local currentStreetName = GetStreetNameFromHashKey(currentStreetHash)
    local intersectStreetName = GetStreetNameFromHashKey(intersectStreetHash)
    v.jobName = currentStreetName
  end

  SendNUIMessage({
    openSection = "deliveryJob",
    deliveries = jobList
  })
end)

RegisterNUICallback('selectedJob', function(data, cb)
    --TriggerEvent("Trucker:SelectJob",data)
    if not doingDelivery then
      TriggerServerEvent('esx_cargodelivery:AcceptTruckerJob', data.jobId)
    else
      print('Doing delivery already')
      exports['mythic_notify']:DoLongHudText('inform', 'You already have a pending package to deliver.')
      Citizen.Wait(1000)
      exports['mythic_notify']:DoLongHudText('inform', 'Rent a truck, to pickup and deliver it.')
    end
end)

function rundropoff(boxcount,costs)
  -- delete this line to enable weed boxes 1 ~= 2 should be curhrs ~= curmins
  --[[if 1 ~= 2 then
    for i = 1, math.random(20) do
      TriggerEvent("chatMessage", "SPAM EMAIL ", 8, "This message was blocked for your safety. Thank you for using nopixel mail services.")
    end
    refreshmail()
    return
  end]]
  local success = true
  local timer = 600000
  TriggerEvent("chatMessage", "EMAIL ", 8, "Yo, here are the coords for the drop off, you have 10 minutes - leave $" .. costs .. " in cash there!")
  refreshmail()
  local location = pickuppoints[math.random(#pickuppoints)]
  CreateBlip(location)
  while timer > 0 do
    Citizen.Wait(1)
    local plycoords = GetEntityCoords(PlayerPedId())
    local dstcheck = #(plycoords - vector3(location["x"],location["y"],location["z"])) 
    if dstcheck < 5.0 then
      DrawText3Ds(location["x"],location["y"],location["z"], "Press E to pickup the dropoff.")
       if dstcheck < 3.0 and IsControlJustReleased(0,38) then
          success = true
          timer = 0
       end
    end
    timer = timer - 1
    if timer == 1 then
      success = false
    end
  end
  if success then
    TriggerServerEvent("weed:phone:buybox",boxcount,costs)
  end
  DeleteBlip()
end


-- turn this to false to re-enable weed purchases.
local waiting = false
RegisterNUICallback('btnBox1', function()
  if waiting then
    return
  end
  waiting = true
  
  Citizen.Wait(math.random(100000))
  rundropoff(1,1500)
  waiting = false
end)

RegisterNUICallback('btnBox2', function()
  if waiting then
    return
  end
  waiting = true
  
  Citizen.Wait(math.random(100000))
  rundropoff(5,4500)
  waiting = false
end)

RegisterNUICallback('btnBox3', function()
  if waiting then
    return
  end
  waiting = true
  
  Citizen.Wait(math.random(100000))
  rundropoff(10,8500)
  waiting = false
end)


RegisterNUICallback('btnBox6', function()
  closeGui()
  TriggerEvent("hacking:attemptHackCrypto","weapon")
end)

RegisterNUICallback('btnBox5', function()
  closeGui()
  TriggerEvent("hacking:attemptHackCrypto","crack")
end)

RegisterNUICallback('btnBox4', function()
  closeGui()
  TriggerEvent("hacking:attemptHackCrypto","bigweapon")
end)

local weaponList = {
  [1] = 324215364,
  [2] = 736523883,
  [3] = 4024951519,
  [4] = 1627465347,
}

local weaponListSmall = {
  [1] = 2017895192,
  [2] = 584646201,
  [3] = 3218215474,
}

local luckList = {
  [1] =  "extended_ap",
  [2] =  "extended_sns",
  [3] =  "extended_micro",
  [4] =  "rifleammo",
  [5] =  "heavyammo",
  [6] =  "lmgammo",
}

RegisterNetEvent("stocks:timedEvent")
AddEventHandler("stocks:timedEvent", function(typeSent)
  local success = true
  local timer = 600000
  TriggerEvent("chatMessage", "EMAIL ", 8, "Yo, here are the coords for the drop off, you have 10 minutes - I already zoinked your Pixerium Credits")
  refreshmail()
  local location = pickuppoints[math.random(#pickuppoints)]
  CreateBlip(location)
  while timer > 0 do
    Citizen.Wait(1)
    local plycoords = GetEntityCoords(PlayerPedId())
    local dstcheck = #(plycoords - vector3(location["x"],location["y"],location["z"])) 
    if dstcheck < 5.0 then
      DrawText3Ds(location["x"],location["y"],location["z"], "Press E to pickup the dropoff.")
       if dstcheck < 3.0 and IsControlJustReleased(0,38) then
          success = true
          timer = 0
       end
    end
    timer = timer - 1
    if timer == 1 then
      success = false
    end
  end

  if success then

    if math.random(1000) == 69 then
      TriggerEvent("player:receiveItem", "741814745", 1)
    end

    if math.random(10) == 1 then
      TriggerEvent("player:receiveItem", ""..luckList[math.random(6)].."", 1)
    end


    if typeSent == "bigweapon" then
      TriggerEvent("player:receiveItem", ""..weaponList[math.random(4)].."", 1)
    end

    if typeSent == "weapon" then
      TriggerEvent("player:receiveItem", ""..weaponListSmall[math.random(3)].."", 1)
    end

  end

  DeleteBlip()
 
end)


function buyItem(typeSent)
  local success = true
  local timer = 600000
  TriggerEvent("chatMessage", "EMAIL ", 8, "Yo, here are the coords for the drop off, you have 10 minutes - it will cost " .. costs .. " Pixerium")
  refreshmail()
  local location = pickuppoints[math.random(#pickuppoints)]
  CreateBlip(location)
  while timer > 0 do
    Citizen.Wait(1)
    local plycoords = GetEntityCoords(PlayerPedId())
    local dstcheck = #(plycoords - vector3(location["x"],location["y"],location["z"])) 
    if dstcheck < 5.0 then
      DrawText3Ds(location["x"],location["y"],location["z"], "Press E to pickup the dropoff.")
       if dstcheck < 3.0 and IsControlJustReleased(0,38) then
          success = true
          timer = 0
       end
    end
    timer = timer - 1
    if timer == 1 then
      success = false
    end
  end
  if success then
    TriggerEvent("crypto:buybox",typeSent,costs)
  end
  DeleteBlip()
end

RegisterNUICallback('resetPackages', function()
  insideDelivers = false
end)

local requestHolder = 0

RegisterNetEvent("phone:packages")
AddEventHandler("phone:packages", function(packages)
  while insideDelivers do
    if requestHolder ~= 0 then
      SendNUIMessage({
        openSection = "packagesWith"
      })
    else
      SendNUIMessage({
        openSection = "packages"
      })
    end
    
    
    for i, v in pairs(packages) do
      if GetPlayerServerId(PlayerId()) == v.source then
        local currentStreetHash2, intersectStreetHash2 = GetStreetNameAtCoord(v.drop[1], v.drop[2], v.drop[3], currentStreetHash2, intersectStreetHash2)
        local currentStreetName2 = GetStreetNameFromHashKey(currentStreetHash2)
        local intersectStreetName2 = GetStreetNameFromHashKey(intersectStreetHash2)

        SendNUIMessage({openSection = "addPackages", street2 = currentStreetName2, jobId = v.id ,distance = getDriverDistance(v.driver , v.drop)})
      end
    end 
    Wait(4000)
  end
end)


RegisterNetEvent("phone:OwnerRequest")
AddEventHandler("phone:OwnerRequest", function(holder)
  requestHolder = holder
end)

RegisterNUICallback('btnRequest', function()
  TriggerServerEvent("trucker:confirmRequest",requestHolder)
  requestHolder = 0
end)




function getDriverDistance(driver , drop)
  local dist = 0

  local ped = GetPlayerPed(value)
  if driver ~= 0 then
    local current = #(vector3(drop[1],drop[2],drop[3]) - GetEntityCoords(ped))
    if current < 15 then
      dist = "Driver at store"
    else
      dist = current
      dist = math.ceil(dist)
    end
    
  else
    dist = "Waiting for driver"
  end

  return dist
end

gurgleList = {}
RegisterNetEvent('websites:updateClient')
AddEventHandler('websites:updateClient', function(passedList)
  gurgleList = passedList

  local gurgleObjects = {}

  if not guiEnabled then
    return
  end

  for i = 1, #gurgleList do
    table.insert(gurgleObjects, {
      webTitle = gurgleList[i]["Title"], 
      webKeywords = gurgleList[i]["Keywords"], 
      webDescription = gurgleList[i]["Description"] 
    })
  end

  SendNUIMessage({ openSection = "gurgleEntries", gurgleData = gurgleObjects})
end)

function hasPhone()
	return exports['conx_inventory']:hasEnoughOfItem('phone', 1)
end
--[[
function hasRadio()
    if exports["np-inventory"]:hasEnoughOfItem("radio",1,false) and not exports["isPed"]:isPed("disabled") then
      return true
    else
      return false
    end
end]]

function DrawRadioChatter(x,y,z, text,opacity)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    if opacity > 215 then
      opacity = 215
    end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, opacity)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 370
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 41, 11, 41, 68)
end
local activeMessages = 0

RegisterNetEvent('radiotalkcheck')
AddEventHandler('radiotalkcheck', function(args,senderid)

  if hasRadio() and radioChannel ~= 0 then
    randomStatic(true)

    local ped = GetPlayerPed( -1 )

      if ( DoesEntityExist( ped ) and not IsEntityDead( ped )) then

        loadAnimDict( "random@arrests" )

        TaskPlayAnim(ped, "random@arrests", "generic_radio_chatter", 8.0, 2.0, -1, 50, 2.0, 0, 0, 0 )

        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
      end


    TriggerServerEvent("radiotalkconfirmed",args,senderid,radioChannel)
    Citizen.Wait(2500)
    ClearPedSecondaryTask(PlayerPedId())
  end

end)




function loadAnimDict( dict )
    while ( not HasAnimDictLoaded( dict ) ) do
        RequestAnimDict( dict )
        Citizen.Wait( 5 )
    end
end 

function randomStatic(loud)
  local vol = 0.05
  if loud then
    vol = 0.9
  end
  local pickS = math.random(4)
  if pickS == 4 then
    TriggerEvent("InteractSound_CL:PlayOnOne","radiostatic1",vol)
  elseif pickS == 3 then
    TriggerEvent("InteractSound_CL:PlayOnOne","radiostatic2",vol)
  elseif pickS == 2 then
    TriggerEvent("InteractSound_CL:PlayOnOne","radiostatic3",vol)
  else
    TriggerEvent("InteractSound_CL:PlayOnOne","radioclick",vol)
  end

end

RegisterNetEvent('radiotalk')
AddEventHandler('radiotalk', function(args,senderid,channel)

    local senderid = tonumber(senderid)

    table.remove(args,1)
    local radioMessage = ""
    for i = 1, #args do
        radioMessage = radioMessage .. " " .. args[i]
    end

    if channel == radioChannel and hasRadio() and radioMessage ~= nil then
      -- play radio click sound locally.
      TriggerEvent('chatMessage', "RADIO #" .. channel, 3, radioMessage, 5000)
      randomStatic(true)

      local radioMessage = ""
      for i = 1, #args do
        if math.random(50) > 25 then
          radioMessage = radioMessage .. " " .. args[i]
        else
          radioMessage = radioMessage .. " **BZZZ** "
        end
      end
      TriggerServerEvent("radiochatter:server",radioMessage)
    end
end)
RegisterNetEvent('radiochatter:client')
AddEventHandler('radiochatter:client', function(radioMessage,senderid)

    local senderid = tonumber(senderid) 
    local location = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(senderid)))
    local dst = #(GetEntityCoords(PlayerPedId()) - location)
    activeMessages = activeMessages + 0.1
    if dst < 5.0 then
      -- play radio static sound locally.
      local counter = 350
      local msgZ = location["z"]+activeMessages
      if PlayerPedId() ~= GetPlayerPed(GetPlayerFromServerId(senderid)) then
        randomStatic(false)
        while counter > 0 and dst < 5.0 do
          location = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(senderid)))
          dst = #(GetEntityCoords(PlayerPedId()) - location)
          DrawRadioChatter(location["x"],location["y"],msgZ, "Radio Chatter: " .. radioMessage, counter)
          counter = counter - 1
          Citizen.Wait(1)
        end
      end
    end
    activeMessages = activeMessages - 0.1 
end)


RegisterNetEvent('radiochannel')
AddEventHandler('radiochannel', function(chan)
  local chan = tonumber(chan)
  if hasRadio() and chan < 1000 and chan > -1 then
    radioChannel = chan
    TriggerEvent("InteractSound_CL:PlayOnOne","radioclick",0.4)
    TriggerEvent('chatMessage', "RADIO CHANNEL " .. radioChannel, 3, "Active", 5000)
    -- play radio click sound.
  end
end)

RegisterNetEvent('canPing')
AddEventHandler('canPing', function(target)
  if hasPhone() and not isDead then
    local crds = GetEntityCoords(PlayerPedId())
    TriggerServerEvent("requestPing", target, crds["x"],crds["y"],crds["z"] )
  else
    TriggerEvent("DoLongHudText","You need a phone to use GPS!",2)
  end
end)

local pingcount = 0
local currentblip = 0
local currentping = { ["x"] = 0.0,["y"] = 0.0,["z"] = 0.0, ["src"] = 0 }
RegisterNetEvent('allowedPing')
AddEventHandler('allowedPing', function(x,y,z,src,name)
  if pingcount > 0 then
    TriggerEvent("DoLongHudText","Somebody sent you a GPS flag but you already have one in process!",2)
    return
  end
  
  if hasPhone() and not isDead then
    pingcount = 5
    currentping = { ["x"] = x,["y"] = y,["z"] = z, ["src"] = src }
    while pingcount > 0 do
      TriggerEvent("DoLongHudText",name .. " has given you a ping location, type /pingaccept to accept",2)
      Citizen.Wait(5000)
      pingcount = pingcount - 1
    end
  else
    TriggerEvent("DoLongHudText","Somebody sent you a GPS flag but you have no phone!",2)
  end
  pingcount = 0
  currentping = { ["x"] = 0.0,["y"] = 0.0,["z"] = 0.0, ["src"] = 0 }
end)

RegisterNetEvent('acceptPing')
AddEventHandler('acceptPing', function()
  if pingcount > 0 then
    if DoesBlipExist(currentblip) then
      RemoveBlip(currentblip)
    end
    currentblip = AddBlipForCoord(currentping["x"], currentping["y"], currentping["z"])
    SetBlipSprite(currentblip, 280)
    SetBlipAsShortRange(currentblip, false)
    BeginTextCommandSetBlipName("STRING")
    SetBlipColour(currentblip, 4)
    SetBlipScale(currentblip, 1.2)
    AddTextComponentString("Accepted GPS Marker")
    EndTextCommandSetBlipName(currentblip)
    TriggerEvent("DoLongHudText","Their GPS ping has been marked on the map")
    TriggerServerEvent("pingAccepted",currentping["src"])
    pingcount = 0
    Citizen.Wait(60000)
    if DoesBlipExist(currentblip) then
      RemoveBlip(currentblip)
    end
  end
end)


--radiotalk
--radiochannel

-- Open Gui and Focus NUI

-- read -- cellphone_text_read_base
-- texting -- cellphone_swipe_screen
-- phone away -- cellphone_text_out


Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    if IsControlJustPressed(1, 288) then
		if exports["conx_inventory"]:hasEnoughOfItem('phone', 1, false) then
			GotPhone()
		else
			exports['mythic_notify']:DoLongHudText('error', 'You don\'t have mobile phone.')
		end
      --TriggerServerEvent("tp:checkPhoneCount")
    end
  end
end)

RegisterNetEvent('tp:heHasPhone')
AddEventHandler('tp:heHasPhone', function()
    GotPhone()
end)

function hasTrucker()
  local trucker = GetHashKey('mule2')

  if IsPedInAnyVehicle(PlayerPedId(), true) then
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
      
    if IsVehicleModel(veh, trucker) then
      return true
    end
  end

  return false
end


function GotPhone()
  openGuiNow()
end

local recentopen = false
function openGuiNow()
 
  if hasPhone() then
    
    if activeOnCallUI then
      SendNUIMessage({
        openSection = "activatecallui",
        show = false
      })    
      activeOnCallUI = false  
    end    

    TriggerEvent('RemoveBindedWeapon')
    guiEnabled = true
    SetNuiFocus(false,false)
    SetNuiFocus(true,true)

    local trucker = hasTrucker()

    SendNUIMessage({openPhone = true, hasDevice = device, hasDecrypt = decrypt, hasDecrypt2 = decrypt2, hasTrucker = trucker, vpnConnected = vpnConnected, isRealEstateAgent = isREAgent, playerId = GetPlayerServerId(PlayerId())})

    TriggerEvent('phoneEnabled',true)
    TriggerEvent('animation:sms',true)

    lstContacts = {}
    TriggerServerEvent('getContacts')
  else
    closeGui()
  end
  recentopen = false
end


RegisterNUICallback('btnPagerType', function(data, cb)
  TriggerServerEvent("secondaryjob:ServerReturnDate")
end)
local jobnames = {
  ["taxi"] = "Taxi Driver",
  ["towtruck"] = "Tow Truck Driver",
  ["trucker"] = "Delivery Driver",
}

RegisterNUICallback('newPostSubmit', function(data, cb)
  if ESX.PlayerData.job.name ~= "taxi" and ESX.PlayerData.job.name ~= "towtruck" and ESX.PlayerData.job.name ~= "trucker" then
    TriggerServerEvent('phone:updatePhoneJob', data.advert)
  else
    TriggerServerEvent('phone:updatePhoneJob', ESX.PlayerData.job.name .. " | " .. data.advert)
    TriggerEvent("DoLongHudText","You are already listed as a " .. myjob)
  end
end)

RegisterNUICallback('deleteYP', function()
  TriggerServerEvent('phone:RemovePhoneJob')
end)

RegisterNetEvent("yellowPages:retrieveLawyersOnline")
AddEventHandler("yellowPages:retrieveLawyersOnline", function(command)
    local isFound = false
    local jsonparse = json.decode(YellowPages)
    exports['mythic_notify']:DoLongHudText('inform', 'Searching for a Lawyer...', 2500, { ['background-color'] = '#0062ff' })
    Citizen.Wait(2000)
    for i = 1, #YellowPageArray do
      local job = jsonparse[tonumber(i)].advert
      if string.find(job, 'attorney') or string.find(job, 'lawyer') or string.find(job, 'Lawyer') or string.find(job, 'public defender') then
        local name = jsonparse[tonumber(i)].name
        local number = jsonparse[tonumber(i)].phoneNumber
        TriggerServerEvent('phone:foundLawyerC', name, number)
        isFound = true
        --TriggerEvent('chatMessage', "", {0, 0, 255}, "⚖️ " .. jsonparse[tonumber(i)].name .. " ☎️ " .. jsonparse[tonumber(i)].phoneNumber)
      end
    end
    if not isFound then
      TriggerEvent('chatMessage', "", {255, 255, 255}, "There are no lawyers available right now. 😢")
    end
    
end)


RegisterNUICallback('notificationsYP', function()
  TriggerServerEvent('getYP')
  Citizen.Wait(200)
  TriggerEvent("YPUpdatePhone")
end)


RegisterNetEvent('YPUpdatePhone')
AddEventHandler('YPUpdatePhone', function()

  lstnotifications = {}

  local jsonparse = json.decode(YellowPages)

  for i = 1, #YellowPageArray do
    lstnotifications[#lstnotifications + 1] = {
      id = tonumber(i),
      name = jsonparse[tonumber(i)].name,
      message = jsonparse[tonumber(i)].advert,
      phoneNumber = jsonparse[tonumber(i)].phoneNumber
    }
  end
  SendNUIMessage({openSection = "notificationsYP", list = lstnotifications})
end)

-- Close Gui and disable NUI
function closeGui()
  TriggerEvent("closeInventoryGui")
  SetNuiFocus(false,false)
  SendNUIMessage({openPhone = false})
  guiEnabled = false
  TriggerEvent('animation:sms',false)
  TriggerEvent('phoneEnabled',false)
  recentopen = true
  Citizen.Wait(3000)
  recentopen = false
  insideDelivers = false
end

function closeGui2()
  TriggerEvent("closeInventoryGui")
  SetNuiFocus(false,false)
  SendNUIMessage({openPhone = false})
  guiEnabled = false
  recentopen = true
  Citizen.Wait(3000)
  recentopen = false  
end
local mousenumbers = {
  [1] = 1,
  [2] = 2,
  [3] = 3, 
  [4] = 4, 
  [5] = 5, 
  [6] = 6, 
  [7] = 12, 
  [8] = 13, 
  [9] = 66, 
  [10] = 67, 
  [11] = 95, 
  [12] = 96,   
  [13] = 97,   
  [14] = 98,
  [15] = 169,
   [16] = 170,
}


-- Disable controls while GUI open
Citizen.CreateThread(function()
  local focus = true
  
  while true do

    if guiEnabled then
      DisableControlAction(0, 1, guiEnabled) -- LookLeftRight
      DisableControlAction(0, 2, guiEnabled) -- LookUpDown
      DisableControlAction(0, 14, guiEnabled) -- INPUT_WEAPON_WHEEL_NEXT
      DisableControlAction(0, 15, guiEnabled) -- INPUT_WEAPON_WHEEL_PREV
      DisableControlAction(0, 16, guiEnabled) -- INPUT_SELECT_NEXT_WEAPON
      DisableControlAction(0, 17, guiEnabled) -- INPUT_SELECT_PREV_WEAPON
      DisableControlAction(0, 99, guiEnabled) -- INPUT_VEH_SELECT_NEXT_WEAPON
      DisableControlAction(0, 100, guiEnabled) -- INPUT_VEH_SELECT_PREV_WEAPON
      DisableControlAction(0, 115, guiEnabled) -- INPUT_VEH_FLY_SELECT_NEXT_WEAPON
      DisableControlAction(0, 116, guiEnabled) -- INPUT_VEH_FLY_SELECT_PREV_WEAPON
      DisableControlAction(0, 142, guiEnabled) -- MeleeAttackAlternate
      DisableControlAction(0, 106, guiEnabled) -- VehicleMouseControlOverride
      if IsDisabledControlJustReleased(0, 142) then -- MeleeAttackAlternate
        SendNUIMessage({type = "click"})
      end

    else
      mousemovement = 0
    end

    if selfieMode then
        if IsControlJustPressed(0, 177) then
          selfieMode = false
          DestroyMobilePhone()
          CellCamActivate(false, false)
        end
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(19)
        HideHudAndRadarThisFrame()
    else
      selfieMode = false
      DestroyMobilePhone()
      CellCamActivate(false, false)
    end

    if creatingMap then

      local plycoords = GetEntityCoords(GetPlayerPed(-1))

      DrawMarker(27,plycoords.x,plycoords.y,plycoords.z,0,0,0,0,0,0,dst,dst,0.3001,255,255,255,255,0,0,0,0)
      
      if #currentMap == 0 then
        DrawText3Ds(plycoords.x,plycoords.y,plycoords.z,"[E] to add start point, up/down for size, phone to save or cancel.")
      else
        DrawText3Ds(plycoords.x,plycoords.y,plycoords.z,"[E] to add check point, up/down for size, phone to save or cancel.")
      end

      if IsControlPressed(0,27) then
        dst = dst + 1
        if dst > 60.0 then
          dst = 60.0
        end
      end

      if IsControlPressed(0,173) then
        dst = dst - 1
        if dst < 4 then
          dst = 3.0
        end
      end

      if IsControlJustReleased(0,38) then
        if (IsControlPressed(0,21)) then
          PopLastCheckpoint()
        else
          AddCheckPoint()
        end
        Wait(1000)
      end

    end
    Citizen.Wait(1)
  end
end)

function ShowText(text)
  TriggerEvent("DoLongHudText",text)
end

-- Opens our phone
RegisterNetEvent('phoneGui2')
AddEventHandler('phoneGui2', function()
  openGui()
end)

-- NUI Callback Methods
RegisterNUICallback('close', function(data, cb)
  closeGui()
  cb('ok')
end)

RegisterNetEvent('phone:close')
AddEventHandler('phone:close', function(number, message)
  closeGui()

end)

-- SMS Callbacks
RegisterNUICallback('messages', function(data, cb)
  loading()
  TriggerServerEvent('phone:getSMS')
  cb('ok')
end)

RegisterNetEvent('phone:clientGetMessagesBetweenParties')
AddEventHandler('phone:clientGetMessagesBetweenParties', function(messages, displayName, clientNumber)
  
  SendNUIMessage({openSection = "messageRead", messages = messages, displayName = displayName, clientNumber = clientNumber})
end)

--$.post...
RegisterNUICallback('messageRead', function(data, cb)
  TriggerServerEvent('phone:serverGetMessagesBetweenParties', data.sender, data.receiver, data.displayName)
  cb('ok')
end)

RegisterNUICallback('messageDelete', function(data, cb)
  TriggerServerEvent('phone:removeSMS', data.id, data.number)
  cb('ok')
end)

RegisterNUICallback('newMessage', function(data, cb)
  SendNUIMessage({openSection = "newMessage"})
  cb('ok')
end)





RegisterNUICallback('messageReply', function(data, cb)
  SendNUIMessage({openSection = "newMessageReply", number = data.number})
  cb('ok')
end)

RegisterNUICallback('newMessageSubmit', function(data, cb)
  if not isDead then
    TriggerEvent('phone:sendSMS', tonumber(data.number), data.message)
    cb('ok')
  else
    TriggerEvent("DoLongHudText","You can not do this while injured.",2)
  end
end)


function testfunc()

end
RegisterNetEvent("TokoVoip:UpVolume");
AddEventHandler("TokoVoip:UpVolume", setVolumeUp);

RegisterNetEvent('refreshContacts')
AddEventHandler('refreshContacts', function()
  TriggerServerEvent('getContacts')
  SendNUIMessage({openSection = "contacts"})
end)

RegisterNetEvent('refreshYP')
AddEventHandler('refreshYP', function()
  if guiEnabled then
    TriggerServerEvent('getYP')
    Citizen.Wait(250)
    TriggerEvent('YPUpdatePhone')
  end
end)

RegisterNetEvent('refreshSMS')
AddEventHandler('refreshSMS', function()
  TriggerServerEvent('phone:getSMS')
  Citizen.Wait(250)
  SendNUIMessage({openSection = "messages"})
end)

-- Contact Callbacks
RegisterNUICallback('contacts', function(data, cb)
  TriggerServerEvent('getContacts')
  SendNUIMessage({openSection = "contacts"})
  cb('ok')
end)

RegisterNUICallback('newContact', function(data, cb)
  SendNUIMessage({openSection = "newContact"})
  cb('ok')
end)

RegisterNUICallback('newContactSubmit', function(data, cb)
  TriggerEvent('phone:addContact', data.name, tonumber(data.number))
  cb('ok')
end)

RegisterNUICallback('removeContact', function(data, cb)
  TriggerServerEvent('deleteContact', data.name, data.number)
  cb('ok')
end)

--call status 0 = no call, 1 = dialing, 2 = receiving call, 3 = in progresss
myID = 0
mySourceID = 0

-- myID = Myself
-- mySourceID = Target

mySourceHoldStatus = false
TriggerEvent('phone:setCallState', isNotInCall)
costCount = 1

RegisterNetEvent('animation:phonecallstart')
AddEventHandler('animation:phonecallstart', function()
  DestroyPhoneProp()
  TriggerEvent("incall",true)
  local lPed = PlayerPedId()
  RequestAnimDict("cellphone@")
  while not HasAnimDictLoaded("cellphone@") do
    Citizen.Wait(0)
  end
  local count = 0
  costCount = 1
  inPhone = false
  Citizen.Wait(200)
  ClearPedTasks(lPed)
  
  AttachPhoneProp()

  --exports['mythic_notify']:SendAlert('inform', '[E] Toggles Call.')

  while callStatus ~= isNotInCall do

    if isDead then
      endCall()
    end


    if IsEntityPlayingAnim(lPed, "cellphone@", "cellphone_call_listen_base", 3) and not IsPedRagdoll(PlayerPedId()) then
      --ClearPedSecondaryTask(lPed)
    else 



      if IsPedRagdoll(PlayerPedId()) then
        Citizen.Wait(1000)
      end
      TaskPlayAnim(lPed, "cellphone@", "cellphone_call_listen_base", 1.0, 1.0, -1, 49, 0, 0, 0, 0)
    end
    Citizen.Wait(1)
    count = count + 1

    if AnonCall then
       local dPB = #(PhoneBooth - GetEntityCoords( PlayerPedId()))
       if dPB > 2.0 then
        exports['mythic_notify']:DoLongHudText('error', 'Moved too far.')

        endCall()
       end
    end



    if IsControlJustPressed(0, 38) then
      TriggerEvent("phone:holdToggle")
    end

    if onhold then
      if count == 800 then
         count = 0
         exports['mythic_notify']:DoLongHudText('inform', 'Call On Hold.', 5000)
      end
    end

      --check if not unarmed
    local curw = GetSelectedPedWeapon(PlayerPedId())
    noweapon = `WEAPON_UNARMED`
    if noweapon ~= curw then
      SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
    end

  end
  ClearPedTasks(lPed)
  TaskPlayAnim(lPed, "cellphone@", "cellphone_call_out", 2.0, 2.0, 800, 49, 0, 0, 0, 0)
  Citizen.Wait(700)
  DestroyPhoneProp()
  TriggerEvent("incall",false)
end)

RegisterNetEvent('phone:makecall')
AddEventHandler('phone:makecall', function(pnumber)

  local pnumber = tonumber(pnumber)
  AnonCall = false
  if callStatus == isNotInCall and not isDead and hasPhone() then
    local dialingName = getContactName(pnumber)
    TriggerEvent('phone:setCallState', isDialing, dialingName)
    TriggerEvent("animation:phonecallstart")
    recentcalls[#recentcalls + 1] = { ["type"] = 2, ["number"] = pnumber, ["name"] = dialingName }
    TriggerServerEvent('phone:callContact', pnumber, true)
  else
    exports['mythic_notify']:DoLongHudText('inform', 'It appears you are already in a call, injured or with out a phone, please type /h to reset your calls.', 10000)

    --TriggerEvent("DoLongHudText","It appears you are already in a call, injured or with out a phone, please type /hangup to reset your calls.",2)
  end
end)



local PayPhoneHex = {
  [1] = 1158960338,
  [2] = -78626473,
  [3] = 1281992692,
  [4] = -1058868155,
  [5] = -429560270,
  [6] = -2103798695,
  [7] = 295857659,
  [8] = -1559354806,
}

function checkForPayPhone()
  for i = 1, #PayPhoneHex do
    local objFound = GetClosestObjectOfType( GetEntityCoords(PlayerPedId()), 5.0, PayPhoneHex[i], 0, 0, 0)
    if DoesEntityExist(objFound) then
      return true
    end
  end
  return false
end

RegisterNetEvent('phone:makepayphonecall')
AddEventHandler('phone:makepayphonecall', function(pnumber) 

    if not checkForPayPhone() then
      --TriggerEvent("DoLongHudText","You are not near a payphone.",2)
      exports['mythic_notify']:DoLongHudText('error', 'You are not to any payphone.')
      return
    end

    PhoneBooth = GetEntityCoords( PlayerPedId() )
    AnonCall = true

    local pnumber = tonumber(pnumber)
    if callStatus == isNotInCall and not isDead then
      -- TriggerEvent('phone:setCallState', isDialing)
      -- TriggerEvent("animation:phonecallstart")
      TriggerEvent("InteractSound_CL:PlayOnOne","payphonestart",0.5)
      TriggerServerEvent('phone:callContact', pnumber, false, isDialing)
    else
      --TriggerEvent("DoLongHudText","It appears you are already in a call, injured or with out a phone, please type /hangup to reset your calls.",2)
      exports['mythic_notify']:DoLongHudText('error', 'Call Error.')
    end

end)




--[[ The following happens for regular calls too ]]

RegisterNUICallback('callContact', function(data, cb)
  closeGui()
  AnonCall = false
  Wait(1500)
  if callStatus == isNotInCall and hasPhone() then
    TriggerEvent('phone:setCallState', isDialing, data.name == "" and data.number or data.name)
    TriggerEvent("animation:phonecallstart")
    TriggerServerEvent('phone:callContact', data.number, true)
  else
    TriggerEvent("DoLongHudText","It appears you are already in a call, injured or with out a phone, please type /hangup to reset your calls.",2)
  end
  cb('ok')
end)

RegisterNUICallback('callContact', function(data, cb)
  closeGui()
  AnonCall = false
  Wait(1500)
  if callStatus == isNotInCall and hasPhone() then
    TriggerServerEvent('phone:callContact', data.number, true)
  else
    --TriggerEvent("DoLongHudText","It appears you are already in a call, injured or with out a phone, please type /hangup to reset your calls.",2)
    exports['mythic_notify']:DoLongHudText('error', 'Call Error.')
  end
  cb('ok')
end)

debugn = false
function t(trace)
  print(trace)
end

RegisterNetEvent('phone:failedCall')
AddEventHandler('phone:failedCall', function()
    t("Failed Call")
    endCall()
end)


RegisterNetEvent('phone:hangup')
AddEventHandler('phone:hangup', function(AnonCall)
    if AnonCall then
      t("Call Anon Hangup")
      endCall2()
    else
      t("Call Hangup")
      endCall()
    end
end)

local callid = 0

RegisterNetEvent('phone:hangupcall')
AddEventHandler('phone:hangupcall', function()
    if AnonCall then
      t("Call Anon Hangup 2")
      endCall2()
    else
      t("Call Hangup 2")
      endCall()
    end
end)

RegisterNetEvent('phone:endCalloncommand')
AddEventHandler('phone:endCalloncommand', function()
  TriggerServerEvent('phone:EndCall', mySourceID, callid, true)
end)

RegisterNetEvent('phone:otherClientEndCall')
AddEventHandler('phone:otherClientEndCall', function()
    TriggerEvent("InteractSound_CL:PlayOnOne","demo",0.1)
    --exports['mythic_notify']:SendAlert('inform', 'Your call was ended!', 5000)

    callid = 0
    myID = 0
    mySourceID = 0
    mySourceHoldStatus = false
    TriggerEvent('phone:setCallState', isNotInCall)
    onhold = false
end)

RegisterNUICallback('btnAnswer', function()
    closeGui()
    TriggerEvent("phone:answercall")
end)
RegisterNUICallback('btnHangup', function()
    closeGui()
    TriggerEvent("phone:hangup")
end)

RegisterNetEvent('phone:answercall')
AddEventHandler('phone:answercall', function()
    if callStatus == isReceivingCall and hasPhone() then
    answerCall()
    TriggerEvent("animation:phonecallstart")
    --exports['mythic_notify']:SendAlert('inform', 'You have answered a call.')
    exports['mythic_notify']:DoLongHudText('inform', 'You have answered a call.')
    callTimer = 0
  else
    --exports['mythic_notify']:SendAlert('error', 'You are not being called, injured, or you took too long.')
    exports['mythic_notify']:DoLongHudText('error', 'Call Error.')
    --TriggerEvent("DoLongHudText","You are not being called, injured, or you took too long.",2)
  end
end)

RegisterNetEvent('phone:initiateCall')
AddEventHandler('phone:initiateCall', function(srcID)
    --exports['mythic_notify']:SendAlert('inform', 'You have started a call.', 5000)
    exports['mythic_notify']:DoLongHudText('inform', 'You have started a call.')
    --TriggerEvent("DoLongHudText","You have started a call.",1)
    initiatingCall()
    if not AnonCall then
      TriggerEvent("InteractSound_CL:PlayOnOne","demo",0.1)
    end
end)

RegisterNetEvent('phone:addToCall')
AddEventHandler('phone:addToCall', function(voipchannel)
  local playerName = GetPlayerName(PlayerId())
  exports.tokovoip_script:addPlayerToRadio(tonumber(voipchannel))
end)

RegisterNetEvent('phone:callFullyInitiated')
AddEventHandler('phone:callFullyInitiated', function(srcID,sentSource)
 TriggerEvent("InteractSound_CL:PlayOnOne","demo",0.1)
  myID = srcID
  mySourceID = sentSource
  TriggerEvent('phone:setCallState', isCallInProgress)
  callTimer = 0
  TriggerEvent("phone:callactive")
end)

function drawTxt(x,y ,width,height,scale, text, r,g,b,a)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x - width/2, y - height/2 + 0.005)
end
RegisterNetEvent('phone:callactive')
AddEventHandler('phone:callactive', function()
    Citizen.Wait(100)
    local held1 = false
    local held2 = false
    while callStatus == isCallInProgress do
      local phoneString = ""
      Citizen.Wait(1)

      if onhold then
        phoneString = phoneString .. "They are on Hold | "
        if not held1 then
          TriggerEvent("DoLongHudText","You have put the caller on hold.",888)
          held1 = true
        end
      else
        phoneString = phoneString .. "Call Active | "
        if held1 then
          TriggerEvent("DoLongHudText","Your call is no longer on hold.",888)
          held1 = false
        end
      end

      if mySourceHoldStatus then
        phoneString = phoneString .. "You are on hold"
        if not held2 then
          TriggerEvent("DoLongHudText","You are on hold.",2)
          held2 = true
        end
      else
        phoneString = phoneString .. "Caller Active"
        if held2 then
          TriggerEvent("DoLongHudText","You are no longer on hold.",2)
          held2 = false
        end
      end
      drawTxt(0.97, 1.46, 1.0,1.0,0.33, phoneString, 255, 255, 255, 255)  -- INT: kmh
    end
end)



RegisterNetEvent('phone:id')
AddEventHandler('phone:id', function(sentcallid)
  callid = sentcallid
end)

RegisterNetEvent('phone:setCallState')
AddEventHandler('phone:setCallState', function(pCallState, pCallInfo)
  callStatus = pCallState
  SendNUIMessage({
    openSection = 'callState',
    callState = pCallState,
    callInfo = pCallInfo
  })
end)

RegisterNetEvent('phone:receiveCall')
AddEventHandler('phone:receiveCall', function(phoneNumber, srcID, calledNumber)
  local callFrom = getContactName(calledNumber)
  
  recentcalls[#recentcalls + 1] = { ["type"] = 1, ["number"] = calledNumber, ["name"] = callFrom }

  if not hasPhone() then
    return
  end

  if callStatus == isNotInCall then
    myID = 0
    mySourceID = srcID
    TriggerEvent('phone:setCallState', isReceivingCall, callFrom)

    receivingCall(callFrom) -- Send contact name if exists, if not send number
  else
    exports['mythic_notify']:DoLongHudText('inform', "You are receiving a call from " .. callFrom .. " but are currently already in one, sending busy response.")
  end
end)

callTimer = 0

function initiatingCall()
  callTimer = 8

  --exports['mythic_notify']:SendAlert('inform', 'You are making a call, please hold.', 7500)
  exports['mythic_notify']:DoLongHudText('inform', 'You are making a call, please hold.')

  --TriggerEvent("DoLongHudText","You are making a call, please hold.",1)
  while (callTimer > 0 and callStatus == isDialing) do
    if AnonCall and callTimer < 7 then
      TriggerEvent("InteractSound_CL:PlayOnOne","payphoneringing",0.5)
    elseif not AnonCall then
      TriggerEvent("InteractSound_CL:PlayOnOne","cellcall",0.5)
    end
    
    Citizen.Wait(2500)
    callTimer = callTimer - 1
  end
  if callStatus == isDialing or callTimer == 0 then
    endCall()
  end
end


function receivingCall(callFrom)
  callTimer = 8
  while (callTimer > 0 and callStatus == isReceivingCall) do
    if hasPhone() then
      --exports['mythic_notify']:SendAlert('inform', 'Call from: ' .. callFrom .. " /ans or /h", 5000)
      exports['mythic_notify']:DoCustomHudText('inform', 'Call from: ' .. callFrom .. " /ans or /h", 2250)
      if phoneNotifications then
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 2.0, 'cellcall', 0.5)
      end
    end
    Citizen.Wait(2300)
    callTimer = callTimer - 1
  end
  if callStatus ~= isCallInProgress then
    endCall()
  end
end

function answerCall()
    if mySourceID ~= 0 then
      TriggerServerEvent("phone:StartCallConfirmed",mySourceID)
      TriggerEvent('phone:setCallState', isCallInProgress)
      TriggerEvent("phone:callactive")
    end
end

RegisterNetEvent('phone:removefromToko')
AddEventHandler('phone:removefromToko', function(playerRadioChannel)
	exports.tokovoip_script:removePlayerFromRadio(playerRadioChannel)
end)

function endCall()
  TriggerEvent("InteractSound_CL:PlayOnOne","demo",0.1)
  if tonumber(mySourceID) ~= 0 then
    TriggerServerEvent("phone:EndCall",mySourceID,callid)
  end

  if tonumber(myID) ~= 0 then
    TriggerServerEvent("phone:EndCall",myID,callid)
  end 

  myID = 0
  mySourceID = 0
  TriggerEvent('phone:setCallState', isNotInCall)
  onhold = false
  mySourceHoldStatus = false
  AnonCall = false
  callid = 0
end

function endCall2()
  TriggerEvent("InteractSound_CL:PlayOnOne","payphoneend",0.1)
  if tonumber(mySourceID) ~= 0 then
    TriggerServerEvent("phone:EndCall",mySourceID,callid)
  end

  if tonumber(myID) ~= 0 then
    TriggerServerEvent("phone:EndCall",myID,callid)
  end 

  myID = 0
  mySourceID = 0
  TriggerEvent('phone:setCallState', isNotInCall)
  onhold = false
  mySourceHoldStatus = false
  AnonCall = false
  callid = 0
  --[[ 
  NetworkSetTalkerProximity(1.0)
  Citizen.Wait(300)
  NetworkClearVoiceChannel()
  Citizen.Wait(300)
  NetworkSetTalkerProximity(18.0)
  ]]
end


RegisterNetEvent('phone:holdToggle')
AddEventHandler('phone:holdToggle', function()
  if myID == nil then
    myID = 0
  end
  if myID ~= 0 then
    if not onhold then
      exports['mythic_notify']:DoLongHudText('inform', 'Call on hold.')
      onhold = true
      TriggerServerEvent("OnHold:Server",mySourceID,true)
    else
      exports['mythic_notify']:DoLongHudText('inform', 'Call no longer on hold.')
      TriggerServerEvent("OnHold:Server",mySourceID,false)
      onhold = false
    end
  else

    if mySourceID ~= 0 then
      if not onhold then
        exports['mythic_notify']:DoLongHudText('inform', 'Call on hold.')
        onhold = true
        TriggerServerEvent("OnHold:Server",mySourceID,true)
      else
        exports['mythic_notify']:DoLongHudText('inform', 'Call no longer on hold.')
        TriggerServerEvent("OnHold:Server",mySourceID,false)
        onhold = false
      end
    end
  end
end)

RegisterNetEvent('OnHold:Client')
AddEventHandler('OnHold:Client', function(newHoldStatus,srcSent)
    mySourceHoldStatus = newHoldStatus
    if mySourceHoldStatus then
        local playerId = GetPlayerFromServerId(srcSent)
        
        TriggerEvent("DoLongHudText","You just got put on hold.")
    else
        if not onhold then
          local playerId = GetPlayerFromServerId(srcSent)
          
        end
        TriggerEvent("DoLongHudText","Your caller is back on the line.")
    end
end)
----------

curNotifications = {}

RegisterNetEvent('phone:addnotification')
AddEventHandler('phone:addnotification', function(name,message)

  SendNUIMessage({
      openSection = "newemail"
  })

  if not hasPhone() then
    return
  end  

  if not guiEnabled then
    TriggerEvent('InteractSound_CL:PlayOnOne', 'email', 1.0)
  end

  exports['mythic_notify']:DoLongHudText('inform', 'New Email!')
  curNotifications[#curNotifications+1] = { ["name"] = name, ["message"] = message, ["time"] = GetGameTimer(), ["received"] = nil }
end)

RegisterNetEvent('YellowPageArray')
AddEventHandler('YellowPageArray', function(pass)
    local notdecoded = json.encode(pass)
    YellowPages = notdecoded

    YellowPageArray = pass
end)

RegisterNetEvent('givemethehandle')
AddEventHandler('givemethehandle', function(thehandle)
    handle = thehandle
end)

local currentTwats = {}

RegisterNetEvent('Client:UpdateTweets')
AddEventHandler('Client:UpdateTweets', function(data)
    
    SendNUIMessage({openSection = "twatter", twats = data, myhandle = handle})

end)

RegisterNetEvent('Client:UpdateTweet')
AddEventHandler('Client:UpdateTweet', function(data, handle2)
    local src = source

    local message = data
    if string.find(message,handle) then
        if handle2 ~= handle then
            SendNUIMessage({openSection = "newtweet"})
        end
    end

    if not hasPhone() then
      return
    end

    if guiEnabled then
        -- TriggerServerEvent('GetTweets', true)
    end
    
    local message = data
    if string.find(message,handle) then
    
        if handle2 ~= handle then
            if phoneNotifications then
                PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
                exports['mythic_notify']:DoLongHudText('inform', 'You were just mentioned in a tweet.')
            end
        end
    end
    
    if allowpopups and not guiEnabled then
        SendNUIMessage({openSection = "notify", handle = handle2, message = message})
    elseif allowpopups and guiEnabled then
    end
end)

function createGeneralAreaBlip(alertX, alertY, alertZ)
  local genX = alertX + math.random(-50, 50)
  local genY = alertY + math.random(-50, 50)
  local alertBlip = AddBlipForRadius(genX,genY,alertZ,75.0) 
  SetBlipColour(alertBlip,1)
  SetBlipAlpha(alertBlip,80)
  SetBlipSprite(alertBlip,9)
  Wait(60000)
  RemoveBlip(alertBlip)
end

RegisterNetEvent('phone:triggerHOAAlert')
AddEventHandler('phone:triggerHOAAlert', function(pAlertLocation, pAlertX, pAlertY, pAlertZ)
  local hoaRank = GroupRank("hoa")
  if hoaRank > 0 then
    SendNUIMessage({
      openSection = "hoa-notification",
      alertLocation = pAlertLocation
    })
    createGeneralAreaBlip(pAlertX, pAlertY, pAlertZ)
  end
end)

local lastTime = 0;
RegisterNetEvent('phone:triggerPager')
AddEventHandler('phone:triggerPager', function()
  --local job = exports["isPed"]:isPed("myjob")
  if job == "doctor" then
    local currentTime = GetGameTimer()
    if lastTime == 0 or lastTime + (5 * 60 * 1000) < currentTime then
      TriggerServerEvent('InteractSound_CL:PlayWithinDistance', 3.0, 'pager', 0.4)
      SendNUIMessage({
        openSection = "newpager"
      })
      lastTime = currentTime
    end
  end
end)

RegisterCommand('closephone', function(source)
  closeGui()
end)

RegisterNUICallback('loadUserGPS', function(data)
    TriggerEvent("GPS:SetRoute",data.house_id,data.house_type)
end)

RegisterNUICallback('btnTwatter', function()
  TriggerServerEvent('GetTweets')
end)

RegisterNUICallback('newTwatSubmit', function(data, cb)
    closeGui()
    TriggerServerEvent('Tweet', handle, data.twat, data.time)   
end)

RegisterNUICallback('btnCamera', function()
  SetNuiFocus(false,false)
  SetNuiFocus(true,true)
end)

RegisterNUICallback('notifications', function()

    lstnotifications = {}

    for i = 1, #curNotifications do

        local message2 = {
          id = tonumber(i),
          name = curNotifications[tonumber(i)].name,
          message = curNotifications[tonumber(i)].message
        }

        lstnotifications[#lstnotifications+1]= message2
    end

    
  SendNUIMessage({openSection = "notifications", list = lstnotifications})

end)

RegisterNetEvent('phone:loadSMSOther')
AddEventHandler('phone:loadSMSOther', function(messages,mynumber)
  openGui()
  lstMsgs = {}
  if (#messages ~= 0) then
    for k,v in pairs(messages) do
      if v ~= nil then
        local msgDisplayName = ""
        if v.receiver == mynumber then
          msgDisplayName = getContactName(v.sender)
        else
          msgDisplayName = getContactName(v.receiver)
        end
        local message = {
          id = tonumber(v.id),
          msgDisplayName = msgDisplayName,
          sender = tonumber(v.sender),
          receiver = tonumber(v.receiver),
          date = tonumber(v.date),
          message = v.message
        }
        lstMsgs[#lstMsgs+1]= message
      end
    end
  end
  SendNUIMessage({openSection = "messagesOther", list = lstMsgs, clientNumber = mynumber})
end)


RegisterNUICallback('accountInformation', function()
  TriggerServerEvent('getAccountInfo')
end)

RegisterNetEvent('getAccountInfo')
AddEventHandler('getAccountInfo', function(cash, bank, licences)

    --[[ local licencesString = '<br>'
    for k, v in pairs(licences) do
        licencesString = licencesString .. v .. "<br>"
    end ]]

    local responseObject = {
        cash = cash,
        bank = bank,
        job = ESX.PlayerData.job.name .. ', ' .. ESX.PlayerData.job.grade_label,
        secondaryJob = "Coming soon.",
        licenses = licences, 
        pagerStatus = true
    }
    --exports['mythic_notify']:SendAlert('inform', 'Basic mode.', 2500)
    SendNUIMessage({openSection = "accountInformation", response = responseObject})
end)


RegisterNetEvent('phone:newSMS')
AddEventHandler('phone:newSMS', function(id, number, message, mypn, date, recip)
  lastnumber = number
  if hasPhone() then
    SendNUIMessage({
        openSection = "newsms"
    })
      TriggerServerEvent('phone:getSMS') 
    if phoneNotifications then
	  exports['mythic_notify']:DoLongHudText('inform', 'You just received a new SMS.')
      PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
    end
  end
end)

-- SMS Events
RegisterNetEvent('phone:loadSMS')
AddEventHandler('phone:loadSMS', function(messages,mynumber)

  lstMsgs = {}
  if (#messages ~= 0) then
    for k,v in pairs(messages) do
      if v ~= nil then
        local msgDisplayName = ""
        if v.receiver == mynumber then
          msgDisplayName = getContactName(v.sender)
        else
          msgDisplayName = getContactName(v.receiver)
        end
        local message = {
          id = tonumber(v.id),
          msgDisplayName = msgDisplayName,
          sender = tonumber(v.sender),
          receiver = tonumber(v.receiver),
          date = v.date,
          message = v.message
        }
        lstMsgs[#lstMsgs+1]= message
      end
    end
  end
  SendNUIMessage({openSection = "messages", list = lstMsgs, clientNumber = mynumber})
end)

RegisterNetEvent('phone:sendSMS')
AddEventHandler('phone:sendSMS', function(number, message)
  if(number ~= nil and message ~= nil) then
    TriggerServerEvent('phone:sendSMS', number, message)
    Citizen.Wait(1000)
    TriggerServerEvent('phone:getSMSc')
  else
    phoneMsg("You must fill in a number and message!")
  end
end)

local lastnumber = 0

RegisterNetEvent('animation:sms')
AddEventHandler('animation:sms', function(enable)
  DestroyPhoneProp()
  local lPed = PlayerPedId()
  inPhone = enable
  
  RequestAnimDict("cellphone@")
  while not HasAnimDictLoaded("cellphone@") do
    Citizen.Wait(0)
  end

  if not isInTrunk then
    TaskPlayAnim(lPed, "cellphone@", "cellphone_text_in", 2.0, 3.0, -1, 49, 0, 0, 0, 0)
  end
  Citizen.Wait(300)
  if inPhone then
	AttachPhoneProp()
    Citizen.Wait(150)
    while inPhone do
		--[[
      if isDead then
        closeGui()
        inPhone = false
      end]]
      if not isInTrunk and not IsEntityPlayingAnim(lPed, "cellphone@", "cellphone_text_read_base", 3) and not IsEntityPlayingAnim(lPed, "cellphone@", "cellphone_swipe_screen", 3) then
        TaskPlayAnim(lPed, "cellphone@", "cellphone_text_read_base", 2.0, 3.0, -1, 49, 0, 0, 0, 0)
      end    
      Citizen.Wait(1)
    end
    if not isInTrunk then
      ClearPedTasks(PlayerPedId())
    end
  else
    if not isInTrunk then
      Citizen.Wait(100)
      ClearPedTasks(PlayerPedId())
      TaskPlayAnim(lPed, "cellphone@", "cellphone_text_out", 2.0, 1.0, 5.0, 49, 0, 0, 0, 0)
      Citizen.Wait(400)
	  DestroyPhoneProp()
      Citizen.Wait(400)
      ClearPedTasks(PlayerPedId())
    else
	  DestroyPhoneProp()
    end
  end
end)


RegisterNetEvent('phone:reply')
AddEventHandler('phone:reply', function(message)
  if lastnumber ~= 0 then
    TriggerServerEvent('phone:sendSMS', lastnumber, message)
    TriggerEvent("chatMessage", "You", 6, message)
  else
    phoneMsg("No user has recently SMS'd you.")
  end
end)



function phoneMsg(inputText)
  TriggerEvent("chatMessage", "Service ", 5, inputText)
end


RegisterNetEvent("house:returnKeys")
AddEventHandler("house:returnKeys", function(pSharedKeys)
  SendNUIMessage({
    openSection = "manageKeys",
    sharedKeys = pSharedKeys
  })
end)


RegisterNetEvent('phone:deleteSMS')
AddEventHandler('phone:deleteSMS', function(id)
  table.remove( lstMsgs, tablefindKeyVal(lstMsgs, 'id', tonumber(id)))
  phoneMsg("Message Removed!")
end)

function getContactName(number)
  if (#lstContacts ~= 0) then
    for k,v in pairs(lstContacts) do
      if v ~= nil then
        if (v.number ~= nil and tonumber(v.number) == tonumber(number)) then
          return v.name
        end
      end
    end
  end

  return number
end

-- Contact Events
RegisterNetEvent('phone:loadContacts')
AddEventHandler('phone:loadContacts', function(contacts)

  lstContacts = {}

  if (#contacts ~= 0) then
    for k,v in pairs(contacts) do
      if v ~= nil then
        local contact = {
        }
        if activeNumbersClient['active' .. tonumber(v.number)] then
        
          contact = {
            name = v.name,
            number = v.number,
            activated = 1
          }
        else
    
          contact = {
            name = v.name,
            number = v.number,
            activated = 0
          }
        end
        lstContacts[#lstContacts+1]= contact

        SendNUIMessage({
          newContact = true,
          contact = contact,
        })
      end
    end
  else
       SendNUIMessage({
        emptyContacts = true
      })
  end
end)

RegisterNetEvent('phone:addContact')
AddEventHandler('phone:addContact', function(name, number)
  if(name ~= nil and number ~= nil) then
    number = tonumber(number)
    TriggerServerEvent('phone:addContact', name, number)
  else
     phoneMsg("You must fill in a name and number!")
  end
end)

RegisterNetEvent('phone:newContact')
AddEventHandler('phone:newContact', function(name, number)
  local contact = {
      name = name,
      number = number
  }
  lstContacts[#lstContacts+1]= contact

  SendNUIMessage({
    newContact = true,
    contact = contact,
  })
  phoneMsg("Contact Saved!")
  TriggerServerEvent('getContacts')
end)

RegisterNetEvent('phone:deleteContact')
AddEventHandler('phone:deleteContact', function(name, number)
  local contact = {
      name = name,
      number = number
  }

  table.remove( lstContacts, tablefind(lstContacts, contact))
  
  SendNUIMessage({
    removeContact = true,
    contact = contact,
  })
  
  TriggerServerEvent('deleteContact', name, number)
end)

------------- BLACK MARKET || VPN
RegisterNUICallback('btnBlackMarket', function(data, cb)

  if not vpnConnected then
    exports['mythic_notify']:DoLongHudText('inform', 'You are not connected to VPN.')
    return
  end

  TriggerServerEvent('conx_crafting:GetPostedOffers')
  cb('ok')
end)

RegisterNUICallback('bmRejectOffer', function(data, cb)
  closeGui()

  TriggerServerEvent('phone:RejectClientOffer')
  cb('ok')
end)

RegisterNUICallback('bmAcceptOffer', function(data, cb)
  closeGui()

  TriggerServerEvent('conx_crafting:AcceptOffer', data.offerId)
  cb('ok')
end)

RegisterNetEvent('phone:blackmarketOffers')
AddEventHandler('phone:blackmarketOffers', function(offers)
  local curOffers = {}

  for k, v in pairs(offers) do
    table.insert(curOffers, {
      id = v.offerId,
      label = v.offerLabel,
      name = v.offerItem,
      qty = v.offerQty,
      price = v.offerPrice
    })
  end

  SendNUIMessage({
    openSection = "blackMarket",
    offers = curOffers
  })       

end)


RegisterNUICallback('btnVPN', function(data, cb)
  closeGui()

  if vpnConnected then
    vpnConnected = not vpnConnected
    exports['mythic_notify']:DoLongHudText('inform', 'You have disconnected from VPN.')
    return
  end

  local hasvpn = exports['conx_inventory']:hasEnoughOfItem('vpn_router', 1)

  if hasvpn then
    TriggerEvent('phone:toggleVPN')
  else
    exports['mythic_notify']:DoLongHudText('error', 'You do not have a VPN Router')
  end

  -- TriggerServerEvent('phone:toggleVPN')
  cb('ok')
end)

RegisterNetEvent('phone:useVPN')
AddEventHandler('phone:useVPN', function()

  if not hasPhone() then
    exports['mythic_notify']:DoLongHudText('error', 'You do not have a phone.')
    return
  end

  if vpnConnected then
    vpnConnected = not vpnConnected
    exports['mythic_notify']:DoLongHudText('inform', 'You have disconnected from VPN.')
    return
  end

  local hasvpn = exports['conx_inventory']:hasEnoughOfItem('vpn_router', 1)

  if hasvpn then
    TriggerEvent('phone:toggleVPN')
  else
    exports['mythic_notify']:DoLongHudText('error', 'You do not have a VPN Router')
  end  
end)

RegisterNetEvent('phone:toggleVPN')
AddEventHandler('phone:toggleVPN', function()
	ESX.Progressbar("unique_action_name", "Connecting to VPN", 10000, false, false, {
		disableMovement = true,
		disableCarMovement = true,
		disableMouse = false,
		disableCombat = true,
	}, {}, {}, {}, function() -- Done
		vpnConnected = not vpnConnected
        exports['mythic_notify']:DoLongHudText('inform', 'You have successfully connected to VPN.')
        while vpnConnected do
          local hasvpn = exports['conx_inventory']:hasEnoughOfItem('vpn_router', 1)

          if not hasvpn then
            vpnConnected = false
            exports['mythic_notify']:DoLongHudText('inform', 'You have disconnected from VPN.')
            return
          end
          
          Citizen.Wait(1000)
        end
	end)

end)



function tablefind(tab,el)
  for index, value in pairs(tab) do
    if value == el then
      return index
    end
  end
end

function tablefindKeyVal(tab,key,val)
  for index, value in pairs(tab) do
    if value ~= nil  and value[key] ~= nil and value[key] == val then
      return index
    end
  end
end


RegisterNetEvent('resetPhone')
AddEventHandler('resetPhone', function()
     SendNUIMessage({
      emptyContacts = true
    })

end)

local weather = ""
RegisterNetEvent("kWeatherSync")
AddEventHandler("kWeatherSync", function(pWeather)
  weather = pWeather
end)

RegisterNUICallback('getWeather', function(data, cb)
  SendNUIMessage({openSection = "weather", weather = weather})
  cb("ok")
end)

function MyPlayerId()
  for i=0,256 do
    if(NetworkIsPlayerActive(i) and GetPlayerPed(i) == PlayerPedId()) then return i end
  end
  return nil
end

function Voip(intPlayer, boolSend)
  --Citizen.InvokeNative(0x97DD4C5944CC2E6A, intPlayer, boolSend)
end

RegisterNetEvent('sendMessagePhoneN')
AddEventHandler('sendMessagePhoneN', function(phonenumberlol)
  TriggerServerEvent('message:tome', phonenumberlol)

  local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
	if closestPlayer ~= -1 and closestDistance <= 5.0 then
    TriggerServerEvent('message:inDistanceZone', GetPlayerServerId(closestPlayer), phonenumberlol)
  else    
    --exports['mythic_notify']:SendAlert('inform', 'No closest player.')
  end
end)

-- PHONE PROPS
local phoneProp = 0

function DestroyPhoneProp()
  if DoesEntityExist(phoneProp) then
    DeleteEntity(phoneProp)
    phoneProp = 0
  end
end

function AttachPhoneProp()
  DestroyPhoneProp()
  attachModelPhone = GetHashKey("prop_npc_phone_02")
  SetCurrentPedWeapon(PlayerPedId(), 0xA2719263)
  local bone = GetPedBoneIndex(PlayerPedId(), 57005)
  --local x,y,z = table.unpack(GetEntityCoords(PlayerPedId(), true))
  RequestModel(attachModelPhone)
  while not HasModelLoaded(attachModelPhone) do
    Citizen.Wait(100)
  end
  phoneProp = CreateObject(attachModelPhone, 1.0, 1.0, 1.0, 1, 1, 0)
  AttachEntityToEntity(phoneProp, PlayerPedId(), bone, 0.14, 0.01, -0.02, 110.0, 120.0, -15.0, 1, 0, 0, 0, 2, 1)
end

-------------------- BUSINESS TASKS
RegisterNUICallback('btnBusiness', function(data, cb)

  ESX.TriggerServerCallback('conx_company:getBusinesses', function(businesses)
    local business = {}

    for k, v in pairs(businesses) do
      table.insert(business, {
        name = v.shop_name,
        id = v.id,
        funds = ESX.Math.GroupDigits(v.shop_funds),
        stocks = ESX.Math.GroupDigits(v.shop_stocks)
      })
    end


    SendNUIMessage({
      openSection = "businessList", 
      business = business
    })

  end)  
  
  cb("ok")
end)

RegisterNUICallback('businessTasks', function(data, cb)
  TriggerServerEvent('conx_company:GetBusinessTask', data.name)
  cb("ok")
end)

RegisterNUICallback('AssignBusinessTask', function(data, cb)
  print(data.taskid)

  TriggerServerEvent('conx_company:AssignBusinessTask', data.businessname, data.taskid, data.targetid, data.taskpayout)
  cb("ok")
end)

RegisterNUICallback('CancelBusinessTask', function(data, cb)

  TriggerServerEvent('conx_company:CancelBusinessTask', data.businessname, data.taskid)
  cb("ok")
end)

RegisterNetEvent("phone:BusinessTasks")
AddEventHandler("phone:BusinessTasks", function(businessTasks)
  local tasks = {}

  for k, v in pairs(businessTasks) do
    table.insert(tasks, {
      id = v.taskId,
      businessName = v.businessName,
      title = v.taskTitle,
      deliveryid = v.taskDeliveryId,
      reward = ESX.Math.GroupDigits(v.reward),
      assignedTo = v.assignedTo,
      assignedName = v.assignedName,
      status = v.taskStatus
    })

  end

  SendNUIMessage({
    openSection = "businessTasks",
    tasks = tasks
  })
end)

-------------------- PERSONAL TASKS
RegisterNUICallback('btnMyTasks', function(data, cb)
  TriggerServerEvent('conx_company:GetMyTasks')  
  cb("ok")
end)

RegisterNUICallback('acceptTask', function(data, cb)
  closeGui()
  TriggerServerEvent('conx_company:AcceptBusinessTask', data.businessname, data.taskid)  
  cb("ok")
end)

RegisterNetEvent("phone:MyTasks")
AddEventHandler("phone:MyTasks", function(taskList)
  SendNUIMessage({
    openSection = "myTasks",
    tasks = taskList
  })
end)

----------------------- BOOMBOX
local boomboxList = {}
local playingBoombox = nil
local listeningRadio = false
local canTalk = false

RegisterNetEvent("phone:DropBoombox")
AddEventHandler("phone:DropBoombox", function()
  DropBoomBox()
end)

RegisterNetEvent("phone:DeleteBoombox")
AddEventHandler("phone:DeleteBoombox", function(deviceid)
  if NetworkDoesNetworkIdExist(deviceid) then
    local wutdis = NetworkGetEntityFromNetworkId(deviceid)
    ESX.Game.DeleteObject(wutdis)     
  end
end)

RegisterNUICallback('PairDevice', function(data, cb)
  closeGui()

  local deviceid = tonumber(data.deviceid)
  local volume = tonumber(data.volume)
  local ytlink = data.ytlink

  if not NetworkDoesNetworkIdExist(deviceid) then
    exports['mythic_notify']:DoLongHudText('error', "Device couldn't be found.")
    return
  end

  local pedCoords = GetEntityCoords(PlayerPedId())
  local curObj = NetworkGetEntityFromNetworkId(deviceid)
  local objCoords = GetEntityCoords(curObj)
  local dist = GetDistanceBetweenCoords(pedCoords, objCoords, 1)

  if dist > 10.0 then
    exports['mythic_notify']:DoLongHudText('error', "You are too far from the device.")
    return
  end

  TriggerServerEvent('phone:PairDevice', deviceid, ytlink, volume)  
end)

function DropBoomBox()
  local pedCoords = GetEntityCoords(PlayerPedId())

  local object = GetClosestObjectOfType(pedCoords, 5.0, GetHashKey('prop_boombox_01'), false, false, false)

  if DoesEntityExist(object) then
    exports['mythic_notify']:DoLongHudText('error', "You are too close from other boombox.")
    return
  end

  loadAnimDict("anim@heists@money_grab@briefcase")

  TaskPlayAnim(PlayerPedId(), "anim@heists@money_grab@briefcase", "put_down_case", 8.0, -8.0, -1, 1, 0, false, false, false)
  Citizen.Wait(1000)
  ClearPedTasks(PlayerPedId())

  TriggerEvent('esx:spawnObject', 'prop_boombox_01')  
  Citizen.Wait(1500)

  local object = GetClosestObjectOfType(pedCoords, 5.0, GetHashKey('prop_boombox_01'), false, false, false)
  local deviceid = NetworkGetNetworkIdFromEntity(object) 

  TriggerServerEvent('phone:PlaceBoombox', deviceid)
end

Citizen.CreateThread(function()

  while true do
    local sleep = 500
    local pedCoords = GetEntityCoords(PlayerPedId())

    local object = GetClosestObjectOfType(pedCoords, 1.0, GetHashKey('prop_boombox_01'), false, false, false)
    local closestObject = nil

    if DoesEntityExist(object) then
      local health = GetEntityHealth(object)

      if health <= 0 then
        local deviceid = NetworkGetNetworkIdFromEntity(object)
        local wutdis = NetworkGetEntityFromNetworkId(deviceid)
        TriggerServerEvent('phone:PickupBoombox', deviceid, false)
        Citizen.Wait(1000)       
      end

      closestObject = object
    end

    if closestObject ~= nil and NetworkDoesNetworkIdExist(NetworkGetNetworkIdFromEntity(closestObject)) then
      sleep = 1
      local objCoords = GetEntityCoords(closestObject)
      local deviceid = NetworkGetNetworkIdFromEntity(closestObject)
      FreezeEntityPosition(closestObject, true)

      if boomboxList[deviceid] ~= nil then
        DrawText3Ds(objCoords.x, objCoords.y, objCoords.z, "Bluetooth ID: " .. deviceid)

        
        if IsControlJustReleased(0, 38) then
            local finished = exports['conx_skillbar']:skillBar(5000, math.random(3, 5))
            if finished >= 100 then
              local wutdis = NetworkGetEntityFromNetworkId(deviceid)
              TriggerServerEvent('phone:PickupBoombox', deviceid, true)

              TaskPlayAnim(PlayerPedId(), "anim@heists@money_grab@briefcase", "put_down_case", 8.0, -8.0, -1, 1, 0, false, false, false)
              Citizen.Wait(1000)
              ClearPedTasks(PlayerPedId())        
              Citizen.Wait(1000)
            end        
        end
      end      
    end

    Citizen.Wait(sleep)
  end

end)

RegisterNetEvent("phone:UpdateBoomboxList")
AddEventHandler("phone:UpdateBoomboxList", function(newList)
  boomboxList = newList
end)

Citizen.CreateThread(function()

  while true do
    local sleep = 500
    local closestBoombox = nil
    
    for k, v in pairs(boomboxList) do

      if NetworkDoesNetworkIdExist(k) then
        local pedCoords = GetEntityCoords(PlayerPedId())
        local curObj = NetworkGetEntityFromNetworkId(k)
        local objDistance = GetEntityCoords(curObj)
        local dist = GetDistanceBetweenCoords(pedCoords, objDistance, 1)

        if dist < 15.0 and boomboxList[k].ytlink ~= nil then
          closestBoombox = k
        elseif (dist > 15.0 and boomboxList[k].playing) then
          boomboxList[k].playing = false
		  
		  if listeningRadio then
            listeningRadio = false
            TriggerEvent('conx_radio:StopListeningRadio')
          end

          SendNUIMessage({
              boombox = 'StopBoombox'
          })          
        end
      end

    end

    if closestBoombox ~= nil then
      if not boomboxList[closestBoombox].playing and boomboxList[closestBoombox].ytlink ~= nil then
        boomboxList[closestBoombox].playing = true
        playingBoombox = closestBoombox

        if tonumber(boomboxList[closestBoombox].ytlink) == 19.19 then           
          print('Radio Station On')
          listeningRadio = true

          exports['mythic_notify']:DoLongHudText('inform', "You are now listening to Weazel News 19.19 Radio Station!")
          TriggerEvent('conx_radio:ListenRadio')
          SendNUIMessage({
              boombox = 'StopBoombox'
          })          
        else
          print('Play! ' .. closestBoombox )
          print('Volume: ' .. boomboxList[closestBoombox].volume )
          SendNUIMessage({
              boombox = 'PlayBoombox',
              ytlink = boomboxList[closestBoombox].ytlink,
              volume = boomboxList[closestBoombox].volume
          })           
        end  

      end
    end

    if closestBoombox ~= playingBoombox then

      if playingBoombox ~= nil then
        if (boomboxList[playingBoombox] == nil) or (GetPlayerServerId(PlayerId()) == boomboxList[playingBoombox].connected and boomboxList[playingBoombox].ytlink ~= nil) then
            TriggerServerEvent('phone:UnpairDevice', playingBoombox)
            exports['mythic_notify']:DoLongHudText('error', "You got disconnected from the boombox.")
        end
      end
	  
	  playingBoombox = nil

      if listeningRadio then
        listeningRadio = false
        TriggerEvent('conx_radio:StopListeningRadio')
      end

      SendNUIMessage({
          boombox = 'StopBoombox'
      })    
  
    end

    Citizen.Wait(sleep)
  end

end)

RegisterNetEvent("phone:RadioGuestTalk")
AddEventHandler("phone:RadioGuestTalk", function(state)
  canTalk = state
end)

local tunedIn = false

RegisterCommand('carradio', function(source)
  local playerPed = PlayerPedId()

  if IsPedInAnyVehicle(playerPed, true) then

    if DoesPlayerVehHaveRadio() then
      tunedIn = not tunedIn

      if tunedIn then
        listeningRadio = true
        TriggerEvent('conx_radio:ListenRadio')
        exports['mythic_notify']:DoLongHudText('inform', "You are now listening to Weazel News 19.19 Radio Station!")
      else
        listeningRadio = false
        TriggerEvent('conx_radio:StopListeningRadio')
        exports['mythic_notify']:DoLongHudText('inform', "You are no longer tuned in to Weazel News 19.19 Radio Station!")
      end
    end

    TriggerEvent("phone:CarRadio")
  end

  

end)

Citizen.CreateThread(function(source)

  while true do
    local sleep = 500

    if listeningRadio and not canTalk then
      sleep = 1
      DisableControlAction(0, 19, true) -- Radio
    end

    Citizen.Wait(sleep)
  end

end)

RegisterNetEvent("phone:CarRadio")
AddEventHandler("phone:CarRadio", function()

  Citizen.CreateThread(function()
    while true do
      local sleep = 500

      if tunedIn and not IsPedInAnyVehicle(PlayerPedId(), true) then
        tunedIn = false
        listeningRadio = false
        TriggerEvent('conx_radio:StopListeningRadio')
        exports['mythic_notify']:DoLongHudText('inform', "You are no longer tuned in to Weazel News 19.19 Radio Station!")        
      end

      if not tunedIn then
        return
      end

      Citizen.Wait(sleep)
    end
  end)

end)


---- ETO YUNG Twitter NA BAGO PO =)

Citizen.CreateThread(function()
  local focus = true
  local takingPic = false
  while true do
    local sleep = 500

    if selfieMode then
      sleep = 1
      if IsControlJustPressed(0, 177) then
        selfieMode = false
        DestroyMobilePhone()
        CellCamActivate(false, false)
      end

      if IsControlJustPressed(0, 176) and not takingPic then
        ESX.TriggerServerCallback('conx_news:Uploader', function(file)
            if file then
              takingPic = true             
              exports['screenshot-basic']:requestScreenshotUpload(file, 'files[]', function(data)
                  local image = json.decode(data)
                  lastSavedPhoto = image.attachments[1].proxy_url
                  takingPic = false       
                  selfieMode = false
                  DestroyMobilePhone()
                  CellCamActivate(false, false) 

                  local fields = {
                      { label = "Image Link (Copy)", type = "text", disabled = true, value = lastSavedPhoto, icon = "linked_camera", element = "textarea" },        
                  }

                  TriggerEvent('conx_inputs:OpenInputs', fields, true, function(submitted, data)
                      if submitted then
                      end
                  end)

              end)  
            end
        end) 
      end
      HideHudComponentThisFrame(7)
      HideHudComponentThisFrame(8)
      HideHudComponentThisFrame(9)
      HideHudComponentThisFrame(6)
      HideHudComponentThisFrame(19)
      HideHudAndRadarThisFrame()
    -- else
    --   selfieMode = false
    --   DestroyMobilePhone()
    --   CellCamActivate(false, false)
    end


    Citizen.Wait(sleep)
  end
end)


























