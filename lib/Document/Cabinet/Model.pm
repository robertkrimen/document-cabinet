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

use File::Verbose qw/:all/;

has file => qw/is ro lazy_build 1/;
sub _build_file {
    my $self = shift;
    return $self->cabinet->var_cabinet_dir->file($self->uuid);
}

has assets_dir => qw/is ro lazy_build 1/;
sub _build_assets_dir {
    my $self = shift;
    return $self->cabinet->var_cabinet_dir->subdir(join '_', $self->uuid, qw/assets/);
}

sub trash {
    my $self = shift;

    my $trash_dir = $self->cabinet->var_cabinet_trash_dir;
    $trash_dir->mkpath unless -d $trash_dir;

    my $file = $self->file;
    rename $file, $trash_dir->file($file->basename) if -e $file;

    my $assets_dir = $self->assets_dir;
    rename $assets_dir, $trash_dir->subdir($assets_dir->dir_list(-1)) if -e $assets_dir;

    $self->storage->delete;
}

package Document::Cabinet::Model;

use Moose;

BEGIN {
    extends qw/MooseX::DBIC::Modeler/;

    __PACKAGE__->setup(qw/Document::Cabinet::Schema/);
}

has cabinet => qw/is ro required 1 weak_ref 1/;

1;
