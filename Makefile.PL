use inc::Module::Install;

name 'Document-Cabinet';
all_from 'lib/Document/Cabinet.pm';

build_requires 'Test::More';

auto_install;

WriteAll;

