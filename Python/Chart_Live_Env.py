
class Chart:
    def __init__(self, start_balance, symbol, lotsize, max_buy, max_sell, trader):
        self.max_buy       = max_buy
        self.max_sell      = max_sell        
        self.lot           = lotsize
        self.start_balance = start_balance
        self.equity        = start_balance
        self.symbol        = symbol
        self.longs         = 0
        self.shorts        = 0
        self.current_price = 0
        self.candle        = 0
        self.trader        = trader   

    def get_state(self):
        state =  (self.longs)                    *self.max_sell*200
        state += (self.shorts)                                 *200
        state += int(self.equity/self.start_balance*100)     
        return state
    
    def CloseBuy(self):
        self.trader.close_order(0)

    def CloseSell(self):
        self.trader.close_order(1)

    def step(self, action, newprice, longs, shorts, equity):
        self.candle += 1
        self.current_price = newprice
        ret = ()
        self.longs = longs
        self.shorts = shorts
        self.equity = equity

        if action == 0:    # Buy
            if self.longs < self.max_buy:
                self.trader.open_order(self.symbol, 'buy', self.lot, 0, 0, 0, 12, self.candle, 0)
                ret=  (-1, False)
            else:
                ret = (-50, False)

                
        elif action == 1:  # Sell
            if self.shorts < self.max_sell:
                self.trader.open_order(self.symbol, 'sell', self.lot, 0, 0, 0, 12, self.candle, 0)
                ret = (-1, False)
            else:
                ret = (-50, False)

        elif action == 2:  # Close buy
            if (self.longs) > 0:
                self.CloseBuy()
                ret=  (-1, False)
            else:
                ret = (-30, False)


        elif action == 3:  # Close sell
            if (self.shorts) > 0:
                self.CloseSell()
                ret=  (-1, False)
            else:
                ret = (-30, False)


        elif action == 4: # Hold
            ret = (-1, False)
        
        if self.equity <= 0:
            return -1000, True
        elif self.equity > 2 * self.start_balance:
            self.trader.close_all_orders()
            return 1000, True      

        return ret

        
