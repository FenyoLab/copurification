from scipy.cluster.hierarchy import linkage, dendrogram, set_link_color_palette
from scipy.spatial.distance import pdist
from scipy.cluster.vq import vq, kmeans, whiten
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import matplotlib as mpl
import math
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


def cluster_ms(data_dist, cluster_dist):

    #read in yeast crappome txt file
    crappome_table = pd.read_csv("C:\\NCDIR\\96-Well\\MS Clustering\\yeast-crappome.txt", '\t')
    
    #crappome dictionary
    crap_names = {}
    for j in range(len(crappome_table.index)):
        crap_names[crappome_table['Systematic Name'][j]] = 1
        
    #read in zhanna list of nups we expect to find - will use for double checking
    nups_table = pd.read_csv("C:\\NCDIR\\96-Well\\MS Clustering\\Nups_Kaps.txt", '\t')
    
    #nups dictionary
    nup_names = {}
    for j in range(len(nups_table.index)):
        nup_names[nups_table['Systematic'][j]] = 1
        
    #lanes with top protein not the bait protein
    remove_lanes1 = { 'D2':1,'D12':1,'F1':1,'F4':1,'G4':1,'G5':1,'G6':1,'G7':1,'G8':1,'G10':1,'H1':1,'H7':1,'H10':1,'H11':1}
    
    #lanes with top protein not a Nup protein (nups_table)
    remove_lanes2 = { 'D12':1,'G8':1,'H1':1}
    
    #lanes with MS not good, as per Kelly
    remove_lanes3 = {'C1':1,'A4':1,'E10':1,'F10':1,'F11':1,'H11':1}
    
    #open each file with MS results information by lane
    sample_letters = ['A','B','C','D','E','F','G','H']
    protein_list = {}
    lane_proteins = {}
    new_crap_names = {}
    for letter in sample_letters:
        for i in range(1,12+1):
            label = letter + str(i)
            #if(label in remove_lanes3): continue
            
            file_name = 'protein-intensities-' + label + '-nocontam-sorted-merged.txt' #'-sorted-merged.txt' #
            sample_table = pd.read_csv("C:\\NCDIR\\96-Well\\MS Clustering\\all-lanes\\" + file_name, '\t')
            
            #cutoff at 1/10 of highest Intensity
            #subtract 1 since score is the log10 of intensity
            top_intensity = sample_table['score'][0]
            median = np.median(sample_table['score'])
            
            initial_cutoff = top_intensity-1 # cutoff is .1 or .01 of top intensity (-1 or -2)
            #initial_cutoff = top_intensity - 2 + math.log(5,10)
            #initial_cutoff = top_intensity - 1 + math.log(2,10) #cutoff is .2 of top intensity (-1 + log 2)
            
            filtered_table = sample_table[sample_table['score'] > initial_cutoff]
            #filtered_table = sample_table
            
            cutoff = top_intensity - 1 + math.log(2,10) #top_intensity-1
            #cutoff = top_intensity - ((top_intensity-median)*.5)
            
            lane_proteins[label] = {}
            for j in range(len(filtered_table.index)):
                # way 1:
                #remove crap proteins completely
                #leave all others with given score
                #check all others are part of zhannas list, if not, print out message
                name = filtered_table['Systematic'][j]
                #if(name in crap_names): # and filtered_table['score'][j] < cutoff):
                    #pass #leave them out of vector
                    
                    #if(filtered_table['score'][j] >= cutoff):
                    
                    #if(name in protein_list):
                    #    protein_list[name] += 1
                    #else: protein_list[name] = 1
                    #lane_proteins[label][name] = 2 #filtered_table['score'][j]
                    
                #else:
                #if(not (name in nup_names)):
                #    new_crap_names[name] = 1
                #    
                used = False
                if(name in nup_names):
                    #if filtered_table['score'][j] > cutoff: lane_proteins[label][name] = 2
                    #else: lane_proteins[label][name] = 1
                    lane_proteins[label][name] = 1 #filtered_table['score'][j]
                    used = True
                elif(name in crap_names):
                    #if filtered_table['score'][j] > cutoff: lane_proteins[label][name] = 2
                    #else: lane_proteins[label][name] = 1
                    #if filtered_table['score'][j] > cutoff:
                    #    lane_proteins[label][name] = 1 #filtered_table['score'][j]
                    #    used = True
                    #lane_proteins[label][name] = 1 #filtered_table['score'][j]
                    #used = True
                    pass
                else:
                    #if filtered_table['score'][j] > cutoff: lane_proteins[label][name] = 2
                    #else: lane_proteins[label][name] = 1
                    #lane_proteins[label][name] = filtered_table['score'][j]
                    #used = True
                    #new_crap_names[name] = 1
                    #pass
                    #if filtered_table['score'][j] > cutoff:
                    lane_proteins[label][name] = 1 #filtered_table['score'][j]
                    used = True
                    pass
                if(used):
                    if(name in protein_list):
                        protein_list[name] += 1
                    else: protein_list[name] = 1
                
                #if(j >= 10): break
                        
    for new_name in new_crap_names.keys():
        #print 'x\t' + new_name + '\t0'
        print new_name
    print len(protein_list.keys())
    print max(protein_list.values())
    
    protein_count_cutoff = 0 #int(.10*96) #must be in 10% of lanes out of 96 to include the protein
    
    #create vectors for dendrogram
    f = open("C:\\NCDIR\\96-Well\\MS Clustering\\lane_proteins-MS-" + data_dist + "-" + cluster_dist + ".txt", 'w')
    ordered_labels = []
    lane_vectors = []
    ordered_protein_list = protein_list.keys()
    for letter in sample_letters:
        for i in range(1,12+1):
            label = letter + str(i)
            #if(label in remove_lanes3): continue
            
            f.write(label + ': ')
            ordered_labels.append(label)
            cur_vector = []
            to_print = []
            for protein in ordered_protein_list:
                if(protein_list[protein] >= protein_count_cutoff):
                    if(protein in lane_proteins[label]):
                        cur_vector.append(lane_proteins[label][protein])
                        to_print.append([lane_proteins[label][protein],protein])
                    else:
                        cur_vector.append(0)
                        
            lane_vectors.append(cur_vector)
            
            to_print.sort(reverse=True)
            for p in to_print:
                p = p[1]
                if(p in nup_names):
                    f.write('*' + p + '* (' + str(lane_proteins[label][p]) + '), ')
                elif(p in crap_names):
                    f.write('-' + p + '- (' + str(lane_proteins[label][p]) + '), ')
                else:
                    f.write('?' + p + '? (' + str(lane_proteins[label][p]) + '), ')
            f.write('\n')
    f.close()
    
    #go through vectors, remove proteins over max, e.g. only 10 proteins per lane (top 10)
    #lane_proteins_max = 10
    #for vector_i, vector in enumerate(lane_vectors):
    #    sort_list = []
    #    for i,v in enumerate(vector):
    #        if(v != 0):
    #            sort_list.append([v,i])
    #    if(len(sort_list) > lane_proteins_max):
    #        sort_list.sort(reverse=True)
    #        for i in range(lane_proteins_max, len(sort_list)):
    #            vector[sort_list[i][1]] = 0
          
    #sets scores other than 0 to 1 for boolean comparision  
    #for vector_i, vector in enumerate(lane_vectors):
    #    for i,v in enumerate(vector):
    #        if(v != 0): vector[i] = 1
            
    print len(lane_vectors[0])
    
    l_matrix = linkage(lane_vectors, method=cluster_dist, metric=data_dist)
    
    fig = plt.gcf()
    fig.set_size_inches(34,10)
    ax = plt.gca()
    ax.set_frame_on(False)
    ax.yaxis.set_visible(False)
    ax.xaxis.set_visible(False)
    ddata = dendrogram(l_matrix, labels=ordered_labels, leaf_font_size=12, count_sort='ascending',color_threshold=np.inf) #, p=10, truncate_mode='lastp', show_contracted=True)
    plt.savefig("C:\\NCDIR\\96-Well\\MS Clustering\\dendrogram-MS-" + data_dist + "-" + cluster_dist + ".png")
    plt.clf()
    
    f = open("C:\\NCDIR\\96-Well\\MS Clustering\\dendrogram-MS-" + data_dist + "-" + cluster_dist + ".txt", 'w')
    for i in range(len(ddata['ivl'])):
        f.write(ddata['ivl'][i] + '\n')
    f.close()
    
    f = open("C:\\NCDIR\\96-Well\\MS Clustering\\dendrogram-MS-numID-" + data_dist + "-" + cluster_dist + ".txt", 'w')
    for i in range(len(ddata['ivl'])):
        to_print = sample_to_number_mapping[ddata['ivl'][i]]
        if(to_print <= 9): f.write('  ')
        else: f.write(' ')
        f.write(str(sample_to_number_mapping[ddata['ivl'][i]]))
        if(to_print <= 9): f.write('  ')
        
    f.close()
    
    return (l_matrix, pdist(lane_vectors, metric=data_dist), ordered_labels)

cluster_ms('euclidean','ward')






