#include <YSI\y_hooks>
/*
	##     ##    ###     ######  ########   #######   ######  
	###   ###   ## ##   ##    ## ##     ## ##     ## ##    ## 
	#### ####  ##   ##  ##       ##     ## ##     ## ##       
	## ### ## ##     ## ##       ########  ##     ##  ######   
	##     ## ######### ##       ##   ##   ##     ##       ## 
	##     ## ##     ## ##    ## ##    ##  ##     ## ##    ## 
	##     ## ##     ##  ######  ##     ##  #######   ######  
*/

//Igrac je novi na serveru ili je stari
#define MAX_ADO_LABELS  200
#define PlayerNewUser_Set(%0,%1) \
		Bit1_Set(gr_NewUser,%0,%1)

#define COLOR_RADIO		(0xFFEC8BFF)
#define COLOR_RADIOEX	(0xB5AF8FFF)

#define CP_JOB_GPS		(150)

// Player Module Includes at the bottom


/*
	######## #### ##     ## ######## ########   ######     ##     ##    ###    ########   ######  
	   ##     ##  ###   ### ##       ##     ## ##    ##    ##     ##   ## ##   ##     ## ##    ## 
	   ##     ##  #### #### ##       ##     ## ##          ##     ##  ##   ##  ##     ## ##       
	   ##     ##  ## ### ## ######   ########   ######     ##     ## ##     ## ########   ######  
	   ##     ##  ##     ## ##       ##   ##         ##     ##   ##  ######### ##   ##         ## 
	   ##     ##  ##     ## ##       ##    ##  ##    ##      ## ##   ##     ## ##    ##  ##    ## 
	   ##    #### ##     ## ######## ##     ##  ######        ###    ##     ## ##     ##  ######  
*/

new ADOText[MAX_PLAYERS],
	PlayerText:BlindTD[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };

/*
	 ######   ##        #######  ########     ###    ##          ##     ##    ###    ########   ######  
	##    ##  ##       ##     ## ##     ##   ## ##   ##          ##     ##   ## ##   ##     ## ##    ## 
	##        ##       ##     ## ##     ##  ##   ##  ##          ##     ##  ##   ##  ##     ## ##       
	##   #### ##       ##     ## ########  ##     ## ##          ##     ## ##     ## ########   ######  
	##    ##  ##       ##     ## ##     ## ######### ##           ##   ##  ######### ##   ##         ## 
	##    ##  ##       ##     ## ##     ## ##     ## ##            ## ##   ##     ## ##    ##  ##    ## 
	 ######   ########  #######  ########  ##     ## ########       ###    ##     ## ##     ##  ######  
*/
enum E_ADO_LABEL_INFO
{
	labelid,
	Text3D:label,
	Float:lablpos[3]
}

new
	AdoLabels[MAX_ADO_LABELS][E_ADO_LABEL_INFO],
	Bit1:	gr_BlockedLIVE			<MAX_PLAYERS>,
	Bit1:	gr_BlockedOOC			<MAX_PLAYERS>;
	
new
	PlayerDrunkLevel[MAX_PLAYERS],
    PlayerFPS[MAX_PLAYERS],
	PlayerFPSUnix[MAX_PLAYERS];

enum E_DATA_TAXI 
{
	bool: eTaxiDuty,
	bool: eTaxiActive,
	eTaxiDriver,
	eTaxiPassanger,
	eTaxiMetersFare,
	eTaxiTraveled,
	eTaxiFare,
	eTaxiPayment,
	Float: eTaxiStartPos[3],
}
new TaxiData[MAX_PLAYERS][E_DATA_TAXI];
	
/*
	######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######  
	##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ## 
	##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##       
	######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######  
	##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ## 
	##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ## 
	##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######  
*/

ResetMonthPaydays()
{
	new resetString[128];
	mysql_format(g_SQL, resetString, sizeof(resetString), "UPDATE `experience` SET `monthpaydays` = '0' WHERE 1");
	mysql_tquery(g_SQL, resetString, "", "");
	return 1;
}

Function: CheckAccountsForInactivity()
{	
	new currentday, currentmonth, loadString[ 128 ], logString[2048];
			
	new inactivetimestamp = gettimestamp() - MAX_JOB_INACTIVITY_TIME;
	mysql_format(g_SQL, loadString, 128, "SELECT * FROM `accounts` WHERE lastloginstamp <= '%d'",inactivetimestamp);
	
	inline OnInactiveAccsLoad()
	{
		new rows;
		cache_get_row_count(rows);
		if( rows == 0 ) 
			return Log_Write("logfiles/inactive_players.txt", "(%s) - Accounts for property/job removal due to inactivity currently don't exist.", ReturnDate());
			
		new 
			sqlid, 
			jobkey, 
			contracttime, 
			loginstamp,
			propertytimestamp, 
			playername[24], 
			updateQuery[150],
			motd[256],
			tmpString[20];
			
		new 
			donaterank = 0,
			bool:skip = false,
			monthpaydays = 0,
			bankmoney = 0,
			houseid = INVALID_HOUSE_ID,
			bizzid = INVALID_BIZNIS_ID, 
			cid = INVALID_COMPLEX_ID, 
			crid = INVALID_COMPLEX_ID,
			garageid = INVALID_HOUSE_ID,
			Cache:Data;
			
		Data = cache_save();
			
		for( new i=0; i < rows; i++ ) 
		{
			donaterank = 0;
			skip = false;
			monthpaydays = 0;
			bankmoney = 0;
			houseid = INVALID_HOUSE_ID;
			bizzid = INVALID_BIZNIS_ID;
			cid = INVALID_COMPLEX_ID;
			crid = INVALID_COMPLEX_ID;
			garageid = INVALID_HOUSE_ID;
			logString[0] = EOS;
			
			cache_get_value_name_int(i, "sqlid", sqlid);
			
			if(IsValidInactivity(sqlid)) // Ukoliko postoji prijavljena neaktivnost koja jos uvijek traje
				continue;

			monthpaydays = GetPlayerPaydayCount(sqlid);
			
			cache_set_active(Data); // Povratak cachea nakon provjere u bazi
				
			cache_get_value_name(i, 	"name"	, playername, 24);
			cache_get_value_name_int(i, "jobkey", jobkey);
			cache_get_value_name_int(i, "contracttime", contracttime);
			cache_get_value_name_int(i, "lastloginstamp", loginstamp);
			cache_get_value_name_int(i, "vipRank", donaterank);
			
			switch(donaterank)
			{
				case 1: loginstamp += (5 * 24 * 3600);
				case 2: loginstamp += (10 * 24 * 3600);
				case 3,4: skip = true;
			}
			if(skip)
			{
				skip = false;
				continue;
			}
			
			cache_get_value_name(0, "AdminMessage", logString, 2048); 
			
			if(jobkey != 0 && loginstamp <= (gettimestamp() - MAX_JOB_INACTIVITY_TIME) && monthpaydays < 3) // 
			{
				mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `jobkey` = '0', `contracttime` = '0' WHERE `sqlid` = '%d'", sqlid);
				mysql_tquery(g_SQL, updateQuery, "", "");
				
				RemoveOfflineJob(jobkey);
				
				switch(jobkey)  
				{
					 case 1:  format(tmpString, 20, "Cistac ulica");
					 case 2:  format(tmpString, 20, "Pizza Boy");
					 case 3:  format(tmpString, 20, "Mehanicar");
					 case 4:  format(tmpString, 20, "Kosac trave");
					 case 5:  format(tmpString, 20, "Tvornicki radnik");
					 case 6:  format(tmpString, 20, "Taksist");
					 case 7:  format(tmpString, 20, "Farmer");
					 case 8:  format(tmpString, 20, "Nepoznato");
					 case 9:  format(tmpString, 20, "Nepoznato");
					 case 12: format(tmpString, 20, "Gun Dealer");
					 case 13: format(tmpString, 20, "Car Jacker");
					 case 14: format(tmpString, 20, "Drvosjeca");
					 case 15: format(tmpString, 20, "Nepoznato");
					 case 16: format(tmpString, 20, "Smetlar");
					 case 17: format(tmpString, 20, "Vehicle Impounder");
					 case 18: format(tmpString, 20, "Transporter");
					 case 19: format(tmpString, 20, "Nepoznato");
					 case 20: format(tmpString, 20, "Nepoznato");
					 case 21: format(tmpString, 20, "Nepoznato");
					 case 22: format(tmpString, 20, "Nepoznato");
					 case 23: format(tmpString, 20, "Nepoznato");
					 case 24: format(tmpString, 20, "Nepoznato");
					 case 25: format(tmpString, 20, "Nepoznato");
					 default: format(tmpString, 20, "Nezaposlen");
				}
				
				Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his %s[Job ID:%d] job i %d hours of job contract.",
					ReturnDate(),
					playername,
					sqlid,
					tmpString,
					jobkey,
					contracttime
				);
	
				if(isnull(logString))
					format(motd, sizeof(motd), "[%s] - Izgubili ste	posao %s i %d sati ugovora radi nedovoljne aktivnosti.",
						ReturnDate(),
						tmpString,
						contracttime
					);
				else
					format(motd, sizeof(motd), "\n[%s] - Izgubili ste posao %s i %d sati ugovora radi nedovoljne aktivnosti.",
						ReturnDate(),
						tmpString,
						contracttime
					);
					
				strcat(logString, motd, 2048);
			}
			// Property Inactivity Check
			propertytimestamp = gettimestamp() - MAX_INACTIVITY_TIME;
			if(loginstamp <= propertytimestamp)
			{
				
				cache_get_value_name_int(i, "bankMoney"	, bankmoney);
				
				foreach(new h: Houses)
				{
					if(HouseInfo[h][hOwnerID] == sqlid)
					{
						houseid = h;
						break;
					}
				}
				foreach(new b: Bizzes)
				{
					if(BizzInfo[b][bOwnerID] == sqlid)
					{
						bizzid = b;
						break;
					}
				}
				foreach(new c: Complex)
				{
					if(ComplexInfo[c][cOwnerID] == sqlid)
					{
						cid = c;
						break;
					}
				}
				foreach(new cr: ComplexRooms)
				{
					if(ComplexRoomInfo[cr][cOwnerID] == sqlid)
					{
						crid = cr;
						break;
					}
				}
				foreach(new g: Garages)
				{
					if(GarageInfo[g][gOwnerID] == sqlid)
					{
						garageid = g;
						break;
					}
				}
				if(houseid != INVALID_HOUSE_ID)
				{
					bankmoney += HouseInfo[houseid][hValue];
					if(HouseInfo[houseid][hTakings] > 0)
						bankmoney += HouseInfo[houseid][hTakings];
						
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `houses` SET `ownerid` = '0', `takings` = '0' WHERE `id` = '%d'", HouseInfo[houseid][hSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his house %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						HouseInfo[houseid][hAdress],
						HouseInfo[houseid][hSQLID],
						(HouseInfo[houseid][hValue] + HouseInfo[houseid][hTakings])
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste kucu na adresi %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							HouseInfo[houseid][hAdress], 
							(HouseInfo[houseid][hValue] + HouseInfo[houseid][hTakings])
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste kucu na adresi %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							HouseInfo[houseid][hAdress], 
							(HouseInfo[houseid][hValue] + HouseInfo[houseid][hTakings])
						);
						
					strcat(logString, motd, 2048);
				}
				if(garageid != INVALID_HOUSE_ID)
				{
					bankmoney += GarageInfo[garageid][gPrice];
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `server_garages` SET `ownerid` = '0' WHERE `id` = '%d'", 
						GarageInfo[garageid][gSQLID]
					);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his garage %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						GarageInfo[garageid][gAdress],
						GarageInfo[garageid][gSQLID],
						GarageInfo[garageid][gPrice]
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste garazu %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							GarageInfo[garageid][gAdress],
							GarageInfo[garageid][gPrice]
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste garazu %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							GarageInfo[garageid][gAdress],
							GarageInfo[garageid][gPrice]
						);
						
					strcat(logString, motd, 2048);
				}
				if(bizzid != INVALID_BIZNIS_ID)
				{
					bankmoney += BizzInfo[bizzid][bBuyPrice];
					if(BizzInfo[ bizzid ][ bTill ] > 0)
						bankmoney += BizzInfo[bizzid][bTill];
						
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `bizzes` SET `ownerid` = '0' WHERE `id` = '%d'", BizzInfo[bizzid][bSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost Business %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						BizzInfo[bizzid][bMessage],
						BizzInfo[bizzid][bSQLID],
						(BizzInfo[bizzid][bBuyPrice] + BizzInfo[bizzid][bTill])
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste biznis %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.", 
							BizzInfo[bizzid][bMessage],
							(BizzInfo[bizzid][bBuyPrice] + BizzInfo[bizzid][bTill])
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste biznis %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.", 
							BizzInfo[bizzid][bMessage],
							(BizzInfo[bizzid][bBuyPrice] + BizzInfo[bizzid][bTill])
						);
						
					strcat(logString, motd, 2048);
				}
				if(cid != INVALID_COMPLEX_ID)
				{
					bankmoney += ComplexInfo[cid][cPrice];
					if(ComplexInfo[cid][cTill] > 0)
						bankmoney += ComplexInfo[cid][cTill];
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `server_complex` SET `owner_id` = '0' WHERE `id` = '%d'", ComplexInfo[cid][cSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his Complex %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						ComplexInfo[cid][cName],
						ComplexInfo[cid][cSQLID],
						ComplexInfo[cid][cPrice]
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste complex %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							ComplexInfo[cid][cName],
							(ComplexInfo[cid][cPrice] + ComplexInfo[cid][cTill])
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste complex %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							ComplexInfo[cid][cName],
							(ComplexInfo[cid][cPrice] + ComplexInfo[cid][cTill])
						);
						
					strcat(logString, motd, 2048);
				}
				if(crid != INVALID_COMPLEX_ID)
				{	
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `server_complex_rooms` SET `ownerid` = '0' WHERE `id` = '%d'", ComplexRoomInfo[crid][cSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his Complex Room %s [SQLID: %d].",
						ReturnDate(),
						playername,
						sqlid,
						ComplexRoomInfo[crid][cAdress],
						ComplexRoomInfo[crid][cSQLID]
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste sobu %s u Complexu %s radi nedovoljne aktivnosti.", 
							ReturnDate(),
							ComplexRoomInfo[crid][cAdress],
							ComplexInfo[GetComplexEnumID(crid)][cName]
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste sobu %s u Complexu %s radi nedovoljne aktivnosti.", 
							ReturnDate(),
							ComplexRoomInfo[crid][cAdress],
							ComplexInfo[GetComplexEnumID(crid)][cName]
						);
						
					strcat(logString, motd, 2048);
				}
				SendServerMessage(sqlid, logString);
			}
		}
		cache_delete(Data);
		return 1;
	}
	mysql_tquery_inline(g_SQL, loadString, using inline OnInactiveAccsLoad, "");
	
	getdate(_, currentmonth, currentday);
	if(currentday == 1) 
	{
		mysql_format(g_SQL, loadString, 128, "SELECT * FROM `experience` WHERE monthpaydays < '%d'", MIN_MONTH_PAYDAYS);
		inline OnMinPayDayAccsLoad()
		{
			new rows, Cache:QueryData;
			QueryData = cache_save();
			cache_get_row_count(rows);

			new 
				sqlid,
				playername[24], 
				updateQuery[150],
				motd[256];
				
			new 
				donaterank = 0,
				bool:skip = false,
				bankmoney = 0,
				houseid = INVALID_HOUSE_ID,
				bizzid = INVALID_BIZNIS_ID, 
				cid = INVALID_COMPLEX_ID, 
				crid = INVALID_COMPLEX_ID,
				garageid = INVALID_HOUSE_ID;

			for(new i = 0; i < rows; i++)
			{
				donaterank = 0;
				skip = false;
				bankmoney = 0;
				houseid = INVALID_HOUSE_ID;
				bizzid = INVALID_BIZNIS_ID;
				cid = INVALID_COMPLEX_ID;
				crid = INVALID_COMPLEX_ID;
				garageid = INVALID_HOUSE_ID;
				logString[0] = EOS;
			
				cache_get_value_name_int(i, "sqlid", sqlid);

				format(playername, sizeof(playername), "%s", ConvertSQLIDToName(sqlid));
				donaterank = GetPlayerVIP(sqlid);
				bankmoney = GetPlayerBankMoney(sqlid);
				strcat(logString, GetPlayerAdminMessage(sqlid), sizeof(logString));

				if(IsValidInactivity(sqlid)) // Ukoliko postoji prijavljena neaktivnost koja jos uvijek traje
					continue;
			
				cache_set_active(QueryData); // Povratak cachea nakon provjere u bazi
			
				switch(donaterank)
				{
					case 1 .. 4: skip = true;
				}
				if(skip)
				{
					skip = false;
					continue;
				}
				
				foreach(new h: Houses)
				{
					if(HouseInfo[h][hOwnerID] == sqlid)
					{
						houseid = h;
						break;
					}
				}
				foreach(new b: Bizzes)
				{
					if(BizzInfo[b][bOwnerID] == sqlid)
					{
						bizzid = b;
						break;
					}
				}
				foreach(new c: Complex)
				{
					if(ComplexInfo[c][cOwnerID] == sqlid)
					{
						cid = c;
						break;
					}
				}
				foreach(new cr: ComplexRooms)
				{
					if(ComplexRoomInfo[cr][cOwnerID] == sqlid)
					{
						crid = cr;
						break;
					}
				}
				foreach(new g: Garages)
				{
					if(GarageInfo[g][gOwnerID] == sqlid)
					{
						garageid = g;
						break;
					}
				}
				if(houseid != INVALID_HOUSE_ID)
				{
					bankmoney += HouseInfo[houseid][hValue];
					if(HouseInfo[houseid][hTakings] > 0)
						bankmoney += HouseInfo[houseid][hTakings];
						
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `houses` SET `ownerid` = '0', `takings` = '0' WHERE `id` = '%d'", HouseInfo[houseid][hSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his house on adress %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						HouseInfo[houseid][hAdress],
						HouseInfo[houseid][hSQLID],
						(HouseInfo[houseid][hValue] + HouseInfo[houseid][hTakings])
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste kucu na adresi %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							HouseInfo[houseid][hAdress], 
							(HouseInfo[houseid][hValue] + HouseInfo[houseid][hTakings])
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste kucu na adresi %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							HouseInfo[houseid][hAdress], 
							(HouseInfo[houseid][hValue] + HouseInfo[houseid][hTakings])
						);
						
					strcat(logString, motd, 2048);
				}
				if(garageid != INVALID_HOUSE_ID)
				{
					bankmoney += GarageInfo[garageid][gPrice];
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `server_garages` SET `ownerid` = '0' WHERE `id` = '%d'", 
						GarageInfo[garageid][gSQLID]
					);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his garage %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						GarageInfo[garageid][gAdress],
						GarageInfo[garageid][gSQLID],
						GarageInfo[garageid][gPrice]
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste garazu %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							GarageInfo[garageid][gAdress],
							GarageInfo[garageid][gPrice]
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste garazu %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							GarageInfo[garageid][gAdress],
							GarageInfo[garageid][gPrice]
						);
						
					strcat(logString, motd, 2048);
				}
				if(bizzid != INVALID_BIZNIS_ID)
				{
					bankmoney += BizzInfo[bizzid][bBuyPrice];
					if(BizzInfo[ bizzid ][ bTill ] > 0)
						bankmoney += BizzInfo[bizzid][bTill];
						
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `bizzes` SET `ownerid` = '0' WHERE `id` = '%d'", BizzInfo[bizzid][bSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his Business %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						BizzInfo[bizzid][bMessage],
						BizzInfo[bizzid][bSQLID],
						(BizzInfo[bizzid][bBuyPrice] + BizzInfo[bizzid][bTill])
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste biznis %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.", 
							BizzInfo[bizzid][bMessage],
							(BizzInfo[bizzid][bBuyPrice] + BizzInfo[bizzid][bTill])
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste biznis %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.", 
							BizzInfo[bizzid][bMessage],
							(BizzInfo[bizzid][bBuyPrice] + BizzInfo[bizzid][bTill])
						);
						
					strcat(logString, motd, 2048);
				}
				if(cid != INVALID_COMPLEX_ID)
				{
					bankmoney += ComplexInfo[cid][cPrice];
					if(ComplexInfo[cid][cTill] > 0)
						bankmoney += ComplexInfo[cid][cTill];
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `accounts` SET `bankMoney` = '%d' WHERE `sqlid` = '%d'", bankmoney, sqlid);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `server_complex` SET `owner_id` = '0' WHERE `id` = '%d'", ComplexInfo[cid][cSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his Complex %s[SQLID: %d] and got %d$ refunded.",
						ReturnDate(),
						playername,
						sqlid,
						ComplexInfo[cid][cName],
						ComplexInfo[cid][cSQLID],
						ComplexInfo[cid][cPrice]
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste complex %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							ComplexInfo[cid][cName],
							(ComplexInfo[cid][cPrice] + ComplexInfo[cid][cTill])
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste complex %s radi nedovoljne aktivnosti i dobili %d$ naknade na bankovni racun.",
							ReturnDate(),
							ComplexInfo[cid][cName],
							(ComplexInfo[cid][cPrice] + ComplexInfo[cid][cTill])
						);
						
					strcat(logString, motd, 2048);
				}
				if(crid != INVALID_COMPLEX_ID)
				{	
					mysql_format(g_SQL, updateQuery, sizeof(updateQuery), "UPDATE `server_complex_rooms` SET `ownerid` = '0' WHERE `id` = '%d'", ComplexRoomInfo[crid][cSQLID]);
					mysql_tquery(g_SQL, updateQuery, "", "");
					
					Log_Write("logfiles/inactive_players.txt", "(%s) %s[SQLID: %d] due to inactivity lost his Complex Room on adress %s[SQLID: %d].",
						ReturnDate(),
						playername,
						sqlid,
						ComplexRoomInfo[crid][cAdress],
						ComplexRoomInfo[crid][cSQLID]
					);
					
					if(isnull(logString))
						format(motd, sizeof(motd), "[%s] - Izgubili ste sobu %s u Complexu %s radi nedovoljne aktivnosti.", 
							ReturnDate(),
							ComplexRoomInfo[crid][cAdress],
							ComplexInfo[GetComplexEnumID(crid)][cName]
						);
					else
						format(motd, sizeof(motd), "\n[%s] - Izgubili ste sobu %s u Complexu %s radi nedovoljne aktivnosti.", 
							ReturnDate(),
							ComplexRoomInfo[crid][cAdress],
							ComplexInfo[GetComplexEnumID(crid)][cName]
						);
						
					strcat(logString, motd, 2048);
				}
				SendServerMessage(sqlid, logString);
			}
			cache_delete(QueryData);
			return 1;
		}
		mysql_tquery_inline(g_SQL, loadString, using inline OnMinPayDayAccsLoad, "");

		mysql_format(g_SQL, loadString, sizeof(loadString), "SELECT * FROM  `experience` ORDER BY `experience`.`monthpaydays` DESC LIMIT 0 , 30");
		inline OnRewardActivePlayers()
		{
			new rows, rewarded= 0, sql, monthpaydays, Cache:RewardQueryData;
			RewardQueryData = cache_save();
			cache_get_row_count(rows);
			for(new i = 0; i < rows; i++)
			{
				if(rewarded == 5)
					break; 

				logString[0] = EOS;
				cache_get_value_name_int(i, "sqlid", sql);
				cache_get_value_name_int(i, "monthpaydays", monthpaydays);

				if(IsAccountTeamStaff(sql))
					continue;
				
				cache_set_active(RewardQueryData); // Povratak cachea nakon provjere u bazi
				rewarded++;
				switch(rewarded)
				{
					case 1: 
					{
						RewardPlayerForActivity(sql, PREMIUM_GOLD_EXP);
						Log_Write("logfiles/rewarded_players.txt", "(%s) - %s got awarded with %d EXP as most active player of %d. month with %d paydays.", 
							ReturnDate(),
							ConvertSQLIDToName(sql),
							PREMIUM_GOLD_EXP,
							(currentmonth - 1),
							monthpaydays
						);
						format(logString, sizeof(logString), "[%s] - Dobili ste %d EXP-a kao najaktivniji igrac %d. mjeseca sa %d paydayova.\nOvom nagradom mozete iskoristiti brojne pogodnosti koje Vam server nudi sa komandom /exp buy.\nVelike cestitke od City of Angels Teama!",
							ReturnDate(),
							PREMIUM_GOLD_EXP,
							(currentmonth - 1),
							monthpaydays
						);
						SendServerMessage(sql, logString);
					}
					case 2: 
					{
						RewardPlayerForActivity(sql, 100);
						Log_Write("logfiles/rewarded_players.txt", "(%s) - %s got awarded 100 EXP as an award for second most active player of %d. month with %d paydays.", 
							ReturnDate(),
							ConvertSQLIDToName(sql),
							(currentmonth - 1),
							monthpaydays
						);
						format(logString, sizeof(logString), "[%s] - Dobili ste %d EXP-a kao 2. najaktivniji igrac %d. mjeseca sa %d paydayova.\nOvom nagradom mozete iskoristiti brojne pogodnosti koje Vam server nudi sa komandom /exp buy.\nVelike cestitke od City of Angels Teama!",
							ReturnDate(),
							100,
							(currentmonth - 1),
							monthpaydays
						);
						SendServerMessage(sql, logString);
					}
					case 3: 
					{
						RewardPlayerForActivity(sql, 75);
						Log_Write("logfiles/rewarded_players.txt", "(%s) - %s got awarded with 75 EXP as an award for third most active player of %d. month with %d paydays.", 
							ReturnDate(),
							ConvertSQLIDToName(sql),
							(currentmonth - 1),
							monthpaydays
						);
						format(logString, sizeof(logString), "[%s] - Dobili ste %d EXP-a kao 3. najaktivniji igrac %d. mjeseca sa %d paydayova.\nOvom nagradom mozete iskoristiti brojne pogodnosti koje Vam server nudi sa komandom /exp buy.\nVelike cestitke od City of Angels Teama!",
							ReturnDate(),
							75,
							(currentmonth - 1),
							monthpaydays
						);
						SendServerMessage(sql, logString);
					}
					case 4: 
					{
						RewardPlayerForActivity(sql, 50);
						Log_Write("logfiles/rewarded_players.txt", "(%s) - %s got awarded with 50 EXP as an award for fourth most active player of %d. month with %d paydays.", 
							ReturnDate(),
							ConvertSQLIDToName(sql),
							(currentmonth - 1),
							monthpaydays
						);
						format(logString, sizeof(logString), "[%s] - Dobili ste %d EXP-a kao 4. najaktivniji igrac %d. mjeseca sa %d paydayova.\nOvom nagradom mozete iskoristiti brojne pogodnosti koje Vam server nudi sa komandom /exp buy.\nVelike cestitke od City of Angels Teama!",
							ReturnDate(),
							50,
							(currentmonth - 1),
							monthpaydays
						);
						SendServerMessage(sql, logString);
					}
					case 5: 
					{
						RewardPlayerForActivity(sql, 25);
						Log_Write("logfiles/rewarded_players.txt", "(%s) - %s got awarded with 25 EXP as an award for fifth most active player of %d. month with %d paydays.", 
							ReturnDate(),
							ConvertSQLIDToName(sql),
							(currentmonth - 1),
							monthpaydays
						);
						format(logString, sizeof(logString), "[%s] - Dobili ste %d EXP-a kao 5. najaktivniji igrac %d. mjeseca sa %d paydayova.\nOvom nagradom mozete iskoristiti brojne pogodnosti koje Vam server nudi sa komandom /exp buy.\nVelike cestitke od City of Angels Teama!",
							ReturnDate(),
							25,
							(currentmonth - 1),
							monthpaydays
						);
						SendServerMessage(sql, logString);
					}
				}
			}
			cache_delete(RewardQueryData);
			ResetMonthPaydays();
			return 1;
		}	
		mysql_tquery_inline(g_SQL, loadString, using inline OnRewardActivePlayers, "");
		return 1;
	}
	return 1;
}

stock CheckPlayerMasks(playerid)
{
	foreach(new i : Player) 
	{
		if(Bit1_Get(gr_MaskUse, i)) 	
			ShowPlayerNameTagForPlayer(playerid, i, 0);
	}
	return 1;
}

stock CheckPlayerInteriors(playerid)
{
	new interior = -1, virtualworld = -1;
	interior = GetPlayerInterior(playerid);
	virtualworld = GetPlayerVirtualWorld(playerid);

	foreach(new h: Houses)
	{
		if(IsPlayerInRangeOfPoint(playerid, 100.0, HouseInfo[h][hExitX], HouseInfo[h][hExitY], HouseInfo[h][hExitZ]) && HouseInfo[h][hInt] == interior && HouseInfo[h][hVirtualWorld] == virtualworld)
		{
			Bit16_Set(gr_PlayerInHouse, playerid, h);
			return 1;
		}
	}
	foreach(new b: Bizzes)
	{
		if(IsPlayerInRangeOfPoint(playerid, 100.0, BizzInfo[b][bExitX], BizzInfo[b][bExitY], BizzInfo[b][bExitZ]) && BizzInfo[b][bInterior] == interior && BizzInfo[b][bVirtualWorld] == virtualworld)
		{
			Bit16_Set(gr_PlayerInBiznis, playerid, b);
			return 1;
		}
	}
	foreach(new pickup: Pickups)
	{
		if(IsPlayerInRangeOfPoint(playerid, 100.0, PickupInfo[pickup][epExitx],PickupInfo[pickup][epExity],PickupInfo[pickup][epExitz]) && PickupInfo[pickup][epInt] == interior && PickupInfo[pickup][epViwo] == virtualworld)
		{
			Bit16_Set(gr_PlayerInPickup, playerid, pickup);
			return 1;
		}
	}
	foreach(new c: Complex) 
	{
		if(IsPlayerInRangeOfPoint(playerid, 100.0, ComplexInfo[c][cExitX], ComplexInfo[c][cExitY], ComplexInfo[c][cExitZ]) && ComplexInfo[c][cInt] == interior && ComplexInfo[c][cViwo] == virtualworld) 
		{
			Bit16_Set(gr_PlayerInComplex, playerid, c);
			return 1;
		}
	}
	foreach(new cr: ComplexRooms)
	{
		if(IsPlayerInRangeOfPoint(playerid, 100.0, ComplexRoomInfo[cr][cExitX], ComplexRoomInfo[cr][cExitY], ComplexRoomInfo[cr][cEnterZ]) && interior == ComplexRoomInfo[cr][cIntExit] && virtualworld == ComplexRoomInfo[cr][cVWExit] ) 
		{
			Bit16_Set(gr_PlayerInRoom, playerid, cr);
			return 1;
		}
	}
	foreach(new garage: Garages)
	{
		if(IsPlayerInRangeOfPoint(playerid, 100.0, GarageInfo[ garage ][ gExitX ], GarageInfo[ garage ][ gExitY ], GarageInfo[ garage ][ gExitZ ]))
		{
			Bit16_Set(gr_PlayerInGarage, playerid, garage);
			return 1;
		}
	}
	return 1;
}
		

forward KickPlayer(playerid);
public KickPlayer(playerid)
	return Kick(playerid);
	
forward BanPlayer(playerid);
public BanPlayer(playerid)
	return Ban(playerid);

stock GetAdoFreeLabelSlot() {
	for(new i = 0; i < MAX_ADO_LABELS; i++)
	{
	    if(!AdoLabels[i][label])
	    {
	        return i;
	    }
	}
	return -1;
}
stock ResetAdoLabelSlot(playerid, type, value)
{
	switch(type)
	{
	    //slot
		case 1:
		{
		    ADOText[AdoLabels[value][labelid]] = 0;
		    AdoLabels[value][labelid] = 0;
      		DestroyDynamic3DTextLabel(AdoLabels[value][label]);
		    AdoLabels[value][lablpos][0] = 0;
		    AdoLabels[value][lablpos][1] = 0;
		    AdoLabels[value][lablpos][2] = 0;
      		SendClientMessage(playerid, COLOR_RED, "[ ! ] Uspjesno ste obrisali prikvaceni opis.");
			return 1;
		}
		//playerid
		case 2:
		{
		    for(new i = 0; i < MAX_ADO_LABELS; i++)
		    {
		        if(AdoLabels[i][labelid] == value)
		        {
		            ADOText[AdoLabels[i][labelid]] = 0;
		            AdoLabels[i][labelid] = -1;
		      		DestroyDynamic3DTextLabel(AdoLabels[i][label]);
				    AdoLabels[i][lablpos][0] = 0;
				    AdoLabels[i][lablpos][1] = 0;
				    AdoLabels[i][lablpos][2] = 0;
				    SendClientMessage(playerid, COLOR_RED, "[ ! ] Uspjesno ste obrisali prikvaceni opis.");
				    return 1;
		        }
		    }
		}
	}
	return 0;
}

stock LevelUp(playerid)
{
	if(PlayerInfo[playerid][pLevel] > 0)
	{
		new
			expamount = ( PlayerInfo[playerid][pLevel] + 1 ) * 4;
		if (PlayerInfo[playerid][pRespects] < expamount) {
			return 0;
		}

		PlayerInfo[playerid][pLevel]++;
		if(PlayerInfo[playerid][pDonateRank] > 0)
		{
			PlayerInfo[playerid][pRespects] -= expamount;
			new total = PlayerInfo[playerid][pRespects];
			if(total > 0) PlayerInfo[playerid][pRespects] = total;
			else
				PlayerInfo[playerid][pRespects] = 0;
		}
		else
			PlayerInfo[playerid][pRespects] = 0;

		new levelUpUpdate[90];
		format(levelUpUpdate, 90, "UPDATE `accounts` SET `levels` = '%d', `respects` = '%d' WHERE `sqlid` = '%d'",
			PlayerInfo[playerid][pLevel],
			PlayerInfo[playerid][pRespects],
			PlayerInfo[playerid][pSQLID]
		);
		mysql_pquery(g_SQL, levelUpUpdate);

		SetPlayerScore(playerid, PlayerInfo[playerid][pLevel]);
	}
	return 1;
}

/*
	######## #### ##     ## ######## ########   ######  
	   ##     ##  ###   ### ##       ##     ## ##    ## 
	   ##     ##  #### #### ##       ##     ## ##       
	   ##     ##  ## ### ## ######   ########   ######  
	   ##     ##  ##     ## ##       ##   ##         ## 
	   ##     ##  ##     ## ##       ##    ##  ##    ## 
	   ##    #### ##     ## ######## ##     ##  ######  
*/

Function: LoginCheck(playerid)
{
	if( !IsPlayerLogged(playerid) && IsPlayerConnected(playerid) )
	{
		SendClientMessage(playerid, COLOR_RED, "[SERVER]  Dobio si kick nakon 60 sekundi!");
		KickMessage(playerid);
	}
	return 1;
}

Function: PlayerMinuteTask(playerid)
{
	PlayerTaskTStamp[playerid] = gettimestamp() + 60;
	
	if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER && LastVehicle[playerid] != INVALID_VEHICLE_ID) 
	{
		LastVehicleDriver[LastVehicle[playerid]] = INVALID_PLAYER_ID;
		LastVehicle[playerid] = INVALID_VEHICLE_ID;
	}
	if( (CreditInfo[playerid][cCreditType] == 5 || CreditInfo[playerid][cCreditType] == 6 || CreditInfo[playerid][cCreditType] == 7) && !CreditInfo[playerid][cUsed] && gettimestamp() >= CreditInfo[playerid][cTimestamp]) 
	{
		ResetCreditVars(playerid);
		SavePlayerCredit(playerid);
		SendClientMessage(playerid, COLOR_YELLOW, "[SMS]: Automatski vam je ponisten namjenski kredit radi neobavljanja kupovne obveze.");
	}
	PlayerInfo[playerid][pPayDay] += 1;
	if(PlayerInfo[playerid][pPayDay] >= 60)
		GivePlayerPayCheck(playerid);
		
	if(PlayerInfo[playerid][pJailTime] > 0)
		PlayerInfo[playerid][pJailTime] -= 1;
	else if(PlayerInfo[playerid][pJailTime] == 0 )
	{
		if( PlayerInfo[playerid][pJailed] == 1 )
		{
			SetPlayerPosEx(playerid, 90.6552, -236.3789, 1.5781, 0, 0, false);
			SetPlayerWorldBounds(playerid, 20000.0000, -20000.0000, 20000.0000, -20000.0000);
			SetPlayerColor(playerid, COLOR_PLAYER);
			SendMessage(playerid, MESSAGE_TYPE_SUCCESS, "Slobodni ste, platili ste svoj dug drustvu!");
		}
		else if( PlayerInfo[playerid][pJailed] == 2 )
		{
			SetPlayerPosEx(playerid, 1482.7426, -1740.1372, 13.7500, 0, 0, false);
			SetPlayerWorldBounds(playerid, 20000.0000, -20000.0000, 20000.0000, -20000.0000);
			SetPlayerColor(playerid, COLOR_PLAYER);
			SendClientMessage(playerid, COLOR_LIGHTBLUE, "Pusten si iz Fort DeMorgana, pripazi na ponasanje i server pravila!");
		}
		else if( PlayerInfo[playerid][pJailed] == 3 )
		{
			SetPlayerPosEx(playerid, 636.7744,-601.3240,16.3359, 0, 0, false);
			SendMessage(playerid, MESSAGE_TYPE_SUCCESS, "Slobodni ste, platili ste svoj dug drustvu!");
		}
		else if( PlayerInfo[playerid][pJailed] == 5 ) // Treatment
		{
			TogglePlayerControllable(playerid, 1);
			ClearAnim(playerid);
			SetPlayerPosEx(playerid, 1185.4681,-1323.8542,13.5720, 0, 0, false);
			SendMessage(playerid, MESSAGE_TYPE_SUCCESS, "Zavrsilo je vase lijecenje, otpusteni ste iz bolnice!");
		}
		PlayerInfo[playerid][pJailed] = 0;
		PlayerInfo[playerid][pJailTime] = 0;
	}
	else if(PlayerInfo[playerid][pJailTime] < 0)
		PlayerInfo[playerid][pJailTime] = 0;
		
		
	if(PlayerInfo[playerid][pDrugUsed] != 0)
	{
		if(-- PlayerInfo[playerid][pDrugSeconds] <= 0)
		{
			PlayerInfo[playerid][pDrugSeconds] = 0;
			PlayerInfo[playerid][pDrugUsed] = 0;
		}
	}
	if(PlayerInfo[playerid][pDrugOrder] > 0)
	{
		-- PlayerInfo[playerid][pDrugOrder];
	}
	
	HungerCheck(playerid);
	AFKCheck(playerid);
	AC_SavePlayerWeapons(playerid);
	return 1;	
}

/*new
	timercheck = 0;
*/
timer PlayerGlobalTask[1000](playerid)
{
	/*printf("PlayerGlobalTask took %d miliseconds!", tickcount() - timercheck);
	timercheck = tickcount();*/
	
	if ( !SafeSpawned[playerid] || !IsPlayerConnected(playerid) ) return 1;
	if( gettimestamp() >= PlayerTaskTStamp[playerid] )
		PlayerMinuteTask(playerid);	
	
	if(TaxiData[playerid][eTaxiActive] == true) {
		_TaximeterCount(playerid);
	}
	
	PlayerSyncs[ playerid ] = false;
	new tmphour,tmpmins,tmpsecs;
	GetServerTime(tmphour,tmpmins,tmpsecs);
	SetPlayerTime(playerid,tmphour,tmpmins);
	
	static
		pcar = INVALID_VEHICLE_ID;
	
	if((pcar = GetPlayerVehicleID(playerid)) != INVALID_VEHICLE_ID && GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
	{
		LastVehicle[playerid] = GetPlayerVehicleID(playerid);
		LastVehicleDriver[LastVehicle[playerid]] = playerid;
		GetVehiclePreviousInfo(LastVehicle[playerid]);
		
		static
			Float:vhealth;

		GetVehicleHealth(pcar, vhealth);
		
		if(vhealth < 250.0)
		{
			AC_SetVehicleHealth(pcar, 254.0);
			CallLocalFunction("OnPlayerCrashVehicle", "idf", playerid, pcar, 0.0);
			
			new
				engine, lights, alarm, doors, bonnet, boot, objective;
			
			GetVehicleParamsEx(pcar, engine, lights, alarm, doors, bonnet, boot, objective);
			SetVehicleParamsEx(pcar, 0, lights, alarm, doors, bonnet, boot, objective);
			
			VehicleInfo[pcar][vEngineRunning] = false;
		}
	}
	if(Bit1_Get(gps_Activated, playerid))
		gps_GetDistance(playerid, GPSInfo[playerid][gGPSID], GPSInfo[playerid][gX], GPSInfo[playerid][gY], GPSInfo[playerid][gZ]);
	
	CheckHouseInfoTextDraws(playerid); // House Info Textdraw removal if not in checkpoint 
	CheckWoundedPlayer(playerid);
	
	if(PlayerCarTow[playerid])
		VehicleTowTimer(PlayerInfo[playerid][pSpawnedCar], playerid);
	
	SprayingBarChecker(playerid);
	SprayingTaggTimer(playerid);
	
	PackageLossCheck(playerid);
	return 1;
}

/*
	 ######  ########  #######   ######  ##    ##  ######  
	##    ##    ##    ##     ## ##    ## ##   ##  ##    ## 
	##          ##    ##     ## ##       ##  ##   ##       
	 ######     ##    ##     ## ##       #####     ######  
		  ##    ##    ##     ## ##       ##  ##         ## 
	##    ##    ##    ##     ## ##    ## ##   ##  ##    ## 
	 ######     ##     #######   ######  ##    ##  ######  
*/
/**
    <summary>
        Funkcija za promjenu imena igracu.
    </summary>
	
	<param name="playerid">
        ID igraca kojem mijenjamo ime.
    </param>
	
	<param name="newname">
        Novo ime.
    </param>

    <returns>
        /
    </returns>

    <remarks>
        -
    </remarks>
*/

stock ChangePlayerName(playerid, newname[], type, bool:admin_cn = false)
{	
	new	Cache:result,
		counts,
		cnQuery[ 200 ];
	
	mysql_format(g_SQL, cnQuery, sizeof(cnQuery), "SELECT * FROM `accounts` WHERE `name` = '%e' LIMIT 0,1", newname);
	result = mysql_query(g_SQL, cnQuery);
	counts = cache_num_rows();
	cache_delete(result);
	
	if( counts ) return SendMessage(playerid, MESSAGE_TYPE_ERROR, "Taj nick vec postoji!");
	
	new
		oldname[MAX_PLAYER_NAME];
	format( oldname, MAX_PLAYER_NAME, GetName(playerid, false) );
	
	new log[100];
	format( log, sizeof(log), "[ChangeName Report]: Stari nick: %s, novi nick: %s", oldname, newname);
	SendAdminMessage(COLOR_RED, log);
	
	#if defined MODULE_LOGS
	Log_Write("logfiles/namechange.txt", "(%s) {%d} Old nickname: %s | New nickname: %s",
		ReturnDate(),
		PlayerInfo[ playerid ][ pSQLID ],
		oldname,
		newname
	);
	#endif
	
	// MySQL
	mysql_format(g_SQL, cnQuery, sizeof(cnQuery), "INSERT INTO `player_changenames`(`player_id`, `old_name`, `new_name`) VALUES ('%d','%e','%e')",
		PlayerInfo[ playerid ][ pSQLID ],
		oldname,
		newname
	);
	mysql_pquery(g_SQL, cnQuery, "");
	
	mysql_format(g_SQL, cnQuery, sizeof(cnQuery), "UPDATE `accounts` SET `name` = '%e', `sex` = '%d' WHERE `sqlid` = '%d'",
		newname,
		PlayerInfo[ playerid ][pAge],
		PlayerInfo[ playerid ][ pSQLID ]
	);
	mysql_pquery(g_SQL, cnQuery, "");
	
	PlayerInfo[ playerid ][ pArrested ] = 0;
	PlayerInfo[ playerid ][ pGunLic ] 	= 0;
	SavePlayerData(playerid);
	
	if(admin_cn == (false)) {
		if( !PlayerInfo[ playerid ][ pDonateRank ] )
			PlayerToBudgetMoney( playerid, 10000);
	}
	if(type == 1)
	{
		if(PlayerInfo[playerid][pLevel] < 10)
			PlayerInfo[ playerid ][ pChangenames ] = gettimestamp() + 172800; // 2 dana
		else if(PlayerInfo[playerid][pLevel] >= 10 && PlayerInfo[playerid][pLevel] < 20)
			PlayerInfo[ playerid ][ pChangenames ] = gettimestamp() + 86400; // 1 dan
	}
	else if(type == 2)
		PlayerInfo[playerid][pChangeTimes]--;
	
	// Poruka
	va_SendClientMessage( playerid, COLOR_RED, "[ ! ] Uspjesno ste promjenili ime u %s, ponovno se logirajte s novim imenom!", newname);
	if(PlayerInfo[playerid][pDonateRank] > 0)
		va_SendClientMessage( playerid, COLOR_RED, "[ ! ] Preostalo Vam je %d besplatnih changenameova.", PlayerInfo[playerid][pChangeTimes]);
	KickMessage(playerid);
	return 1;
}

/**
    <summary>
        Provjera za hunger sistem.
    </summary>
	
	<param name="playerid">
        ID igraca na kojem ce se vrSiti provjera.
    </param>

    <returns>
        /
    </returns>

    <remarks>
        -
    </remarks>
*/
stock static HungerCheck(playerid)
{
	if(PlayerWounded[playerid] || PlayerInfo[playerid][pKilled] > 0)
		return 1;
		
	new 
		Float:health;	
	if( PlayerInfo[ playerid ][ pHunger ] < 0.0 ) {
		if( PlayerInfo[ playerid ][ pMuscle ] > 10 ) {
			PlayerInfo[playerid][pHunger] -= 0.001;
		} else PlayerInfo[playerid][pHunger] -= 0.006;
		
		if( PlayerInfo[ playerid ][ pHunger ] < -5.0 ) 
			PlayerInfo[ playerid ][ pHunger ] = -5.0;
	}
	else PlayerInfo[ playerid ][ pHunger ] -= 0.002;

	GetPlayerHealth(playerid, health);
	if(health < 100.0)
		SetPlayerHealth(playerid, health + PlayerInfo[playerid][pHunger]);
	else if(PlayerInfo[playerid][pHunger] < 0.0)
		SetPlayerHealth(playerid, health + PlayerInfo[playerid][pHunger]);
	return 1;
}

/**
    <summary>
        Uzimamo igracev IP.
    </summary>
	
	<param name="playerid">
        Samo objaSnjivo.
    </param>

    <returns>
        Igracev IP.
    </returns>

    <remarks>
        -
    </remarks>
*/
		
/*GetPlayerIP(playerid)
{
	new 
		dest[24];
	GetPlayerIp(playerid, dest, 24);
    return dest;
}*/

/**
    <summary>
        Provjerava dali je igracev nick po RP pravilima (Ime_Prezime)
    </summary>
	
	<param name="name">
        Ime od igraca
    </param>

    <returns>
        1 - Nick po pravilima, 0 - Nick nije po pravilima
    </returns>

    <remarks>
        -
    </remarks>
*/
IsValidName(name[])
{
	new length = strlen(name),
		namesplit[2][MAX_PLAYER_NAME],
		FirstLetterOfFirstname,
		FirstLetterOfLastname,
		ThirdLetterOfLastname,
		Underscore;

	split(name, namesplit, '_');
    if (strlen(namesplit[0]) > 1 && strlen(namesplit[1]) > 1)
    {
        // Firstname and Lastname contains more than 1 character + it there are separated with '_' char. Continue...
    }
    else return 0; // No need to continue...

    FirstLetterOfFirstname = namesplit[0][0];
	if (FirstLetterOfFirstname >= 'A' && FirstLetterOfFirstname <= 'Z')
	{
        // First letter of Firstname is capitalized. Continue...
	}
	else return 0; // No need to continue...

	FirstLetterOfLastname = namesplit[1][0];
    if (FirstLetterOfLastname >= 'A' && FirstLetterOfLastname <= 'Z')
    {
		// First letter of Lastname is capitalized. Continue...
	}
	else return 0; // No need to continue...

	ThirdLetterOfLastname = namesplit[1][2];
    if (ThirdLetterOfLastname >= 'A' && ThirdLetterOfLastname <= 'Z' || ThirdLetterOfLastname >= 'a' && ThirdLetterOfLastname <= 'z')
    {
		// Third letter of Lastname can be uppercase and lowercase (uppercase for Lastnames like McLaren). Continue...
	}
	else return 0; // No need to continue...

    for(new i = 0; i < length; i++)
	{
		if (name[i] != FirstLetterOfFirstname && name[i] != FirstLetterOfLastname && name[i] != ThirdLetterOfLastname && name[i] != '_')
		{
			if(name[i] >= 'a' && name[i] <= 'z')
			{
				// Name contains only letters and that letters are lowercase (except the first letter of the Firstname, first letter of Lastname and third letter of Lastname). Continue...
			}
			else return 0; // No need to continue...
		}

		// This checks that '_' char can be used only one time (to prevent names like this Firstname_Lastname_Something)...
		if (name[i] == '_')
		{
			Underscore++;
			if (Underscore > 1) return 0; // No need to continue...
		}
	}
	return 1; // All check are ok, Name is valid...
}

/**
    <summary>
        Daje informacije o igracevu FPSu.
    </summary>
	
	<param name="playerid">
        Playerid od igraca.
    </param>

    <returns>
        Igracev FPS.
    </returns>

    <remarks>
        -
    </remarks>
*/
stock GetPlayerFPS(playerid)
	return PlayerFPS[playerid];

/**
    <summary>
        Daje igracev nick od njegovog MySQL IDa
    </summary>
	
	<param name="sqlid">
        MySQL ID od igraca
    </param>

    <returns>
        Igracev nick
    </returns>

    <remarks>
        -
    </remarks>
*/

stock GetPlayerAdminMessage(id)
{
	new message[2048], 
		sqlquery[128];
	format( sqlquery, sizeof(sqlquery), "SELECT `AdminMessage` FROM `accounts` WHERE `sqlid` = '%d' LIMIT 0,1", id);
	
	new 
		Cache:result = mysql_query(g_SQL, sqlquery);
	cache_get_value_name(0, "AdminMessage", message, 2048);
	cache_delete(result);
	return message;
}

stock GetPlayerVIP(sqlid)
{
	new	Cache:result,
		rows,
		value = 0,
		inactiveQuery[ 128 ];

	format(inactiveQuery, sizeof(inactiveQuery), "SELECT `vipRank` FROM `accounts` WHERE `sqlid` = '%d' LIMIT 0 , 1", sqlid);
	result = mysql_query(g_SQL, inactiveQuery);
	rows = cache_num_rows();
	if(!rows)
		value = 0;
	else
		cache_get_value_name_int(0, "vipRank", value);
	
	cache_delete(result);
	return value;
}

stock GetPlayerBankMoney(sqlid)
{
	new	Cache:result,
		rows,
		value = 0,
		inactiveQuery[ 128 ];

	format(inactiveQuery, sizeof(inactiveQuery), "SELECT `bankMoney` FROM `accounts` WHERE `sqlid` = '%d' LIMIT 0 , 1", sqlid);
	result = mysql_query(g_SQL, inactiveQuery);
	rows = cache_num_rows();
	if(!rows)
		value = 0;
	else
		cache_get_value_name_int(0, "bankMoney", value);
	
	cache_delete(result);
	return value;
}

stock GetPlayerPaydayCount(sqlid)
{
	new	Cache:result,
		rows,
		value = 0,
		inactiveQuery[ 128 ];

	format(inactiveQuery, sizeof(inactiveQuery), "SELECT `monthpaydays` FROM `experience` WHERE `sqlid` = '%d' LIMIT 0 , 1", sqlid);
	result = mysql_query(g_SQL, inactiveQuery);
	rows = cache_num_rows();
	if(!rows)
		value = 0;
	else
		cache_get_value_name_int(0, "monthpaydays", value);
	
	cache_delete(result);
	return value;
}

stock IsAccountTeamStaff(sqlid)
{
	new	Cache:result,
		rows,
		bool:value = false,
		admin = 0,
		helper = 0,
		inactiveQuery[ 128 ];

	format(inactiveQuery, sizeof(inactiveQuery), "SELECT `adminLvl`, `helper` FROM `accounts` WHERE `sqlid` = '%d' LIMIT 0 , 1", sqlid);
	result = mysql_query(g_SQL, inactiveQuery);
	rows = cache_num_rows();
	if(!rows)
		value = false;
	else
	{
		cache_get_value_name_int(0, "adminLvl", admin);
		cache_get_value_name_int(0, "helper", helper);
		if(admin > 0 || helper > 0)
			value = true;
	}
	cache_delete(result);
	return value;
}

stock IsValidInactivity(sqlid)
{
	new	Cache:result,
		rows,
		bool:value = false,
		endstamp,
		inactiveQuery[ 128 ];

	format(inactiveQuery, sizeof(inactiveQuery), "SELECT `sqlid`, `endstamp` FROM `inactive_accounts` WHERE `sqlid` = '%d' LIMIT 0 , 1", sqlid);
	result = mysql_query(g_SQL, inactiveQuery);
	rows = cache_num_rows();
	if(!rows)
		value = false;
	else
	{
		cache_get_value_name_int(0, "endstamp", endstamp);
		if(endstamp >= gettimestamp()) // Prijavljena neaktivnost jos uvijek traje
			value = true;
		else // Prijavljena neaktivnost je istekla
		{
			format(inactiveQuery, sizeof(inactiveQuery), "DELETE FROM `inactive_accounts` WHERE `sqlid` = '%d'", sqlid);
			mysql_tquery(g_SQL, inactiveQuery, "", "");
			value = false;
		}
	}
	cache_delete(result);
	return value;
}

/**
    <summary>
        Daje igracev broj od njegovog MySQL IDa
    </summary>
	
	<param name="sqlid">
        MySQL ID od igraca
    </param>

    <returns>
        Igracev broj
    </returns>

    <remarks>
        -
    </remarks>
*/
stock GetPlayerMobileNumberFromSQL(sqlid)
{
    new
		dest = 0;
	if( sqlid > 0 ) {
	    new	Cache:result,
			mobileQuery[ 128 ];

		format(mobileQuery, sizeof(mobileQuery), "SELECT `number` FROM `player_phones` WHERE `player_id` = '%d' AND `type` = '1'", sqlid);
		result = mysql_query(g_SQL, mobileQuery);
  		cache_get_value_index_int(0, 0, dest);
		cache_delete(result);
	} 
	return dest;
}

////////
PrintAccent(playerid)
{
	new 
		string[64];
	
	if(!isnull(PlayerInfo[playerid][pAccent]) || PlayerInfo[playerid][pAccent][0] == EOS)
		format(string, 64, "");
	else if( strcmp(PlayerInfo[playerid][pAccent], "None", true) )
		format(string, 64, "[%s] ", PlayerInfo[playerid][pAccent]);
    return string;
}

stock ClearPlayerChat(playerid)
{
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
	SendClientMessage(playerid, -1, "\n");
}

stock OOCProxDetector(Float:radi, playerid, string[], col1, col2, col3, col4, col5)
{
	if(IsPlayerConnected(playerid))
	{
		new Float:posx,
		    Float:posy,
			Float:posz,
		    Float:oldposx,
		    Float:oldposy,
			Float:oldposz,
		    Float:tempposx,
			Float:tempposy,
			Float:tempposz;

		GetPlayerPos(playerid, oldposx, oldposy, oldposz);

		foreach (new i : Player)
		{
			if(GetPlayerVirtualWorld(playerid) == GetPlayerVirtualWorld(i))
			{
				if( !Bit1_Get(gr_BlockedOOC, i) )
				{
					GetPlayerPos(i, posx, posy, posz);
					tempposx = (oldposx -posx);
					tempposy = (oldposy -posy);
					tempposz = (oldposz -posz);

					if (((tempposx < radi/16) && (tempposx > -radi/16)) && ((tempposy < radi/16) && (tempposy > -radi/16)) && ((tempposz < radi/16) && (tempposz > -radi/16)))
					{
						SendClientMessage(i, col1, string);
					}
					else if (((tempposx < radi/8) && (tempposx > -radi/8)) && ((tempposy < radi/8) && (tempposy > -radi/8)) && ((tempposz < radi/8) && (tempposz > -radi/8)))
					{
						SendClientMessage(i, col2, string);
					}
					else if (((tempposx < radi/4) && (tempposx > -radi/4)) && ((tempposy < radi/4) && (tempposy > -radi/4)) && ((tempposz < radi/4) && (tempposz > -radi/4)))
					{
						SendClientMessage(i, col3, string);
					}
					else if (((tempposx < radi/2) && (tempposx > -radi/2)) && ((tempposy < radi/2) && (tempposy > -radi/2)) && ((tempposz < radi/2) && (tempposz > -radi/2)))
					{
						SendClientMessage(i, col4, string);
					}
					else if (((tempposx < radi) && (tempposx > -radi)) && ((tempposy < radi) && (tempposy > -radi)) && ((tempposz < radi) && (tempposz > -radi)))
					{
						SendClientMessage(i, col5, string);
					}
				}
				else if(Bit1_Get(gr_BlockedOOC, i) && (PlayerInfo[playerid][pAdmin] || PlayerInfo[playerid][pHelper]))
				{
					GetPlayerPos(i, posx, posy, posz);
					tempposx = (oldposx -posx);
					tempposy = (oldposy -posy);
					tempposz = (oldposz -posz);

					if (((tempposx < radi/16) && (tempposx > -radi/16)) && ((tempposy < radi/16) && (tempposy > -radi/16)) && ((tempposz < radi/16) && (tempposz > -radi/16)))
					{
						SendClientMessage(i, col1, string);
					}
					else if (((tempposx < radi/8) && (tempposx > -radi/8)) && ((tempposy < radi/8) && (tempposy > -radi/8)) && ((tempposz < radi/8) && (tempposz > -radi/8)))
					{
						SendClientMessage(i, col2, string);
					}
					else if (((tempposx < radi/4) && (tempposx > -radi/4)) && ((tempposy < radi/4) && (tempposy > -radi/4)) && ((tempposz < radi/4) && (tempposz > -radi/4)))
					{
						SendClientMessage(i, col3, string);
					}
					else if (((tempposx < radi/2) && (tempposx > -radi/2)) && ((tempposy < radi/2) && (tempposy > -radi/2)) && ((tempposz < radi/2) && (tempposz > -radi/2)))
					{
						SendClientMessage(i, col4, string);
					}
					else if (((tempposx < radi) && (tempposx > -radi)) && ((tempposy < radi) && (tempposy > -radi)) && ((tempposz < radi) && (tempposz > -radi)))
					{
						SendClientMessage(i, col5, string);
					}
				}
			}
		}
	}
	return 1;
}

stock ReportMessage(color,const string[],level)
{
	foreach (new i : Player)
	{
		if(PlayerInfo[i][pAdmin] >= level && !Bit1_Get( a_TogReports, i ) )
			SendClientMessage(i, color, string);
		else if( PlayerInfo[i][pHelper] )
			SendClientMessage(i, color, string);
	}
	return 1;
}

stock GetPlayerNameFromID(mysqlid)
{
	new 
		name[MAX_PLAYER_NAME];
		
	if(mysqlid == 9999) {
		format(name, MAX_PLAYER_NAME, "None");
		return name;
	}
	
	new
		nameQuery[ 128 ],
		Cache:result;
	
	format(nameQuery, 128, "SELECT `name` FROM `accounts` WHERE `sqlid` = '%d'", mysqlid);
	result = mysql_query(g_SQL, nameQuery);
	
	cache_get_value_name(0, "name",  name);
	cache_delete(result);
	return name;
}

// Pokazuje stats dialog igracu (targetid-u).
stock ShowPlayerStats(playerid, targetid)
{
	new
		tmpString[ 20 ],
		motd[ 256 ], gender[15+1], b_coowner[4];

	switch(PlayerInfo[targetid][pSex])	{
		case 0: format(gender, sizeof(gender), "Musko"); // re-bug
		case 1: format(gender, sizeof(gender), "Musko");
		case 2: format(gender, sizeof(gender), "Zensko");
	}
	if(PlayerInfo[playerid][BizCoOwner] == true)
		format(b_coowner, sizeof(b_coowner), "Da");
	else if(PlayerInfo[playerid][BizCoOwner] == false)
		format(b_coowner, sizeof(b_coowner), "Ne");
		
    new pDialog[1500];
	format(motd, sizeof(motd),"Datum: %s\n\n"COL_COABLUE"IC STATS:\n\n"COL_WHITE"%s | Spol: [%s] | Godina: [%d] | Crypto broj: [%d] | Novac: [$%d] | Banka: [$%d] | Broj telefona: [%d]\n",
		ReturnDate(),
		GetName(targetid,true),
		gender,
		PlayerInfo[targetid][pAge],
		PlayerInfo[targetid][pCryptoNumber],
		PlayerInfo[targetid][pMoney],
		PlayerInfo[targetid][pBank],
		PlayerInfo[targetid][pMobileNumber]
	);
    strcat(pDialog,motd, sizeof(pDialog));

	switch(PlayerInfo[targetid][pJob])  {
         case 1:  format(tmpString, 20, "Cistac ulica");
         case 2:  format(tmpString, 20, "Pizza Boy");
         case 3:  format(tmpString, 20, "Mehanicar");
         case 4:  format(tmpString, 20, "Kosac trave");
         case 5:  format(tmpString, 20, "Tvornicki radnik");
         case 6:  format(tmpString, 20, "Taksist");
         case 7:  format(tmpString, 20, "Farmer");
		 case 8:  format(tmpString, 20, "Nepoznato");
         case 9:  format(tmpString, 20, "Nepoznato");
         case 12: format(tmpString, 20, "Gun Dealer");
         case 13: format(tmpString, 20, "Car Jacker");
         case 14: format(tmpString, 20, "Drvosjeca");
         case 15: format(tmpString, 20, "Nepoznato");
         case 16: format(tmpString, 20, "Smetlar");
         case 17: format(tmpString, 20, "Vehicle Impounder");
         case 18: format(tmpString, 20, "Transporter");
         case 19: format(tmpString, 20, "Nepoznato");
         case 20: format(tmpString, 20, "Nepoznato");
         case 21: format(tmpString, 20, "Nepoznato");
		 case 22: format(tmpString, 20, "Nepoznato");
		 case 23: format(tmpString, 20, "Nepoznato");
         case 24: format(tmpString, 20, "Nepoznato");
         case 25: format(tmpString, 20, "Nepoznato");
         default: format(tmpString, 20, "Nezaposlen");
    }
	/*new
		tmpMarried[MAX_PLAYER_NAME];
	if(!isnull(PlayerInfo[targetid][pMarriedTo]))
		format( tmpMarried, MAX_PLAYER_NAME, PlayerInfo[targetid][pMarriedTo] );
	else
		format( tmpMarried, MAX_PLAYER_NAME, "Nikim");*/
	//ispred Posao: fali Ozenjen s: %s
    format(motd, sizeof(motd),""COL_WHITE"Posao: [%s] | Ugovor: [%d/%d] | Uhicen: [%d] | Profit po PayDayu: [$%d] | Organizacija: [%s] | Rank u organizaciji: [%s (%d)] | Hunger: [%.2f]\n",
		//tmpMarried,
		tmpString,
		PlayerInfo[targetid][pContractTime],
		PlayerInfo[targetid][pDonateRank] ? 1 : 5,
		PlayerInfo[targetid][pArrested],
		PlayerInfo[targetid][pPayDayMoney],
		ReturnPlayerFactionName(targetid),
		ReturnPlayerRankName(targetid),
		PlayerInfo[targetid][pRank],
		PlayerInfo[targetid][pHunger]
	);
	strcat(pDialog,motd, sizeof(pDialog));
	
	format(motd, sizeof(motd),""COL_WHITE"Bankovna stednja: [%dh / %dh] | Ulozeno novaca: [%d$] | Zabrana stednje: [%dh]\n\n\n",
		PlayerInfo[targetid][pSavingsTime],
		PlayerInfo[targetid][pSavingsType],
		PlayerInfo[targetid][pSavingsMoney],
		PlayerInfo[targetid][pSavingsCool]
	);
	strcat(pDialog,motd, sizeof(pDialog));

	switch( PlayerInfo[targetid][pDonateRank] ) {
		case 1: format(tmpString, 20, "Bronze");
		case 2:	format(tmpString, 20, "Silver");
		case 3:	format(tmpString, 20, "Gold");
		case 4: format(tmpString, 20, "Platinum");
		default:
			format(tmpString, 20, "Nista");
	}

    format(motd, sizeof(motd),""COL_COABLUE"OOC STATS:\n\n"COL_WHITE"SQL ID: [%d] | Level: [%d] | Premium Account: [%s] | Sati igranja: [%d] | Respekti: [%d/%d]\n",
		PlayerInfo[targetid][pSQLID],
		PlayerInfo[targetid][pLevel],
		tmpString,
		PlayerInfo[targetid][pConnectTime],
		PlayerInfo[targetid][pRespects],
		( PlayerInfo[targetid][pLevel] + 1 ) * 4
	);
    strcat(pDialog,motd, sizeof(pDialog));

    format(motd, sizeof(motd),""COL_WHITE"Muscle lvl: [%d] | Warnings: [%d/3] | Vrijeme do place: [%d minuta] | VIP Vozilo: [%d] | Donator Veh Perms: [%d] | Mobile Credits: [%d$]\n",
		PlayerInfo[targetid][pMuscle],
		PlayerInfo[targetid][pWarns],
		( 60 - PlayerInfo[targetid][pPayDay] ),
		PlayerInfo[targetid][pDonatorVehicle],
		PlayerInfo[targetid][pDonatorVehPerms],
		PlayerInfo[targetid][pMobileCost]
	);
    strcat(pDialog,motd, sizeof(pDialog));
	
	format(motd, sizeof(motd),""COL_WHITE"Zadnji puta IG: [%s]\n",
		PlayerInfo[targetid][pLastLogin]
	);
	strcat(pDialog,motd, sizeof(pDialog));
	
	format(motd, sizeof(motd),""COL_WHITE"House key: [%d] | Biznis key: [%d] | Garage key: [%d] | RentKey[%d] | CarKey: [%d] | Job Key: [%d] | ComplexKey [%d] | ComplexRoomKey [%d] | Biznis Co-Owner [%s/%d]\n\n\n",
		PlayerInfo[targetid][pHouseKey],
		PlayerInfo[targetid][pBizzKey],
		PlayerInfo[targetid][pGarageKey],
		PlayerInfo[targetid][pRentKey],
		PlayerInfo[targetid][pSpawnedCar],
		PlayerInfo[targetid][pJob],
		PlayerInfo[targetid][pComplexKey],
		PlayerInfo[targetid][pComplexRoomKey],
		b_coowner,
		PlayerInfo[targetid][pBusiness]	
	);
	strcat(pDialog,motd, sizeof(pDialog));
	if( PlayerInfo[playerid][pAdmin] >= 1 )
	{

		format(motd, sizeof(motd), ""COL_COABLUE"WEAPONS STATS:\n\n"COL_WHITE"Gun #1: [%d] | Gun #2: [%d] | Gun #3: [%d] | Gun #4: [%d] | Gun #5: [%d]\nGun #6: [%d] | Gun #7: [%d] | Gun #8: [%d] | Gun #9: [%d] | Gun #10: [%d]\n",
			PlayerWeapons[targetid][pwWeaponId][1],
			PlayerWeapons[targetid][pwWeaponId][2],
			PlayerWeapons[targetid][pwWeaponId][3],
			PlayerWeapons[targetid][pwWeaponId][4],
			PlayerWeapons[targetid][pwWeaponId][5],
			PlayerWeapons[targetid][pwWeaponId][6],
			PlayerWeapons[targetid][pwWeaponId][7],
			PlayerWeapons[targetid][pwWeaponId][8],
			PlayerWeapons[targetid][pwWeaponId][9],
			PlayerWeapons[targetid][pwWeaponId][10]
		);
		strcat(pDialog,motd, sizeof(pDialog));

		format(motd, sizeof(motd), "\n\n"COL_WHITE"Ammo #1: [%d] | Ammo #2: [%d] | Ammo #3: [%d] | Ammo #4: [%d] | Ammo #5: [%d]\nAmmo #6: [%d] | Ammo #7: [%d] | Ammo #8: [%d] | Ammo #9: [%d] | Ammo #10: [%d]\n",
			PlayerWeapons[targetid][pwAmmo][1],
			PlayerWeapons[targetid][pwAmmo][2],
			PlayerWeapons[targetid][pwAmmo][3],
			PlayerWeapons[targetid][pwAmmo][4],
			PlayerWeapons[targetid][pwAmmo][5],
			PlayerWeapons[targetid][pwAmmo][6],
			PlayerWeapons[targetid][pwAmmo][7],
			PlayerWeapons[targetid][pwAmmo][8],
			PlayerWeapons[targetid][pwAmmo][9],
			PlayerWeapons[targetid][pwAmmo][10]
		);
		strcat(pDialog,motd, sizeof(pDialog));
	}
    ShowPlayerDialog(playerid, DIALOG_STATS, DIALOG_STYLE_MSGBOX, ""COL_COABLUE"Your Stats", pDialog, "OK", "");
	return 1;
}

Function: SayHelloToPlayer(playerid)
{
	//Hello Message
	new 
		string[85];
	format(string, 85, "~w~Dobro dosli~n~~h~~h~~b~%s", GetName(playerid));
	GameTextForPlayer(playerid, string, 2500, 1);
	Bit1_Set( gr_FristSpawn, playerid, false );
	return 1;
}

stock SetPlayerScreenFade(playerid)
{
    BlindTD[playerid] = CreatePlayerTextDraw(playerid, -20.000000, 0.000000, "_");
	PlayerTextDrawUseBox(playerid, BlindTD[playerid], 1);
	PlayerTextDrawBoxColor(playerid, BlindTD[playerid], 0x000000FF);
	PlayerTextDrawFont(playerid, BlindTD[playerid], 3);
	PlayerTextDrawLetterSize(playerid, BlindTD[playerid], 1.0, 100.0);
	PlayerTextDrawColor(playerid, BlindTD[playerid], 0x000000FF);
	PlayerTextDrawShow(playerid, BlindTD[playerid]);
	return 1;
}

stock RemovePlayerScreenFade(playerid)
{
	PlayerTextDrawHide(playerid, BlindTD[playerid]);
	PlayerTextDrawDestroy(playerid, BlindTD[playerid]);
	BlindTD[playerid] = PlayerText:INVALID_TEXT_DRAW;
	return 1;
}
stock IllegalFactionJobCheck(factionid, jobid)
{
    new	Cache:result,
		counts,
		tmpQuery[256];

	format(tmpQuery, sizeof(tmpQuery), "SELECT * FROM `accounts` WHERE `jobkey` = '%d' AND (`facMemId` = '%d' OR `facLeadId` = '%d')", jobid, factionid, factionid);
	result = mysql_query(g_SQL, tmpQuery);
	counts = cache_num_rows();
	cache_delete(result);
	
	return counts;
}

/*
	##     ##  #######   #######  ##    ##  ######  
	##     ## ##     ## ##     ## ##   ##  ##    ## 
	##     ## ##     ## ##     ## ##  ##   ##       
	######### ##     ## ##     ## #####     ######  
	##     ## ##     ## ##     ## ##  ##         ## 
	##     ## ##     ## ##     ## ##   ##  ##    ## 
	##     ##  #######   #######  ##    ##  ######  
*/
hook OnPlayerConnect(playerid) 
{
    PlayerDrunkLevel[playerid]	= 0;
    PlayerFPS[playerid]       	= 0;
	PlayerFPSUnix[playerid]		= gettimestamp();
	return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
	if(SafeSpawned[playerid])
	{
		stop PlayerTask[playerid];
		PlayerGlobalTaskTimer[playerid] = false;
	}
	
	RemovePlayerScreenFade(playerid);
	DisablePlayerCheckpoint(playerid);
    PlayerDrunkLevel[playerid]	= 0;
    PlayerFPS[playerid]       	= 0;
	PlayerFPSUnix[playerid]		= 0;
	if(ADOText[playerid])
	{
		for(new i = 0; i < MAX_ADO_LABELS; i++)
		{
		    if(AdoLabels[i][labelid] == playerid)
		    {
		        AdoLabels[i][labelid] = 0;
                DestroyDynamic3DTextLabel(AdoLabels[i][label]);
		        ADOText[playerid] = 0;
		        break;
		    }
		}
	}
	return 1;
}
/*
public OnPlayerPause(playerid)
{
	if(SafeSpawned[playerid])
	{
		stop PlayerTask[playerid];
		PlayerGlobalTaskTimer[playerid] = false;
	}
	return 1;
}*/

hook OnPlayerUpdate(playerid) 
{
	if(!PlayerGlobalTaskTimer[playerid] && SafeSpawned[playerid])
	{
		PlayerGlobalTaskTimer[playerid] = true;
		PlayerTask[playerid] = repeat PlayerGlobalTask(playerid);
	}
		
	if( PlayerFPSUnix[playerid] < gettimestamp() ) 
	{
		new drunkLevel = GetPlayerDrunkLevel(playerid);
		if( drunkLevel < 100 ) {
			SetPlayerDrunkLevel(playerid, 2000);
		} else {
			if( PlayerDrunkLevel[playerid] != drunkLevel ) {
				new 
					restFPS = PlayerDrunkLevel[playerid] - drunkLevel;
				if( ( restFPS > 0 ) && ( restFPS < 200 ) )
					PlayerFPS[playerid] = restFPS;
				PlayerDrunkLevel[playerid] = drunkLevel;
			}
		}
		PlayerFPSUnix[playerid] = gettimestamp();
	}
	return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
		case DIALOG_RULES: 
		{
			if( !response ) return 1;
			switch(listitem) 
			{
				case 0: 
				{
					new string[835];
					strcat(string,"Metagaming - Metagaming najcesce predstavlja mijesanje Out Of Characted (OOC) i In Character (IC) stvari. Naravno,\n takav vid krsenja pravila se moze ispoljiti na vise nacina ali najcesci su:\n 1.) Citanje nametaga iznad igraca te dozivanje istoga IC iako ga ne poznajete ili nikada niste ni culi njegovo ime", sizeof(string));
					strcat(string,"\n 2.) Koristenje /pm komande kako bi se nasli negdje radi neke IC stvari,\n tipa prodaja oruzja, droge ili jednostavno radi neke price. U ovaj vid krsenja pravila se takodje ubraja i\n koristenje 3rd party programa kako bi se nasli negdje IC.", sizeof(string));
					strcat(string,"\n 3.) Koristenje informacija koje ste saznali OOC za IC svrhe je takodje zabranjeno.\n Primjer, ako ste culi da dolazi policija da vas uhapsi OOC i iskoristite to IC kako bi pobjegli daleko od njih kako vas ne mogu naci.", sizeof(string));
					strcat(string,"\n Sve ovo je kaznjivo i strogo zabranjeno na nasem serveru.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "Metagaming", string, "Close", "");
					return 1;
				}
				case 1: 
				{
					new string[860];
					strcat(string, "Powergaming - Powergaming je, u najcescim slucajevima, roleplay radnje koja u tom trenutku nije moguca ili uopste nije moguca, za ljudsko tijelo ili slicno.\n Naravno, i powergaming kao metagaming moze biti na vise nacina uradjen. Takodje kaznjih. Najcesce radnje su:\n 1. Skakanje sa neke odredjene visine koja je dovoljna da vas povrijedi pri padu i udari o tlo a da se povreda na roleplaya nego igrac jednostavno ustane i nastavi dalje.", sizeof(string));
					strcat(string, "\n 2. Zavezani ste lisicama a onda roleplayate da jednostavno lomite lisice. To u, barem toj situaciji, nije nikako moguce.", sizeof(string));
					strcat(string, "\n 3. Drzi vas jedan lik sa ledja dok vas drugi udara sprijeda, vi se okrenete i prebacite jednoga preko ledja a drugoga kung-fu potezom udarite u glavu i pobjegnete.\n Velika je vjerovatnoca da ovo nikako ne mozete izvesti, tako da se i ovo smatra powergamingom. Svaki vid powergaminga je kaznjiv.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "Powergaming", string, "Close", "");
					return 1;
				}
				case 2: 
				{
					new string[720];
					strcat(string, "RP2WIN - RP2WIN je roleplay sa nekom drugom osobom u kojem forsirate, bukvalno, da sve ide u vasu korist.\n Nesto sto moze da vam priblizi ovu radnju je sledeci me: / me sutira Ime_Prezime ta ga obara na pod izazivajuci mu nesvijest.\n Ovo je zabranjeno raditi jer u roleplayu treba svakome dati pravednu sansu da odradi svoju stranu RP-a.\n Pravilan me bi trebao glasiti: / me pokusava udariti Ime_Prezime kako bi ga oborio na pod.", sizeof(string));
					strcat(string, "\n Tek kada vidite da li je igrac pao, odatle mozete nove situacije RPati. Naravno, RP2WIN moze da se izrazi i kada se branite.\n Ukoliko neko iskoristi nesto slicno drugom me-u, a vi samo napisete da vas je promasio ili da ste se izmakli takodje moze biti vid RP2WINa ali takodje i PGa.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "RP2WIN", string, "Close", "");
					return 1;
				}
				case 3: 
				{
					new string[480];
					strcat(string, "Revenge Kill - Revenge Kill kao sto samo ime kaze je ubojstvo iz osvete.\n Kada se dogodi ubojstvo, vi morate zaboraviti SVE u vezi tog dogadjaja. Mjesto ubojstva, pocinjitela, ucesnike.", sizeof(string));
					strcat(string, "Sve.\n Jednostavno nastavljate RPati kao da se to nikada nije dogodilo ali ako ste prezivjeli, naravno,\n imate svako pravo da RPate da se to dogodilo i imate pravo juriti toga koji vas je pokusao ubiti, onda ne bi bio revenge kill\n vec pokusaj ubojstva koji nije uspio.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "Revenge Kill", string, "Close", "");
					return 1;
				}
				case 4: 
				{
					new string[320];
					strcat(string, "Deathmatch - Vjerovatno znate o cemu se radi. DM je ubijanje ljudi bez ikakvog ili bez dovoljno dobrog IC razloga.\n Nedovoljno dobar razlog moze predstavljati to", sizeof(string));
					strcat(string, "sto vas je igrac mrko pogledao a vi ste ispraznili citav sarzer u njega.\n Ovo je STROGO zabranjeno na nasem serveru i isto tako je kaznjivo.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "Deathmatch", string, "Close", "");
					return 1;
				}
				case 5: 
				{
					new string[640];
					strcat(string, "-/me koristite kako bi prikazali radnju koju vas karakter izvrsava u odredjenom trenutku.\n Nema pisanja predugackih /me emotesa sa 5 priloski odredbi za nacin koje zavrsavaju na -ci.\n To je bespotrebno i niste bolji rper ako napisete kilometarski /me.", sizeof(string));
					strcat(string, "\n Ali i ako dodjete u situaciju da napisete sve u jedan /me probajte da tu ne budu\n vise od 3 radnje/glagola jer je onda to PG. Dakle,trudite se citljive i jednostavne\n emotese pisati da vas ljudi koji rpaju sa vama razumiju.", sizeof(string));
					strcat(string, "\n Imenko_Prezimenko vadi kutiju cigareta i lijevog dzepa. \n Imenko_Prezimenko uzima jednu cigaretu te ju pali.\n Ovo su primjeri dobrog koristenja /me emotesa.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "/me komanda", string, "Close", "");
					return 1;
				}
				case 6: 
				{
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "/ame komanda", "-/ame je ustvari isto sto i /me samo ce se tekst koji upisete ispisati vama iznad glave.\nDakle ako upisete /ame gleda kako Johnny jede, ono sto ce iznad vase glave pisati je Imenko_Prezimenko gleda kako Johnny jede.\n/ame jos mozete koristiti za izrazavanje emocija vaseg lika, kao npr /ame se smije. Takodjer se moze koristiti da opisete svoj izgled tj. izgled svoga lika.", "Close", "");
					return 1;
				}
				case 7: 
				{
					new string[660];
					strcat(string, "/do koristite kako bi opisali ono sto se desava oko vas, tj okolinu u kojoj se vas karakter nalazi.\n /Do emotes ne KORISTITE da bi prikazali sta vas karakter radi jer je za to /me. Nema smisla pisati /do Rukujemo se, /do Izgledam kao da imam 15 godina.\n Znaci trudite se da ga ne koristite ni da opisete svog karaktera tako cesto, jer za to mozete koristiti i /ame.\n /ame izgleda kao da ima 15 godina, crne hlace i duks.", sizeof(string));
					strcat(string, "Par primjera ispravnog koristenja /do komande:\n /do Iz pravca mehanicarske radnje bi dolazio miris ulja radi vozila koja sa tamo popravljaju.\n /Do Kafic bi bio sav u neredu, stolice su prevrnute kao i stolovi.", sizeof(string));
					ShowPlayerDialog(playerid, 0, DIALOG_STYLE_MSGBOX, "/do komanda", string, "Close", "");
					return 1;
				}
			}
			return 1;
		}
	}
	return 0;
 }

stock GetChannelSlot(playerid, channel)
{
	if(channel == PlayerInfo[playerid][pRadio][1])return 1;
	if(channel == PlayerInfo[playerid][pRadio][2])return 2;
	if(channel == PlayerInfo[playerid][pRadio][3])return 3;

	return false;
}