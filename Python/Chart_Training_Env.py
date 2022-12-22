
class Chart:
    """
    This class is used for training data, and all money management values are estimated and does match the actual live market
    """
    def __init__(self, start_balance, max_buy, max_sell, data):
        self.start_balance = start_balance
        self.balance = start_balance
        self.equity = start_balance
        self.max_buy = max_buy
        self.max_sell = max_sell        
        self.data = data

        self.longs = []
        self.shorts = []
        self.PL = 100
        self.maxsteps = len(data)
        self.current_price = data[0]
        self.candle = 0


        
    def get_number_of_states(self): # absorbation states are set for number of active long/short trades up to max trades * 200% allower DD
        return (self.max_buy*self.max_buy)*(self.max_sell*self.max_sell)*200
    

    def get_state(self):
        state =  len(self.longs)                    *self.max_sell*200
        state += len(self.shorts)                                 *200
        state += int(abs(self.equity/self.start_balance)*100)     
        return state
    

    def CloseBuy(self):
        first_order = min(self.longs)
        self.balance += self.current_price-first_order
        self.longs.remove(first_order)


    def CloseSell(self):
        first_order = min(self.shorts)
        self.balance += self.current_price-first_order
        self.shorts.remove(first_order)


    def step(self, action):
        self.candle += 1
        if self.candle >= self.maxsteps:
            print(f'maxed out at {self.candle} candles') # The end of the data has finished and still no result 
            return -1000, True
        self.current_price = self.data[self.candle]
        ret = ()


        if action == 0:    # Buy
            if len(self.longs) < self.max_buy:
                self.longs.append(self.current_price)
                self.balance -= 1
                ret=  (-1, False)
            else:
                ret = (-50, False)

                
        elif action == 1:  # Sell
            if len(self.shorts) < self.max_sell:
                self.shorts.append(self.current_price)
                self.balance -= 1

                ret = (-1, False)
            else:
                ret = (-50, False)

        elif action == 2:  # Close buy
            if len(self.longs) > 0:
                self.CloseBuy()
                ret=  (-1, False)
            else:
                ret = (-30, False)


        elif action == 3:  # Close sell
            if len(self.shorts) > 0:
                self.CloseSell()
                ret=  (-1, False)
            else:
                ret = (-30, False)


        elif action == 4: # Hold
            ret = (-1, False)


        curPL = 0
        for op in self.longs:
            curPL += self.current_price-op
        for op in self.shorts:
            curPL += op - self.current_price

        LastPL = self.PL
        self.PL = curPL

        self.equity = self.balance-self.PL
        
        if self.equity <= 0:
            return -1000, True
        elif self.equity > 2 * self.start_balance:
            return 1000, True      

        return ret
