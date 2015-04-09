#!c:/perl/bin/perl.exe
 
#    calculate_lane_scores.pl - Compares lanes in gels - input params tell which lanes and which gels to compare
#
#    Copyright (C) 2015  Sarah Keegan
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;

sub numerically { $a <=> $b; }
sub numericallydesc { $b <=> $a; }
my $MAX_MASS_FOR_ERROR = 200;
my $MATCH_ERROR_CUTOFF_MASS = 250;
my $MIN_MATCH_ERROR = 2;
my $DEFAULT_MASS_ERROR = 2;
my $MIN_GROUP_RATIO = 0; #0.9; #.9
my $MIN_GROUP_SCORE = .9;
my $COMBINE_ALL_GROUPS = 0;
my $USE_INTENSITY_IN_SCORE = 1;
my $DO_IDENTITY_GROUPING = 0;
#get directory for Image Magick from the settings file
my $line = "";
my %SETTINGS=(); open(IN,"../settings.txt"); while($line=<IN>) { chomp($line); if ($line=~/^([^\=]+)\=([^\=]+)$/) { $SETTINGS{$1}=$2; } } close(IN);

print get_default_mass_error(1);

my @gel_lanes;
my $num_gel_lanes = 0;

my $out_directory = $ARGV[0];
my $out_file = $ARGV[1];

#print get_mass_error(49.6, 36, 200) + get_mass_error(30.2, 36, 200);

open(LOG, ">$out_directory/$out_file.log.txt") || die "Error: Could not open file: \'$out_directory/$out_directory/$out_file.log.txt\'.\n"; 

#input the gels/lanes to compare
for(my $i = 2; $i <= $#ARGV; $i+=2)
{
	my $cur_gel = $ARGV[$i];
	my @cur_lanes = split(' ', $ARGV[$i+1]);
	for(my $j = 0; $j <= $#cur_lanes; $j++)
	{
		$gel_lanes[$num_gel_lanes++] = "$cur_gel.lane-details.$cur_lanes[$j].txt";
	}
}

print LOG "Comparing the following lanes:\n";
for(my $j = 0; $j <= $#gel_lanes; $j++)
{
	print LOG $gel_lanes[$j];
	print LOG "\n";
}

my $create_excels = 1;

#gel lane mass/error/intensity data
my @gel_lane_masses;
my @gel_lane_errors;
my @gel_lane_ints;

#input lane data
input_lane_files();

my @gel_groups; #$gel_groups[i] is an array that contains the lanes that have been "matched" in order of how well they matched to each other
				#there could be more than one gel_group as we process b/c intitially some lanes will have no connections
				#! for use in subroutine group_gel_lanes and its helper subs
my $num_gel_groups = 0; #! for use in subroutine group_gel_lanes and its helper subs

my @lane_match_list; #contains a list of the lanes in the gel, ordered based on the match scores (most related are grouped together)

#calculate lane scores for each gel pair
my $num_gel_lane_scores = 0;
my @gel_lane_scores; #each position in this array contains an array with 3 items - (gel #, lane #, score)

for(my $i = 0; $i < $num_gel_lanes; $i++)
{
	for(my $j = $i+1; $j < $num_gel_lanes; $j++)
	{
		calculate_lane_match_scores($i, $j);
	}
}

#sort @gel_lane_scores based on score, and output to file

my @sorted_gel_lane_scores = sort { $b->[4] <=> $a->[4] } @gel_lane_scores;
print LOG "num_gel_lane_scores = $num_gel_lane_scores\n";

if ($create_excels)
{
	my $out_file_ = $out_file;
	$out_file_ =~ s/.txt$//;
	open(OUT, ">$out_directory/$out_file_.match-scores-sorted.csv") || die "Error: Could not open file: \'$out_directory/$out_file_.match-scores-sorted.csv\'.\n"; 
	print OUT "lane 1,lane 2,score,matches,min-error\n"; 
	for(my $i = 0; $i < $num_gel_lane_scores; $i++)
	{ print OUT "$gel_lanes[$sorted_gel_lane_scores[$i][1]],$gel_lanes[$sorted_gel_lane_scores[$i][3]],$sorted_gel_lane_scores[$i][4],$sorted_gel_lane_scores[$i][5],$sorted_gel_lane_scores[$i][6]\n"; }
	close(OUT);
	
	open(OUT, ">$out_directory/$out_file_.match-scores.csv") || die "Error: Could not open file: \'$out_directory/$out_file_.match-scores.csv\'.\n"; 
	print OUT "lane 1,lane 2,score,matches,min-error\n"; 
	for(my $i = 0; $i < $num_gel_lane_scores; $i++)
	{ print OUT "$gel_lanes[$gel_lane_scores[$i][1]],$gel_lanes[$gel_lane_scores[$i][3]],$gel_lane_scores[$i][4],$gel_lane_scores[$i][5],$gel_lane_scores[$i][6]\n"; }
	close(OUT);
	
	create_match_table();
}

#create scores hash table for use below
my %scores_hash = {};
for(my $i = 0; $i < $num_gel_lane_scores; $i++) 
{ 
	$scores_hash{"$gel_lane_scores[$i][1],$gel_lane_scores[$i][3]"} = $gel_lane_scores[$i][4];
	$scores_hash{"$gel_lane_scores[$i][3],$gel_lane_scores[$i][1]"} = $gel_lane_scores[$i][4];
}

if ($DO_IDENTITY_GROUPING)
{
	group_gel_lanes2();
	#identity_group_lanes();
}
else
{
	#group the lanes
	group_gel_lanes();
	
	if ($COMBINE_ALL_GROUPS)
	{
		print LOG "length of lane_match_list = ";
		print LOG scalar(@lane_match_list);
		print LOG "\n";
		
		#print to output file the lanes and scores
		open(OUT, ">$out_directory/$out_file") || die "Error: Could not open file: \'$out_directory/$out_file\'.\n";
		my $max_lane_score = $sorted_gel_lane_scores[0][4]; #first line is the max score
		print OUT "$max_lane_score\n";
		for(my $j = 0; $j <= $#lane_match_list; $j++)
		{
			if ($j != $#lane_match_list)
			{
				print OUT qq!$gel_lanes[$lane_match_list[$j]]\t$scores_hash{"$lane_match_list[$j],$lane_match_list[$j+1]"}\n!;
			}
			else
			{
				print OUT "$gel_lanes[$lane_match_list[$j]]\t0\n";
			}
		}
		close(OUT);
	}
	else
	{
		print LOG "length of lane_match_list = ";
		print LOG scalar(@gel_groups);
		print LOG "\n";
		
		#print to output file the lanes, grouped with \n in between them
		open(OUT, ">$out_directory/$out_file") || die "Error: Could not open file: \'$out_directory/$out_file\'.\n";
		my $max_lane_score = $sorted_gel_lane_scores[0][4]; #first line is the max score
		print OUT "$max_lane_score\n";
		for(my $j = 0; $j <= $#gel_groups; $j++)
		{
			for(my $k = 0; $k < scalar @{$gel_groups[$j]}; $k++)
			{
				if (($k+1) != scalar @{$gel_groups[$j]})
				{
					print OUT qq!$gel_lanes[$gel_groups[$j][$k]]\t$scores_hash{"$gel_groups[$j][$k],$gel_groups[$j][$k+1]"}\n!;
				}
				else { print OUT "$gel_lanes[$gel_groups[$j][$k]]\t0\n"; }
			}
			print OUT "\n";
		}
		close(OUT);
	}
}

#my $num_lane_matches = scalar(@lane_match_list);
#print "Lane Match List ($num_lane_matches): ";
#for(my $j = 0; $j <= $#lane_match_list; $j++) { print "'$lane_match_list[$j]' "; }
#print "\n";
#
#create_lane_match_image();

close(LOG);

######## subroutines ###########################################################################################################################################

sub get_default_mass_error
{#gets mass error based on mass, uses function derived from mass errors of a sample gel
 #uses max-mass = 200 and max-error = 36
	my $mass = shift;
	return get_mass_error($mass, 36, 200);
	
}

sub get_mass_error
{#gets mass error based on mass, uses function derived from mass errors of a sample gel
 #uses a line passing through (0,0) and (m,max(mass_error)* 1.5) , and the line y=max(mass_error)* 1.5 after mass=m
	my $multiplier = 1.5; #1.5; #1;
	my $mass = shift;
	my $max_mass_error = shift;
	my $max_mass = shift;
	
	if ($mass > $max_mass)
	{#curve levels off after mass=$max_mass
		return $max_mass_error * $multiplier;
	}
	my $x1 = $max_mass;
	my $y1 = $max_mass_error * $multiplier;
	
	my $mass_error = ($y1/$x1) * ($mass-$x1) + $y1;
	return $mass_error;
	
}

sub create_match_table
{#create a useful table of the scores for each lane 

	my $out_file_ = $out_file;
	$out_file_ =~ s/.txt$//;
	if (open(OUT,">$out_directory/$out_file_.lanes.match-table.csv"))
	{
		#print out the lane numbers (across):
		print OUT ",";
		for(my $i = 1; $i <= $num_gel_lanes; $i++) { print OUT "$i,"; }
		print OUT "\n";
	
		my %table_scores;
		my $num_out = 0;
		for(my $i = 0; $i < $num_gel_lane_scores; $i++) 
		{ 
			my $str = "$gel_lane_scores[$i][1],$gel_lane_scores[$i][3]";
			#print "[$str] ";
			$table_scores{$str} = $gel_lane_scores[$i][4]; 
			$str = "$gel_lane_scores[$i][3],$gel_lane_scores[$i][1]";
			$table_scores{$str} = $gel_lane_scores[$i][4];
		}
	
		#if comparing a gel to itself, we still need to output the data:
		#print out the i value, then score for (i, 1), (i, 2), (i, 3), (i, 4), ...
		#if i == j , print blank
		
		for(my $i = 1; $i <= $num_gel_lanes; $i++)
		{
			print OUT "$i,";
			for(my $j = 1; $j <= $num_gel_lanes; $j++)
			{
				my $index_i = $i-1;
				my $index_j = $j-1;
				if($index_i == $index_j) { print OUT ","; }
				else
				{
					print OUT $table_scores{"$index_i,$index_j"};
					print OUT ",";
				}
			}
			print OUT "\n";
		}
		
		close(OUT);
	}
	else { print qq!Error opening file: $out_directory/gels.match-table.csv.\n!; }
}

sub input_lane_files
{
	for(my $i = 0; $i <= $#gel_lanes; $i++)
	{
		if (open(IN,$gel_lanes[$i]))
		{ # gel1.lane-details.1
			my $line=<IN>;
			my $mass_error = 0; my $amount = 0; 
			if ($line =~ /\tmass error/) { $mass_error = 1; }
			
			my $mass_count = 0;
			while($line=<IN>)
			{
				chomp($line);
				if ($mass_error)
				{
					if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
					{# mass	pixel	min	max	cen	sum	max	mass error
						$gel_lane_masses[$i][$mass_count] = $1;
						$gel_lane_errors[$i][$mass_count] = $8;
						$gel_lane_ints[$i][$mass_count++] = $6;
						
					}
					
				}
				else
				{
					if ($line=~/^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)/)
					{# mass	pixel	min	max	cen	sum	max
						$gel_lane_masses[$i][$mass_count] = $1;
						$gel_lane_errors[$i][$mass_count] = get_default_mass_error($gel_lane_masses[$i][$mass_count]);
						$gel_lane_ints[$i][$mass_count++] = $6;
						
					}
				}
				
				
			}
			close(IN);
			
			#get max of mass error and corresonding mass
			#use this value to calculate actual mass error that we will use.
			my $max_error = 0;
			my $max_pos = -1;
			for(my $j = 0; $j < $mass_count; $j++)
			{
				if($max_error <  $gel_lane_errors[$i][$j] && $gel_lane_masses[$i][$j] < $MAX_MASS_FOR_ERROR)
				{
					$max_error = $gel_lane_errors[$i][$j];
					$max_pos = $j;
				}
			}
			my $max_error_mass = $gel_lane_masses[$i][$max_pos];
			
			#set the errors:
			for(my $j = 0; $j < $mass_count; $j++)
			{
				$gel_lane_errors[$i][$j] = get_mass_error($gel_lane_masses[$i][$j],$max_error,$max_error_mass);
			}
			
		}
		else { print qq!Error opening input file: "$gel_lanes[$i]".\n!; }	
	}
}

sub calculate_lane_match_scores
{#match lane1 to lane2 and record the score...
	my $lane1 = shift;
	my $lane2 = shift;
	
	#data already read in to @gel_lane_masses, @gel_lane_errors, and @gel_lane_ints arrays
	my $lane1_mass_count = $#{$gel_lane_masses[$lane1]} + 1;
	my $lane2_mass_count = $#{$gel_lane_masses[$lane2]} + 1;
	
	#find 2nd biggest error found for mass < 250, if it is < 2, use 2
	my $lane1_error_b = 0; my $lane1_error_2b = 0;
	my $lane2_error_b = 0; my $lane2_error_2b = 0;
	for(my $i = 0; $i < $lane1_mass_count; $i++)
	{
		if($gel_lane_masses[$lane1][$i] < $MATCH_ERROR_CUTOFF_MASS)
		{
			if($lane1_error_b < $gel_lane_errors[$lane1][$i]) { $lane1_error_2b = $lane1_error_b; $lane1_error_b = $gel_lane_errors[$lane1][$i]; }
			elsif($lane1_error_2b < $gel_lane_errors[$lane1][$i]) { $lane1_error_2b = $gel_lane_errors[$lane1][$i]; }
			#print "lane 1: i = $i, lane1_error_b = $lane1_error_b, lane1_error_2b = $lane1_error_2b; "; 
		}
	}
	#print "\n\n"; 
	for(my $i = 0; $i < $lane2_mass_count; $i++)
	{
		if($gel_lane_masses[$lane2][$i] < $MATCH_ERROR_CUTOFF_MASS)
		{
			if($lane2_error_b < $gel_lane_errors[$lane2][$i]) { $lane2_error_2b = $lane2_error_b; $lane2_error_b = $gel_lane_errors[$lane2][$i]; }
			elsif($lane2_error_2b < $gel_lane_errors[$lane2][$i]) { $lane2_error_2b = $gel_lane_errors[$lane2][$i]; }
			#print "lane 2: i = $i, lane2_error_b = $lane2_error_b, lane2_error_2b = $lane2_error_2b; "; 
		}
	}
	
	#print "\n\nErrors: $lane1_error_b, $lane1_error_2b, $lane2_error_b, $lane2_error_2b\n"; 
	
	my $lane12_error_b = $lane1_error_b + $lane2_error_b;
	my $lane12_error_2b = ($lane1_error_b + $lane2_error_2b) > ($lane1_error_2b + $lane2_error_b) ? 
		($lane1_error_b + $lane2_error_2b) : ($lane1_error_2b + $lane2_error_b);
	if($lane12_error_2b >= $lane12_error_b) { $lane12_error_2b = $lane1_error_2b + $lane2_error_2b; }
	
	#print "Errors: $lane12_error_b, $lane12_error_2b\n"; 
	
	if($lane12_error_2b < $MIN_MATCH_ERROR) { $lane12_error_2b = $MIN_MATCH_ERROR; }
	if($lane12_error_b < $MIN_MATCH_ERROR) { $lane12_error_b = $MIN_MATCH_ERROR; }
	
	#look for matches within the error margin...only one match per mass (band), use the match with the highest intensity.
	my $lane1_int_sumsq = 0; my $lane2_int_sumsq = 0;
	my @lane12_matches; #array contains the potential matches, each entry contains the intensity (sum) for a "matching" lane (within the error margin)
				#and the amount to add to the score (if it's really a match) - we'll need to weed out the real matches below (based on highest
				#intensity if a mass matches to more than one other mass
	my $matches_count = 0;
	for(my $i = 0; $i < $lane1_mass_count; $i++)
	{
		if ($USE_INTENSITY_IN_SCORE) { $lane1_int_sumsq += (($gel_lane_ints[$lane1][$i])**2); }
		else { $lane1_int_sumsq += (1**2); }
		
		for(my $j = 0; $j < $lane2_mass_count; $j++)
		{
			if($i == 0)
			{
				if ($USE_INTENSITY_IN_SCORE) { $lane2_int_sumsq += (($gel_lane_ints[$lane2][$j])**2); }
				else { $lane2_int_sumsq += (1**2); }
			}
			my $error = $gel_lane_errors[$lane1][$i] + $gel_lane_errors[$lane2][$j];
			#if($error < $lane12_error_2b) { $error = $lane12_error_2b; }
			
			my $dif = abs($gel_lane_masses[$lane1][$i] - $gel_lane_masses[$lane2][$j]); 
			if($dif < $error) 
			{
				$lane12_matches[$matches_count][0] = $dif; #$gel_lane_ints[$lane1][$i] + $gel_lane_ints[$lane2][$j]; # will sort by this
				if ($USE_INTENSITY_IN_SCORE)
				{ $lane12_matches[$matches_count][1] = $gel_lane_ints[$lane1][$i] * $gel_lane_ints[$lane2][$j]; }# will add to score (numerator) if this is really a match
				else { $lane12_matches[$matches_count][1] = 1 * 1; }# will add to score (numerator) if this is really a match
				$lane12_matches[$matches_count][2] = $i;
				$lane12_matches[$matches_count++][3] = $j;
				
				#print "Found (potential) match: $dif, $error, $matches_count "; 
				#print "[ $lane12_matches[$matches_count-1][0], $lane12_matches[$matches_count-1][1], $lane12_matches[$matches_count-1][2], $lane12_matches[$matches_count-1][3] ]\n\n";
				
			}
		}
	}
	
	#PERHAPS SUBTRACT FROM SCORE FOR BANDS THAT DO NOT MATCH ANY OTHER BAND?
	
	#sorting by intensity
	#my @lane12_matches_sorted = sort { $b->[0] <=> $a->[0] } @lane12_matches;
	
	#sorting by mass difference
	my @lane12_matches_sorted = sort { $a->[0] <=> $b->[0] } @lane12_matches;
	
	my $lane12_real_matches_count = 0; my $score = 0;
	my %used_lane1_masses; my %used_lane2_masses;
	for(my $i = 0; $i < $matches_count; $i++)
	{
		if($used_lane1_masses{$lane12_matches_sorted[$i][2]} !~ /\w/ && 
		   $used_lane2_masses{$lane12_matches_sorted[$i][3]} !~ /\w/)
		{#its a match!
			$used_lane1_masses{$lane12_matches_sorted[$i][2]} = 1;
			$used_lane2_masses{$lane12_matches_sorted[$i][3]} = 1;
			$score += $lane12_matches_sorted[$i][1]; 
			$lane12_real_matches_count++;
			
			#print "Found (real) match: $lane12_matches_sorted[$i][2], $lane12_matches_sorted[$i][3], $score\n"; 
		}
	}
	#print "Done with matching: score = $score, lane1_int_sumsq = $lane1_int_sumsq, lane2_int_sumsq = $lane2_int_sumsq, count = $lane12_real_matches_count\n"; 
	
	#calculate the score:
	
	$score = $score / (sqrt($lane1_int_sumsq * $lane2_int_sumsq));
	
	$gel_lane_scores[$num_gel_lane_scores][0] = 0; #unused
	$gel_lane_scores[$num_gel_lane_scores][1] = $lane1;
	$gel_lane_scores[$num_gel_lane_scores][2] = 0; #unused
	$gel_lane_scores[$num_gel_lane_scores][3] = $lane2;
	$gel_lane_scores[$num_gel_lane_scores][4] = $score;
	$gel_lane_scores[$num_gel_lane_scores][5] = $lane12_real_matches_count;
	$gel_lane_scores[$num_gel_lane_scores++][6] = $lane12_error_2b;
}

sub group_gel_lanes
{
	for(my $i = 0; $i < $num_gel_lane_scores; $i++)
	{
		my $lane1 = $sorted_gel_lane_scores[$i][1];
		my $lane2 = $sorted_gel_lane_scores[$i][3];
		
		if (!$COMBINE_ALL_GROUPS)
		{
			if ($sorted_gel_lane_scores[$i][4] < ($MIN_GROUP_RATIO*$sorted_gel_lane_scores[0][4]))
			{
				#stop grouping here.
				remove_empty_groups();
				return;
			}
		}
		
		#check if $lane1, lane2 in a gel group and which one
		my $found_lane1 = 0; my $found_lane2 = 0;
		my $lane1_gel_group; my $lane1_gel_group_pos;
		my $lane2_gel_group; my $lane2_gel_group_pos;
		for(my $j = 0; ($j < $num_gel_groups) && ($found_lane1 == 0 || $found_lane2 == 0); $j++)
		{	
			for(my $k = 0; ($k <= $#{$gel_groups[$j]}) && ($found_lane1 == 0 || $found_lane2 == 0); $k++)
			{
				#if($gel_groups[$j][$k] == $lane1) { $found_lane1 = 1; $lane1_gel_group = $j; $lane1_gel_group_pos = $k; }
				#elsif($gel_groups[$j][$k] == $lane2) { $found_lane2 = 1; $lane2_gel_group = $j; $lane2_gel_group_pos = $k; }
				
				if($gel_groups[$j][$k] eq "$lane1") { $found_lane1 = 1; $lane1_gel_group = $j; $lane1_gel_group_pos = $k; }
				elsif($gel_groups[$j][$k] eq "$lane2") { $found_lane2 = 1; $lane2_gel_group = $j; $lane2_gel_group_pos = $k; }
			}
		}
		
		if($found_lane1 && $found_lane2)
		{
			if($lane1_gel_group != $lane2_gel_group) # (if $lane1, $lane2 both in same group, skip)
			{#  combine the 2 groups
				group_combine($lane1_gel_group, $lane2_gel_group, $lane1_gel_group_pos, $lane2_gel_group_pos, $i);
			}
		}
		elsif($found_lane1)
		{# $lane1 in a group, but not $lane2, add $lane2 to $lane1 group
			group_add($lane1_gel_group, $lane1_gel_group_pos, $lane2, $i);
		}
		elsif($found_lane2)
		{# $lane2 in a group, but not $lane1, add $lane1 to $lane2 group
			group_add($lane2_gel_group, $lane2_gel_group_pos, $lane1, $i);
		}
		else
		{# neither in a group, create a new group
			create_group($lane1, $lane2);
		}
	}	
	remove_empty_groups();
	if($num_gel_groups != 1) { print "Error: num_gel_groups != 1 at end of group_gel_lanes!.\n" }  #all groups should be related by the end
	
	if($num_gel_groups > 0) { @lane_match_list = @{$gel_groups[0]}; }
	
}

sub remove_empty_groups
{
	my @new_gel_groups; my $new_num_gel_groups = 0;
	
	for(my $i = 0; $i < $num_gel_groups; $i++)
	{
		if($#{$gel_groups[$i]} >= 0) 
		{
			@{$new_gel_groups[$new_num_gel_groups++]} = @{$gel_groups[$i]};
			@{$gel_groups[$i]} = ();
		}
	}
	$num_gel_groups = $new_num_gel_groups;
	@gel_groups = @new_gel_groups;
	# for(my $i = 0; $i < $new_num_gel_groups; $i++)
	# {
		# @{$gel_groups[$i]} = @{$new_gel_groups[$i]};
	# }
}

sub group_combine
{
	my $gel_group1_num = shift; #the first group, we need to combine	
	my $gel_group2_num = shift; #the second group, we need to combine
	my $lane_pos_in_group1 = shift; #the lane position of the lane num in the first group
	my $lane_pos_in_group2 = shift; #the lane position of the lane num in the second group
	my $cur_pos = shift; #where we are in the sorted lane scores array, will start looking from here down for the indicator of where to put the new
				#lane in the group
						 
	#print "In group_combine: gel_group1_num = $gel_group1_num, gel_group2_num = $gel_group2_num, lane_pos_in_group1 = $lane_pos_in_group1, lane_pos_in_group2 = $lane_pos_in_group2, cur_pos = $cur_pos\n";
						 
	my $group1_side_to_add = -1; my $group2_side_to_add = -1; #tells where to add/remove for the 2 groups
	
	#check if lane nums for either or both groups are at the ends, b/c then we just add to the ends
	if($lane_pos_in_group1 == 0) { $group1_side_to_add = 0; }
	elsif($lane_pos_in_group1 == $#{$gel_groups[$gel_group1_num]}) { $group1_side_to_add = 1; }
	
	if($lane_pos_in_group2 == 0) {  $group2_side_to_add = 0; } 
	elsif($lane_pos_in_group2 == $#{$gel_groups[$gel_group2_num]}) { $group2_side_to_add = 1; } 
	
	#if we have 2 groups and both lane nums are in the middle of the group, we need to search down the match list to see how to combine them...
	for(my $i = $cur_pos+1; ($i < $num_gel_lane_scores) && ($group1_side_to_add == -1 || $group2_side_to_add == -1); $i++)
	{
		my $newlane1 = $sorted_gel_lane_scores[$i][1];
		my $newlane2 = $sorted_gel_lane_scores[$i][3];
	
		my $gel_lane1_to_add = $gel_groups[$gel_group1_num][$lane_pos_in_group1];
		my $gel_lane2_to_add = $gel_groups[$gel_group2_num][$lane_pos_in_group2];
		
		#print "$i: $newlane1, $newlane2, $lane1_to_add, $lane2_to_add\n";
		
		if($group2_side_to_add == -1 &&
		   ("$newlane1" eq $gel_lane1_to_add || "$newlane2" eq $gel_lane1_to_add))
		{#found lane 1 num in this position, what is the match lane number?  
		 #if it is found in the lane 2 group, its location will tell which side to add lane 1 group to lane 2 group
			my $indicator_lane = ("$newlane1" eq $gel_lane1_to_add ? "$newlane2" : "$newlane1"); 
			#print "in first if ($i): $indicator_lane\n";
			for(my $j = 0; $j <= $#{$gel_groups[$gel_group2_num]}; $j++)
			{
				#print "in first for ($j): $gel_groups[$gel_group2_num][$j]\n";
				if($indicator_lane eq $gel_groups[$gel_group2_num][$j]) 
				{ 
					if($j < $lane_pos_in_group2) { $group2_side_to_add = 0; } else { $group2_side_to_add = 1; }
					last;
				}
			}	
		}
		if($group1_side_to_add == -1 && 
		   ("$newlane1" eq $gel_lane2_to_add || "$newlane2" eq $gel_lane2_to_add))
		{#found lane 2 num in this position, what is the match lane number?  
		 #if it is found in the lane 1 group, its location will tell which side to add lane 2 group to lane 1 group
			my $indicator_lane = ("$newlane1" eq $gel_lane2_to_add ? "$newlane2" : "$newlane1"); ###
			#print "in second if ($i): $indicator_lane\n";
			for(my $j = 0; $j <= $#{$gel_groups[$gel_group1_num]}; $j++)
			{
				#print "in second for ($j): $gel_groups[$gel_group1_num][$j]\n";
				if($indicator_lane eq $gel_groups[$gel_group1_num][$j]) 
				{ 
					if($j < $lane_pos_in_group1) { $group1_side_to_add = 0; } else { $group1_side_to_add = 1; }
					last;
				}
			}	
		}
	}
	
	if($group2_side_to_add == -1 || $group1_side_to_add == -1) { print "Error! group1/2_side_to_add is -1 in group_combine subroutine!\n";  return;}  
	#what to do here? - should not be reached
	
	#merge group 1 and group 2
	if($group1_side_to_add == 0)
	{
		if($group2_side_to_add == 0)
		{#take from beginning of group 1, add at beginning of group 2
			unshift @{$gel_groups[$gel_group2_num]}, (reverse @{$gel_groups[$gel_group1_num]});
			@{$gel_groups[$gel_group1_num]} = ();
			# while($#{@gel_groups[$gel_group1_num]} >= 0) { unshift @{$gel_groups[$gel_group2_num]}, (shift @{$gel_groups[$gel_group1_num]}); }
		}
		else
		{#take from beginning of group 1, add at end of group 2
			push @{$gel_groups[$gel_group2_num]}, @{$gel_groups[$gel_group1_num]};
			@{$gel_groups[$gel_group1_num]} = ();
			#while($#{@gel_groups[$gel_group1_num]} >= 0) { push @{$gel_groups[$gel_group2_num]}, (shift @{$gel_groups[$gel_group1_num]}); }
		}
	}
	else
	{
		if($group2_side_to_add == 0)
		{#add at end of group 1, take from beginning of group 2
			push @{$gel_groups[$gel_group1_num]}, @{$gel_groups[$gel_group2_num]};
			@{$gel_groups[$gel_group2_num]} = ();
			#while($#{@gel_groups[$gel_group2_num]} >= 0) { push @{$gel_groups[$gel_group1_num]}, (shift @{$gel_groups[$gel_group2_num]}); }
		}
		else
		{#add at end of group 1, take from end of group 2
			push @{$gel_groups[$gel_group1_num]}, (reverse @{$gel_groups[$gel_group2_num]});
			@{$gel_groups[$gel_group2_num]} = ();
			#while($#{@gel_groups[$gel_group2_num]} >= 0) { push @{$gel_groups[$gel_group1_num]}, (pop @{$gel_groups[$gel_group2_num]}); }
		}
	}
	#??? should I remove the groups that have been emptied or just leave them?
}



sub group_add
{
	my $gel_group_num = shift; #the group number where we are adding the new lane
	my $lane_pos_in_group = shift; #the pos of the matched lane that's already in the group
	my $lane_to_add = shift; #the new lane to add
	my $cur_pos = shift; #where we are in the sorted lane scores array, will start looking from here down for the indicator of where to put the new
				#lane in the group
						 
	#print "In group_add: gel_group_num = $gel_group_num, lane_pos_in_group = $lane_pos_in_group, lane_to_add = $lane_to_add, cur_pos = $cur_pos\n";
	
	#get set of lane numbers that are before/after the position of the current lane number we are looking at
	#if before/after set is empty, add new lane number there
	#else look for new lane in the sorted_lane_scores array to find what it next matches with, that will tell where to put it (before or after)
	
	if($lane_pos_in_group == 0) { unshift @{$gel_groups[$gel_group_num]}, "$lane_to_add"; } 
	elsif($lane_pos_in_group == $#{$gel_groups[$gel_group_num]}) { push @{$gel_groups[$gel_group_num]}, "$lane_to_add"; }
	else 
	{#its somewhere in the middle, we have to figure out the best side:
		my $found = 0;
		for(my $i = $cur_pos+1; $i < $num_gel_lane_scores; $i++)
		{
			my $newlane1 = $sorted_gel_lane_scores[$i][1];
			my $newlane2 = $sorted_gel_lane_scores[$i][3];
			
			#print "$i: $newlane1, $newlane2\n";
			
			if("$newlane1" eq "$lane_to_add" || "$newlane2" eq "$lane_to_add")###
			{#found next pos of new lane in the match list, what's it match with?  that tells where to put new lane. -> maybe change something here...
				my $indicator_lane = ("$newlane1" eq "$lane_to_add" ? "$newlane2" : "$newlane1");
				
				#print "in if ($i): $indicator_lane\n";
				
				for(my $j = 0; $j <= $#{$gel_groups[$gel_group_num]}; $j++)
				{
					#print "in for ($j): $gel_groups[$gel_group_num][$j]\n";
					if($indicator_lane eq $gel_groups[$gel_group_num][$j]) 
					{ 
						if($j < $lane_pos_in_group) { unshift @{$gel_groups[$gel_group_num]}, "$lane_to_add"; }
						else { push @{$gel_groups[$gel_group_num]}, "$lane_to_add"; }
						$found = 1;
						last; 
					}
				}
				if($found == 1) { last; }
			}
		}
		if($found == 0) { print "Error! found is 0 in group_add subroutine!\n"; }  #what to do here? - should not be reached
	}
}

sub create_group
{##need to change to we add "gelnum,lanenum" as an entry  instead of just lanenum
	#print "In create_group: $_[0], $_[1], $_[2], $_[3]\n";
	$gel_groups[$num_gel_groups][0] = "$_[0]";
	$gel_groups[$num_gel_groups++][1] = "$_[1]";
}

sub create_lane_match_image
{
	#append all gel lanes images in the order of the @gel_groups array...
	print "Creating lane match image...\n";
	
	my $show_labels = 1;
	
	my $cur_file_list = "";
	for(my $j = 0; $j <= $#lane_match_list; $j++)
	{
		#add the lane number to the image to make it easy to understand the appended images
		
		my $lane_file = $gel_lanes[int($lane_match_list[$j])]; #gel2.lane-details.1
		$lane_file =~ /(.*)[\\\/]([^\\\/]+)\.lane-details\.(\d+)\.txt$/;
		my $dir = $1 . '/';
		my $gel_name = $2;
		my $lane_num = $3;
		
		if ($show_labels)
		{
			system(qq!"$SETTINGS{'ImageMagick'}/convert" "$dir$gel_name.lane.$lane_num.png" "-background" "Yellow" "label:$lane_num" "+swap" "-gravity" "Center" "-append" "$dir$gel_name.lane_labeled.$lane_num.png"!); 
			system(qq!"$SETTINGS{'ImageMagick'}/convert" "$dir$gel_name.lane_labeled.$lane_num.png" "-background" "Yellow" "label:$gel_name" "+swap" "-gravity" "Center" "-append" "$dir$gel_name.lane_labeled.$lane_num.png"!); 
			
			$cur_file_list .= qq!"$dir$gel_name.lane_labeled.$lane_num.png" !;
		}
		else
		{
			$cur_file_list .= qq!"$dir$gel_name.lane.$lane_num.png" !;
		}
		
		if ($j != $#lane_match_list)
		{
			if ($scores_hash{"$lane_match_list[$j],$lane_match_list[$j+1]"} < $MIN_GROUP_SCORE)
			{
				$cur_file_list .= qq!"$SETTINGS{'INSTALL_DIR'}/spacing.png" !;
			}
		}
	}
	system(qq!"$SETTINGS{'ImageMagick'}/convert" $cur_file_list "-background" "White" "+append" "$out_directory/gel_lane_match.png"!);
	
	if ($show_labels)
	{
		for(my $j = 0; $j <= $#lane_match_list; $j++)
		{
			my $lane_file = $gel_lanes[int($lane_match_list[$j])]; #gel2.lane-details.1
			$lane_file =~ /(.*)([^\\\/]+)\.lane-details\.(\d+)\.txt$/;
			my $dir = $1;
			my $gel_name = $2;
			my $lane_num = $3;
			
			unlink("$dir$gel_name.lane_labeled.$lane_num.png");
		}
	}
}

sub identity_group_lanes
{
	my %identity_lane_groups;
	for(my $i = 0; $i < $#gel_lane_scores; $i++)
	{
		if($gel_lane_scores[$i][4] == 1)
		{
			push @{$identity_lane_groups{"$gel_lane_scores[$i][1]"}}, $gel_lane_scores[$i][3];
			push @{$identity_lane_groups{"$gel_lane_scores[$i][3]"}}, $gel_lane_scores[$i][1];
		}
	}
	
	#print out identity_lane_groups from largest to smallest
	#mark lanes once they are printed, if they have been printed, don't print them again
	my @identity_lanes = keys %identity_lane_groups;
	my @identity_lanes_sorted;
	for(my $i = 0; $i <= $#identity_lanes; $i++)
	{
		push @identity_lanes_sorted, [$identity_lanes[$i],$#{$identity_lane_groups{$identity_lanes[$i]}}+1];
	}
	@identity_lanes_sorted = sort { $b->[1] <=> $a->[1]; } @identity_lanes_sorted;
	
	if(open(OUT, ">$out_directory/$out_file"))
	{
		#my @printed;
		my %used_lanes;
		print OUT "1\n";
		for(my $i = 0; $i < $#identity_lanes_sorted; $i++)
		{
			my @cur_lanes = @{$identity_lane_groups{$identity_lanes_sorted[$i][0]}};
			push @cur_lanes, $identity_lanes_sorted[$i][0];
			my $first = 1;
			for(my $j = 0; $j <= $#cur_lanes; $j++)
			{
				if (not $used_lanes{$cur_lanes[$j]})
				{
					#print OUT "$cur_lanes[$j]\t";
					if (not $first)
					{
						print OUT "\t1\n";
					}
					else { $first = 0; }
					
					print OUT "$gel_lanes[$cur_lanes[$j]]";
					#push @printed, "$gel_lanes[$cur_lanes[$j]]";
					$used_lanes{$cur_lanes[$j]} = 1;
				}
			}
			if (not $first)
			{#atleast one lane printed
				print OUT "\t0\n\n";
			}
		}
		close(OUT);
	}
	
	
	
	#$gel_lane_scores[$num_gel_lane_scores][0] = 0; #unused
	#$gel_lane_scores[$num_gel_lane_scores][1] = $lane1;
	#$gel_lane_scores[$num_gel_lane_scores][2] = 0; #unused
	#$gel_lane_scores[$num_gel_lane_scores][3] = $lane2;
	#$gel_lane_scores[$num_gel_lane_scores][4] = $score;
	#$gel_lane_scores[$num_gel_lane_scores][5] = $lane12_real_matches_count;
	#$gel_lane_scores[$num_gel_lane_scores++][6] = $lane12_error_2b;
	
}

sub group_gel_lanes2
{
	my $sort_by_group_size = 0;
	my $score_min = .9;
	
	my %identity_lane_groups;
	for(my $i = 0; $i < $#sorted_gel_lane_scores; $i++)
	{
		if($sorted_gel_lane_scores[$i][4] >= $score_min)
		{
			if (!(defined $identity_lane_groups{"$sorted_gel_lane_scores[$i][1]"}))
			{
				push @{$identity_lane_groups{"$sorted_gel_lane_scores[$i][1]"}}, $sorted_gel_lane_scores[$i][4];
			}
			push @{$identity_lane_groups{"$sorted_gel_lane_scores[$i][1]"}}, $sorted_gel_lane_scores[$i][3];
			
			if (!(defined $identity_lane_groups{"$sorted_gel_lane_scores[$i][3]"}))
			{
				push @{$identity_lane_groups{"$sorted_gel_lane_scores[$i][3]"}}, $sorted_gel_lane_scores[$i][4];
			}
			push @{$identity_lane_groups{"$sorted_gel_lane_scores[$i][3]"}}, $sorted_gel_lane_scores[$i][1];
		}
	}
	
	#sort identity_lane_groups from largest to smallest
	#OR - sort identity_lane_groups by order of key lane from highest score to lowest
	my @identity_lanes;
	my @identity_lanes_sorted;
	if ($sort_by_group_size)
	{
		@identity_lanes = keys %identity_lane_groups;
		for(my $i = 0; $i <= $#identity_lanes; $i++)
		{
			push @identity_lanes_sorted, [$identity_lanes[$i],$#{$identity_lane_groups{$identity_lanes[$i]}}];
		}
		@identity_lanes_sorted = sort { $b->[1] <=> $a->[1]; } @identity_lanes_sorted;
	}
	else
	{#sort by key lane (highest) score
		@identity_lanes = keys %identity_lane_groups;
		for(my $i = 0; $i <= $#identity_lanes; $i++)
		{
			push @identity_lanes_sorted, [$identity_lanes[$i],$identity_lane_groups{$identity_lanes[$i]}[0]];
		}
		@identity_lanes_sorted = sort { $b->[1] <=> $a->[1]; } @identity_lanes_sorted;
		
	}
	
	if(open(OUT, ">$out_directory/$out_file"))
	{
		#my @printed;
		my %used_lanes; #mark lanes once they are printed, if they have been printed, don't print them again
		print OUT "1\n";
		for(my $i = 0; $i < $#identity_lanes_sorted; $i++)
		{
			my @cur_lanes = @{$identity_lane_groups{$identity_lanes_sorted[$i][0]}};
			shift @cur_lanes; #take off score
			push @cur_lanes, $identity_lanes_sorted[$i][0]; #put on key lane
			my $first = 1;
			for(my $j = 0; $j <= $#cur_lanes; $j++)
			{
				if (not $used_lanes{$cur_lanes[$j]})
				{
					#print OUT "$cur_lanes[$j]\t";
					if (not $first)
					{
						my $score = $scores_hash{"$cur_lanes[$j-1],$cur_lanes[$j]"};
						print OUT "\t$score\n";
					}
					else { $first = 0; }
					
					print OUT "$gel_lanes[$cur_lanes[$j]]";
					#push @printed, "$gel_lanes[$cur_lanes[$j]]";
					$used_lanes{$cur_lanes[$j]} = 1;
				}
			}
			if (not $first)
			{#atleast one lane printed
				print OUT "\t0\n\n";
			}
		}
		close(OUT);
	}
	
	
	
	#$gel_lane_scores[$num_gel_lane_scores][0] = 0; #unused
	#$gel_lane_scores[$num_gel_lane_scores][1] = $lane1;
	#$gel_lane_scores[$num_gel_lane_scores][2] = 0; #unused
	#$gel_lane_scores[$num_gel_lane_scores][3] = $lane2;
	#$gel_lane_scores[$num_gel_lane_scores][4] = $score;
	#$gel_lane_scores[$num_gel_lane_scores][5] = $lane12_real_matches_count;
	#$gel_lane_scores[$num_gel_lane_scores++][6] = $lane12_error_2b;
	
}



