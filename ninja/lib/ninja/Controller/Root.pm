package ninja::Controller::Root;
use Moose;
use namespace::autoclean;
use UUID::Tiny;
use YAML;

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

    # Hello World
    #$c->response->body( $c->welcome_message );
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
    my $lol = $c->req->params->{lol};
    $c->stash->{lol} = $lol;
    my $ip = $c->req->params->{ip};
    my $log = $c->req->params->{log};
    my $curr_path = `pwd`;
    chomp($curr_path);
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
        $c->stash->{content} = `$list_dans_command`;
        $c->stash->{nav} = "<a href=\"/ninja\">Home</a>";
    }
}

sub send :Global {
    my ( $self, $c ) = @_;
    my $id = $c->req->params->{id};
    my $name = $c->req->params->{name};
    my $action = $c->req->params->{action};
    my $request_dir = '/etc/dansguardian/dans_controller/';
    if($name && $action && $id) {

        my $curr_path = `pwd`;
        chomp($curr_path);
        my $log_file_dir = $curr_path . "/log/";
        system("mkdir $log_file_dir") unless ( -d $log_file_dir );
        my $log_file = $log_file_dir . "changes.log";
        
        my $v1_mc_UUID_string  = create_UUID_as_string(UUID_V1);
        my $request_file = $request_dir . $v1_mc_UUID_string . ".req";
        my $client_address = $c->req->address();
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
    $c->stash->{server_status} = `cat $status_file` . " :: " . `uptime` ;
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

jon,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
