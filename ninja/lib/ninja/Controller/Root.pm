package ninja::Controller::Root;
use Moose;
use namespace::autoclean;
use UUID::Tiny;
use YAML;
use Config::Std;
use JSON;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

ninja::Controller::Root - Root Controller for ninja

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->res->redirect("/ninja");
    
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub ninja :Global {
    my ( $self, $c ) = @_;

    my $ip = $c->req->params->{ip};
    my $log = $c->req->params->{log};
    my $curr_path = `pwd`;
    chomp($curr_path);

    if ($c->session->{'login-ok'}) {
         $c->stash->{logged_in} = "<div id=\"login_status\" style=\"float: right;\">logged in<span class=\"ui-icon ui-icon-circle-check\" style=\"float:right;\"></span><div style=\"float: left;\" id=\"logout-user\"><a href=\"#logout\">logout</a> &nbsp;</div></div>";
    }
    else {
         my $client_address = $c->req->address();
         # REMOVE THIS WHEN DONE WITH IT
         # $client_address = '192.168.0.100';
         $ip = $client_address; # overide requested ip address with actual ip address if not logged in
         $c->stash->{logged_in} = "<div id=\"login_status\" style=\"float: right;\"><div style=\"float: left;\" id=\"login-user\"><a href=\"#\">login</a> &nbsp;</div></div>";
    }

    my %cfg = get_config();
    my $uid;
    $c->stash->{user} = $c->session->{'date_str'} ;
    $c->stash->{server_address} = $cfg{'srv'};
    $c->stash->{server_port} = $cfg{'prt'};
    if($ip && $log) {
        $c->stash->{tooltips} = 1;
        my $list_dans_command = $curr_path . "/bin/list_dans_log_files.pl -l $log -i $ip";
        $c->stash->{title} = "DansGuardian Log Summary for $ip";
        $c->stash->{content} = `$list_dans_command`;
        $c->stash->{nav} = "<a href=\"/ninja\">Home</a>";
    }
    else {
        $c->stash->{tooltips} = 0;
        $c->stash->{title} = "DansGuardian Host Log Summary";
        my $list_dans_command = $curr_path . '/bin/list_dans_log_files.pl';
        if (! $c->session->{'login-ok'}) {
            $list_dans_command .= " -i $ip";
        }
        $c->stash->{content} = `$list_dans_command`;
        $c->stash->{nav} = "<a href=\"/ninja\">Home</a>";
    }
}

sub list :Global {

    my ( $self, $c ) = @_;
    my $ip = $c->req->params->{ip};
    my $log = $c->req->params->{log};
    my $curr_path = `pwd`;
    my $client_address = $c->req->address();
    # REMOVE THIS WHEN DONE WITH IT
    # $client_address = '192.168.0.100';
    chomp($curr_path);

   if (! $c->session->{'login-ok'}) {
         $ip = $client_address; # overide requested ip address with actual ip address if not logged in
    }



    if($ip && $log) {
        my $list_dans_command = $curr_path . "/bin/list_dans_log_files.pl -h -l $log -i $ip";
        $c->stash->{content} = `$list_dans_command`;
    }
    else {
        my $list_dans_command = $curr_path . '/bin/list_dans_log_files.pl -h -e ' . $client_address;
        if (! $c->session->{'login-ok'}) {
            $list_dans_command .= " -i $ip";
        }
        $c->stash->{content} = `$list_dans_command`;
    }
}



sub send :Global {
    my ( $self, $c ) = @_;
    my $id = $c->req->params->{id};
    my $name = $c->req->params->{name};
    my $action = $c->req->params->{action};
    my $request_dir = '/etc/dansguardian/dans_controller/';
    $c->stash->{user} = " date :: " . $c->session->{'date_str'} . " session_id :: " . $c->session->{'session_id'};
    if($name && $action && $id) {

        my $curr_path = `pwd`;
        chomp($curr_path);
        my $log_file_dir = $curr_path . "/log/";
        system("mkdir $log_file_dir") unless ( -d $log_file_dir );
        my $log_file = $log_file_dir . "changes.log";
        
        my $v1_mc_UUID_string  = create_UUID_as_string(UUID_V1);
        my $request_file = $request_dir . $v1_mc_UUID_string . ".req";
        my $client_address = $c->req->address();

        # REMOVE THIS WHEN DONE WITH IT
        # $client_address = '192.168.0.100';

        my %req = (
            'id' => $id,
            'name' => $name,
            'action' => $action,
            'client' => $client_address,
        );
        YAML::DumpFile($request_file, %req);
        my $log_entry = $client_address . " :: $id :: $name :: $action";
        open(LOG, ">>$log_file") or die "can't open log [$log_file_dir][$log_file] for write : $!\n";
        print LOG scalar(localtime()) . " :: " . $log_entry . "\n";
        close LOG;
    }
    my $unblock_directory = '/etc/dansguardian/dans_controller/';
    my $status_file = $unblock_directory . "status.txt";
    $c->stash->{server_status} = `cat $status_file` . "<br>" . `uptime` ;
}

sub login_status :Global {
    my ( $self, $c ) = @_;
        my $json = new JSON;
        my %stat_str = ( 
                         'user-login-status' => $c->session->{'user-logged-in'},
                         'login-ok' => $c->session->{'login-ok'},
                       ) ;
        my $json_text   = $json->encode(\%stat_str);

    $c->stash->{'login_status'} = $json_text;
    $c->stash->{'session_id'} = $c->session->{'user-logged-in'};
}

sub banned :Global {
    my ( $self, $c ) = @_;
    my $status = 'nada';#ui-state-hover
    if($c->sessionid) {
        $status = $c->sessionid();
    }
    $c->stash->{'login_status'} = $status;
}

=head2 end

Attempt to render a view, if needed.

=cut

sub get_config {
    my $curr_path = `pwd`;
    chomp($curr_path);
    my $main_config = $curr_path . '/main.cfg';
    read_config $main_config => my %config;
    my %cfg = ();
    $cfg{srv} = $config{'webdans'}{'webservice_address'};
    $cfg{prt} = $config{'webdans'}{'webservice_port'};
    return %cfg;
}

sub login :Global {

    my ( $self, $c ) = @_;
    if ( $c->req->params->{'logout'} ) {
        $c->logout();
        $c->delete_session('logged out');
    }

    use Data::Dumper;
    #$c->res->body( Dumper($c->req->params) );
    #return;
    if (    my $user = $c->req->params->{user}
        and my $password = $c->req->params->{password} )
    {
        if (
            $c->authenticate(
                {
                    username => $user,
                    password => $password
                }
            )
          )
        {
        my $roles = $c->user->{'roles'};
        my @rls = $roles;
            $c->res->body( "<span class=\"ui-icon ui-icon-circle-check\" style=\"float:left; margin:0 7px 50px 0;\"></span>
" );
        $c->session->{'date_str'} = scalar(localtime());
        $c->session->{'session_id'} = $c->sessionid();
        $c->session->{'user-logged-in'} = $c->req->params->{user} . ' logged in';
        $c->session->{'login-ok'} = 1;
        }
        else {

            # login incorrect
            #$c->res->body( '<div style="float: right;" id="login-user"><a href="#">login yyy</a> &nbsp; <span class="ui-icon ui-icon-circle-close"></span></div>' );
            #$c->res->body( "<div id=\"login_status\" style=\"float: right;\"><div style=\"float: left;\" id=\"login-user\"><a href=\"#\">login aaa</a> &nbsp;</div></div>" );
            $c->res->body( "" );
            $c->logout();
            $c->session->{'login-ok'} = 0;
            $c->delete_session('logged out');
        }
    }
    else {

        # invalid form input
        #$c->res->body( '<div style="float: right;" id="login-user"><a href="#">login xxx</a> &nbsp; <span class="ui-icon ui-icon-circle-close"></span></div>' );
        #$c->res->body( "<div id=\"login_status\" style=\"float: right;\"><div style=\"float: left;\" id=\"login-user\"><a href=\"#\">login aaa</a> &nbsp;</div></div>" );
        $c->res->body( "logged out" );
        $c->logout();
        $c->session->{'login-ok'} = 0;
        $c->delete_session('logged out');
    }
}


sub end : ActionClass('RenderView') {}

=head1 AUTHOR

jon,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
