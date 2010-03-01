package App::RabbitTail;
use Moose;
use RabbitFoot;
use App::RabbitTail::FileTailer;
use AnyEvent;
use Data::Dumper;
use MooseX::Types::Moose qw/Str/;
use namespace::autoclean;

our $VERSION = '0.000_01';
$VERSION = eval $VERSION;

with 'MooseX::Getopt';

has filename => (
    isa => Str,
    is => 'ro',
    required => 1,
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
    routing_key => '#',
);

foreach my $k (keys %defaults) {
    has $k => ( is => 'ro', default => $defaults{$k} );
}

has _ch => (
    is => 'ro',
    lazy => 1,
    builder => '_build_ch',
);

sub _build_ch {
    my ($self) = @_;
    my $ch = $self->_rf->open_channel;
    warn("Channel open");
  #  my $exch_frame = $ch->declare_exchange(
  #      type => $self->exchange_type,
  #      durable => $self->exchange_durable,
  #      exchange => $self->exchange_name,
  #  )->method_frame;
    warn("Got exchange");
   # die Dumper($exch_frame) unless blessed $exch_frame and $exch_frame->isa('Net::AMQP::Protocol::Exchange::DeclareOk');
    return $ch;
}

sub run {
    my $self = shift;
    warn("QUACH");
    $self->_ch;
    warn("SETUP");
    my $ft = $self->setup_tail($self->filename, $self->_ch);
    $ft->tail;
    AnyEvent->condvar->recv;
}

sub setup_tail {
    my ($self, $file, $ch) = @_;
    App::RabbitTail::FileTailer->new(
        cb => sub {
            my $message = shift;
            warn("SENT $message");
            $ch->publish(
                body => $message,
                exchange => $self->exchange_name,
                routing_key => $self->routing_key,
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

