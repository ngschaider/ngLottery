local ESX = nil;
TriggerEvent("esx:getSharedObject", function(obj)
	ESX = obj;
end);

ESX.RegisterServerCallback("ngLottery:GetLotteryInfo", function(src, cb, lotteryId)
	local xPlayer = ESX.GetPlayerFromId(src);
	local lottery = GetLotteryConfig(lotteryId);
	
	local data = {};
	
	MySQL.Async.fetchAll("SELECT SUM(ticket_amount) AS sum FROM ng_lottery WHERE lottery_id=@lottery_id", {
		["@lottery_id"] = lotteryId,
	}, function(sumResults) 
		if sumResults and #sumResults > 0 then
			local sum = sumResults[1].sum or 0;
			sum = math.floor(sum * lottery.price * lottery.rewardPercentage);
			MySQL.Async.fetchAll("SELECT * FROM ng_lottery WHERE identifier=@identifier AND lottery_id=@lottery_id", {
				["identifier"] = xPlayer.identifier,
				["@lottery_id"] = lotteryId,
			}, function(results)
				if results and #results > 0 then
					local result = results[1];
					result.sum = sum;
					cb(result);
				else
					cb({
						sum = sum,
						ticket_amount = 0;
						reward = nil;
					});
				end
			end);
		end
	end);
	
	
end);

ESX.RegisterServerCallback("ngLottery:BuyTickets", function(src, cb, lotteryId, number)
	local xPlayer = ESX.GetPlayerFromId(src);
	local lottery = GetLotteryConfig(lotteryId);

	if xPlayer.getMoney() < lottery.price * number then
		xPlayer.showNotification(_U("not_enough_money"));
		return;
	end
	
	MySQL.Async.fetchAll("SELECT * FROM ng_lottery WHERE identifier=@identifier AND lottery_id=@lottery_id", {
		["identifier"] = xPlayer.identifier,
		["@lottery_id"] = lottery.id,
	}, function(results)
		if not results or #results < 1 then 
			MySQL.Async.execute("INSERT INTO ng_lottery (identifier, ticket_amount, lottery_id) VALUES (@identifier, @ticket_amount, @lottery_id)", {
				["@identifier"] = xPlayer.identifier,
				["@ticket_amount"] = number,
				["@lottery_id"] = lottery.id,
			}, function()
				xPlayer.showNotification(_U("tickets_bought", number));
				OnTicketsBought(lottery);
			end);
		else
			MySQL.Async.execute("UPDATE ng_lottery SET ticket_amount=@ticket_amount WHERE identifier=@identifier AND lottery_id=@lottery_id", {
				["@identifier"] = xPlayer.identifier,
				["@ticket_amount"] = results[1].ticket_amount + number,
				["@lottery_id"] = lottery.id,
			}, function()
				xPlayer.showNotification(_U("tickets_bought", number));
				OnTicketsBought(lottery);
			end);
		end
		
		xPlayer.removeMoney(lottery.price * number);
	end);
end);

ESX.RegisterServerCallback("ngLottery:RequestPayout", function(src, cb, lotteryId)
	local xPlayer = ESX.GetPlayerFromId(src);
	local lottery = GetLotteryConfig(lotteryId);
	
	MySQL.Async.fetchAll("SELECT * FROM ng_lottery WHERE identifier=@identifier AND lottery_id=@lottery_id", {
		["identifier"] = xPlayer.identifier,
		["@lottery_id"] = lottery.id,
	}, function(results)
		if results and #results > 0 then
			local reward = results[1].reward;
			
			if reward then
				MySQL.Async.execute("DELETE FROM ng_lottery WHERE identifier=@identifier AND lottery_id=@lottery_id", {
					["@identifier"] = xPlayer.identifier,
					["@lottery_id"] = lottery.id,
				});
				xPlayer.addMoney(reward);
				xPlayer.showNotification(_U("payout_complete", reward));
				cb();
			end
		end
	end);
end);

function GetLotteryConfig(id)
	for _,lottery in pairs(Config.Lotteries) do
		if lottery.id == id then
			return lottery;
		end
	end
	
	return nil;
end

function EndLottery(lottery)
	MySQL.Async.fetchAll("SELECT * FROM ng_lottery WHERE lottery_id=@lottery_id", {
		["@lottery_id"] = lottery.id,
	}, function(results)
		if results and #results > 0 then
			
			local pot = {};
			
			for k,v in pairs(results) do
				for i=1, v.ticket_amount, 1 do
					table.insert(pot, v.identifier);
				end
			end
			
			math.randomseed(GetGameTimer());
			local randomIndex = math.random(1, #pot);
			
			local winner = pot[randomIndex];
			
			MySQL.Async.execute("UPDATE ng_lottery SET reward=0 WHERE lottery_id=@lottery_id AND identifier<>@identifier", {
				["@lottery_id"] = lottery.id,
				["@identifier"] = winner,
			});
			
			MySQL.Async.fetchAll("SELECT SUM(ticket_amount) AS sum FROM ng_lottery WHERE lottery_id=@lottery_id", {
				["@lottery_id"] = lottery.id,
			}, function(sumResults) 
				if sumResults and #sumResults > 0 then
					local sum = sumResults[1].sum or 0;
					sum = math.floor(sum * lottery.price * lottery.rewardPercentage);
					MySQL.Async.execute("UPDATE ng_lottery SET reward=@reward WHERE lottery_id=@lottery_id AND identifier=@identifier", {
						["@reward"] = sum,
						["@lottery_id"] = lottery.id,
						["@identifier"] = winner,
					});

					MySQL.Async.fetchAll("SELECT firstname, lastname FROM users WHERE identifier=@identifier", {
						["@identifier"] = winner,
					}, function(userResults)
						if userResults and #userResults > 0 then
							local embed = {
								{
									["color"] = 16753920,
									["title"] = "**".. userResults[1].firstname .." " .. userResults[1].lastname .. "** hat die Lotterie gewonnen!",
									--["description"] = message,
									["footer"] = {
										["text"] = "",
									},
								}
							};

							PerformHttpRequest("https://discord.com/api/webhooks/1018934404774637618/vp4n9FF3gi_xpHTanXH04AU60U3nZ8tP8c3XhMEOx58cSeNuoug3rEES7KxKOjlw6b2E", function(err, text, headers) end, 'POST', json.encode({
								username = "Lotterie", 
								embeds = embed,
							}), {
								["Content-Type"] = "application/json"
							});
						end
					end);
				end
			end);
		end
	end);
end

function OnTicketsBought(lottery)
	MySQL.Async.fetchAll("SELECT SUM(ticket_amount) AS sum FROM ng_lottery WHERE lottery_id=@lottery_id", {
		["@lottery_id"] = lottery.id,
	}, function(sumResults) 
		if sumResults and #sumResults > 0 then
			local sum = sumResults[1].sum or 0;
			sum = math.floor(sum * lottery.price * lottery.rewardPercentage);
			print(sum, lottery.endAt);
			if sum >= lottery.endAt then
			print("ending lottery");
				EndLottery(lottery);
			end
		end
	end);
end

RegisterCommand("endlottery", function(playerId, args, raw)
	local lottery = GetLotteryConfig(args[1]);
	if lottery then
		EndLottery(lottery);
	end
end, true);