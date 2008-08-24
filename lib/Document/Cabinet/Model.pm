package Document::Cabinet::Role::Model;

use Moose::Role;

has model => qw/is ro required 1 lazy 1/, default => sub {
    return shift->schema->modeler;
};

has cabinet => qw/is ro required 1 lazy 1 isa Document::Cabinet/, default => sub {
    return shift->model->cabinet;
}; 
package Document::Cabinet::Model::Post;

use Moose;
use Document::Cabinet::Carp;

with qw/Document::Cabinet::Role::Model/;

use File::Verbose qw/symlink/;
use Path::Class;
use Document::Stembolt;

has file => qw/is ro lazy_build 1/;
sub _build_file {
    my $self = shift;
    return $self->cabinet->run_cabinet_dir->file($self->uuid);
}

has assets_dir => qw/is ro lazy_build 1/;
sub _build_assets_dir {
    my $self = shift;
    return $self->cabinet->run_cabinet_dir->subdir(join '_', $self->uuid, qw/assets/);
}

has document => qw/is ro lazy_build 1/;
sub _build_document {
    my $self = shift;
    return Document::Stembolt->new(file => $self->file);
}

has safe_title => qw/is ro lazy_build 1 isa Str/;
sub _build_safe_title {
    my $self = shift;
    my $title = $self->title;
    $title =~ s/[^A-Za-z0-9]+/-/g;
    $title =~ s/^-+//g;
    $title =~ s/-+$//g;
    return $title;
}

sub trash {
    my $self = shift;

    my $trash_dir = $self->cabinet->run_cabinet_trash_dir;
    $trash_dir->mkpath unless -d $trash_dir;

    my $file = $self->file;
    rename $file, $trash_dir->file($file->basename) if -e $file;

    my $assets_dir = $self->assets_dir;
    rename $assets_dir, $trash_dir->subdir($assets_dir->dir_list(-1)) if -e $assets_dir;

    $self->storage->delete;
}

has content => qw/is ro lazy_build 1 isa Str/;
sub _build_content {
    my $self = shift;
}

sub link {
    my $self = shift;
    my @path = @_;
    @path = qw/./ unless @path;

    my $path = Path::Class::dir(@path);
    $path = $path->file($self->safe_title) if -d $path;

    $path = Path::Class::file($path);
    $path->parent->mkpath unless -d $path;

    my $file = $self->file;
    symlink $file, "$path.document";

    my $assets_dir = $self->assets_dir;
    symlink $assets_dir, "$path.assets";
}

package Document::Cabinet::Model;

use Moose;

BEGIN {
    extends qw/MooseX::DBIC::Modeler/;

    __PACKAGE__->setup(qw/Document::Cabinet::Schema/);
}

has cabinet => qw/is ro required 1 weak_ref 1/;

1;
