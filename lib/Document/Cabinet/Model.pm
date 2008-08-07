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

package Document::Cabinet::Model;

use Moose;

BEGIN {
    extends qw/MooseX::DBIC::Modeler/;

    __PACKAGE__->setup(qw/Document::Cabinet::Schema/);
}

has cabinet => qw/is ro required 1 weak_ref 1/;

1;
