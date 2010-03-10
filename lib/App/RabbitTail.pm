package App::RabbitTail;
use Moose;
use RabbitFoot;
use App::RabbitTail::FileTailer;
use AnyEvent;
use Data::Dumper;
use Moose::Autobox;
use MooseX::Types::Moose qw/ArrayRef Str Int/;
use namespace::autoclean;

our $VERSION = '0.000_02';
$VERSION = eval $VERSION;

with 'MooseX::Getopt';

has filename => (
    isa => ArrayRef[Str],
    is => 'ro',
    cmd_aliases => ['fn'],
    required => 1,
    traits => ['Getopt'],
);

has routing_key => (
    isa => ArrayRef[Str],
    is => 'ro',
    cmd_aliases => ['rk'],
    default => sub { [ '#' ] },
    traits => ['Getopt'],
);

has max_sleep => (
    isa => Int,
    is => 'ro',
    default => 10,
    documentation => 'The max sleep time between trying to read a line from an input file',
);

has _rf => (
    isa => 'RabbitFoot',
    is => 'ro',
    lazy => 1,
    builder => '_build_rf',
);

sub _build_rf {
    my ($self) = @_;
    RabbitFoot->new()->load_xml_spec(
        RabbitFoot::default_amqp_spec(),
    )->connect(
        map { $_ => $self->$_ }
        qw/ host port user pass vhost /
    );
}

my %defaults = (
    host => 'localhost',
    port => 5672,
    user => 'guest',
    pass => 'guest',
    vhost => '/',
    exchange_type => 'direct',
    exchange_name => 'logs',
    exchange_durable => 0,
);

foreach my $k (keys %defaults) {
    has $k => ( is => 'ro', isa => Str, default => $defaults{$k} );
}

has _ch => (
    is => 'ro',
    lazy => 1,
    builder => '_build_ch',
);

sub _build_ch {
    my ($self) = @_;
    my $ch = $self->_rf->open_channel;
    my $exch_frame = $ch->declare_exchange(
        type => $self->exchange_type,
        durable => $self->exchange_durable,
        exchange => $self->exchange_name,
    )->method_frame;
    die Dumper($exch_frame) unless blessed $exch_frame
        and $exch_frame->isa('Net::AMQP::Protocol::Exchange::DeclareOk');
    return $ch;
}

sub run {
    my $self = shift;
    my $rkeys = $self->routing_key;
    foreach my $fn ($self->filename->flatten) {
        my $rk = $rkeys->shift;
        $rkeys->unshift($rk) unless $rkeys->length;
       # warn("Setup tail for $fn on $rk");
        my $ft = $self->setup_tail($fn, $rk, $self->_ch);
        $ft->tail;
    }
    AnyEvent->condvar->recv;
}

sub setup_tail {
    my ($self, $file, $routing_key, $ch) = @_;
    App::RabbitTail::FileTailer->new(
        max_sleep => $self->max_sleep,
        cb => sub {
            my $message = shift;
            chomp($message);
#            warn("SENT $message to " . $self->exchange_name . " with " . $routing_key);
            $ch->publish(
                body => $message,
                exchange => $self->exchange_name,
                routing_key => $routing_key,
            );
        },
        fn => $file,
    );
}

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

App::RabbitTail

=cut

