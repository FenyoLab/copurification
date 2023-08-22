#!c:/perl/bin/perl.exe 

use warnings;
use strict;

my $method = 'euclidean-ward';
my $data_type = 'dark_light'; #'MS';
my $folder = 'Gel'; # 'MS';

#my $dir = "C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\230"; #\\209";
my $html_dir = 'zhanna_gels_project_1_comparison_230'; #228'; #_227'; #'john_gels_project_2';

# gel1 is Nup1_matrix4_filt_original_bottomleft: D1,C1,D2,C2,...
# gel2 is Nup1_matrix4_filt_original_bottomright: B1,A1,B2,A2,...
# gel3 is Nup1_matrix4_filt_original_topleft: H1,G1,H2,G2,...
# gel4 is Nup1_matrix4_filt_original_topright: F1,E1,F2,E2,...
my @gels = ("gel1", "gel2", "gel3", "gel4");

my %lane_to_sample_mapping;
my %sample_to_lane_mapping;
$lane_to_sample_mapping{"gel1"} = ["D", "C"];
$lane_to_sample_mapping{"gel2"} = ["B", "A"];
$lane_to_sample_mapping{"gel3"} = ["H", "G"];
$lane_to_sample_mapping{"gel4"} = ["F", "E"];

my @sample_letters = ("A", "B", "C", "D", "E", "F", "G", "H");

#we have lane to sample mapping, create sample to lane mapping
my %sample_masses;
foreach my $gel (@gels)
{
    for(my $i = 2; $i <= 25; $i++)
    {
        my $index = $i % 2 == 0 ? 0 : 1;
        my $sample_id = $lane_to_sample_mapping{$gel}[$index] . int($i/2);
        #my $cur_file = "$dir/$gel.lane.$i.nn.png";
        my $image_html = qq!<img src="./$html_dir/$gel.lane.$i.n.png" width="24" height="300" />!; #width="24" height="300" />!; 
		
        $sample_to_lane_mapping{$sample_id} = $image_html;
    }
}

#also create number to sample mapping
my %number_to_sample_mapping;
my %sample_to_number_mapping;
# H1-H12 = 1-12, G1-G12 = 13-24, F1-F12 = 25-36, E1-E12 = 37-48, D1-D12 = 49-60, C1-C12 = 61-72, B1-B12 = 73-84, A1-A12 = 85-96
for(my $i = 1; $i <= 96; $i++)
{
    my $sample_id; 
    my $n = int($i/12);
    if ($i%12 == 0) { $n--; }
    $sample_id = $i-(12*$n);
    
    if ($i <= 12)            { $sample_id = "H" . $sample_id; }
    if ($i > 12 && $i <= 24) { $sample_id = "G" . $sample_id; }
    if ($i > 24 && $i <= 36) { $sample_id = "F" . $sample_id; }
    if ($i > 36 && $i <= 48) { $sample_id = "E" . $sample_id; }
    if ($i > 48 && $i <= 60) { $sample_id = "D" . $sample_id; }
    if ($i > 60 && $i <= 72) { $sample_id = "C" . $sample_id; }
    if ($i > 72 && $i <= 84) { $sample_id = "B" . $sample_id; }
    if ($i > 84 && $i <= 96) { $sample_id = "A" . $sample_id; }
    
    $number_to_sample_mapping{"$i"} = $sample_id;
    $sample_to_number_mapping{$sample_id} = "$i";
}

#read in the order that the lanes will be displayed 
my $lane_cluster_order_file = "C:\\NCDIR\\96-Well\\$folder Clustering\\dendrogram-$data_type-$method.txt";
#"C:\\NCDIR\\96-Well\\MS Clustering\\dendrogram-MS-9.txt";
#"C:\\NCDIR\\96-Well\\Gel Clustering\\dendrogram-dark_light_bands.txt";
#"C:\\NCDIR\\96-Well\\MS Clustering\\dendrogram-MS-9.txt"; #"C:/temp/dendrogram-I-new.2.2.txt"; #"C:\\NCDIR\\96-Well\\data_v2_0\\6\\Experiments\\230\\sample_mass_table_grouped_3-IntensityRank.txt"; #ordered_samples_2.txt";
my @lane_cluster_order_list;
if (open(IN, $lane_cluster_order_file))
{
    my $line;
    while ($line=<IN>)
    {
        if ($line=~/^\s*([[ABCDEFGH1234567890]+)\s*$/)
        {
            my $sample_id = $1;
            push @lane_cluster_order_list, $sample_id;
        }
    }
    close(IN);
}

#open html output file #transform-origin: left top 0;
open(OUT, ">C:\\NCDIR\\96-Well\\html\\figure_bottom-$data_type-$method.htm") || die "Can't open out file!";
print OUT "<HTML><HEAD>";
print OUT "<style> 
.text_td
{
width:10px;
height:100px
overflow:hidden;
transform:rotate(90deg);
font-family:Arial, Helvetica, sans-serif;
font-weight: bold;
font-size:20px
}
.condition_td
{
    width:20px;
}
</style>";
print OUT "</HEAD><BODY><TABLE>\n";

#first, print out the lane clustering images
print OUT "<tr>\n";
for(my $i = 0; $i <= $#lane_cluster_order_list; $i++)
{
    print OUT "<td style=\"border: solid 1px black;\" bgcolor=\"#FFFFFF\">";
    print OUT $sample_to_lane_mapping{$lane_cluster_order_list[$i]};
    print OUT "</td>\n";
}
print OUT "</tr>\n";

#second, add the yes/no/maybe squares from john and zhanna

#input the classification data
my $lane_classification_file = "C:\\NCDIR\\96-Well\\real_data\\Zhanna 08_29_2014\\lane_classification.txt";
my %sample_lane_grades;
if (open(IN, $lane_classification_file))
{
    my $line=<IN>;
    while ($line=<IN>)
    {
        if ($line=~/([0-9]+)\t([123])/)
        {
            my $lane = $1;
            my $grade = $2;
            
            my $sample_id = $number_to_sample_mapping{$lane};
            $sample_lane_grades{$sample_id} = $grade;
        }
        else { print $line; }
    }
    close(IN);
}

#print out the classification data in the cluster order, same as images above
#print OUT "<tr>\n";
#for(my $i = 0; $i <= $#lane_cluster_order_list; $i++)
#{
#    my $grade = $sample_lane_grades{$lane_cluster_order_list[$i]};
#    
#    if ($grade eq "1") #good - black
#    {
#        print OUT "<td bgcolor=\"#000000\">";
#    }
#    if ($grade eq "2") #maybe - gray
#    {
#        print OUT "<td bgcolor=\"#848484\">";
#    }
#    if ($grade eq "3") #fail - white
#    {
#        print OUT "<td style=\"border: solid 1px black;\" bgcolor=\"#FFFFFF\">";
#    }
#    
#    print OUT "&nbsp;</td>\n";
#}
#print OUT "</tr>\n";

#print out the lane coding
#print OUT "<tr>\n";
#for(my $i = 0; $i <= $#lane_cluster_order_list; $i++)
#{
#    my $grade = $sample_lane_grades{$lane_cluster_order_list[$i]};
#    
#    
#    print OUT "<td>"; # style=\"border: solid 1px black;\" bgcolor=\"#FFFFFF\">";
#    
#    #print OUT "<b>$lane_cluster_order_list[$i]</b></td>\n";
#    print OUT "<b>$sample_to_number_mapping{$lane_cluster_order_list[$i]}</b></td>\n";
#}
#print OUT "</tr>\n";

#input the conditions data
my $lane_conditions_file = "C:\\NCDIR\\96-Well\\real_data\\Zhanna 08_29_2014\\lane_conditions.txt";
my %sample_lane_conditions;
if (open(IN, $lane_conditions_file))
{
    my $line=<IN>;
    while ($line=<IN>)
    {
	chomp($line);
        if ($line=~/([0-9]+)\t"(.+)"/)
        {
            my $lane = $1;
            my $text = $2;
            
            my $sample_id = $number_to_sample_mapping{$lane};
            $sample_lane_conditions{$sample_id} = $text;
        }
        else { print $line; }
    }
    close(IN);
}

my $show_conditions = 0;


if ($show_conditions)
{
    #txt file for Zhanna outputting conditions in order
    my $lane_conditions_out = "C:\\NCDIR\\96-Well\\$folder Clustering\\dendrogram-conditions-$data_type-$method.txt";
    open(CONDITIONS_OUT, ">$lane_conditions_out") || die "Can't open out file!";

}

#print out the conditions data in the cluster order, same as images above
#print OUT "<tr>\n";
#for(my $i = 0; $i <= $#lane_cluster_order_list; $i++)
#{
#    my $text = $sample_lane_conditions{$lane_cluster_order_list[$i]};
#    
#    if ($show_conditions)
#    {
#	print CONDITIONS_OUT "$lane_cluster_order_list[$i],$text\n";
#    }
#    
##    print OUT "<td nowrap align=\"center\">";
##    print OUT "<div class=\"text_td\">";
##    my @text_list = split(/,/,$text);
##    print OUT "<table><tr>";
##    for(my $j = 0; $j <= $#text_list; $j++)
##    {
##	print OUT "<td >$text_list[$j]</td>";
##    }
##    print OUT "</tr></table>";
##    print OUT "</div>";
##    print OUT "</td>\n";
#    print OUT "<td nowrap align=\"center\">";
#    print OUT "<div class=\"text_td\">$text</div>";
#    print OUT "</td>\n";
#}
#print OUT "</tr>\n";

print OUT "</BODY></TABLE></HTML>\n";
close(OUT);
close(CONDITIONS_OUT);