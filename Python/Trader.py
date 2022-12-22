
import json
from time import sleep
from os.path import join, exists
from traceback import print_exc
from datetime import datetime, timedelta




class Server():

    def __init__(self, event_handler=None, metatrader_dir_path='',
                 sleep_delay=0.005,             # 5 ms for time.sleep()
                 max_retry_command_seconds=10,
                 verbose=True
                 ):

        self.event_handler = event_handler
        self.sleep_delay = sleep_delay
        self.max_retry_command_seconds = max_retry_command_seconds
        self.verbose = verbose

        if not exists(metatrader_dir_path):
            print('ERROR: metatrader_dir_path does not exist!')
            exit()

        self.path_messages = join(metatrader_dir_path,
                                  'Python_Server', 'Messages.txt')
        self.path_commands_prefix = join(metatrader_dir_path,
                                         'Python_Server', 'Commands_')

        self.num_command_files = 50

        self._last_messages_millis = 0
        self._last_open_orders_str = ""

        self.open_orders = {}
        self.account_info = {}
        self.market_data = {}


        self.ACTIVE = True
        self.START = False


        # no need to wait.
        if self.event_handler is None:
            self.start()

    """START can be used to check if the client has been initialized.  
    """

    def start(self):
        self.START = True

    """Tries to read a file. 
    """

    def try_read_file(self, file_path):

        try:
            if exists(file_path):
                with open(file_path) as f:
                    text = f.read()
                return text
        # can happen if mql writes to the file. don't print anything here.
        except (IOError, PermissionError):
            pass
        except:
            print_exc()
        return ''

    """Regularly checks the file for open orders and triggers
    the event_handler.on_order_event() function.
    """

    def GetData(self, choice)-> float: 
        status = ''
        if self.ACTIVE:
            text = self.try_read_file(self.path_messages)

            if len(text.strip()) == 0:
                return 

            self._last_open_orders_str = text
            data = json.loads(text)
            return data['account_info']['Bid'], data['account_info']['equity'], data['account_info']['buy_count'], data['account_info']['sell_count'] 


    def open_order(self, symbol,
                   order_type,
                   lots=0.01,
                   price=0,
                   stop_loss=0,
                   take_profit=0,
                   magic=0,
                   comment='',
                   expiration=0):

        data = [symbol, order_type, lots, price, stop_loss,
                take_profit, magic, comment, expiration]
        self.send_command('OPEN_ORDER', ','.join(str(p) for p in data))


    def close_order(self, dir):

        data = dir
        self.send_command('CLOSE_ORDER', ','.join(str(data)))

    def close_all_orders(self):

        self.send_command('CLOSE_ALL_ORDERS', '')

    def send_command(self, command, content):

        end_time = datetime.utcnow() + timedelta(seconds=self.max_retry_command_seconds)
        now = datetime.utcnow()

        # trying again for X seconds in case all files exist or are currently read from mql side.
        while now < end_time:
            # using 10 different files to increase the execution speed for muliple commands.
            for i in range(self.num_command_files):
                # only send commend if the file does not exists so that we do not overwrite all commands.
                file_path = f'{self.path_commands_prefix}{i}.txt'
                if not exists(file_path):
                    try:
                        with open(file_path, 'w') as f:
                            f.write(f'<:{command}|{content}:>')
                            return
                    except:
                        print_exc()
            sleep(self.sleep_delay)
            now = datetime.utcnow()



