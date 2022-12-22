import numpy as np
import csv
import random 
import os 
from Chart_Training_Env import Chart

INITIAL_DEPOSITE = 1000          # the starting account balance
MAXORDERS        = 30            # increasing that will also increas the Q table 
TRAINNING_STEPS  = 1_000_000     # You can set that it will save the best table and you can stop at any point 

EPSILON = 0.1
ALPHA = 0.1
GAMMA = 0.8

TABLE_NAME = 'Q_table_1.npy'    # To create different tables

DATADIR = 'Python\DATA\Cleaned_Data'
Q_TABLES_DIR = 'Python\Q_Tables'

def GetRandomData():
    """ Get a Random file and start from a Random price """
    randomfile = random.choice(os.listdir(DATADIR))
    data = []
    with open(os.path.join(DATADIR, randomfile)) as file:
        reader = csv.reader(file)
        if reader is None : return None
        for row in reader:            
            data.append(float(row[0]))
    
    randomslice = random.randint(1, int(len(data)*0.6)) # make sure the the random start is below 60% of the total data
    return data[randomslice:]


def RLagent(q_table):
    """ Test the bot in a Random Data to evaluate """

    random_data = GetRandomData()
    if random_data is None: return None

    chart = Chart(INITIAL_DEPOSITE, MAXORDERS, MAXORDERS, random_data)
    done = False
    candles, rewards = 0, 0

    while not done:
        state = chart.get_state()
        action = np.argmax(q_table[state])
        reward, done = chart.step(action)                
        candles += 1
    
    return candles, reward


def RandomSol():
    """ Test with a random action to compare """
    random_data = GetRandomData()
    if random_data is None: return None

    chart = Chart(INITIAL_DEPOSITE, MAXORDERS, MAXORDERS, random_data)
    done = False
    candles, rewards = 0, 0

    while not done:
        action = random.randint(0, 4)
        reward, done = chart.step(action)
        candles += 1
        rewards += reward

    return candles, reward

def Get_New_Q_Table():
    random_data = GetRandomData()
    if random_data is None: return None

    chart = Chart(INITIAL_DEPOSITE, MAXORDERS, MAXORDERS, random_data)
    number_of_states = chart.get_number_of_states()
    number_of_actions = 5   # (buy, sell, close buy, close sell, do nothing)
    return np.zeros((number_of_states, number_of_actions))



# Q_table = np.load(TABLE_NAME) # If you already have a table trained and you want to proceed training
Q_table = Get_New_Q_Table()        # Create a New Empty Q_table



best_result = 0  # Skip any negative result
for _ in range(1, TRAINNING_STEPS):

    if not _ % 500: print(f'Training Step {_}') # to let us know which step are we at every 500 step

    random_data = GetRandomData()
    if random_data is None: continue

    chart = Chart(INITIAL_DEPOSITE, MAXORDERS, MAXORDERS, random_data)

    done = False
    while not done:
        state = chart.get_state()
        if random.uniform(0, 1) < EPSILON:
            action = random.randint(0, 4)
        else:
            action = np.argmax(Q_table[state])
            
        reward, done = chart.step(action)
        # Q[state, action] = (1 – ALPHA) * Q[state, action] + ALPHA * (reward + GAMMA * max(Q[new_state]) — Q[state, action])
        
        new_state = chart.get_state()
        new_state_max = np.max(Q_table[new_state])
        
        Q_table[state, action] = (1 - ALPHA)*Q_table[state, action] + ALPHA*(reward + GAMMA*new_state_max - Q_table[state, action])


    if not _ % 10_000: # make a quick test and save the best result table
        
        print(f' Testing & saving {_//500} ...')
        steps, result = 0, 0
        
        tests = 1000    # Number of random tests 

        for i in range(tests):
            steps, result = RLagent(Q_table)
            result += (result/1000)     # Result is +/- 1000
            steps += steps              # Number of steps that the bot took to finish

        if result > best_result and result > 0:
            print(f'saving Q_table Accuracy : {round(result/tests, ndigits=2)}%  n_steps : {steps/tests}')
            np.save(os.path.join(Q_TABLES_DIR, TABLE_NAME), Q_table)
            best_result = result









print('Final Testing ... ')
rlsteps, rlresult = 0, 0
randsteps, randresult = 0, 0
tests = 2000

for i in range(tests):
    steps, result = RLagent(Q_table)
    rlresult += (result/1000)
    rlsteps += steps

    steps, result = RandomSol()
    randresult += (result/1000)
    randsteps += steps


print(f'Random. Avg Result : {round(randresult/tests, ndigits=2)} steps : {randsteps/tests}')
print(f'RL.  Avg Result : {round(rlresult/tests, ndigits=2)} steps : {rlsteps/tests}')


