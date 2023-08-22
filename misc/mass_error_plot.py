#!/usr/bin/env python

#plot mass vs. mass error for a gel - given directory.

import glob
import pandas as pd
import matplotlib.pyplot as plt 

plot_dir = "C:\\NCDIR\\96-Well\\gel_files_mass_error\\Zhanna-2-Csl4-TAP"
#plot_dir = "C:\\NCDIR\\96-Well\\gel_files_mass_error\\Zhanna-2-Snu71_Csl4-TAP"
#plot_dir = "C:\\NCDIR\\96-Well\\gel_files_mass_error\\Zhanna-3-Rtn1_Arp2-GFP"
#plot_dir = "C:\\NCDIR\\96-Well\\gel_files_mass_error\\Zhanna-3-Rtn1-GFP"

file_list = glob.glob(plot_dir + '/*.txt')
df_gel = pd.DataFrame()
for file_name in file_list:
    if(file_name.endswith(".1.txt") or file_name.endswith(".26.txt")):
        continue
    
    df = pd.read_table(file_name)
    
    df_gel = pd.concat([df_gel, df])
    
fig1 = plt.figure()        
plt.scatter(df_gel['mass'], df_gel['mass error'])
fig1.savefig(plot_dir + '/plot.png')


print str(max(df_gel['mass error'])) + '\n\n'
print df_gel.to_string()


