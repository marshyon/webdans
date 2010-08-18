#!/home/jon/local/bin/perl -w

use Config::Std;

my $main_config = shift || 'main.cfg';
print_help() unless ( -e $main_config );
read_config $main_config => my %config;

my $port = $config{'webdans'}{'webservice_port'};


system("script/ninja_server.pl -f --pidfile dans_web.pid --background -p$port");

system("sudo bin/dans_controller.pl");

sub print_help {
     print "giving up, no config file specified\n";
    exit;
}
