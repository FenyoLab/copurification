#!/usr/bin/env python

from scipy.cluster.hierarchy import linkage, dendrogram, set_link_color_palette
from scipy.spatial.distance import pdist
from scipy.cluster.vq import vq, kmeans, whiten
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import matplotlib as mpl
mpl.rcParams['lines.linewidth'] = 6
set_link_color_palette(['black'])

number_to_sample_mapping = {}
sample_to_number_mapping = {}
# H1-H12 = 1-12, G1-G12 = 13-24, F1-F12 = 25-36, E1-E12 = 37-48, D1-D12 = 49-60, C1-C12 = 61-72, B1-B12 = 73-84, A1-A12 = 85-96
for i in range(1,97):
    n = int(i/12)
    if (i%12 == 0): n = n-1
    sample_id = i-(12*n)
    
    if (i <= 12):
        sample_id = "H" + str(sample_id)
    if (i > 12 and i <= 24):
        sample_id = "G" + str(sample_id)
    if (i > 24 and i <= 36): sample_id = "F" + str(sample_id)
    if (i > 36 and i <= 48): sample_id = "E" + str(sample_id)
    if (i > 48 and i <= 60): sample_id = "D" + str(sample_id)
    if (i > 60 and i <= 72): sample_id = "C" + str(sample_id)
    if (i > 72 and i <= 84): sample_id = "B" + str(sample_id)
    if (i > 84 and i <= 96): sample_id = "A" + str(sample_id)
    
    number_to_sample_mapping[i] = sample_id;
    sample_to_number_mapping[sample_id] = i;

def cluster_gels(data_dist, cluster_dist):

    table = pd.read_csv("C:\NCDIR\96-Well\Gel Clustering\\sample_mass_table_grouped-IntensityRanked2-dark_light_bands.txt", '\t')  
                        #sample_mass_table_grouped-IntensityRanked2-dark_bands_only.txt", '\t') 
                        #sample_mass_table_grouped-IntensityRanked2-dark_light_bands.txt", '\t') #sample_mass_table_grouped-IntensityRanked2-darkbandsonly.txt", '\t') #sample_mass_table_grouped-IntensityRanked.txt", '\t') #sample_mass_table_grouped-IntensityRanked2.txt", '\t') #sample_mass_table_grouped_3.txt", '\t')
    f = open("C:\NCDIR\96-Well\Gel Clustering\\dendrogram-dark_light-" + data_dist + "-" + cluster_dist + ".txt", 'w')
    f2 = open("C:\NCDIR\96-Well\Gel Clustering\\dendrogram-dark_light-numID-" + data_dist + "-" + cluster_dist + ".txt", 'w')
    lane_vectors = []
    labels = []
    for col in table.columns:
        cur_v = []
        if(col != 'Unnamed: 0'):
            labels.append(col)
            for i in range(len(table.index)):
                if(np.isnan(table[col][i])): cur_v.append(0)
                else: cur_v.append(table[col][i]) #table[col][i])  #(1) #(table[col][i])
            lane_vectors.append(cur_v)
    
    #l_matrix = linkage(lane_vectors, method='ward', metric='euclidean')
    l_matrix = linkage(lane_vectors, method=cluster_dist, metric=data_dist)
    
    fig = plt.gcf()
    fig.set_size_inches(34,10)
    ax = plt.gca()
    ax.set_frame_on(False)
    ax.yaxis.set_visible(False)
    ax.xaxis.set_visible(False)
    ddata = dendrogram(l_matrix, labels=labels, leaf_font_size=12, count_sort='ascending', color_threshold=np.inf) #, p=10, truncate_mode='lastp', show_contracted=True)
    # 
    
    for i in range(len(ddata['ivl'])):
        to_print = sample_to_number_mapping[ddata['ivl'][i]]
        if(to_print <= 9): f2.write('  ')
        else: f2.write(' ')
        f2.write(str(sample_to_number_mapping[ddata['ivl'][i]]))
        if(to_print <= 9): f2.write('  ')
        
        f.write(ddata['ivl'][i] + '\n')
        
    plt.savefig("C:\NCDIR\96-Well\Gel Clustering\\dendrogram-dark_light-" + data_dist + "-" + cluster_dist + ".png")
    plt.clf()
    f.close()
    f2.close()
    
    return (l_matrix, pdist(lane_vectors, metric=data_dist), labels)

cluster_gels('euclidean','ward')
            
            