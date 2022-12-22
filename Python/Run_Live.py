from Trader import Server
from Chart_Live_Env import Chart

import numpy as np
import time


LOTSIZE = 0.01
MAXORDERS = 30
SYMBOL = 'XAUUSDm'

Q_TABLE = 'Python\Q_Tables\Q_table_1.npy'

MT4_FILES_DIR = '' # C:\\Users\\{PC_NAME}\\AppData\\Roaming\\MetaQuotes\\Terminal\\{PLATFORMNAME}\\MQL4\\Files\\


Q_table = np.load(Q_TABLE, mmap_mode ='r') 
trader = Server(None, MT4_FILES_DIR, 0.005, 3, False)

try: Current_Price, StartBalance, longs, shorts = trader.GetData('balance')
except: 
    print('Could not connect to the server \nexiting....')
    exit()


print(f'Starting Balnce : {StartBalance}', " Current_Price : ", Current_Price)

chart = Chart(StartBalance, SYMBOL, LOTSIZE, MAXORDERS, MAXORDERS, trader)

done = False
candles, rewards = 0, 0
Current_Price+=2

while not done:
    time.sleep(0.2)

    try: NewPrice, Equity, longs, shorts = trader.GetData('Bid')
    except: continue


    if abs(NewPrice-Current_Price) > 1:
        print(f'{time.ctime()},  New Candle : {candles}, Price : {NewPrice}, Equity : {Equity}')
        Current_Price = NewPrice

        state = chart.get_state()
        action = np.argmax(Q_table[state])
        
        print('Action : ', action)
        reward, done = chart.step(action, Current_Price, longs, shorts, Equity)
        
        candles += 1

