use strict;
use warnings;
use inc::Module::Install;
#use Module::Install::AuthorRequires;
#use Module::Install::AuthorTests;

name 'App-RabbitTail';
all_from 'lib/App/RabbitTail.pm';

requires 'Moose';
requires 'namespace::autoclean';
requires 'RabbitFoot';
requires 'AnyEvent';
requires 'MooseX::Types::Path::Class';
requires 'MooseX::Types';

test_requires 'Test::More' => '0.88';

if ($Module::Install::AUTHOR) {
    system("pod2text lib/App/RabbitTail.pm > README")
        and die $!;
}

WriteAll;

