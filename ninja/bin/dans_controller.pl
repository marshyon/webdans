#!/home/jon/local/bin/perl -w

use strict;

use Net::Server::Daemonize qw(daemonize is_root_user check_pid_file);
use IO::Dir;
use IO::File;
use YAML;
use Data::Dumper;
use Config::Std;
use Net::SMTP;

my $main_config = shift || 'main.cfg';
print_help() unless ( -e $main_config );
my %config = load_config();

my $pidfile           = $config{'dans_controller'}{'pidfile'};
my $unblock_directory;
my $status_file;
my $whitelist;
my $start_cmd;
my $stop_cmd;
my $email_alerts;
my $smtp_host;
$smtp_from;
my $subject;
my $debug             = $config{'dans_controller'}{'debug'};
my $sleep             = $config{'dans_controller'}{'sleep'};
my @banned_unblocks   = $config{'unblock banned list'}{'url'};

my %banned_unblocks = ();

dpkg-deb --build debian

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
    sleep $sleep;

    %config = reload_config();
    map{ $banned_unblocks{$_}++ } @{$config{'unblock banned list'}{'url'}};

    my ( $unblocks, $emails ) =
      $unblock_directory = $config{'dans_controller'}{'unblock_directory'};
      check_for_unblock_requests( { 'dir' => $unblock_directory } );
    if ( %{$unblocks} ) {
        my $message = "unblocks : \n" . Dumper($unblocks);
        $message .= "emails : \n" . Dumper($emails);
       
        $email_alerts = $config{'dans_controller'}{'email_alerts'};
        $subject = $config{'dans_controller'}{'subject'};
        foreach my $to (@{$email_alerts}) {
            mail_report( { to => $to, subject => $subject, message => $message } );
        }
        update_whitelist( { 'sites' => $unblocks } );
        $start_cmd         = $config{'dans_controller'}{'start_cmd'};
        $stop_cmd          = $config{'dans_controller'}{'stop_cmd'};
        restart_dansguardian( { 'start' => $start_cmd, 'stop' => $stop_cmd } );
    }

    $smtp_host = $config{'dans_controller'}{'smtp_host'};
    $smtp_from = $config{'dans_controller'}{'smtp_from'};
    $subject = $config{'dans_controller'}{'subject'};
    check_dansguardian_process(
        {
            'host'    => $smtp_host,
            'from'    => $smtp_from,
            'subject' => $subject
        }
    );
}

sub check_for_unblock_requests {
    my ($param) = @_;
    my $d = $param->{'dir'};
    print "checking for request files in $d\n" if $debug;

    my %summary_by_req  = ();
    my %summary_by_addr = ();
    my %dir             = ();
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
        print "client:: $req{'client'}\n"  if $debug;
        update_status("request files located, about to process");
        my $addr = $req{'id'};
        $addr =~ s{ ^\#checkbx_ \d+ - }{}mxs;
        $addr =~ s{_}{\.}mxgs;
        $summary_by_req{ $req{'action'} }->{$addr}++;
        $summary_by_addr{ $req{'client'} }->{ $req{'action'} }->{$addr}++;
    }
    return ( \%summary_by_req, \%summary_by_addr );
}

sub update_whitelist {
    my ($param) = @_;
    my $s = $param->{sites};
    $whitelist = $config{'dans_controller'}{'whitelist'};

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


    ADDITION :
    foreach my $addition ( keys( %{ $s->{'add'} } ) ) {
        next ADDITION if ( $banned_unblocks{$addition} );
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

    my $h = $param->{host};
    my $f = $param->{from};
    my $s = $param->{subject};

    my $check_command = 'ps -ef |grep dansguardian | grep sbin | wc -l';
    my $dans_procs    = `$check_command`;

    chomp($dans_procs);

    print "dans_procs : [$dans_procs]\n" if $debug;

    if ( $dans_procs < 10 ) {
        $email_alerts = $config{'dans_controller'}{'email_alerts'};
        foreach my $to ( @{$email_alerts} ) {
            mail_report(
                {
                    to      => $to,
                    subject => 'dansguardian not running, restarting ....',
                    message => 'restart to dans commencing'
                }
            );
        }
        $start_cmd = $config{'dans_controller'}{'start_cmd'};
        #system($start_cmd);
    }
}

sub update_status {

    my $status = shift;

    $status_file = $config{'dans_controller'}{'status_file'};
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

sub print_help {
    print <<END;

    $0 <configuratin file>

configuration file 'main.cfg' is to be found at the base of the webdans directory

either change to this directory and try to run this script again or else specify 
it's full path 

eg./

    $0 /home/joe/webdans/main.cfg

END
    exit(1);

}

sub mail_report {

    my ($param) = @_;
    my $to      = $param->{'to'};
    my $subject = $param->{'subject'};
    my $message = $param->{'message'};
    my $smtp_host = $param->{'host'};
    my $smtp_from = $param->{'from'};
    my $smtp = Net::SMTP->new($smtp_host);

    $smtp->mail( $ENV{USER} );
    $smtp->to($to);

    $smtp->data();
    $smtp->datasend("To: $to\n");
    $smtp->datasend("From: $smtp_from\n");
    $smtp->datasend("Subject: $subject\n");
    $smtp->datasend("\n");
    $smtp->datasend("$message\n");
    $smtp->dataend();

    $smtp->quit;
}

sub reload_config {
    my %config = ();
    read_config $main_config => %config;
    return %config;
}

