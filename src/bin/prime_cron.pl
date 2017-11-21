#!/usr/bin/perl

=pod

=head1 LICENSE

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 DESCRIPTION

I kind of know what I've written: I implemented a scheduling algorithm that
stores the period of all primes found but it stores it relative to other primes.
An interesting benefit is along the way you see the prime factors of every number.

Usage:

The first un-named argument should be an integer to find all prime numbers up to.

Options:
	--explain -- prints the state machine table at every number
	--status -- every 10000 numbers checked print a short status message
	--verbose -- give more info
	--summary -- print a summary at the end of the run
	--final-state -- print the state of the state machine at the end of the run 
	--say-prime -- print when a prime number has been found
	--debug -- only if you really want to see what's happening behind the scenes

Examples:
	To find all prime numbers from 2-10, and output when a prime is found
	./prime_cron.pl 10 --say

	To show an example of the state machine at every step:
	./prime_cron.pl 20 --explain
		An explanation:
			Counter: 13
			1=>7,2; 1=>5,3; 7=>11;
		The primes below 13 are 7,2,5,3, and 11
		7,2 are off phase by 1 from 13.
		5,3 are off phase by 1 from the phase of 7,2
		11 is off phase by 7 from the phase of 5
		Nothing is at 0 in its phase.  13 is prime.

			Counter: 14
			0=>7,2; 1=>5,3; 7=>11; 4=>13;
		The primes below 14 are 7,2,5,3,11, and 13
		14 is in phase with 7,2.  14 is not prime.
		5,3 are off phase by 1 from 7,2
		11 is off phase by 7 from 5,3
		13 is off phase by 4 from 11.

	To find all prime numbers from 2-10, and only output a summary:
	./prime_cron.pl 10 --summary

=head1 More:

Is it a Sieve of Eratosthenes?  Not really.  Is it a wheel factorization?  Not really.

I think the state machine might be reversible too; i.e. if during the process of reversal
no primes are set to be in the 0 slot for the next round and the highest found prime
has a total phase offset of itself-1 then it should be removed from the list.

Something else that's interesting to me is that if you were to take a random list of numbers
and assign random relative phases, and then reverse the addition process, what are the
periodic properties of the state machine?

Sorry; it's implemented in Perl.  The memory usage isn't optimized at all.


-- Martin VanWinkle

=cut

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;

my (
	$debug,
	$explain,
	$status,
	$verbose,
	$summary,
	$say_prime,
	$final_state,
);

GetOptions(
	"debug" => \$debug,
	"explain" => \$explain,
	"status" => \$status,
	"verbose" => \$verbose,
	"summary" => \$summary,
	"say-prime" => \$say_prime,
	"final-state" => \$final_state,
);

my $counter = 1;

my $til = $ARGV[0];

my $cron = [];
my $need_zero;

my $start_time = time;
my $num_primes = 0;
# print "Start time: $start_time\n" if $verbose;

while ( $counter < $til )
{
	
	#debug("===============================================================\n");
	#debug("===============================================================\n");
	$counter++;

	#debug("Counter: $counter\n");
	
	print "Counter: $counter\n" if ($verbose || $explain);
	
	if ($explain)
	{
		show_explain($cron);
	}

	if ( ($verbose || $status) && $counter %10000 == 0)
	{
		print '---------------------',$/;
		print "Counter: $counter\n";
		print "Elapsed seconds:\t",time-$start_time,$/;
		print "Primes:\t$num_primes\n";
	}
	
	# Top
	if ( !$cron->[0] || $cron->[0]->{offset} )
	{
		$num_primes++;
		print "Found prime: $counter\n" if ($verbose || $say_prime);
		print "Number of primes found: $num_primes\n" if $verbose;
		# Found a prime.  Add it to the list.
		#print "Found prime: $counter\n";
		#debug("Found prime: $counter\n");
		my $newer = $counter;
		my $pointer = \$newer;
		unshift @{$cron}, {
			data => [$pointer],
			offset => 0,
		};
		
		debug("New cron: ", Dumper($cron));
	}
	else
	{
		debug("No prime found.\n");
	}
	
	# Bottom
	
	my $zero = shift @$cron;
	my @zero_parts = sort {$$a <=> $$b}
		@{$zero->{data}};
	
	#debug("Zero parts: ", Dumper(\@zero_parts));
	
	#debug("Cron after 0 removed: ", Dumper($cron));
	
	my $current_index = 0;
	my $current_offset = 0;

	if (scalar(@$cron))
	{
		$cron->[0]->{offset}--;
	}
	
	while (scalar(@zero_parts))
	{
		#debug("\t********************\n");
		#debug("Cron after shift: ", Dumper($cron));
		my $put_me = shift @zero_parts;
		my $put_me_location = $$put_me - 1;
		#debug("Looking to add: ",$$put_me,"\n");
		#debug("To position: $put_me_location\n");

		if (! scalar(@$cron))
		{
			unshift @{$cron}, {
				data => [$put_me],
				offset => $put_me_location
			};
			next;
		}
		
		if ($cron->[0]->{offset} > $put_me_location)
		{
			unshift @{$cron}, {
				data => [$put_me],
				offset => $put_me_location,
			};
			$cron->[1]->{offset}-=$put_me_location;
			next;
		}
		
		$current_offset = $cron->[0]->{offset}
			if ($current_index == 0);
		#debug("Current Index before loop: $current_index\n");
		#debug("Scalar cron: ",scalar(@$cron),$/);
		while (
			( $current_index < scalar(@$cron)-1)
			&& $cron->[$current_index+1]->{offset} + $current_offset <= $put_me_location
		)
		{
			$current_index++;
			$current_offset+=$cron->[$current_index]->{offset};
			#debug("Incremented current index to: $current_index\n");
			#debug("Current offset now: $current_offset\n");
		}

		if ($current_offset == $put_me_location)
		{
			#debug("We found an exact match.\n");
			push @{$cron->[$current_index]->{data}}, $put_me;
			next;
		}

		if ($current_index == scalar(@$cron) -1)
		{
			#debug("Adding one to the end of the list.\n");
			push @$cron, {
				offset => $put_me_location - $current_offset,
				data => [$put_me],
			};
			next;
		}

		#debug("We need to insert something.\n");
		my $this_offset = $put_me_location - $current_offset;

		splice @$cron, $current_index+1, 0, {
			offset => $this_offset,
			data => [$put_me],
		};		
		$cron->[$current_index+2]->{offset}-=$this_offset;

	}
	#debug ("Cron after ALL: ", Dumper($cron));
	# <STDIN>;
}

summary() if $summary;
final_state() if $final_state;
exit;

sub summary
{
	print "Number of primes found: $num_primes\n";
	show_primes($cron);
}

sub final_state
{
	print "Final state:\n";
	show_explain($cron);
}

sub debug
{
	print @_ if $debug;
}

sub show_primes
{
	my ($cron) = @_;
	my @primes;
	my $cron_entry;
	foreach $cron_entry (@$cron)
	{
		push @primes, map{my $blah = $_; $$blah} @{$cron_entry->{data}};
	}
	
	print join(",", sort @primes),$/;
}

sub show_explain
{
	my ($cron) = @_;
	my $cron_entry;
	foreach $cron_entry (@$cron)
	{
		print $cron_entry->{offset},"=>";
		print join(',', map{my $blah = $_; $$blah} @{$cron_entry->{data}},);
		print "; ";
	}
	
	print "\n";
}
