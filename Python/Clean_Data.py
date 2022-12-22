import csv
import os

ROW_DATA_DIR     = 'Python\DATA\Row_Tick_Data'    # Tick Data with random time periods
CLEANED_DATA_DIR = 'Python\DATA\Cleaned_Data'     # Tick Data filtered repeeted prices down to sensitivity in pips


SENSITIVITY = 1  # pips



for filename in os.listdir(ROW_DATA_DIR):
    data = []
    print(f'Opening : {filename}')
    with open(os.path.join(ROW_DATA_DIR, filename)) as s_file:
        reader = csv.reader(s_file, delimiter=',')
        next(reader)  # skip the labels row
        temp = 0
        for row in reader:
            p = float(row[-1]) # Get the Bid price
            if abs(p-temp) >= SENSITIVITY:  # Check if the current tick price is changed SENSITIVITY amount in pips 
                data.append(p)
                temp=p

    print(f'writing {len(data)} ticks in : {filename}')
    with open(os.path.join(CLEANED_DATA_DIR, filename), 'w', newline='') as d_file:
        writer = csv.writer(d_file)
        for val in data:
            if val is not None:
                writer.writerow([val])

