package App::RabbitTail::FileTailer;
use Moose;
use AnyEvent;
use MooseX::Types::Moose qw/CodeRef Num/;
use MooseX::Types::Path::Class qw/File/;
use Coro::Handle;
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
    required => 1,
);

has _sleep_interval => (
    isa => Num,
    is => 'rw',
    default => 0,
);

has _next_backoff => (
    isa => Num,
    is => 'rw',
    clearer => '_clear_next_backoff',
    predicate => '_has_next_backoff',
);

has backoff_increment => (
    isa => Num,
    is => 'ro',
    default => 0.1,
);

has max_sleep => (
    isa => Num,
    is => 'ro',
    default => 10,
);

has _watcher => (
    is => 'rw'
);

sub tail {
    my ($self) = @_;

    while ($self->_read_one_line) {}
    $self->_sleep_till_lines
}

sub _sleep_till_lines {
    my ($self) = @_;
    $self->_watcher(AnyEvent->timer(
        after => $self->_sleep_interval,
        cb => sub {
            if ( !$self->_read_one_line ) {
                if (!$self->_has_next_backoff) {
                    $self->_next_backoff($self->backoff_increment);
                }
                $self->_sleep_interval($self->_sleep_interval + $self->_next_backoff);
                if ($self->_sleep_interval > $self->max_sleep) {
                    $self->_sleep_interval($self->max_sleep);
                    $self->_next_backoff(0);
                }
                elsif ($self->_sleep_interval < $self->max_sleep) {
                    $self->_next_backoff( $self->_next_backoff * 2 );
                }
                $self->_sleep_till_lines;
            }
            else {
                $self->tail;
            }
        },
    ));
}

sub _read_one_line {
    my $self = shift;
    my $line = unblock($self->fh)->readline;
    return if !defined $line;
    $self->_sleep_interval(0);
    $self->_clear_next_backoff;
    $self->cb->($line);
    return $line;
}

__PACKAGE__->meta->make_immutable;

