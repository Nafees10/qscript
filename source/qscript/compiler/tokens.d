module qscript.compiler.tokens;

import utils.misc;

import qscript.compiler.compiler;
import qscript.compiler.tokengen;

debug{import std.stdio;}

/// possible token types
enum TokenType : ushort{
	Comment, /// single line comment
	CommentMultiline, /// multiline comment
	LiteralInt, /// integer literal
	LiteralFloat, /// float literal
	LiteralString, /// string literal
	LiteralChar, /// char literal
	LiteralHexadecimal, /// hexadecimal literal
	LiteralBinary, /// binary literal
	KeywordImport, /// `import` keyword
	KeywordFunction, /// `function` keyword
	KeywordVar, /// `var` keyword
	KeywordEnum, /// `enum` keyword
	KeywordStruct, /// `struct` keyword
	KeywordPrivate, /// `private` keyword
	KeywordPublic, /// `public` keyword
	KeywordReturn, /// `return` keyword
	KeywordThis, /// `this` keyword
	KeywordInt, /// `int` keyword
	KeywordFloat, /// `float` keyword
	KeywordChar, /// `char` keyword
	KeywordBool, /// `bool` keyword
	KeywordTrue, /// `true` keyword
	KeywordFalse, /// `false` keyword
	KeywordIf, /// `if` keyword
	KeywordElse, /// `else` keyword
	KeywordWhile, /// `while` keyword
	KeywordDo, /// `do` keyword
	KeywordFor, /// `for` keyword
	KeywordBreak, /// `break` keyword
	KeywordContinue, /// `continue` keyword
	KeywordOther, /// any other keyword
	Identifier, /// identifier
	Semicolon, /// `;`
	Comma, /// `,`
	BinOperator, /// binary operator
	UnOperator, /// unary operator
	BracketOpen, /// `(`
	BracketClose, /// `)`
	IndexOpen, /// `[`
	IndexClose, /// `]`
	CurlyOpen, /// `{`
	CurlyClose, /// `}`
}

/// for reading tokens from a qscript source file
class QScriptTokenGen{
private:
	TokenGen _tkGen; /// the actual class used for token gen
public:
	/// constructor
	this(){
		_tkGen = new TokenGen();
	}
	~this(){
		.destroy(_tkGen);
	}
}