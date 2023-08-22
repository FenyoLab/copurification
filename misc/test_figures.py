from scipy.cluster.hierarchy import linkage, dendrogram, cophenet
from scipy.spatial.distance import pdist, squareform
from scipy.cluster.vq import vq, kmeans, whiten
from scipy.stats import pearsonr
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import matplotlib as mpl
import math
mpl.rcParams['lines.linewidth'] = 6

def dist(p1, p2):
    d = ( (p1[0]-p2[0])**2 + (p1[1]-p2[1])**2 + (p1[2]-p2[2])**2 ) ** .5
    return d

pts = [[0,1,7],[9,8,5],[6,3,2],[1,1,3],[5,4,10],[9,0,8]]
ordered_labels=['0','1','2','3','4','5']
for i in range(len(pts)):
    for j in range(len(pts)):
        d = dist(pts[i],pts[j])
        print str(i) + ' ' + str(j) + ' ' + str(d)
        
l_matrix = linkage(pts, method='ward', metric='euclidean')

print l_matrix

fig = plt.gcf()
fig.set_size_inches(34,10)
ax = plt.gca()
ax.set_frame_on(False)
ax.yaxis.set_visible(False)
ax.xaxis.set_visible(False)
ddata = dendrogram(l_matrix, leaf_font_size=12) #, p=10, truncate_mode='lastp', show_contracted=True)
plt.savefig("C:\\temp\\dendrogram-test.png")

f = open("C:\\temp\\dendrogram-test.txt", 'w')
for i in range(len(ddata['ivl'])):
    f.write(ddata['ivl'][i] + '\n')
f.close()

y = pdist(pts)
cd = cophenet(l_matrix, y)
print cd[0]
print squareform(cd[1])

r = pearsonr(y,cd[1])
print r