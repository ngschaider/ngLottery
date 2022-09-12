local ESX = nil;
TriggerEvent("esx:getSharedObject", function(obj)
	ESX = obj;
end);

local menuPool = NativeUI.CreatePool();

-- Add Blips
Citizen.CreateThread(function()
	for _,lottery in pairs(Config.Lotteries) do
		if lottery.blip then
			local size = lottery.blip.size or 1.0;
			local color = lottery.blip.color or 3;
			local type = lottery.blip.type;
			local pos = vector3(lottery.pos[1], lottery.pos[2], lottery.pos[3]);
			
			local handle = AddBlipForCoord(pos);
			SetBlipSprite(handle, type);
			SetBlipDisplay(handle, 4);
			SetBlipScale(handle, size);
			SetBlipColour(handle, color);
			--SetBlipAsShortRange(handle, true);
			BeginTextCommandSetBlipName("STRING");
			AddTextComponentString(lottery.label);
			EndTextCommandSetBlipName(handle);
		end
	end
end);

-- draw markers
Citizen.CreateThread(function()
	while true do
		for _,lottery in pairs(Config.Lotteries) do
			if lottery.marker then
				local type = lottery.marker.type or 1;
				local size = lottery.marker.size or 1.0;
				local pos = vector3(lottery.pos[1], lottery.pos[2], lottery.pos[3]);
				
				local dir = vector3(0.0, 0.0, 0.0);
				local rot = vector3(0.0, 0.0, 0.0);
				local scale = vector3(1.0, 1.0, 1.0);
				
				DrawMarker(type, pos, dir, rot, scale, 100, 255, 0, 100, false, false, 2, nil, nil, false);
			end
		end
		Citizen.Wait(0);
	end
end);

-- process menupool
Citizen.CreateThread(function()
	while true do 
		menuPool:ProcessMenus();
		Citizen.Wait(0);
	end
end);

-- open menu on keypress
Citizen.CreateThread(function()
	while true do		
		local coords = GetEntityCoords(PlayerPedId());
		
		for _,lottery in pairs(Config.Lotteries) do						
			local pos = vector3(lottery.pos[1], lottery.pos[2], lottery.pos[3]);
			if GetDistanceBetweenCoords(coords, pos, true) < lottery.radius then
				if not menuPool:IsAnyMenuOpen() then
					ESX.ShowHelpNotification(_U("menu_open_hint"));
					
					if IsControlJustPressed(0, 51) then
						OpenMenu(lottery);
					end
				end
			end
		end

		Citizen.Wait(0);
	end
end);

function GetNumberList(startNum, endNum, increment)
	local numbers = {};

	for i = startNum, endNum, increment do
		table.insert(numbers, i);
	end
	
	return numbers;
end

function OpenMenu(lottery)
	local menu = NativeUI.CreateMenu(lottery.label, "");
	menuPool:Clear();
	menuPool:Add(menu);
	
	ESX.TriggerServerCallback("ngLottery:GetLotteryInfo", function(info)
		if info.reward then
			local rewardItem = NativeUI.CreateItem(_U("menu_reward", info.reward), "");
			menu:AddItem(rewardItem);
			
			local payoutItem = NativeUI.CreateItem(_U("menu_payout"), "");
			menu:AddItem(payoutItem);
			payoutItem.Activated = function()
				menu:Visible(false);
				ESX.TriggerServerCallback("ngLottery:RequestPayout", function()
					OpenMenu(lottery);
				end, lottery.id);
			end;
		else
			local potAmount = NativeUI.CreateItem(_U("menu_pot_amount", info.sum), "");
			menu:AddItem(potAmount);
			
			local ticketPrice = NativeUI.CreateItem(_U("ticket_price", lottery.price), "");
			menu:AddItem(ticketPrice);
			
			local ticketAmount = NativeUI.CreateItem(_U("ticket_amount", info.ticket_amount), "");
			menu:AddItem(ticketAmount);
				
			local buyTicket = NativeUI.CreateListItem(_U("menu_buy_tickets"), GetNumberList(0, 100, 1), 1, "");
			menu:AddItem(buyTicket);
			
			buyTicket.OnListSelected = function(menu, item, newindex)
				local value = buyTicket:IndexToItem(newindex);
				menu:Visible(false);
				ESX.TriggerServerCallback("ngLottery:BuyTickets", function()
				
				end, lottery.id, value);
			end
		end
			
		menu:Visible(true);
		menuPool:MouseControlsEnabled(false);
		menuPool:MouseEdgeEnabled(false);
		menuPool:RefreshIndex();
	end, lottery.id);	
end