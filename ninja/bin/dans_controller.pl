#!/home/jon/local/bin/perl -w

use strict;

use Net::Server::Daemonize qw(daemonize is_root_user check_pid_file);
use IO::Dir;
use IO::File;
use YAML;
use Data::Dumper;

my $pidfile           = '/var/run/dans_controller.pid';
my $unblock_directory = '/etc/dansguardian/dans_controller/';
my $status_file       = $unblock_directory . "status.txt";
my $whitelist         = '/etc/dansguardian/dans_controller/whitelist.conf';
my $start_cmd .= ' /etc/init.d/dansguardian start';
my $stop_cmd  .= ' /etc/init.d/dansguardian stop';
my @email_alerts = qw(marshyon@gmail.com nigel.thompson@gmail.com);
my $smtp_host    = 'localhost';
my $smtp_from    = 'dans_guardian_daemon@myhost.com';
my $subject      = 'dans_gaurdian process died';
my $debug        = 1;

if ( !$debug ) {
    die "not root user\n"   unless is_root_user();
    die "already running\n" unless check_pid_file($pidfile);
    daemonize(
        'root',     # User
        'root',     # Group
        $pidfile    # Path to PID file - optional
    );
}

while (1) {
    print "sleeping ....\n" if $debug;
    sleep 10;
    my ($unblocks, $emails) =
      check_for_unblock_requests( { 'dir' => $unblock_directory } );
    if (%{$unblocks}) {
        print Dumper( $unblocks );
        print Dumper( $emails );
        update_whitelist( { 'sites' => $unblocks } );
        restart_dansguardian( { 'start' => $start_cmd, 'stop' => $stop_cmd } );
    }

    #check_dansguardian_process(
    #    {
    #        'emails'  => \@email_alerts,
    #        'host'    => $smtp_host,
    #        'from'    => $smtp_from,
    #        'subject' => $subject
    #    }
    #);
}

sub check_for_unblock_requests {
    my ($param) = @_;
    my $d = $param->{'dir'};
    print "checking for request files in $d\n" if $debug;

    my %summary_by_req = ();
    my %summary_by_addr= ();
    my %dir     = ();
    tie %dir, 'IO::Dir', $d;
    foreach ( keys %dir ) {
        next unless /\.req$/;
        print "$_\n" if $debug;
        my %req = ();
        eval {
            %req = YAML::LoadFile("$d$_");
            unlink("$d$_");
        };
        if ($@) {
            print "Error parsing file : $@\n";
            return;
        }

        print "name :: $req{'name'}\n"     if $debug;
        print "action :: $req{'action'}\n" if $debug;
        print "id:: $req{'id'}\n"          if $debug;
        print "client:: $req{'client'}\n"          if $debug;
        update_status("request files located, about to process");
        my $addr = $req{'id'};
        $addr =~ s{ ^\#checkbx_ \d+ - }{}mxs;
        $addr =~ s{_}{\.}mxgs;
        $summary_by_req{ $req{'action'} }->{$addr}++;
        $summary_by_addr{ $req{'client'} }->{ $req{'action'} }->{ $addr }++;
    }
    return (\%summary_by_req, \%summary_by_addr);
}

sub update_whitelist {
    my ($param) = @_;
    my $s = $param->{sites};

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

    foreach my $addition ( keys( %{ $s->{'add'} } ) ) {
        print ">>DEBUG>> addition : $addition\n" if $debug;
        $whitelist_items{$addition}++;
    }

    if ( $fh->open("> $whitelist") ) {
      ITEM:
        foreach my $item ( sort( keys(%whitelist_items) ) ) {
            next ITEM if ( $s->{'remove'}->{$item} );
            print $fh "$item\n";
        }
        $fh->close;
    }
    else {
        die "cant open whitelist : $whitelist for write : $!\n";
    }
    update_status("request files located commited");
}

sub restart_dansguardian {
    my ($param) = @_;
    my $start   = $param->{'start'};
    my $stop    = $param->{'stop'};
    print ">>DEBUG>> stopping with ..($stop)\n" if $debug;
    update_status("stopping dansguardian ...");

    #system($stop);
    update_status("starting dansguardian ...");

    #system($start);
    update_status("dansguardian restarted");
}

sub check_dansguardian_process {
    my ($param) = @_;
    my $e       = $param->{emails};
    my $h       = $param->{host};
    my $f       = $param->{from};
    my $s       = $param->{subject};

}

sub update_status {

    my $status = shift;

    if ( !-e $status_file ) { system("touch $status_file") }
    my $sfh = new IO::File;
    if ( $sfh->open("> $status_file") ) {
        print $sfh scalar(localtime) . " :: " . $status;
        close $sfh;
    }
    else {
        die "can't open status file $status_file : $!\n";
    }
}
