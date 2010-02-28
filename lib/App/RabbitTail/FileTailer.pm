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

has cb => (
    isa => CodeRef,
    is => 'ro',
    required => 2,
);

__PACKAGE__->meta->make_immutable;

