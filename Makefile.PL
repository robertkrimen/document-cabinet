use inc::Module::Install;

name 'Document-Cabinet';
all_from 'lib/Document/Cabinet.pm';

{
    require ExtUtils::MakeMaker;
    use strict;
    no strict 'refs';

    my $libscan = \&{"ExtUtils::MM_Any::libscan"};
    *{"ExtUtils::MM_Any::libscan"} = sub {
        return '' unless $libscan->(@_);
        return '' if $_[1] =~ /\.sw[p-z]$/;
        return $_[1];
    };
}

{
    map { my ($pk, $vr) = split m/\s/; build_requires $pk => $vr || 0 } grep { ! /^\s*#/ } split m/\n/, <<_END_;
Test::More
Test::Most
_END_

    map { my ($pk, $vr) = split m/\s/; requires $pk => $vr || 0 } grep { ! /^\s*#/ } split m/\n/, <<_END_;
Carp::Clan::Share
DBIx::Deploy
Data::UUID::LibUUID
DateTimeX::Easy
File::Verbose
Framework::Primer
JSON
Moose
Path::Abstract
Path::Class
Text::ASCIITable
_END_
}

auto_install;

WriteAll;

