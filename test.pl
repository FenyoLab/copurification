#!/usr/bin/perl

use warnings;
use strict;

sub param
{
    my @param_array = ('a','b','c','d');
    my $param_value = "test_value";
    
    #return $param_value;
    return @param_array;
}

sub sanitize
{
    my $param_name = shift;
    my $value = shift;
    
    #sanitize/check the value before returning...
    if ($value !~ /^[A-Za-z0-9\-_\,\.\+\s\%\/]+$/)
    {
        open(my $f, '>>', 'report.txt');
        print $f "Not valid: $param_name $value\n\n";
        close $f;
        $value="";
    }
    return $value;
    
}

sub validate
{
    # only param names on the white list, with valid values will be accepted
    my $param_name = shift;
    my $value = shift;
    
    
    
}

sub param_check
{
    if (scalar(@_) > 0)
	{
		my $param_name = $_[0];
        my $is_array = 0;
        if (scalar(@_) > 1)
        {
            #2nd input tells whether return val is an array, if it is absent, assume scalar
            if ($_[1] != 0)
            {
                $is_array = 1;
            }
        }
        
        if ($is_array)
        {
            my @values=param($param_name);
            
            #sanitize/check each value in array before returning...
            
            return @values;
        }
        else
        {
            my $value = param($param_name);
            return sanitize($param_name, $value);
        }
    }
	else
	{
		my @values=param();
        #@values=();
		return @values;
	}
}

#my @test = param_check();#
#print scalar(@test) . "\n";

#my @ret_array = param_check("test");
#print "$ret_array[0]\n";

#my $ret_val = param_check('test_input');
#print "$ret_val\n";

#my $test_str = "123";
#
#my $regex = '^[0-9\,]+$';
#
#if($test_str =~ /$regex/)
#{
#    print "A match!\n";
#}
#else
#{
#    print "Not a match!\n";
#}

#my $lanes_str = "1,2,3,4,5";
#my @lanes_list = split(',',$lanes_str);
#print "$lanes_list[0]\n";

#my $test_str = "hello sarah's stuff\n";
#
#$test_str =~ s/'/\\'/;
#$test_str =~ s/\n/\\\n/;
#
#print "$test_str\n";














