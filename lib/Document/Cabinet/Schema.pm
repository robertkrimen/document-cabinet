package Document::Cabinet::Schema;

use strict;
use warnings;

use base qw/DBIx::Class::Schema Class::Accessor::Fast/;
our $schema = __PACKAGE__;

__PACKAGE__->mk_accessors(qw/cabinet/);
__PACKAGE__->load_namespaces;

package Document::Cabinet::Schema::Result::Post;

use strict;
use warnings;

use base qw/DBIx::Class/;

use JSON;

__PACKAGE__->load_components(qw/InflateColumn::DateTime PK::Auto Core/);
__PACKAGE__->table('post');
__PACKAGE__->add_columns(
    qw/id folder title uuid cdtime mdtime/
);
__PACKAGE__->set_primary_key('id');
#__PACKAGE__->add_unique_constraint([qw//]);
$schema->register_class(substr(__PACKAGE__, 10 + length $schema) => __PACKAGE__);

package Document::Cabinet::Schema;

1;
