package Document::Cabinet;

use warnings;
use strict;

=head1 NAME

Document::Cabinet -

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use Moose;
use Document::Cabinet::Carp;
use Document::Cabinet::Types;
use Framework::Sourmash::Kit name => 'cabinet', dir => <<_END_;
run
run/cabinet
run/cabinet/trash
_END_

use Document::Cabinet::Model;
use Document::Cabinet::Schema;

use DBIx::Deploy;
use Path::Abstract;
use DateTimeX::Easy;
use Data::UUID::LibUUID;

has schema_file => qw/is ro required 1 lazy 1/, isa => File, default => sub {
    my $self = shift;
    return $self->home_dir->file(qw/run cabinet.db/);
};

has deploy => qw/is ro required 1 lazy 1/, default => sub {
    my $self = shift;
    my $deploy;
    $deploy = DBIx::Deploy->create(
        engine => "SQLite",
        database => [ $self->schema_file ],
        create => \<<_END_,
[% PRIMARY_KEY = "INTEGER PRIMARY KEY AUTOINCREMENT" %]
[% KEY = "INTEGER" %]

id INTEGER PRIMARY KEY AUTOINCREMENT,
insert_dtime DATE NOT NULL DEFAULT current_timestamp,

[% CLEAR %]
--
CREATE TABLE post (

    id                  [% PRIMARY_KEY %],

    folder              TEXT NOT NULL,
    title               TEXT NOT NULL,
    uuid                TEXT NOT NULL,
    cdtime              TEXT NOT NULL,
    mdtime              TEXT,

    UNIQUE(uuid)

);
_END_
    );
};

has schema => qw/is ro lazy 1/, default => sub {
    my $self = shift;
    my $schema = Document::Cabinet::Schema->connect($self->deploy->information);
    $schema->cabinet($self);
#    $schema->storage->dbh->{unicode} = 1;
#    weaken $schema->{cabinet};
    return $schema;
};

has model => qw/is ro lazy 1/, default => sub {
    my $self = shift;
    my $model = Document::Cabinet::Model->new(cabinet => $self, schema => $self->schema);
    return $model;
};

sub post {
    my $self = shift;
    my $query = shift;

    my ($post) = $self->model->search(post => { uuid => $query })->slice(0, 0);
    return $post;
}

sub parse_post {
    my $self = shift;
    my $post = shift;
    my $file = shift;

    my $schema = $self->schema;

    return $post unless $file ||= $self->post_file($post);

    my $document = Document::Stembolt->new(file => $file);
    my $header = $document->header;

    unless ($header->{uuid}) {
        print "No UUID, skipping save\n";
        return;
    }

#    if ($header->{path} && $header->{path} eq "#") {
#        print "Path is # so I'll delete\n";
#        if ($post) {
#            print "Nothing to delete\n";
#        }
#        else {
#            print "Post deleted\n";
#        }
#        return;
#    }

    ($post) = $self->model->source(qw/Post/)->search({ uuid => $header->{uuid} })->slice(0, 0);

    {
        my ($path, $title, $cdtime, $mdtime, $uuid) = delete @$header{qw/path title cdtime mdtime uuid/};
        if ($post) {
            $post->storage->update({
                path => $path,
                title => $title,
                cdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
                mdtime => DateTime->now(time_zone => "UTC"),
            });
        }
        else {
            if (! $document->body) {

                print "No content with new post, skipping save\n";
                return;
            }

            $post = $self->schema->resultset(qw/Post/)->create({
                path => $path,
                title => $title,
                uuid => $uuid,
                cdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
                mdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
            });

            $post = $self->model->inflate(post => { storage => $post });
        }
    }

    ($post) = $self->model->source(qw/Post/)->search({ id => $post->id })->slice(0, 0);

    return $post;
}

sub parse_file {
    my $self = shift;
    my $file = shift;

    croak "File \"$file\" doesn't exist" unless -f $file;
    my $document = Document::Stembolt->new(file => $file);
    my ($uuid, $folder, $title, $cdtime) = @{ $document->header }{ qw/uuid folder title cdtime/ };
    croak "Couldn't get uuid from $file" unless $uuid;
    my $post = $self->post($uuid) or croak "Couldn't find post with uuid $uuid";

    $post->storage->update({
        title => $title,
        folder => $folder,
        cdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
        mdtime => DateTime->now(time_zone => "UTC"),
    });
}

sub edit_post {
    my $self = shift;
    my $post = shift;

    my $file = $self->run_cabinet_dir->file($post->uuid);
    my $document = Document::Stembolt->new(file => $file);
    $document->header->{uuid} = $post->uuid;

    $document->edit;

    my ($folder, $title, $cdtime) = @{ $document->header }{ qw/folder title cdtime/ };

    $post->storage->update({
        title => $title,
        folder => $folder,
        cdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
        mdtime => DateTime->now(time_zone => "UTC"),
    });
}

sub trash_post {
    my $self = shift;
    my $post = shift;

    $post->trash;
}

sub new_post {
    my $self = shift;
    my $folder = shift;
    my $title = shift;

    my $uuid = new_uuid_string;
    my $cdtime = DateTime->now->set_time_zone('UTC')->strftime("%F %T %z");

    my $file = $self->run_cabinet_dir->file($uuid);

    my $document = Document::Stembolt->new(file => $file);
    $document->header->{folder} = $folder;
    $document->header->{title} = $title;
    $document->header->{uuid} = $uuid;
    $document->header->{content_type} = 'text/x-multi-markdown';
    $document->header->{cdtime} = $cdtime;

    $document->edit;

    my $post;

    if (1 || $document->body) {
        my ($folder, $title, $uuid, $cdtime) = @{ $document->header }{ qw/folder title uuid cdtime/ };

        $post = $self->schema->resultset(qw/Post/)->create({
            folder => $folder,
            title => $title,
            uuid => $uuid,
            cdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
            mdtime => DateTimeX::Easy->new($cdtime, time_zone => "UTC"),
        });
    }
    else {
        print "No content with new post, skipping save\n";
        $file->remove;
        return;
    }

    return $self->post($post->uuid);
}

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-document-cabinet at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Document-Cabinet>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Document::Cabinet


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Document-Cabinet>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Document-Cabinet>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Document-Cabinet>

=item * Search CPAN

L<http://search.cpan.org/dist/Document-Cabinet>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Document::Cabinet
