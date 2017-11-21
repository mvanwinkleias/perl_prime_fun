#!/usr/bin/perl

#my @p;
#my $c;
for $c (2..$ARGV[0]     || die 'Run me with a positive integer!')
{ push (@p, $c) unless grep { ! ($c % $_) } @p; }
print join(',', @p),$/;
