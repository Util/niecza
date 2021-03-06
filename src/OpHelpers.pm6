module OpHelpers;

sub mnode($M) is export {
    $M.^isa(Match) ??
        { file => $*FILE<name>, line => $M.CURSOR.lineof($M.from), pos => $M.from } !!
        { file => $*FILE<name>, line => $M.lineof($M.pos), pos => $M.pos }
}

sub node($M) is export { { line => $M.CURSOR.lineof($M.pos) } }

sub mklet($value, $body) is export {
    my $var = ::GLOBAL::NieczaActions.gensym;
    ::Op::Let.new(var => $var, to => $value,
        in => $body(::Op::LetVar.new(name => $var)));
}

sub mkcall($/, $name, *@positionals) is export {
    $/.CURSOR.mark_used($name);
    $*CURLEX<!sub>.noninlinable if $name eq '&eval'; # HACK
    ::Op::CallSub.new(|node($/),
        invocant => ::Op::Lexical.new(|node($/), :$name), :@positionals);
}

sub mklex($/, $name, *%_) is export {
    $/.CURSOR.mark_used($name);
    $*CURLEX<!sub>.noninlinable if $name eq '&eval'; # HACK
    ::Op::Lexical.new(|node($/), :$name, |%_);
}

sub mkbool($i) is export { ::Op::Lexical.new(name => $i ?? 'True' !! 'False') }

sub mktemptopic($/, $item, $expr) is export {
    mklet(mklex($/, '$_'), -> $old_ {
        ::Op::StatementList.new(|node($/), children => [
            ::Op::LexicalBind.new(:name<$_>, rhs => $item),
            mklet($expr, -> $result {
                ::Op::StatementList.new(children => [
                    ::Op::LexicalBind.new(:name<$_>, rhs => $old_),
                    $result]) }) ]) });
}
