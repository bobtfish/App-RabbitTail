package App::RabbitTail;
use Moose;
use App::RabbitTail::FileTailer;
use AnyEvent;
use Coro;
use namespace::autoclean;

our $VERSION = '0.000_01';
$VERSION = eval $VERSION;

with 'MooseX::Getopt';

sub run {
    my $cv = AnyEvent->condvar;
    my $ft = App::RabbitTail::FileTailer->new(
        cb => sub { warn("LINE"); },
        fn => '/Users/t0m/code/git/App-RabbitTail/test',
    );
    my $fh = $ft->tail();
    warn("Did tail");
    $cv->recv;
}

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

App::RabbitTail

=cut

