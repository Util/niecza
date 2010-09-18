use 5.010;
use strict;
use warnings;
use utf8;

package Metamodel;
use Unit;
use Body;
use Op;
use RxOp;
use YAML::XS;

### NIECZA COMPILER METAMODEL
# The metamodel exists to create a timeline inside the compiler.  Previously,
# the compiler operated as a pure tree transformer with no conception of how
# PRE-INIT code would play out, thus precluding a lot of important
# optimizations (based on precomputing immutable objects and optimizing
# references to them, mostly).
#
# The metamodel has two main life stages.  First, it is built; an incremental
# process logically called BEGIN.  Then, it is processed to perform closed-
# world optimizations and generate code; this is (UNIT)CHECK.
#
# Kinds of objects which exist in the metamodel
# - Static subs
# - Classes
# - Packages
# - Scopes (the border between two frames, invariant under frame merging)
#
# This graph is a lot more random than the old trees were...

# package, class, etc.  Things with stashes, protoobjects, etc.
# We don't handle normal variables here, those exist only in the runtime
# package tree.
{
    package Metamodel::Packageoid;
    use Moose;

    has zyg => (isa => 'HashRef[Metamodel::Packageoid]', is => 'ro',
        default => sub { +{} });

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

{
    package Metamodel::Package;
    use Moose;
    extends 'Metamodel::Packageoid';

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

{
    package Metamodel::Module;
    use Moose;
    extends 'Metamodel::Packageoid';

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

{
    package Metamodel::Class;
    use Moose;
    extends 'Metamodel::Packageoid';

    has attributes => (isa => 'ArrayRef[Str]', is => 'ro',
        default => sub { [] });
    has methods => (isa => 'ArrayRef[Metamodel::Method]', is => 'ro',
        default => sub { [] });

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

{
    package Metamodel::Method;
    use Moose;

    has name => (isa => 'Str', is => 'ro');
    has body => (isa => 'Metamodel::StaticSub', is => 'ro');

    no Moose;
    __PACKAGE__->meta->make_immutable;
}


# This is a static lexical; they exist in finite number per unit.  They may
# occupy specific slots in pads, or globals, or something else entirely.
{
    package Metamodel::Lexical;
    use Moose;

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

# my $foo, @foo, %foo, &foo
{
    package Metamodel::Lexical::Simple;
    use Moose;
    extends 'Metamodel::Lexical';

    has sigil => (isa => 'Str', is => 'ro');

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

# sub foo { ... }
{
    package Metamodel::Lexical::SubDef;
    use Moose;
    extends 'Metamodel::Lexical';

    has body => (isa => 'Metamodel::StaticSub', is => 'ro');
    has name => (isa => 'Str', is => 'ro');

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

# my class Foo { } or our class Foo { }; the difference is whether some
# package also holds a ref
{
    package Metamodel::Lexical::Packageoid;
    use Moose;
    extends 'Metamodel::Lexical';

    has body => (isa => 'Metamodel::Packageoid', is => 'ro');
    has name => (isa => 'Str', is => 'ro');

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

# The life cycle of a static sub has three phases.
# 1. Open - the end of the sub hasn't been seen, so the full code is absent.
# 2. Closing - all attributes are available but no references exist.  The
#    perfect time for most optimizations, especially ones that look like
#    escape analyses.
# 3. Closed - references exist, possibly even from BEGIN-run code.  The sub
#    must be treated as semantically immutable.  The code can probably still
#    be changed to reflect new information, though.

# TODO: figure out how post-declared lexicals should interact with codegen
# std accepts:  sub foo() { bar }; BEGIN { foo }; sub bar() { }
{
    package Metamodel::StaticSub;
    use Moose;

    has outer => (isa => 'Maybe[Metamodel::StaticSub]', is => 'ro',
        weak_ref => 1);
    has run_once => (isa => 'Bool', is => 'ro', default => 0);

    has lexicals => (isa => 'HashRef[Metamodel::Lexical]', is => 'ro',
        default => sub { +{} });
    has code     => (isa => 'Op', is => 'rw');
    has initq    => (isa => 'ArrayRef[Metamodel::StaticSub]', is => 'ro',
        default => sub { [] });

    sub add_my_name { my ($self, $slot, $list, $hash) = @_;
        $self->lexicals->{$slot} = Metamodel::Lexical::Simple->new(
            slot => $slot, list => $list, hash => $hash);
    }

    sub close { }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

### Code goes here to build up the metamodel from an Op tree
# We should eventually wire this to the parser, so that metamodel stuff can
# exist during the parse itself; will be needed for macros

our @opensubs;
our $mainline;

sub Unit::begin {
    my $self = shift;

    $mainline = $self->mainline->begin;
}

sub Body::begin {
    my $self = shift;

    my $top = @opensubs ? $opensubs[-1] : undef;

    push @opensubs, Metamodel::StaticSub->new(
        outer => $top,
        run_once => !defined($top));
    $self->do->begin;

    $opensubs[-1]->close;
    pop @opensubs;
}

sub Op::begin {
    my $self = shift;

    $_->begin for $self->zyg;
}

sub Op::Lexical::begin {
    my $self = shift;

    if ($self->state_backing) {
        $opensubs[-1]->add_state_name($self->name, $self->state_backing,
            $self->list, $self->hash);
    } elsif ($self->declaring) {
        $opensubs[-1]->add_my_name($self->name, $self->list,
            $self->hash);
    }
}

### Code goes here to generate C# from the metamodel
#

my $y = YAML::XS::LoadFile(\*STDIN);
$y->begin;

print(YAML::XS::Dump($mainline));

1;
