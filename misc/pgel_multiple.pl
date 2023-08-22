#!c:/perl/bin/perl.exe
##
##
#use warnings;
use strict;

require "./cgi-bin/common.pl";
require "./cgi-bin/defines.pl";

my $method = 'euclidean-ward';
#create number to sample mapping and vice versa
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

#read in lane proteins for each lane
my $lane_proteins_file = "C:\\NCDIR\\96-Well\\MS Clustering\\lane_proteins-MS-$method.txt";
open(IN,"$lane_proteins_file") or die "$lane_proteins_file not found";
my %lane_proteins;
while (<IN>)
{
	if (/^([A-H][1-9][0-9]?): (.*)$/)
	{
		my $sample_id = $1;
		$lane_proteins{$sample_id} = {};
		my $protein_list = $2;
		my @protein_list = split(',',$protein_list);
		for my $protein(@protein_list)
		{
			$protein =~ s/^\s+|\s+$//g;
			if ($protein)
			{
				if($protein =~ /([\*\?\-])(.+)[\*\?\-]/)
				{
					my $type = $1;
					my $id = uc($2);
					$lane_proteins{$sample_id}{$id} = $type;	
				}
				else { print "Error reading protein for sample: $sample_id - '$protein'\n"; }
			}
			
			
		}
	}
	else { print "Line not read in: $_\n"; }
}
close(IN);

#read in the order we want to show the lanes
my $lane_order_file = "C:\\NCDIR\\96-Well\\MS Clustering\\dendrogram-MS-$method.txt";
open(IN,"$lane_order_file") or die "$lane_order_file not found";
my @lane_order;
while (<IN>)
{
	if (/^([A-H][1-9][0-9]?)/)
	{
		push(@lane_order, $1);
	}
	else { print "Line not read in: $_\n"; }
}
close(IN);


my $log_10 = 2.303;

my $line;
my $id;
#my $expect;
my $temp;
my $string;
my $uid = 0;
my $intensity = "_";

my @uid;
my @proteins;
my @mass;
my @pi;
my @I;
my @sequences;
my $sequence;
my $pe;
my @pes;
my $value = 0;
my @pcount;
my %counts;
my $trace;
#my $gpm_show = 0;
#my %gpm_value;

#cgi params
my $proex = -1;
my $npep = 0;
#
#
my $r_max = 5;
my $r_blur = 0.5;
my $r_pImin = 3.0;
my $r_pImax = 12.0;
my $r_Mmin = 10.0; #10.0; #1.0;
my $r_Mmax = 300.0; #300.0; #1000.0;
my $logMmin = log(1000 * $r_Mmin) / $log_10 ;
my $logMmax = log(1000 * $r_Mmax) / $log_10 ;

#
# Calculate the dissociation constant, K, from the appropriate pK values
# B. Bjellqvist, et al. Electrophoresis (1994) 15:529-539.
my $K_Asp = exp(-2.303 * 4.05);
my $K_Glu = exp(-2.303 * 4.45);
my $K_His = exp(-2.303 * 5.98);
my $K_Cys = exp(-2.303 * 9.0);
my $K_Tyr = exp(-2.303 * 10.0);
my $K_Lys = exp(-2.303 * 10.0);
my $K_Arg = exp(-2.303 * 12.0);
my $K_CTerminal = exp(-2.303 * 3.55);
my $K_NTerminal = exp(-2.303 * 7.00);

### beginnig of SVG file - header
#my $pic_path ="C:/temp/draw_pseudo_gels/pseudo-lanes.svg";
my $pic_path = "C:\\NCDIR\\96-Well\\MS Clustering\\pseudo-lanes-$method.svg";

open(OUTPUT,">$pic_path")  or die "$pic_path not found";
print OUTPUT <<End_of_svg;
<?xml version="1.0" encoding="ISO-8859-1" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20010904//EN"
"http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" 
onload="getDoc(evt)" width="5400" height="1000">
<script type="text/ecmascript">
<![CDATA[
var svgdoc;

function getDoc(_evt)
{
	svgdoc = _evt.target.ownerDocument;
}
function showText(_id)
{
	var tt = svgdoc.getElementById(_id);
	tt.setAttribute("visibility","visible");
}

function hideText(_id)
{
	var tt = svgdoc.getElementById(_id);
	tt.setAttribute("visibility","hidden");
}
]]></script>
<defs>
<filter id="Gaussian_Blur" filterUnits="objectBoundingBox" x="-10%" y="-10%"
width="150%" height="150%">
End_of_svg
#width="800" height="525"
print OUTPUT "<feGaussianBlur in=\"SourceGraphic\" stdDeviation=\"$r_blur\"/>\n";
print OUTPUT "</filter>\n</defs>\n";

#rest of SVG file - the pseudo gels
my $x1 = 0;
my $x2 = 0;
my $y1 = 0;
my $y2 = 0;
my $x_base = 50;
my $y_base = 25;
my $height = 450; #600; #450;
my $width = 35;
my $cycles = $logMmax - $logMmin;
my $base = $logMmin;
$y1 = $width+10;

my $m_pfAaMass;
my %m_resCount;
my $m_fWater;
my $base_path = 'C:\\NCDIR\\96-Well\\MS Clustering\\XTandem xml results\\';

if (!opendir(DIR,"$base_path")) { print "Error reading $base_path ($!)\n"; exit(1); }
my @allfiles = readdir DIR;
closedir DIR;
my $repeat = 0;
##foreach my $path (@allfiles)
my $max_mass_found = -1;
my $min_mass_found = -1;
foreach my $sample_id (@lane_order)
{
	my $path = '';
	
	#get the file corresponding to the sample id
	for my $f (@allfiles)
	{
		if ($f =~ /^$sample_id\..*\.xml$/)
		{
			#found the right file
			$path = $f;
			last;
		}
	}
	
	#if($path =~ /\.xml$/i) { ; }
	#else { next; }
	
	$path = $base_path . '/' . $path;
	#set up var's
	$m_pfAaMass=set_aa($path);
	## rc - added 20050222 - used in get_mass()
	$m_fWater = $m_pfAaMass->{'H2O'};
	
	#init vars for this iteration
	@uid = ();
	@proteins = ();
	@mass = ();
	@pi = ();
	@I = ();
	@sequences = ();
	@pes = ();
	@pcount = ();
	%counts = ();
	
	# READ IN info from XML file
	open(INPUT,"$path") or die "$path not found";
	while(<INPUT>)
	{
		if(/group/is && /type=\"model\"/is)	{
			$_ = <INPUT>;
			$string = $_;
			$id = get_feature($string,"label");
			$id =~ s/.*?(\S+).*/$1/;
			$uid = get_feature($string,"uid");
			$pe = get_feature($string,"expect");
			if($pe >= $proex){
				next;
			}
			$temp = 0;
			foreach $line(@uid)	{
				if($line == $uid)	{
					$temp = 1;
				}
			}
			if($temp == 0)	{
				push(@proteins,$id);
				push(@uid,$uid);
				push(@pes,$pe);
				$sequence = "";
				$counts{$uid} += 1;
				while($_)	{
					if(/\<protein/s and /uid=\"$uid\"/s)	{
						$intensity = get_feature($_,"sumI");
						if($intensity ne "_")	{
							push(@I,$intensity);
						}
						while(not/\<peptide/is)	{
							$_ = <INPUT>;
						}
						$_ = <INPUT>;
						while(not/\<\/peptide/is and not/\<domain/)	{
							s/\s+//ig;
							$sequence .= $_;
							$_ = <INPUT>;
						}
						last;
					}
					$_ = <INPUT>;
				}
				while(not /\<\/group/s)	{
					if(/\<protein/s)	{
						$uid = get_feature($_,"uid");
						$counts{$uid} += 1;
					}
					$_ = <INPUT>;
				}	
				push(@sequences,$sequence);	
				push(@pi,get_pi($sequence));
				push(@mass,get_mass($sequence));
			}
			else	{
				$counts{$uid} += 1;
				$_ = <INPUT>;
				while(not /\<\/group/s)	{
					if(/\<protein/s)	{
						$uid = get_feature($_,"uid");
						$counts{$uid} += 1;
					}
					$_ = <INPUT>;
				}	
			}	
		}
		if(/\<group/ and /label\=\"unused input parameters\"/)	{
			while($_ and not /\<\/group/ and not /\<\/bioml/)	{
				chomp($_);
				if(/\<note type\=\"input\" label\=\"gpmdb, .+\"/)	{
					$value = $_;
					while($_ and not/<\/note/)	{
						$_ = <INPUT>;
						chomp($_);
						$value .= $_;
					}
					$value =~ s/<note.*?>(.*?)\<\/note\>/$1/;
					$value =~ s/^\t//;
					if(length($value) > 2)	{
						my ($tag) = $_ =~ /label\=\"gpmdb, (.+)\"/;
						#$gpm_value{$tag} .= "$value";
						#$gpm_show++;
					}
				}
				elsif(/\<note type\=\"input\" label\=\"spectrum, trace\"/)	{
					$value = $_;
					while($_ and not/<\/note/)	{
						$_ = <INPUT>;
						chomp($_);
						$value .= $_;
					}
					$value =~ s/<note.*?>(.*?)\<\/note\>/$1/;
					$trace = $value;
				}
				$_ = <INPUT>;
			}
		}
	}
	close(INPUT);
	
	$a = 0;
	foreach $line(@uid)
	{
		if(scalar(@I) == 0)
		{
			push(@pcount,$counts{$line});
		}
		else
		{
			push(@pcount,exp($I[$a]));
		}
		$a++;
	}

	# DRAW CURRENT GEL
	my $boundary_width = $width+10;
	my $offset = $repeat*($boundary_width+10);
	$x_base = 50 + $offset;
	print OUTPUT "<g id=\"boundary 1 d\" style=\"stroke:black; fill:none; stroke-width:4;\">\n";
	print OUTPUT "<rect x=\"$x_base\" y=\"$y_base\" width=\"$boundary_width\" height=\"$height\"/>\n";
	print OUTPUT "</g>\n";	
	print OUTPUT "<g id=\"bands\" style=\"stroke:black; stroke-width:6;\">\n";
	my $l = scalar(@proteins);
	my $max = 1;
	$a = 0;
	while($a < $l)	{
		if($pcount[$a] > $max)	{
			$max = $pcount[$a];
		}
		$a++;
	}
	$a = $l-1;
	my $color;
	my $crap;
	my $clr;
	my $java;
	my $browser = $ENV{'HTTP_USER_AGENT'}; # user agen detection for proper link creation

	while($a >= 0)	{
		$x1 = $x_base+5;
		$x2 = $x1 + $width;
		$y1 =  int($y_base + $height*(1 - (log($mass[$a])/2.303 - $base)/$cycles));
		
		if($y1 >= $y_base+$height)	{
			$y1 = $y_base+$height-10;
		}
		$y2 = $y1;
		
		$clr = int(0.5+(1.0-$pcount[$a]/$max) * 245);
		my $blue = "rgb(0,0,255)";
		my $black = "rgb(0,0,0)";
		$color = sprintf("rgb(%.0f,%.0f,255)", $clr,$clr); #sprintf("rgb(%.0f,%.0f,%.0f)",$clr,$clr,$clr);
		$crap = sprintf("rgb(%.0f,%.0f,%.0f)",$clr,$clr,$clr); #sprintf("rgb(255,%.0f,%.0f)", 255-$clr,255-$clr);
		my $yeast_crap = sprintf("rgb(%.0f,%.0f,%.0f)",$clr,$clr,$clr); #sprintf("rgb(%.0f,%.0f,255)", 255-$clr,255-$clr);
		my $others = sprintf("rgb(%.0f,%.0f,%.0f)",$clr,$clr,$clr); #sprintf("rgb(%.0f,%.0f,255)", 255-$clr,255-$clr);
		
		$uid = $uid[$a];
		$id = $proteins[$a];
		$java = ""; #"/thegpm-cgi/protein.pl?ltype=$ltype&amp;path=$url&amp;uid=$uid&amp;homolog=$uid&amp;label=$id&amp;proex=$proex";
		
		if ($lane_proteins{$sample_id}{uc($id)})
		{
			if ($max_mass_found == -1 || $max_mass_found < $mass[$a])
			{
				$max_mass_found = $mass[$a];
			}
			if ($min_mass_found == -1 || $min_mass_found > $mass[$a])
			{
				$min_mass_found = $mass[$a];
			}
			
			if ($mass[$a] <= ($r_Mmax*1000) && $mass[$a] >= ($r_Mmin*1000))
			{
				
				if ($y1 >= ($y_base +5) && $y1 <= ($y_base + $height))
				{
		
					if ($browser =~ /msie/ig) { # explorer, so write tag for it
		
						print OUTPUT "<a xlink:show=\"new\" xlink:href=\"$java\" onmouseover=\"showText(\'$uid\')\" onmouseout=\"hideText(\'$uid\')\" xlink:target=\"_blank\">\n";
		
					} else { # write tag for non-IE browser
		
						print OUTPUT "<a xlink:show=\"new\" xlink:href=\"$java\" onmouseover=\"showText(\'$uid\')\" onmouseout=\"hideText(\'$uid\')\" target=\"_blank\" xlink:target=\"_blank\">\n";
		
					} # end else
		
					#print OUTPUT "<a  xlink:show=\"new\" xlink:href=\"$java\" onmouseover=\"showText(\'$uid\')\" onmouseout=\"hideText(\'$uid\')\">\n";
					
					my $d = GetProteinDescription($id);
					if($id =~ /sp\|[A-Z0-9]+\_[A-Z0-9]+\|/)
					{
						print OUTPUT "<line xlink:title=\"$id: $d\" cursor=\"pointer\" x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"$black\"><title>$id</title></line>\n";
					
					}
					else
					{
						my $type = $lane_proteins{$sample_id}{uc($id)};
						if ($type eq '*')
						{
							print OUTPUT "<line xlink:title=\"$id: $d\" cursor=\"pointer\" x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"$blue\"><title>$id</title></line>\n";
						
						}
						elsif($type eq '-')
						{
							print OUTPUT "<line xlink:title=\"$id: $d\" cursor=\"pointer\" x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"$black\"><title>$id</title></line>\n";
						}
						else
						{
							print OUTPUT "<line xlink:title=\"$id: $d\" cursor=\"pointer\" x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"$black\"><title>$id</title></line>\n";
						
						}
					}
					print OUTPUT "</a>\n";
				}
			}
			else
			{
				
				print "Mass out of gel range: $mass[$a] ($id)\n";
				
			}
		}
		#else { print "ERROR: $id\n"; }
		
		$x1 = $x2 + 10;
		$a--;
	}
	print OUTPUT "</g>\n";
	#print OUTPUT "<g id=\"lane ids\" style=\"stroke:black; stroke-width:1\" >\n";
	#my $mid_x = ($x_base+8); #$width/5 + ($x_base+5);
	#my $bottom_y = $height+$y_base+20+14;
	#my $output_num = $sample_to_number_mapping{$sample_id};
	#if ($output_num > 9)
	#{
	#	$mid_x = $x_base; #$width/5 + ($x_base);
	#}
	#
	#print OUTPUT "<text x=\"$mid_x\" y=\"$bottom_y\" style=\"font-family:Arial, Helvetica, sans-serif; font-size:30pt;\">$sample_to_number_mapping{$sample_id}</text>\n";
	#print OUTPUT "</g>\n";
	
	$repeat++;
}

print "min mass = $min_mass_found\nmax mass = $max_mass_found";

# draw mass scale
#$x_base = 50;
#print OUTPUT "<g id=\"mass scale\" style=\"stroke:black; stroke-width:2\" >\n";
#my $mass = 1000.0;
#while($mass < 0.9e6)	{
#	$x1 = $x_base;
#	$x2 = $x_base-8;
#	$y1 = int($y_base + $height*(1 - (log($mass)/2.303 - $base)/$cycles));
#	$y2 = $y1;
#	if ($y1 >= $y_base && $y1 <= ($y_base + $height))	{
#		print OUTPUT "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" />\n";
#	}
#	$y1 = int($y_base + $height*(1 - (log($mass*2.0)/2.303 - $base)/$cycles));
#	$y2 = $y1;
#	if ($y1 >= $y_base && $y1 <= ($y_base + $height))	{
#		print OUTPUT "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" />\n";
#	}
#	$y1 = int($y_base + $height*(1 - (log($mass*5.0)/2.303 - $base)/$cycles));
#	$y2 = $y1;
#	if ($y1 >= $y_base && $y1 <= ($y_base + $height))	{
#		print OUTPUT "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" />\n";
#	}
#	if ($cycles <= 1)	{
#		$y1 = int($y_base + $height*(1 - (log($mass*3.0)/2.303 - $base)/$cycles));
#		$y2 = $y1;
#		if ($y1 >= $y_base && $y1 <= ($y_base + $height))	{
#			print OUTPUT "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" />\n";
#		}
#		$y1 = int($y_base + $height*(1 - (log($mass*7.0)/2.303 - $base)/$cycles));
#		$y2 = $y1;
#		if ($y1 >= $y_base && $y1 <= ($y_base + $height))	{
#			print OUTPUT "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" />\n";
#		}
#	}
#	$mass *= 10.0;
#}
#$x1 = $x_base;
#$x2 = $x_base-4;
#$y1 = int($y_base + $height*(1 - (log($mass)/2.303 - $base)/$cycles));
#$y2 = $y1;
#print OUTPUT "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" />\n";
#print OUTPUT "</g>\n";

##print OUTPUT "<g id=\"mass scale text\" style=\"font-family:Verdana,Arial,san-serif; font-size:9pt;\">\n";
##$mass = 1000.0;
##$x1 = 20;
##$a = 3;
##while($mass < 0.9e6)	{
##	$y1 = int($y_base + $height*(1 - (log($mass)/2.303 - $base)/$cycles)+5);
##	$x2 = $x1 + 16;
##	$y2 = $y1 - 5;
##	if ($y1 >= ($y_base - 10) && $y1 <= ($y_base + $height + 10))	{
##		print OUTPUT "<text x=\"$x1\" y=\"$y1\">10</text>\n";
##		print OUTPUT "<text x=\"$x2\" y=\"$y2\">$a</text>\n";
##	}
##	$a++;
##	$x2 -= 3;
##	$y1 = int($y_base + $height*(1 - (log($mass*2.0)/2.303 - $base)/$cycles)+5);
##	if ($y1 >= ($y_base - 10) && $y1 <= ($y_base + $height + 10))	{
##		print OUTPUT "<text x=\"$x2\" y=\"$y1\">2</text>\n";
##	}
##	$y1 = int($y_base + $height*(1 - (log($mass*5.0)/2.303 - $base)/$cycles)+5);
##	if ($y1 >= ($y_base - 10) && $y1 <= ($y_base + $height + 10))	{
##		print OUTPUT "<text x=\"$x2\" y=\"$y1\">5</text>\n";
##	}
##	if ($cycles <= 1)	{
##		$y1 = int($y_base + $height*(1 - (log($mass*3.0)/2.303 - $base)/$cycles)+5);
##		if ($y1 >= ($y_base - 10) && $y1 <= ($y_base + $height + 10))	{
##			print OUTPUT "<text x=\"$x2\" y=\"$y1\">3</text>\n";
##		}
##		$y1 = int($y_base + $height*(1 - (log($mass*7.0)/2.303 - $base)/$cycles)+5);
##		if ($y1 >= ($y_base - 10) && $y1 <= ($y_base + $height + 10))	{
##			print OUTPUT "<text x=\"$x2\" y=\"$y1\">7</text>\n";
##		}
##	}
##	$mass *= 10.0;
##}
##$y1 = int($y_base + $height*(1 - (log($mass)/2.303 - $base)/$cycles)+5);
##$x2 = $x1 + 16;
##$y2 = $y1 - 5;
##if ($y1 >= ($y_base - 10) && $y1 <= ($y_base + $height + 10))	{
##	print OUTPUT "<text x=\"$x1\" y=\"$y1\">10</text>\n";
##	print OUTPUT "<text x=\"$x2\" y=\"$y2\">$a</text>\n";
##}
##print OUTPUT "</g>\n";
##
##print OUTPUT "<g id=\"axis labels\" style=\"font-family:Verdana,Arial,san-serif; font-size:10pt;\">\n";
##$y1 = int($y_base + $height/2); 
##print OUTPUT "<text x=\"5\" y=\"$y1\">M</text>\n";
##$y1 += 5;
##print OUTPUT "<text x=\"16\" y=\"$y1\">r</text>\n";
##
##print OUTPUT "</g>\n";
print OUTPUT "</svg>\n";
close(OUTPUT);

#################################################################	

sub get_mass
{
	my ($s) = @_;
	my @seq = split //,$s;
	my $a = 0;
	my $length = scalar(@seq);
	my $mass = $m_fWater;
	while($a < $length)	{
		$mass += $m_pfAaMass->{$seq[$a]};
		$a++;
	}
	return $mass; 
}

sub get_pi
{
	my ($s) = @_;
	%m_resCount = ();
	my $a = 0;
	my $length = length($s);
	my @seq = split //,$s;
	while($a < $length)	{
		$m_resCount{$seq[$a]} += 1;
		$a++;
	}
	my $pH = 3.0;
	my $charge = calc_charge($pH);
	if($charge < 0.0)	{
		return 3.0;
	}
	elsif($charge == 0.0)	{
		return 3.0;
	}
	my $step = 1.0;
	my $precision = 0.01;
	my $a_ = 0;
	while(1)	{
		if($pH > 12.0)	{
			$pH = 11.9;
			last;
		}
		if(abs($charge) < $precision)	{
			last;
		}
		if($charge > 0.0)	{
			$pH += $step;
		}
		else	{
			$pH -= $step;
			$step /= 2.0;
			$pH += $step;
		}
		$charge = calc_charge($pH);
		$a_++;
	}
	return $pH;
}

sub calc_charge
{
	my ($pH) = @_;
	my $H = exp(-log(10.0) * $pH);
	my $TotalCharge = 0.0;
	$TotalCharge += 1.0/(1.0+($K_NTerminal/$H));
	$TotalCharge -= 1.0/(1.0+($H/$K_CTerminal));
	
	$TotalCharge -= $m_resCount{'D'}*(1.0/(1.0+($H/$K_Asp)));
	$TotalCharge -= $m_resCount{'E'}*(1.0/(1.0+($H/$K_Glu)));
	$TotalCharge -= $m_resCount{'Y'}*(1.0/(1.0+($H/$K_Tyr)));
	$TotalCharge -= $m_resCount{'C'}*(1.0/(1.0+($H/$K_Cys)));

	$TotalCharge += $m_resCount{'H'}*(1.0/(1.0+($K_His/$H)));
	$TotalCharge += $m_resCount{'K'}*(1.0/(1.0+($K_Lys/$H)));
	$TotalCharge += $m_resCount{'R'}*(1.0/(1.0+($K_Arg/$H)));	
	return $TotalCharge;
}
