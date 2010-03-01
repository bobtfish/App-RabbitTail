package App::RabbitTail::FileTailer;
use Moose;
use AnyEvent;
use MooseX::Types::Moose qw/CodeRef/;
use MooseX::Types::Path::Class qw/File/;
use namespace::autoclean;

has fn => (
    isa => File,
    is => 'ro',
    required => 1,
    coerce => 1,
);

has fh => (
    is => 'ro',
    lazy => 1,
    default => sub { shift->fn->openr },
);

has cb => (
    isa => CodeRef,
    is => 'ro',
    required => 2,
);

use AnyEvent::Handle;

sub tail {
    my $self = shift;
    my $hdl = AnyEvent::Handle->new(
        fh => $self->fh,
        on_error => sub {
            my ($hdl, $fatal, $msg) = @_;
            warn "got error $msg\n";
            $hdl->destroy;
        },
        on_eof => sub {
            my ($hdl) = @_;
            warn("Got eof, waiting for readability");
            $hdl->destroy;
            my $w; $w = AnyEvent->io(
                fh => $self->fh,
                poll => 'r',
                cb => sub {
                    warn("Is readable, tailing");
                    undef $w;
                    $self->tail;
                },
            );
        },
    );

    my $reader; $reader = sub {
        my ($hdl, $line) = @_;
        warn "got line <$line>\n";
        $self->cb->($self, $line);
        $self->push_read( line => $reader );
    };
    $hdl->push_read( line => $reader );
}

__PACKAGE__->meta->make_immutable;

