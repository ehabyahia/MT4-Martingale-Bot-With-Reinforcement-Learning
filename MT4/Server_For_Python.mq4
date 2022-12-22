//+------------------------------------------------------------------+
//|                                            Server_For_Python.mq4 |
//|                                                        EhabYahia |
//|                                             eahabyahia@gmail.com |
//+------------------------------------------------------------------+


#property copyright "eahabyahia@gmail.com"
#property link      "https://one.exness.link/a/ua3p9l6i"
#property version "1.0"
#property strict



int maxCommandFiles = 50;
int maxNumberOfCharts = 100;

long lastMessageMillis = 0;
long lastUpdateMillis = GetTickCount(), lastUpdateOrdersMillis = GetTickCount();

string startIdentifier = "<:";
string endIdentifier = ":>";
string delimiter = "|";
string folderName = "Python_Server";
string filePathMessages = folderName + "/Messages.txt";
string filePathCommandsPrefix = folderName + "/Commands_";

string lastOrderText = "", lastMarketDataText = "", lastMessageText = "";
struct MESSAGE{
   long millis;
   string message;
};

MESSAGE lastMessages[];
string MarketDataSymbols[];



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

   if (!EventSetMillisecondTimer(25)) {
      Print("EventSetMillisecondTimer() returned an error: ", ErrorDescription(GetLastError()));
      return INIT_FAILED;
   }
   
   ResetFolder();
   ArrayResize(lastMessages, 50);


   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

   EventKillTimer();
   ResetFolder();
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
   
   // update prices regularly in case there was no tick within X milliseconds (for non-chart symbols). 
   if (GetTickCount() >= lastUpdateMillis + 25) OnTick();
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick() {
   /*
      Use this OnTick() function to send market data to subscribed client.
   */
   lastUpdateMillis = GetTickCount();
   
   CheckCommands();             
   CheckOpenOrders();
}


void CheckCommands() {
   for (int i=0; i<maxCommandFiles; i++) {
      string filePath = filePathCommandsPrefix + IntegerToString(i) + ".txt";
      if (!FileIsExist(filePath)) return;
      int handle = FileOpen(filePath, FILE_READ|FILE_TXT);  // FILE_COMMON | 
      if (handle == -1) return;
      if (handle == 0) return;
      
      string text = "";
      while(!FileIsEnding(handle)) text += FileReadString(handle);
      FileClose(handle);
      FileDelete(filePath);
      
      // make sure that the file content is complete. 
      int length = StringLen(text);
      if (StringSubstr(text, 0, 2) != startIdentifier) {
         SendError("WRONG_FORMAT_START_IDENTIFIER", "Start identifier not found for command: " + text);
         return;
      }
      
      if (StringSubstr(text, length-2, 2) != endIdentifier) {
         SendError("WRONG_FORMAT_END_IDENTIFIER", "End identifier not found for command: " + text);
         return;
      }
      text = StringSubstr(text, 2, length-4);
      
      ushort uSep = StringGetCharacter(delimiter, 0);
      string data[];
      int splits = StringSplit(text, uSep, data);
      
      if (splits != 2) {
         SendError("WRONG_FORMAT_COMMAND", "Wrong format for command: " + text);
         return;
      }
      
      string command = data[0];
      
      if (command == "OPEN_ORDER") {
         OpenOrder(data[1]);
      } else if (command == "CLOSE_ORDER") {
         CloseOrder((int)StringToInteger(data[1]));//CloseOrder(data[1]);
      } else if (command == "CLOSE_ALL_ORDERS") {
         CloseAllOrders();
      } 
      
        
        
   }
}


void OpenOrder(string orderStr) {
   
   string sep = ",";
   ushort uSep = StringGetCharacter(sep, 0);
   string data[];
   int splits = StringSplit(orderStr, uSep, data);
   
   if (ArraySize(data) != 9) {
      SendError("OPEN_ORDER_WRONG_FORMAT", "Wrong format for OPEN_ORDER command: " + orderStr);
      return;
   }
   
   int numOrders = NumOrders();
   
   string symbol = data[0];
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   int orderType = StringToOrderType(data[1]);
   double lots = NormalizeDouble(StringToDouble(data[2]), 2);
   double price = NormalizeDouble(StringToDouble(data[3]), digits);
   double stopLoss = NormalizeDouble(StringToDouble(data[4]), digits);
   double takeProfit = NormalizeDouble(StringToDouble(data[5]), digits);
   int magic = (int)StringToInteger(data[6]);
   string comment = data[7];
   datetime expiration = (datetime)StringToInteger(data[8]);
   
   if (price == 0 && orderType == OP_BUY) price = MarketInfo(symbol, MODE_ASK);
   if (price == 0 && orderType == OP_SELL) price = MarketInfo(symbol, MODE_BID);
   
   if (orderType == -1) {
      SendError("OPEN_ORDER_TYPE", StringFormat("Order type could not be parsed: %f (%f)", orderType, data[1]));
      return;
   }
   
   if (lots < MarketInfo(symbol, MODE_MINLOT) || lots > MarketInfo(symbol, MODE_MAXLOT)) {
      SendError("OPEN_ORDER_LOTSIZE_OUT_OF_RANGE", StringFormat("Lot size out of range (min: %f, max: %f): %f", MarketInfo(symbol, MODE_MINLOT), MarketInfo(symbol, MODE_MAXLOT), lots));
      return;
   }
   
   
   if (price == 0) {
      SendError("OPEN_ORDER_PRICE_ZERO", "Price is zero: " + orderStr);
      return;
   }
   
   int ticket = OrderSend(symbol, orderType, lots, price, 100, stopLoss, takeProfit, comment, magic, expiration);
   if (ticket >= 0) {
      SendInfo("Successfully sent order " + IntegerToString(ticket) + ": " + symbol + ", " + OrderTypeToString(orderType) + ", " + DoubleToString(lots, 2) + ", " + DoubleToString(price, digits));
   } else {
      SendError("OPEN_ORDER", "Could not open order: " + ErrorDescription(GetLastError()));
   }
}


int NumOrders() {
   
   int n = 0;

   for(int i=OrdersTotal()-1; i>=0; i--) {
   
      if (!OrderSelect(i,SELECT_BY_POS)) continue;
      
      if (OrderType() == OP_BUY || OrderType() == OP_SELL 
          || OrderType() == OP_BUYLIMIT || OrderType() == OP_SELLLIMIT 
          || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
         n++;
      }
   }
   return n;
}

void CloseOrder(int dir){

   if(dir == 0){
      double  LowestPrice = 0, llots=0;
      int ftiket = 0;
      
      for(int g=OrdersTotal()-1; g >= 0; g--){
         if(OrderSelect(g,SELECT_BY_POS,MODE_TRADES))
            if (OrderSymbol() == Symbol() && OrderType() == OP_BUY){
               if(OrderOpenPrice() <= LowestPrice || LowestPrice <= 0 ){
                  LowestPrice = OrderOpenPrice();
                  llots = OrderLots();
                  ftiket= OrderTicket();
               }   
           }
      }
   
         if(ftiket > 0 && llots > 0){
            if(!OrderClose(ftiket, llots, Bid, 100, Blue))
               PrintFormat("Error Closing Order %d Lots %f Error #%d",ftiket, llots, GetLastError());
         }
   }else
   if(dir == 1){
   
      double  Highest = 0, llots=0;
      int ftiket = 0;
      
      for(int g=OrdersTotal()-1; g >= 0; g--){
         if(OrderSelect(g,SELECT_BY_POS,MODE_TRADES))
            if (OrderSymbol() == Symbol() && OrderType() == OP_SELL){
               if(OrderOpenPrice() >= Highest || Highest <= 0 ){
                  Highest = OrderOpenPrice();
                  llots = OrderLots();
                  ftiket= OrderTicket();
               }   
           }
      }
   
         if(ftiket > 0 && llots > 0){
            if(!OrderClose(ftiket, llots, Ask, 100, Blue))
               PrintFormat("Error Closing Order %d Lots %f Error #%d",ftiket, llots, GetLastError());
         }

   }
}


void CloseAllOrders() {
   
   int closed = 0, errors = 0;

   for(int i=OrdersTotal()-1; i>=0; i--) {
   
      if (!OrderSelect(i,SELECT_BY_POS)) continue;
      
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
         bool res = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 100);
         if (res) 
            closed++;
         else 
            errors++;         
      } else if (OrderType() == OP_BUYLIMIT || OrderType() == OP_SELLLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
         bool res = OrderDelete(OrderTicket());
         if (res) 
            closed++;
         else 
            errors++; 
      }
   }
   
   if (closed == 0 && errors == 0) 
      SendInfo("No orders to close.");
   if (errors > 0) 
      SendError("CLOSE_ORDER_ALL", "Error during closing of " + IntegerToString(errors) + " orders.");
   else
      SendInfo("Successfully closed " + IntegerToString(closed) + " orders.");
}


int CountTrades(string choice){
   
   int count = 0 ;
   for(int aa=OrdersTotal()-1; aa >= 0; aa--){
      if(OrderSelect(aa,SELECT_BY_POS,MODE_TRADES)){
         if (OrderSymbol() != Symbol() ) continue;
         if (OrderSymbol() == Symbol() ){
            if(choice == "ALL"){
            if(OrderType() == OP_SELL || OrderType() == OP_BUY)
               count+=1;
            }
            else if(choice == "BUY"  && OrderType() == OP_BUY)
               count+=1;
            else if(choice == "SELL" && OrderType() == OP_SELL)
               count+=1;
         }
      }
   }
   
   
   
   return count;
}
double SymbolProfit(string choice ) {
   double p = 0;
   for(int pos_4 = OrdersTotal() - 1; pos_4 >= 0; pos_4--) {
      if(OrderSelect(pos_4, SELECT_BY_POS, MODE_TRADES))
         if (OrderSymbol() != Symbol() ) continue;
         if (OrderSymbol() == Symbol() ) {
            if(choice == "ALL"){
               if(OrderType() == OP_SELL || OrderType() == OP_BUY)
               p += OrderProfit();
            }
            else if(choice == "BUY"  && OrderType() == OP_BUY)
               p += OrderProfit();
            else if(choice == "SELL" && OrderType() == OP_SELL)
               p += OrderProfit();
         }
            
            
     }
   return (p);
  }
void CheckOpenOrders() {
   
   bool first = true;
   string text = StringFormat("{\"account_info\": {\"Ask\": %f,\"Bid\": %f,\"free_margin\": %f, \"balance\": %f, \"equity\": %f, \"buy_profit\": %f, \"sell_profit\": %f, \"buy_count\": %d, \"sell_count\": %d} ", 
                                                   Ask,        Bid,     AccountFreeMargin(), AccountBalance(), AccountEquity(), SymbolProfit("BUY"), SymbolProfit("SELL"), CountTrades("BUY"), CountTrades("SELL"));
   text += "}";
   
   // if there are open positions, it will almost always be different because of open profit/loss. 
   // update at least once per second in case there was a problem during writing. 
   if (text == lastOrderText && GetTickCount() < lastUpdateOrdersMillis + 1000) return;
   if (WriteToFile(filePathMessages, text)) {
      lastUpdateOrdersMillis = GetTickCount();
      lastOrderText = text;
   }
}


bool WriteToFile(string filePath, string text) {
   int handle = FileOpen(filePath, FILE_WRITE|FILE_TXT);  // FILE_COMMON | 
   if (handle == -1) return false;
   // even an empty string writes two bytes (line break). 
   uint numBytesWritten = FileWrite(handle, text);
   FileClose(handle);
   return numBytesWritten > 0;
}


void SendError(string errorType, string errorDescription) {
   Print("ERROR: " + errorType + " | " + errorDescription);
   string message = StringFormat("{\"type\": \"ERROR\", \"time\": \"%s %s\", \"error_type\": \"%s\", \"description\": \"%s\"}", 
                                 TimeToString(TimeGMT(), TIME_DATE), TimeToString(TimeGMT(), TIME_SECONDS), errorType, errorDescription);
   SendMessage(message);
}


void SendInfo(string message) {
   Print("INFO: " + message);
   message = StringFormat("{\"type\": \"INFO\", \"time\": \"%s %s\", \"message\": \"%s\"}", 
                          TimeToString(TimeGMT(), TIME_DATE), TimeToString(TimeGMT(), TIME_SECONDS), message);
   SendMessage(message);
}


void SendMessage(string message) {
   
   for (int i=ArraySize(lastMessages)-1; i>=1; i--) {
      lastMessages[i] = lastMessages[i-1];
   }
   
   lastMessages[0].millis = GetTickCount();
   // to make sure that every message has a unique number. 
   if (lastMessages[0].millis <= lastMessageMillis) lastMessages[0].millis = lastMessageMillis+1;
   lastMessageMillis = lastMessages[0].millis;
   lastMessages[0].message = message;
   
   bool first = true;
   string text = "{";
   for (int i=ArraySize(lastMessages)-1; i>=0; i--) {
      if (StringLen(lastMessages[i].message) == 0) continue;
      if (!first)
         text += ", ";
      text += "\"" + IntegerToString(lastMessages[i].millis) + "\": " + lastMessages[i].message;
      first = false;
   }
   text += "}";
   
   if (text == lastMessageText) return;
   if (WriteToFile(filePathMessages, text)) lastMessageText = text;
}




// use string so that we can have the same in MT5. 
string OrderTypeToString(int orderType) {
   if (orderType == OP_BUY) return "buy";
   if (orderType == OP_SELL) return "sell";
   if (orderType == OP_BUYLIMIT) return "buylimit";
   if (orderType == OP_SELLLIMIT) return "selllimit";
   if (orderType == OP_BUYSTOP) return "buystop";
   if (orderType == OP_SELLSTOP) return "sellstop";
   return "unknown";
}

int StringToOrderType(string orderTypeStr) {
   if (orderTypeStr == "buy") return OP_BUY;
   if (orderTypeStr == "sell") return OP_SELL;
   if (orderTypeStr == "buylimit") return OP_BUYLIMIT;
   if (orderTypeStr == "selllimit") return OP_SELLLIMIT;
   if (orderTypeStr == "buystop") return OP_BUYSTOP;
   if (orderTypeStr == "sellstop") return OP_SELLSTOP;
   return -1;
}

void ResetFolder() {
   //FolderDelete(folderName);  // does not always work. 
   FolderCreate(folderName);
   FileDelete(filePathMessages);
   for (int i=0; i<maxCommandFiles; i++) {
      FileDelete(filePathCommandsPrefix + IntegerToString(i) + ".txt");
   }
}


string ErrorDescription(int errorCode) {
   string errorString;
   
   switch(errorCode)
     {
      //---- codes returned from trade server
      case 0:
      case 1:   errorString="no error";                                                  break;
      case 2:   errorString="common error";                                              break;
      case 3:   errorString="invalid trade parameters";                                  break;
      case 4:   errorString="trade server is busy";                                      break;
      case 5:   errorString="old version of the client terminal";                        break;
      case 6:   errorString="no connection with trade server";                           break;
      case 7:   errorString="not enough rights";                                         break;
      case 8:   errorString="too frequent requests";                                     break;
      case 9:   errorString="malfunctional trade operation (never returned error)";      break;
      case 64:  errorString="account disabled";                                          break;
      case 65:  errorString="invalid account";                                           break;
      case 128: errorString="trade timeout";                                             break;
      case 129: errorString="invalid price";                                             break;
      case 130: errorString="invalid stops";                                             break;
      case 131: errorString="invalid trade volume";                                      break;
      case 132: errorString="market is closed";                                          break;
      case 133: errorString="trade is disabled";                                         break;
      case 134: errorString="not enough money";                                          break;
      case 135: errorString="price changed";                                             break;
      case 136: errorString="off quotes";                                                break;
      case 137: errorString="broker is busy (never returned error)";                     break;
      case 138: errorString="requote";                                                   break;
      case 139: errorString="order is locked";                                           break;
      case 140: errorString="long positions only allowed";                               break;
      case 141: errorString="too many requests";                                         break;
      case 145: errorString="modification denied because order too close to market";     break;
      case 146: errorString="trade context is busy";                                     break;
      case 147: errorString="expirations are denied by broker";                          break;
      case 148: errorString="amount of open and pending orders has reached the limit";   break;
      case 149: errorString="hedging is prohibited";                                     break;
      case 150: errorString="prohibited by FIFO rules";                                  break;
      //---- mql4 errors
      case 4000: errorString="no error (never generated code)";                          break;
      case 4001: errorString="wrong function pointer";                                   break;
      case 4002: errorString="array index is out of range";                              break;
      case 4003: errorString="no memory for function call stack";                        break;
      case 4004: errorString="recursive stack overflow";                                 break;
      case 4005: errorString="not enough stack for parameter";                           break;
      case 4006: errorString="no memory for parameter string";                           break;
      case 4007: errorString="no memory for temp string";                                break;
      case 4008: errorString="not initialized string";                                   break;
      case 4009: errorString="not initialized string in array";                          break;
      case 4010: errorString="no memory for array\' string";                             break;
      case 4011: errorString="too long string";                                          break;
      case 4012: errorString="remainder from zero divide";                               break;
      case 4013: errorString="zero divide";                                              break;
      case 4014: errorString="unknown command";                                          break;
      case 4015: errorString="wrong jump (never generated error)";                       break;
      case 4016: errorString="not initialized array";                                    break;
      case 4017: errorString="dll calls are not allowed";                                break;
      case 4018: errorString="cannot load library";                                      break;
      case 4019: errorString="cannot call function";                                     break;
      case 4020: errorString="expert function calls are not allowed";                    break;
      case 4021: errorString="not enough memory for temp string returned from function"; break;
      case 4022: errorString="system is busy (never generated error)";                   break;
      case 4050: errorString="invalid function parameters count";                        break;
      case 4051: errorString="invalid function parameter value";                         break;
      case 4052: errorString="string function internal error";                           break;
      case 4053: errorString="some array error";                                         break;
      case 4054: errorString="incorrect series array using";                             break;
      case 4055: errorString="custom indicator error";                                   break;
      case 4056: errorString="arrays are incompatible";                                  break;
      case 4057: errorString="global variables processing error";                        break;
      case 4058: errorString="global variable not found";                                break;
      case 4059: errorString="function is not allowed in testing mode";                  break;
      case 4060: errorString="function is not confirmed";                                break;
      case 4061: errorString="send mail error";                                          break;
      case 4062: errorString="string parameter expected";                                break;
      case 4063: errorString="integer parameter expected";                               break;
      case 4064: errorString="double parameter expected";                                break;
      case 4065: errorString="array as parameter expected";                              break;
      case 4066: errorString="requested history data in update state";                   break;
      case 4099: errorString="end of file";                                              break;
      case 4100: errorString="some file error";                                          break;
      case 4101: errorString="wrong file name";                                          break;
      case 4102: errorString="too many opened files";                                    break;
      case 4103: errorString="cannot open file";                                         break;
      case 4104: errorString="incompatible access to a file";                            break;
      case 4105: errorString="no order selected";                                        break;
      case 4106: errorString="unknown symbol";                                           break;
      case 4107: errorString="invalid price parameter for trade function";               break;
      case 4108: errorString="invalid ticket";                                           break;
      case 4109: errorString="trade is not allowed in the expert properties";            break;
      case 4110: errorString="longs are not allowed in the expert properties";           break;
      case 4111: errorString="shorts are not allowed in the expert properties";          break;
      case 4200: errorString="object is already exist";                                  break;
      case 4201: errorString="unknown object property";                                  break;
      case 4202: errorString="object is not exist";                                      break;
      case 4203: errorString="unknown object type";                                      break;
      case 4204: errorString="no object name";                                           break;
      case 4205: errorString="object coordinates error";                                 break;
      case 4206: errorString="no specified subwindow";                                   break;
      default:   errorString="ErrorCode: " + IntegerToString(errorCode);
      }
   return(errorString);
}


void printArray(string &arr[]) {
   if (ArraySize(arr) == 0) Print("{}");
   string printStr = "{";
   int i;
   for (i=0; i<ArraySize(arr); i++) {
      if (i == ArraySize(arr)-1) printStr += arr[i];
      else printStr += arr[i] + ", ";
   }
   Print(printStr + "}");
}

//+------------------------------------------------------------------+
