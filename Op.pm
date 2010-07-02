use strict;
use warnings;
use 5.010;

{
    package Op;
    use Moose;

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

{
    package Op::NIL;
    use Moose;
    extends 'Op';

    has code => (isa => 'ArrayRef', is => 'ro', required => 1);

    sub item_cg {
        my ($self, $cg, $body) = @_;
        for my $insn (@{ $self->code }) {
            my ($op, @args) = @$insn;
            $cg->$op(@args);
        }
    }

    sub void_cg {
        my ($self, $cg, $body) = @_;
        $self->item_cg($cg, $body);
        $cg->drop;
    }

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

{
    package Op::StatementList;
    use Moose;
    extends 'Op';

    has children => (isa => 'ArrayRef[Op]', is => 'ro', required => 1);

    sub item_cg {
        my ($self, $cg, $body) = @_;
        if (!@{ $self->children }) {
            # XXX scoping
            Op::Lexical->new(name => '&Nil')->item_cg($cg, $body);
        } else {
            my @kids = @{ $self->children };
            my $end = pop @kids;
            for (@kids) {
                $_->void_cg($cg, $body);
            }
            $end->item_cg($cg, $body);
        }
    }

    sub void_cg {
        my ($self, $cg, $body) = @_;
        for (@{ $self->children }) {
            $_->void_cg($cg, $body);
        }
    }

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

{
    package Op::CallSub;
    use Moose;
    extends 'Op';

    has invocant    => (isa => 'Op', is => 'ro', required => 1);
    has positionals => (isa => 'ArrayRef[Op]', is => 'ro',
        default => sub { [] });
    # non-parenthesized constructor
    has splittable_pair => (isa => 'Bool', is => 'rw', default => 0);
    has splittable_parcel => (isa => 'Bool', is => 'rw', default => 0);

    sub item_cg {
        my ($self, $cg, $body) = @_;
        $self->invocant->item_cg($cg, $body);
        $cg->fetchlv;
        $_->item_cg($cg, $body) for @{ $self->positionals };
        $cg->call_sub(1, scalar(@{ $self->positionals }));
    }

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

{
    package Op::StringLiteral;
    use Moose;
    extends 'Op';

    has text => (isa => 'Str', is => 'ro', required => 1);

    sub item_cg {
        my ($self, $cg, $body) = @_;
        $cg->string_lv($self->text);
    }

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

{
    package Op::Lexical;
    use Moose;
    extends 'Op';

    has name => (isa => 'Str', is => 'ro', required => 1);

    sub item_cg {
        my ($self, $cg, $body) = @_;
        my ($order, $scope) = (0, $body);
        while ($scope && !$scope->lexical->{$self->name}) {
            $scope = $scope->outer;
            $order++;
        }
        if (!$scope) {
            die "Failed to resolve lexical " . $self->name . " in " .
                $body->name;
        }
        $cg->lex_lv($order, $self->name);
    }

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

{
    package Op::CloneSub;
    use Moose;
    extends 'Op';

    has name => (isa => 'Str', is => 'ro', required => 1);

    sub void_cg {
        my ($self, $cg) = @_;
        $cg->clone_lex($self->name);
    }

    __PACKAGE__->meta->make_immutable;
    no Moose;
}
1;