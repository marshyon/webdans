#!/home/jon/local/bin/perl -w

use strict;

use Net::Server::Daemonize qw(daemonize is_root_user check_pid_file);

my $pidfile           = '/var/run/dans_controller.pid';
my $unblock_directory = '/var/run/dans_controller/';
my $restart_cmd       = '/etc/init.d/dansguardian stop';
$restart_cmd .= ' /etc/init.d/dansguardian start';
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
    sleep 3;
    my @unblocks =
      check_for_unblock_requests( { 'dir' => $unblock_directory } );
    if (@unblocks) {
        unblock_sites( { 'sites' => \@unblocks } );
        restart_dansguardian( { 'cmd' => $restart_cmd } );
    }
    check_dansguardian_process(
        {
            'emails'  => \@email_alerts,
            'host'    => $smtp_host,
            'from'    => $smtp_from,
            'subject' => $subject
        }
    );
}

sub check_for_unblock_requests {
    my ($param) = @_;
    my $d = $param->{'dir'};
}

sub unblock_sites {
    my ($param) = @_;
    my $s = $param->{sites};
}

sub restart_dansguardian {
    my ($param) = @_;
    my $c = $param->{cmd};
}

sub check_dansguardian_process {
    my ($param) = @_;
    my $e       = $param->{emails};
    my $h       = $param->{host};
    my $f       = $param->{from};
    my $s       = $param->{subject};

}
