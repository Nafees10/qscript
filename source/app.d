module app;

import std.stdio;

import qscript.base.ast;
import qscript.base.tokens;

enum TokenType{
	@((string str) => str.length && str[0] >= 'a' && str[0] <= 'z') Var,
	@(`*`) Mul,
	@(`/`) Div,
	@(`+`) Add,
	@(`-`) Sub,
	@(`->`) Arrow,
}

enum MatchType{
	@(`Var`) @(`/ExpressionP0`) @(`/ExpressionP0 -Mul /ExpressionP0`)
		ExpressionP0,

	@(`/ExpressionP0`) @(`/ExpressionP1 -Add /ExpressionP1`)
		ExpressionP1,

	@(`/ExpressionP1`)
		Expression,

	@(`Var -Arrow /Expression`)
		Function
}

alias Tokenizer = qscript.base.tokens.Tokenizer!TokenType;
alias Token = qscript.base.tokens.Token!TokenType;

version(unittest){}else
void main(){
	Tokenizer tokMaker = new Tokenizer(`x->x+y/x`);
	Token[] tokens;
	while (!tokMaker.end)
		tokens ~= tokMaker.next;

	foreach (token; tokens)
		writeln(token);
}
