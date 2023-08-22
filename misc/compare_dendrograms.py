import make_dendrogram
import cluster_ms
from scipy.cluster.hierarchy import linkage, dendrogram, cophenet
from scipy.stats import pearsonr, gaussian_kde
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
import json
mpl.rcParams['lines.linewidth'] = 6

#distance_methods = ['yule','matching','kulsinski','rogerstanimoto','russellrao','wminkowski']
#distance_methods = ['jaccard','dice','hamming','sokalsneath','sokalmichener',]
#cluster_methods = ['single','complete','average','weighted']
multiple_compare = False
distance_methods = ['euclidean']
cluster_methods = ['ward']
f = open("C:\NCDIR\96-Well\Cluster Correlation\clustering_methods_comparison.txt", 'w')

for dist_method in distance_methods:
    for cluster_method in cluster_methods:
        f.write("Distance method = " + dist_method)
        f.write("\n")
        f.write("Cluster method = " + cluster_method)
        f.write("\n")
        
        # (ordered_labels should be same for both)
        (l_matrix_gels, dist_matrix_gels, ordered_labels_gels) = make_dendrogram.cluster_gels(dist_method, cluster_method)
        (l_matrix_ms, dist_matrix_ms, ordered_labels_ms) = cluster_ms.cluster_ms(dist_method, cluster_method)
        
        cd_gels = cophenet(l_matrix_gels, dist_matrix_gels)
        f.write( 'Pearson Corr Coeff (gel dendrogram/gel distance matrix): ' + str(cd_gels[0]) )
        f.write("\n")
        
        cd_ms = cophenet(l_matrix_ms, dist_matrix_ms)
        f.write( 'Pearson Corr Coeff (ms dendrogram/ms distance matrix): ' + str(cd_ms[0]) )
        f.write("\n")
        
        r = pearsonr(cd_ms[1],cd_gels[1])
        f.write( 'Pearson Corr Coeff (ms dendrogram/gel dendrogram): ' + str(r[0]) ) #+ ' (p-value = ' + str(r[1]) + ')'
        f.write("\n")
        
        r = pearsonr(dist_matrix_ms,dist_matrix_gels)
        f.write( 'Pearson Corr Coeff (ms distance matrix/gel distance matrix): ' + str(r[0]) ) #+ ' (p-value = ' + str(r[1]) + ')'
        f.write("\n")
        
        r = pearsonr(cd_ms[1],dist_matrix_gels)
        f.write( 'Pearson Corr Coeff (ms dendrogram/gel distance matrix): ' + str(r[0]) ) #+ ' (p-value = ' + str(r[1]) + ')'
        f.write("\n")
        
        r = pearsonr(dist_matrix_ms,cd_gels[1])
        f.write( 'Pearson Corr Coeff (ms distance matrix/gel dendrogram): ' + str(r[0]) ) #+ ' (p-value = ' + str(r[1]) + ')'
        f.write("\n")
        
        f.write("\n")

if(not multiple_compare):
    run_permutations = False
    num_permutations = 10000000
    if(run_permutations):
        #shuffle l_matrix_ms 1000 times
        r_data_points = []
        l_matrix_ms_shuffled = l_matrix_ms[:]
        for i in range(num_permutations):
            if(i % 10000 == 0): print i
            n = len(l_matrix_ms_shuffled)+1 # 96
            shuffled_lanes = np.random.permutation(n)
            j = 0
            for group in l_matrix_ms_shuffled:
                if(group[0] < n): #its a leaf
                    group[0] = float(shuffled_lanes[j])
                    j += 1
                if(group[1] < n):
                    group[1] = float(shuffled_lanes[j])
                    j += 1
            
            #get cophenetic for shuffled ms linkage
            cd_ms_shuffled = cophenet(l_matrix_ms_shuffled, dist_matrix_ms)
            #print cd_ms_shuffled[0] #just for checking - should be low!
            
            #compare to gel linkage cophenetic
            r = pearsonr(cd_ms_shuffled[1],cd_gels[1])
            
            #record correlation
            r_data_points.append(r[0])
                    
            #for checking, make new dendrogram and label
            #dendrogram structure should be the same but the labels should be different
            #fig = plt.gcf()
            #fig.set_size_inches(34,10)
            #ax = plt.gca()
            #ax.set_frame_on(False)
            #ax.yaxis.set_visible(False)
            #ax.xaxis.set_visible(True)
            #ddata = dendrogram(l_matrix_ms, labels=ordered_labels_ms, leaf_font_size=12)
            #plt.savefig("C:\\NCDIR\\96-Well\\MS Clustering\\random\\dendrogram-Random-" + str(i) + ".png")
            #plt.clf()
            #
            #f = open("C:\\NCDIR\\96-Well\\MS Clustering\\random\\dendrogram-Random-" + str(i) + ".txt", 'w')
            #for i in range(len(ddata['ivl'])):
            #    f.write(ddata['ivl'][i] + '\n')
            #f.close()
    
        #save data points to json
        f_json = open("C:\\NCDIR\\96-Well\\Cluster Correlation\\Permutations_" + str(num_permutations) + ".json", 'w')
        json.dump(r_data_points, f_json)
        f_json.close()
    
    if(not run_permutations):
        #load from json
        f_json = open("C:\\NCDIR\\96-Well\\Cluster Correlation\\Permutations_" + str(num_permutations) + ".json", 'r')
        r_data_points = json.load(f_json)
        f_json.close()
        
    #find percent of shuffled data points that are atleast as extreme as the original value
    r_data = pearsonr(cd_ms[1],cd_gels[1])
    r_data = r_data[0]
    neg_data_points = 0
    pos_data_points = 0
    zero_data_points = 0
    extreme_points = 0
    for pt in r_data_points:
        if(pt < 0): neg_data_points += 1
        if(pt > 0): pos_data_points += 1
        if(pt == 0): zero_data_points += 1
        if(r_data > 0):
            if(pt >= r_data): extreme_points += 1
        if(r_data < 0):
            if(pt <= r_data): extreme_points += 1
            
    f.write("No. of extreme points (> " + str(r_data) + "):" + str(extreme_points) + "\n")
    f.write("No. of permutations: " + str(len(r_data_points)) + "\n")
    #print neg_data_points + zero_data_points
    #print pos_data_points + zero_data_points
    #print zero_data_points
    print max(r_data_points)
    
    fig1 = plt.figure()
    plt.hist(r_data_points, bins=1000)
    plt.xlabel('Pearson Correlation Coefficient (r)')
    plt.ylabel('Frequency')
    fig1.savefig("C:\\NCDIR\\96-Well\\Cluster Correlation\\PearsonR_Histogram.png")

    
        
