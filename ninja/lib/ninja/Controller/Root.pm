package ninja::Controller::Root;
use Moose;
use namespace::autoclean;

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
        $c->stash->{nav} = "<a href=\"/ninja\">Back</a>";
    }
    else {
        $c->stash->{tooltips} = 0;
        $c->stash->{title} = "DansGuardian Host Log Summary";
        my $list_dans_command = $curr_path . '/bin/list_dans_log_files.pl';
        $c->stash->{content} = `$list_dans_command`;
    }

}


sub send :Global {
    my ( $self, $c ) = @_;
    my $id = $c->req->params->{id};
    my $name = $c->req->params->{name};
    my $action = $c->req->params->{action};
    $c->stash->{status} = " SERVER UPTIME " . `uptime`;
    my $log = '/tmp/debug_ajax.log';
    if($name && $action && $id) {
        open (L, ">>$log") or die "cant open $log for append : $!\n";
        print L scalar(localtime()) . " :: START\n";
        print L scalar(localtime()) . " :: id :: $id\n";
        print L scalar(localtime()) . " :: name :: $name\n";
        print L scalar(localtime()) . " :: action :: $action\n";
        print L scalar(localtime()) . " :: END\n";
        close L;
    }
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
