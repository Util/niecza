# vim: ft=perl6
use Test;
use MONKEY_TYPING;

{
    my class Bt {
        has $!pie;
        method get_pie() { $!pie }
        submethod BUILD(:$x) { $!pie = $x }
    }
    is Bt.new(x => 5).get_pie, 5, "BUILD basically works";
    my class SubBT is Bt {
        has $!pie2;
        method get_pie2() { $!pie2 }
        submethod BUILD(:$y) { $!pie2 = $y }
    }
    is SubBT.new(x => 5, y => 2).get_pie, 5, "superclass' BUILD in subclass";
    is SubBT.new(x => 5, y => 2).get_pie2, 2, "subclass' BUILD in subclass";

    my @l;
    @l := [1,2,3];
    is +[@l], 3, 'binding to existing list vars works';
}

is [ 1,2,3 ... 10 ], [1..10];
is [ 1,2,4 ... 256 ], [map 2 ** *, 0..8];
is [ 1,1,*+* ...^ *>100 ], [1,1,2,3,5,8,13,21,34,55,89];

eval_lives_ok q[
    class F2855::G7136 { ... }
    class F2855::G7136 { }
], "can stub then define nested classes";

{
    my @l = gather for 1,2 { take $_ };
    is ~@l, "1 2", "gather for works";

    eval_dies_ok 'class { has $!foo; has $!foo; }',
        "double attribute declaration caught";

    eval_dies_ok 'class { method abar {}; method abar {}; }',
        "double method declaration caught";

    # <chain> isn't tested here.  It's not possible to do the same AST
    # reconstruction tricks.  However if <right> etc work, and chained
    # comparisons work, it's pretty likely to work combinationally.
    sub infix:<@a> { "a(@_.Str())" }
    sub infix:<@b> is assoc<right> { "b(@_.Str())" }
    sub infix:<@c> is assoc<list>  { "c(@_.Str())" }
    sub infix:<@d> is assoc<list>  { "d(@_.Str())" } #OK not used
    sub infix:<@e> is assoc<non>   { "e(@_.Str())" }
    sub infix:<@f> is assoc<left>  { "f(@_.Str())" }

    is (1 @a 2), 'a(1 2)', 'basic operator function';
    is (1 @a 2 @a 3), 'a(a(1 2) 3)', 'operators default to left assoc';
    is (1 @f 2 @f 3), 'f(f(1 2) 3)', 'explicit assoc<left> works too';
    is (1 @f 2 @a 3), 'a(f(1 2) 3)', 'mixed <left> at same prec works (1)';
    is (1 @a 2 @f 3), 'f(a(1 2) 3)', 'mixed <left> at same prec works (2)';
    is (1 @b 2 @b 3), 'b(1 b(2 3))', 'assoc<right> overrides';
    is (1 @c 2 @c 3), 'c(1 2 3)', 'assoc<list> takes all 3 at once';
    eval_dies_ok q[1 @c 2 @d 3], 'mixed <list> at same prec dies';
    eval_dies_ok q[1 @e 2 @e 3], '<non> dies with 3';
    is (1 @e 2), 'e(1 2)', '<non> with 2 works';

    sub infix:<@g> is tighter<@a> { "g(@_.Str())" } #OK not used
    sub infix:<@h> is looser<@a> { "h(@_.Str())" } #OK not used
    sub infix:<@i> is tighter(&infix:<@a>) { "i(@_.Str())" } #OK not used
    sub infix:<@j> is looser(&infix:<@a>) { "j(@_.Str())" } #OK not used
    sub infix:<@k> is tighter<@h> { "k(@_.Str())" } #OK not used
    sub infix:<@l> is looser<@g> { "l(@_.Str())" } #OK not used
    sub infix:<@m> is equiv<@a> { "m(@_.Str())" } #OK not used
    sub infix:<@n> is equiv(&infix:<@a>) { "n(@_.Str())" } #OK not used
    sub infix:<@o> is equiv<@g> { "o(@_.Str())" } #OK not used
    sub infix:<@p> is equiv<@h> { "p(@_.Str())" } #OK not used
    sub infix:<@q> is equiv<@b> { "q(@_.Str())" } #OK not used

    my @cmptests = (
        'a', 'g', 1, 0, 'tighter<> works',
        'h', 'a', 1, 0, 'looser<> works',
        'a', 'i', 1, 0, 'tighter<> works with code object',
        'j', 'a', 1, 0, 'looser<> works with code object',
        'h', 'k', 1, 0, 'tighter of a looser works',
        'l', 'g', 1, 0, 'looser of a tighter works',
        'k', 'a', 1, 0, 'tighter of a looser is still looser',
        'a', 'l', 1, 0, 'looser of a tighter is still tighter',
        'm', 'a', 0, 0, 'equiv works',
        'n', 'a', 0, 0, 'equiv works with code object',
        'o', 'g', 0, 0, 'equiv of tighter works',
        'p', 'h', 0, 0, 'equiv of looser works',
        'q', 'q', 1, 1, 'equiv also copies associativity',
    );
    sub ckb($res is copy) { #OK not used
        $res ~~ s:g /<.alpha>//; #::
        $res eq '((1 2) 3)' ?? 0 !! 1;
    }
    my @frags;
    for @cmptests -> $lt, $gt, $right_br_ord, $right_br_opp, $msg {
        push @frags, "is ckb(1 @$lt 2 @$gt 3), $right_br_ord, '$msg (1)';\n";
        push @frags, "is ckb(1 @$gt 2 @$lt 3), $right_br_opp, '$msg (2)';\n";
    }
    eval @frags.join;
}

{
    lives_ok { my $x; $x = Mu },
        "can assign Mu to default-typed variable (noninline)";
    lives_ok { if 1 { my $x; $x = Mu } },
        "can assign Mu to default-typed variable (inline)";
    dies_ok { my Any $x; $x = Mu },
        "cannot assign Mu to Any-typed variable (noninline)";
    dies_ok { if 1 { my Any $x; $x = Mu } },
        "cannot assign Mu to Any-typed variable (inline)";
    ok { my $x; $x }.() === Any,
        "default-typed variable receives Any (noninline)";
    ok { if 1 { my $x; $x } }.() === Any,
        "default-typed variable receives Any (inline)";

    lives_ok { my @x; push @x, Mu }, "can push Mu";
    lives_ok { my @x; push @x, 5; @x[0] = Mu }, "push creates Mu-ready vars";
    lives_ok { my @x; unshift @x, Mu }, "can unshift Mu";
    lives_ok { my @x; unshift @x, 5; @x[0] = Mu }, "unshift creates Mu-ready vars";
    lives_ok { my $x; $x[0] = Mu }, "array creation autoviv supports Mu";
    lives_ok { my @x; @x[0] = Mu }, "element creation autoviv supports Mu";
    lives_ok { my $x; $x<a> = Mu }, "hash creation autoviv supports Mu";
    lives_ok { my %x; %x<a> = Mu }, "hash element creation autoviv supports Mu";
}

# regression test from thou
{
    my $x = 'Bar';
    my $in = qq:to [A] ;
  $x  Foo
  A
    is $in.substr(0,8), 'Bar  Foo', "spaces preserved after heredoc interpolation";
}

{
    ok @*ARGS.flattens, '@*ARGS is a flatteny thing';
    ok %*ENV.flattens, '%*ENV is a flatteny thing';
    @Y8158::z := [1,2,3];
    ok @Y8158::z.flattens, 'binding to @foo::bar works';
}

# from colomon
{
    isa_ok 1 ** 2, Int, "1 squared is an Int";
    is 1 ** 2, 1, "1 squared is 1";

    isa_ok 2 ** 3, Int, "2 ** 3 is an Int";
    is 2 ** 3, 8, "2 ** 3 is 8";
    isa_ok (2/3) ** 3, Rat, "(2/3) ** 3 is a Rat";
    is (2/3) ** 3, 8 / 27, "(2/3) ** 3 is 8 / 27";
    isa_ok FatRat.new(2, 3) ** 3, FatRat, "FatRat.new(2, 3) ** 3 is a FatRat";
    is FatRat.new(2, 3) ** 3, 8 / 27, "FatRat.new(2, 3) ** 3 is 8 / 27";
    isa_ok 2.54e0 ** 3, Num, "2.54e0 ** 3 is an Num";
    is 2.54e0 ** 3, 16.387064e0, "2.54e0 ** 3 is 16.387064e0";

    isa_ok 2 ** -3, Rat, "2 ** -3 is an Rat"; # spec?
    is 2 ** -3, 1/8, "2 ** -3 is 1/8";
    isa_ok (2/3) ** -3, Rat, "(2/3) ** -3 is a Rat";
    is (2/3) ** -3, 27 / 8, "(2/3) ** -3 is 27 / 8";
    isa_ok FatRat.new(2, 3) ** -3, FatRat, "FatRat.new(2, 3) ** -3 is a FatRat";
    is FatRat.new(2, 3) ** -3, 27 / 8, "FatRat.new(2, 3) ** -3 is 27 / 8";
    isa_ok 2.54e0 ** -3, Num, "2.54e0 ** -3 is an Num";
    is_approx (2.54e0 ** -3), 0.0610237440947323, "2.54e0 ** -3 is 0.0610237440947323, more or less";

    is_approx 1i ** 2, -1, "1i ** 2 is -1"; 
    is_approx 1i ** 3, -1i, "1i ** 3 is -i"; 
    is_approx 1i ** 4, 1, "1i ** 4 is 1"; 
}

#is $?ORIG.substr(0,5), '# vim', '$?ORIG works';

# {
#     {
#         our $x = 5; #OK
#     }
#     ok $::x == 5, '$::x finds our variable';
# 
#     package Fao { our $y = 6; } #OK
#     ok $::Fao::y == 6, '$::Fao::y works as $Fao::y';
# 
#     { class Mao { } }
#     ok ::Mao.new.defined, 'can use classes via ::Mao';
# }
# 
# {
#     my $x = 7; #OK
#     ok $::x == 7, '$::x can find lexicals';
#     class A3 {
#         method moo { 42 }
#         class B4 {
#             ok ::A3.moo, '::A3 can find outer classes';
#         }
#     }
# }

done;
