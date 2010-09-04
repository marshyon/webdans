#!/home/jon/local/bin/perl -w

use strict;
use IO::Dir;
use IO::File;
use Data::Dumper;
use Date::Format;
use Getopt::Std;
use Config::Std;
use MLDBM qw(DB_File Storable);
use Fcntl;
use File::Basename;
use File::stat;

my %opts = ();
getopts( 'e:l:i:c:h', \%opts );    # options as above. Values in %opts
my $no_headers  = $opts{h};
my $excluded_ip = $opts{e};

my $main_config = $opts{c} || 'main.cfg';
print_help() unless ( -e $main_config );

my $match      = '^access\.log.*';
my $logs_files = '/var/log/dansguardian/';
my $mldbm_dir  = '/var/log/dansguardian/mldbm/';
my %dir        = ();

read_config $main_config => my %config;

my $qlog = $opts{l};
my $qip  = $opts{i};
my $c    = 0;

if ( $qlog && $qip ) {
    my $jscript_checked = "<script type=\"text/javascript\">\n";
    my $debug           = 'debug.txt';

    my $log_entries =
      extract_log_entries_from_log( { log => "$logs_files$qlog", ip => $qip } );

    print
'<table cellspacing="1" class="tablesorter"><thead><tr><th>Date</th><th>Address</th><th>Status</th><th>URL</th><th></th></tr></thead><tfoot><tr><th>Date</th><th>Address</th><th>Status</th><th>URL</th><th></th></tr></tfoot><tbody>'
      unless $no_headers;

    my $whitelist = $config{'dans_controller'}{'whitelist'};

    my %whitelist_items = ();
    my $fh              = new IO::File;
    if ( !-e $whitelist ) { system("touch $whitelist") }
    if ( $fh->open("< $whitelist") ) {
        while (<$fh>) {
            chomp($_);
            $whitelist_items{$_}++;
        }
        $fh->close;
    }
    else {
        die "cant open whitelist : $whitelist for read : $!\n";
    }

    my %seen = ();
  LINE:
    foreach my $line ( @{$log_entries} ) {

        next LINE unless ( $qip eq $line->{'ip'} );
        if($excluded_ip) {
            next LINE if ( $excluded_ip eq $line->{'ip'} );
        }



        my $status = $line->{status};
        $status =~ s{\*}{}g;
        my $check_box = '';

        my $denied_icon =
          '<span class="ui-icon ui-icon-alert" style="float:left; "></span>';

        my $info_icon =
          '<span class="ui-icon ui-icon-info " style="float:left; "></span>';

        my $permitted_icon = '';
        $status =~ s{EXCEPTION}{-}g;
        $status =~ s{DENIED}{$denied_icon}g;
        $status =~ s{(?:GET|POST)}{$permitted_icon}g;
        $status .= '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
        my $ub = $line->{url_base};

        print "<tr><td>"
          . $line->{time_str}
          . "</td><td>$qip</td><td>$status</td><td style=\"height: 28px;\"><a href=\""
          . $line->{url} . "\">"
          . $line->{url_base} . "</a>";
        if ( $line->{status} eq '*DENIED*' ) {
            print "<a style=\"float: left;\" title=\"";
            print join( "<br>", @{ $line->{'codes'} } );
            my $url_id = $line->{url_base};
            $url_id =~ s/\./_/g;
            my $checked = '';
            my $lookup  = $whitelist_items{$ub};

            if ($lookup) {
                if ( !$seen{$ub} ) {
                    my $ub_str = $ub;
                    $ub_str =~ s/\./_/g;
                    $jscript_checked .= "hashUriMods[\"$ub_str\"] = \"add\";\n";
                    $seen{$ub}++;
                }
                $checked = 'checked="yes"';
            }

            print "\" href=\"#row$c\">?</a>";

            $check_box =
                "<input type=\"checkbox\" id=\"checkbx_" 
              . $c
              . "-$url_id\" $checked>";
        }
        print "</td><td>$check_box</td></tr>\n";
        $c++;
    }
    print "</tbody></table>\n" unless $no_headers;
    print "$jscript_checked\nupdate_table_checkboxes();\n</script>";

}
else {
    tie %dir, 'IO::Dir', $logs_files;
    my %dir_file_ages = ();

    foreach ( keys %dir ) {
        next unless /$match/;
        
        $dir_file_ages{$_} = $dir{$_}->ctime;
    }

    my @sorted =
      sort { $dir_file_ages{$b} cmp $dir_file_ages{$a} } keys %dir_file_ages;

    my $c = 0;
    print
'<table cellspacing="1" class="tablesorter"><thead><tr><th>Logfile</th><th>Date</th><th>Epoch</td><th>IP Address</th><th>GETs</th><th>POSTs</th><th>*DENIED*</th></tr></thead><tfoot><tr><th>Logfile</th><th>Date</th><th>Epoch</td><th>IP Address</th><th>GETs</th><th>POSTs</th><th>*DENIED*</th></tr></tfoot><tbody>'
      unless $no_headers;



    my $dummy_count = 0;
    foreach my $key (@sorted) {
        my $summary = extract_ips_and_denied_from_log("$logs_files$key");

      LINE:
        foreach my $ip ( sort( keys( %{ $summary->{'user'} } ) ) ) {
            if ($qip) {

                next LINE unless $qip eq $ip;
            }
            $dummy_count++;

            if ($excluded_ip) { next LINE if ( $excluded_ip eq $ip ); }



            my $posts  = $summary->{'user'}->{$ip}->{'POST'}     || 0;
            my $denied = $summary->{'user'}->{$ip}->{'*DENIED*'} || 0;
            my $gets   = $summary->{'user'}->{$ip}->{'GET'}      || 0;





                print "<tr><td>$key</td><td>"
                  . time2str( "%Y %m %d %H:%M", $dir{$key}->mtime )
                  . "</td><td>"
                  . $dir{$key}->mtime
                  . "</td><td><a href=\"/ninja?ip=$ip&log=$key\">$ip</a></td>";
                print "<td>$gets</td><td>$posts</td><td>$denied";
                print "</td></tr>\n";

            $c++;

        }
    }

    print "</tbody></table>\n" unless $no_headers;
}

# return a list of IP addresses and amount of 'DENIED' messages per IP
# taken from a dansguardian log file
#
# returns a hash

sub extract_ips_and_denied_from_log {

    my $file = shift;

    my $st = stat($file) or die "No $file: $!";

    my %mldbm        = ();
    my $mldbm_exists = 0;
    my $mldbm_file =
      $mldbm_dir . "access_log_" . time2str( "%Y%m%d", $st->mtime() ) . ".mdb";

    my $current_logfile = 0;
    if ( basename($file) eq 'access.log' ) {
        $current_logfile = 1;
        unlink($mldbm_file) if ( -e $mldbm_file);
    }
    $mldbm_exists = 1 if ( -e $mldbm_file );

    if ( !$current_logfile ) {
        tie %mldbm, 'MLDBM', $mldbm_file;
    }
    my %tmp;

    my $count = 0;
    if ( !$mldbm_exists ) {
        my $fh = new IO::File;
        if ( $fh->open("< $file") ) {
          LINE:
            while (<$fh>) {
                chomp();
                my ( $time_str, $addr_str, @fields ) = split( / - */, $_ );
                my ( $ip, $url, $status, @codes ) = split( /\s+/, $addr_str );
                $tmp{'user'}->{$ip}->{$status}++;
                $count++;
            }
            $fh->close;
            $mldbm{'a'} = \%tmp unless $current_logfile;
        }
    }

    if ($current_logfile) {
        return \%tmp;
    }
    else {
        return $mldbm{'a'};
    }
}

# return a list of log entries each as a hash from a given
# dansguardian log file given filename and ip address to filter
#
# returns a list of hashes
sub extract_log_entries_from_log {

    my ($param)     = @_;
    my $log         = $param->{log};
    my $qip         = $param->{ip};
    my @log_entries = ();
    my $st = stat($log) or die "No $log : $!";

    my %mldbm        = ();
    my $mldbm_exists = 0;
    my $mldbm_file =
        $mldbm_dir
      . "access_log_entries_"
      . time2str( "%Y%m%d", $st->mtime() ) . ".mdb";

    my $current_logfile = 0;
    if ( basename($log) eq 'access.log' ) {
        $current_logfile = 1;
        unlink( $mldbm_file ) if ( -e $mldbm_file );
    }
    $mldbm_exists = 1 if ( -e $mldbm_file );

    if ( !$current_logfile ) {
        tie %mldbm, 'MLDBM', $mldbm_file;
    }
    my @tmp;

    #print "STILL HERE and looking for [$mldbm_file]\n";
    #unlink($mldbm_file) if ( -e $mldbm_file );

    if ( ! $mldbm_exists ) {

        #print "and file DOES NOT EXIST so opening up [$log]\n";

        my $fh = new IO::File;
        if ( $fh->open("< $log") ) {
          LINE:
            while (<$fh>) {
                chomp();
                my ( $time_str, $addr_str, @fields ) = split( / - */, $_ );
                my ( $ip, $url, $status, @codes ) = split( /\s+/, $addr_str );
                my %log_hash = ();
                $log_hash{'ip'}       = $ip;
                $log_hash{'time_str'} = $time_str;
                $log_hash{'url'}      = $url;
                $url =~ m{^https*://(.+)};
                my @url_list = split( /\//, $1 );
                $log_hash{'url_base'} = $url_list[0];
                $log_hash{'status'}   = $status;
                $log_hash{'codes'}    = \@codes;
                push @log_entries, \%log_hash;
            }
            $fh->close;
            $mldbm{'a'} = \@log_entries;
        }
    }
    else {
    }

    #if ($current_logfile) {
    #    return \@log_entries;
    #}
    #else {
        return \@{$mldbm{'a'}};
    #}

    #return \@log_entries;
}

sub print_help {
    print <<END;

    $0 -c <configuratin file>

configuration file 'main.cfg' is to be found at the base of the webdans directory

either change to this directory and try to run this script again or else specify 
it's full path 

eg./

    $0 -c /home/joe/webdans/main.cfg

END
    exit(1);

}

