#!/usr/bin/perl

<<TOKEN;

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

TOKEN


use strict;
use warnings;
use File::Rsync;
use POSIX qw(strftime);
use Fcntl qw(:flock SEEK_END);

#Here you can edir rsync sources. Those are Canonical's
#my $repoarc = 'rsync://archive.ubuntu.com/ubuntu/';
my $repoarc = 'rsync://ar.archive.ubuntu.com/ubuntu/';
my $reporel = 'rsync://rsync.releases.ubuntu.com/ubuntu-releases/';

#No further editing
my $flocker = "/var/lock/repoupdate";

my ($type,$directory) = @ARGV;
$directory or die "Usage: repoupdate -a/-r DIR \n where -a does Ubuntu Archive update and -r does Ubuntu Releases update\n"; 
$type or die "Uso: repoupdate -a/-r DIR \n where -a does Ubuntu Archive update and -r does Ubuntu Releases update\n"; 

#$directory = "/var/ubuntu/";
#$type = "-a";

dirchk($directory);

(-e "/usr/bin/rsync") or die "Rsync is missing $!";
(-e "/usr/bin/ssh") or die "SSH is missing $!";
(-e "/var/log/repo") or die "No log directory $!";

my $dsrc;
if ($type =~ /-a/) {
	$dsrc = $repoarc;
}
if ($type =~ /-r/ ) {
	$dsrc = $reporel;
}

my %opts = archrel1($type);
my $rsynco1 = File::Rsync->new( \%opts  );

#Lock for no interlapping
flock( $0, LOCK_EX|LOCK_NB) or die "Couldn't establish immediate lock: $!";

#A warning here. Must use ignore-errors or rsync will die with no recursivity.
$rsynco1->exec( { src => $dsrc , dest => $directory } ) or warn "Rsync failed\n" ;

#Log output of first rsync
my @logout1 = $rsynco1->out;
foreach my $logout1 (@logout1) {
	logcorto($logout1,$type);
}

%opts = archrel2($type);
my $rsynco2 = File::Rsync->new( \%opts  );
$rsynco2->exec( { src => $dsrc , dest => $directory } ) or warn "Rsync failed\n" ;


my @logout2 = $rsynco2->out;
foreach my $logout2 (@logout2) {
	logcorto($logout2,$type);
}


sub hora { 
	return strftime("%Y-%m-%d %H:%M:%S", localtime); 
}
sub dirchk { 
	my ($dire) = @_;
	unless  (-e $dire ) {
		my $perms = 664;
		mkdir($dire,$perms) or die "No se pudo crear el directorio $!";  
	} 
}

sub archrel1 {
	my ($type) = @_;
	if ($type =~ /-a/) {
		my @excludea = ('Packages*','Sources*','Releases*');
		my %rsopt = ( 
			archive => 1,	
			compress => 1, 
			rsh => '/usr/bin/rsh', 
			'rsync-path' => '/usr/bin/rsync',
			'recursive' => 1,
			'times' => 1,
			'links' => 1,
			'debug' => 0,
			'no-motd' => 1,
			'ignore-errors' => 1,
			'hard-links' => 1,
			'stats' => 1,
			'exclude' => \@excludea,
			'verbose' => 1
		);
		return %rsopt;
	}
	if ($type =~ /-r/) {
		my @excludea = ('Packages*','Sources*','Releases*');
		my %rsopt = ( 
			archive => 1,	
			compress => 1, 
#			rsh => '/usr/bin/ssh', 
			'rsync-path' => '/usr/bin/rsync',
			'recursive' => 1,
			'times' => 1,
			'links' => 1,
			'no-motd' => 1,
			'ignore-errors' => 1,
			'hard-links' => 1,
			'stats' => 1,
			'verbose' => 1
		);
		return %rsopt;
	}
	else {die "Wrong Switch";}
}

sub archrel2 {
	my ($type) = @_;
	if ($type =~ /-a/) {
		my %rsopt = ( 
			archive => 1,	
			compress => 1, 
			rsh => '/usr/bin/ssh', 
			'rsync-path' => '/usr/bin/rsync',
			'recursive' => 1,
			'times' => 1,
			'links' => 1,
			'no-motd' => 1,
			'ignore-errors' => 1,
			'hard-links' => 1,
			'stats' => 1,
			'delete' => 1,
			'delete-after' => 1
		);
		return %rsopt;
	}
	if ($type =~ /-r/) {
		my %rsopt = ( 
			archive => 1,	
			compress => 1, 
			rsh => '/usr/bin/ssh', 
			'rsync-path' => '/usr/bin/rsync',
			'recursive' => 1,
			'times' => 1,
			'links' => 1,
			'no-motd' => 1,
			'hard-links' => 1,
			'stats' => 1,
			'ignore-errors' => 1,
			'delete' => 1,
			'delete-after' => 1
		);
		return %rsopt;
	}
	else {die "Wrong Switch";}
}


sub logcorto {
	my ($type,$leyenda) = @_;
	if ($type =~ /-a/){
		$type = "archive.log";
	}
	if ($type == /-r/) {
		$type = "release.log";
	}
	my $hora=hora();
	chomp $leyenda;
	open(my $linklog,">>/var/log/repo/$type") or die "No se pudo abrir el log $!\n";
	print $linklog $leyenda;
	close ($linklog);
}