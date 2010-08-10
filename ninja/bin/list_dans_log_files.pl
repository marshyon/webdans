#!/usr/bin/perl -w

use strict;
use IO::Dir;
use IO::File;
use Data::Dumper;
use Date::Format;
use Getopt::Std;

my %opts = ();
getopts('l:i:', \%opts);  # options as above. Values in %opts

my $match = '^access\.log.*';
my $logs_files = '/var/log/dansguardian/';
my %dir = ();

my $qlog = $opts{l};
my $qip = $opts{i};
my $c = 0;

if($qlog && $qip) {
    my $log_entries = extract_log_enties_from_log({log => "$logs_files$qlog", ip => $qip});

    print '<table cellspacing="1" class="tablesorter"><thead><tr><th>Date</th><th>Address</th><th>Status</th><th>URL</th></tr></thead><tfoot><tr><th>Date</th><th>Address</th><th>Status</th><th>URL</th></tr></tfoot><tbody>';

    my $whitelist = '/var/run/dans_controller/whitelist.conf';
    my %whitelist_items = ();
    my $fh = new IO::File;
    if( ! -e $whitelist ) { system("touch $whitelist") }
    if ($fh->open("< $whitelist")) {
        while(<$fh>) {
            chomp($_);
            $whitelist_items{$_}++;
        }
        $fh->close;
    } 
    else {
        die "cant open whitelist : $whitelist for read : $!\n";
    }




    foreach my $line (@{$log_entries}) {
        my $status = $line->{status};
        $status =~ s{\*}{}g;
        print "<tr><td>" . $line->{time_str} . "</td><td>$qip</td><td>$status</td><td><a href=\"".$line->{url} . "\">" . $line->{url_base} . "</a>";
        if($line->{status} eq '*DENIED*') {
            print "&nbsp; <a title=\"";
            print join("<br>", @{$line->{'codes'}});
            my $url_id = $line->{url_base};
            $url_id =~ s/\./_/g;
            my $checked = '';

            if($whitelist_items{$line->{url_base}}) {
               $checked = 'checked = yes'
            }
            
            print "\" href=\"#row$c\">?</a><input style=\"height:30em;\" type=\"checkbox\" id=\"checkbx_".$c."-$url_id\" $checked>";
        }
        print "</td></tr>\n";
        $c++;
    }
    print "</tbody></table>\n";

#    print Dumper($log_entries);

}
else {
    tie %dir, 'IO::Dir', $logs_files;
    my %dir_file_ages = ();

    foreach (keys %dir) {
        next unless /$match/;
        $dir_file_ages{$_} = $dir{$_}->ctime;
    }


    my @sorted = sort { $dir_file_ages{$b} cmp $dir_file_ages{$a} } keys %dir_file_ages;

    my $c = 0;
    print '<table cellspacing="1" class="tablesorter"><thead><tr><th>Logfile</th><th>Date</th><th>Epoch</td><th>IP Address</th><th>GETs</th><th>POSTs</th><th>*DENIED*</th></tr></thead><tfoot><tr><th>Logfile</th><th>Date</th><th>Epoch</td><th>IP Address</th><th>GETs</th><th>POSTs</th><th>*DENIED*</th></tr></tfoot><tbody>';




    foreach my $key (@sorted) {
        my %summary = extract_ips_and_denied_from_log("$logs_files$key");
        foreach my $ip (sort(keys(%{$summary{'user'}}))) {
            my $posts = $summary{'user'}->{$ip}->{'POST'} || 0;
            my $denied = $summary{'user'}->{$ip}->{'*DENIED*'} || 0;
            my $gets = $summary{'user'}->{$ip}->{'GET'} || 0;

            print "<tr><td>$key</td><td>" . time2str("%Y%m%d%H%M", $dir{$key}->mtime) . "</td><td>" . $dir{$key}->mtime . "</td><td><a href=\"/ninja?ip=$ip&log=$key\">$ip</a></td>";
            print "<td>$gets</td><td>$posts</td><td>$denied";
            print "</td></tr>\n";
            $c++;

        }
    }


    print "</tbody></table>\n";
}

# return a list of IP addresses and amount of 'DENIED' messages per IP 
# taken from a dansguardian log file
#
# returns a hash
sub extract_ips_and_denied_from_log {
    my $log = shift;
    my %summary = ();

    my $fh = new IO::File;
    my $count = 0;
    if ($fh->open("< $log")) {
        LINE:
        while( <$fh> ) {
            chomp();
            my ($time_str, $addr_str, @fields) = split(/ - */, $_);
            my ($ip, $url, $status, @codes) = split(/\s+/, $addr_str);
            $summary{'user'}->{$ip}->{$status}++;
            $count++;
        }
    $fh->close;
    }
    $summary{'total_lines'} = $count;
    return %summary;
}

# return a list of log entries each as a hash from a given 
# dansguardian log file given filename and ip address to filter
#
# returns a list of hashes
sub extract_log_enties_from_log {
    my ($param) = @_;
    my $log = $param->{log};
    my $qip = $param->{ip};
    my @log_entries = ();

    my $fh = new IO::File;
    if ($fh->open("< $log")) {
        LINE:
        while( <$fh> ) {
            chomp();
            my ($time_str, $addr_str, @fields) = split(/ - */, $_);
            my ($ip, $url, $status, @codes) = split(/\s+/, $addr_str);
            next LINE unless ( $qip eq $ip );
            my %log_hash = ();
            $log_hash{'time_str'} = $time_str;
            $log_hash{'url'} = $url;
            $url =~ m{^https*://(.+)};
            my @url_list = split(/\//, $1);
            $log_hash{'url_base'} = $url_list[0];
            $log_hash{'status'} = $status;
            $log_hash{'codes'} = \@codes;
            push @log_entries, \%log_hash;
        }
    $fh->close;
    }
    return \@log_entries;
}

