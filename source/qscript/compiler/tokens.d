module qscript.compiler.tokens;

import utils.misc;

import qscript.compiler.compiler;
import qscript.compiler.tokengen;

debug{import std.stdio;}
version(unittest){import std.stdio, std.conv : to;}

/// possible token types
enum TokenType : uint{
	Whitespace			, /// whitespace
	Comment				, /// single line comment
	CommentMultiline	, /// multiline comment
	LiteralInt			, /// integer literal
	LiteralFloat		, /// float literal
	LiteralString		, /// string literal
	LiteralChar			, /// char literal
	LiteralHexadecimal	, /// hexadecimal literal
	LiteralBinary		, /// binary literal
	KeywordImport		, /// `import` keyword
	KeywordFunction		, /// `function` keyword
	KeywordVar			, /// `var` keyword
	KeywordEnum			, /// `enum` keyword
	KeywordStruct		, /// `struct` keyword
	KeywordPrivate		, /// `private` keyword
	KeywordPublic		, /// `public` keyword
	KeywordReturn		, /// `return` keyword
	KeywordThis			, /// `this` keyword
	KeywordVoid			, /// `void` keyword
	KeywordInt			, /// `int` keyword
	KeywordFloat		, /// `float` keyword
	KeywordChar			, /// `char` keyword
	KeywordBool			, /// `bool` keyword
	KeywordTrue			, /// `true` keyword
	KeywordFalse		, /// `false` keyword
	KeywordIf			, /// `if` keyword
	KeywordElse			, /// `else` keyword
	KeywordWhile		, /// `while` keyword
	KeywordDo			, /// `do` keyword
	KeywordFor			, /// `for` keyword
	KeywordBreak		, /// `break` keyword
	KeywordContinue		, /// `continue` keyword
	Identifier			, /// identifier
	Semicolon			, /// `;`
	Comma				, /// `,`
	OpMemberSelect		, /// `.` operator
	OpRef				, /// `@` operator
	OpNot				, /// `!` operator
	OpMultiply			, /// `*` operator
	OpDivide			, /// `/` operator
	OpAdd				, /// `+` operator
	OpSubtract			, /// `-` operator
	OpMod				, /// `%` operator
	OpConcat			, /// `~` operator
	OpIsSame			, /// `==` operator
	OpIsNotSame			, /// `!=` operator
	OpIsGreaterOrSame	, /// `>=` operator
	OpIsSmallerOrSame	, /// `<=` operator
	OpIsGreater			, /// `>` operator
	OpIsSmaller			, /// `<` operator
	OpBoolAnd			, /// `&&` operator
	OpBoolOr			, /// `||` operator
	OpAssign			, /// `=` operator
	BracketOpen			, /// `(`
	BracketClose		, /// `)`
	IndexOpen			, /// `[`
	IndexClose			, /// `]`
	CurlyOpen			, /// `{`
	CurlyClose			, /// `}`
}

/// for reading tokens from a qscript source file
class QScriptTokenGen{
private:
	TokenGen _tkGen; /// the actual class used for token gen
	/// prepares _tkGen with qscript syntax
	void _prepare(){
		_tkGen.addTokenType(TokenType.Whitespace, `[\s]+`);
		_tkGen.addTokenType(TokenType.Comment, `#.*`);
		_tkGen.addTokenType(TokenType.CommentMultiline, `\/\*[^\*\/]*\*\/`);
		_tkGen.addTokenType(TokenType.LiteralInt, `[\d]+`);
		_tkGen.addTokenType(TokenType.LiteralFloat, `[\d]+\.[\d]+`);
		_tkGen.addTokenType(TokenType.LiteralString, `"(?:[^"\\]|\\.)*"`);
		_tkGen.addTokenType(TokenType.LiteralChar, `'(?:[^"\\]|\\.)'`);
		_tkGen.addTokenType(TokenType.LiteralHexadecimal, `0[xX][\da-fA-F]+`);
		_tkGen.addTokenType(TokenType.LiteralBinary, `0[bB][01]+`);
		_tkGen.addTokenType(TokenType.KeywordImport, `import`);
		_tkGen.addTokenType(TokenType.KeywordFunction, `function`);
		_tkGen.addTokenType(TokenType.KeywordVar, `var`);
		_tkGen.addTokenType(TokenType.KeywordEnum, `enum`);
		_tkGen.addTokenType(TokenType.KeywordStruct, `struct`);
		_tkGen.addTokenType(TokenType.KeywordPrivate, `private`);
		_tkGen.addTokenType(TokenType.KeywordPublic, `public`);
		_tkGen.addTokenType(TokenType.KeywordReturn, `return`);
		_tkGen.addTokenType(TokenType.KeywordThis, `this`);
		_tkGen.addTokenType(TokenType.KeywordVoid, `void`);
		_tkGen.addTokenType(TokenType.KeywordInt, `int`);
		_tkGen.addTokenType(TokenType.KeywordFloat, `float`);
		_tkGen.addTokenType(TokenType.KeywordChar, `char`);
		_tkGen.addTokenType(TokenType.KeywordBool, `bool`);
		_tkGen.addTokenType(TokenType.KeywordTrue, `true`);
		_tkGen.addTokenType(TokenType.KeywordFalse, `false`);
		_tkGen.addTokenType(TokenType.KeywordIf, `if`);
		_tkGen.addTokenType(TokenType.KeywordElse, `else`);
		_tkGen.addTokenType(TokenType.KeywordWhile, `while`);
		_tkGen.addTokenType(TokenType.KeywordDo, `do`);
		_tkGen.addTokenType(TokenType.KeywordFor, `for`);
		_tkGen.addTokenType(TokenType.KeywordBreak, `break`);
		_tkGen.addTokenType(TokenType.KeywordContinue, `continue`);
		_tkGen.addTokenType(TokenType.Identifier, `[a-zA-Z][a-zA-Z0-9_]*`);
		_tkGen.addTokenType(TokenType.Semicolon, `;`);
		_tkGen.addTokenType(TokenType.Comma, `,`);
		_tkGen.addTokenType(TokenType.OpMemberSelect, `\.`);
		_tkGen.addTokenType(TokenType.OpRef, `@`);
		_tkGen.addTokenType(TokenType.OpNot, `!`);
		_tkGen.addTokenType(TokenType.OpMultiply, `\*`);
		_tkGen.addTokenType(TokenType.OpDivide, `\/`);
		_tkGen.addTokenType(TokenType.OpAdd, `\+`);
		_tkGen.addTokenType(TokenType.OpSubtract, `-`);
		_tkGen.addTokenType(TokenType.OpMod, `%`);
		_tkGen.addTokenType(TokenType.OpConcat, `~`);
		_tkGen.addTokenType(TokenType.OpIsSmaller, `<`);
		_tkGen.addTokenType(TokenType.OpIsGreater, `>`);
		_tkGen.addTokenType(TokenType.OpIsSmallerOrSame, `<=`);
		_tkGen.addTokenType(TokenType.OpIsGreaterOrSame, `>=`);
		_tkGen.addTokenType(TokenType.OpIsSame, `==`);
		_tkGen.addTokenType(TokenType.OpIsNotSame, `!=`);
		_tkGen.addTokenType(TokenType.OpBoolAnd, `&&`);
		_tkGen.addTokenType(TokenType.OpBoolOr, `\|\|`);
		_tkGen.addTokenType(TokenType.OpAssign, `=`);
		_tkGen.addTokenType(TokenType.BracketOpen, `\(`);
		_tkGen.addTokenType(TokenType.BracketClose, `\)`);
		_tkGen.addTokenType(TokenType.IndexOpen, `\[`);
		_tkGen.addTokenType(TokenType.IndexClose, `\]`);
		_tkGen.addTokenType(TokenType.CurlyOpen, `\{`);
		_tkGen.addTokenType(TokenType.CurlyClose, `\}`);
	}
public:
	/// constructor
	this(){
		_tkGen = new TokenGen();
		_prepare();
	}
	~this(){
		.destroy(_tkGen);
	}
	/// Generates tokens from a source.
	/// Will write errors locations [line, column] to `errors`
	/// 
	/// Returns: tokens
	Token[] readTokens(string source, ref uint[2][] errors){
		Token[] r;
		errors = [];
		_tkGen.source = source;
		_tkGen.readTokensLongest();
		r = _tkGen.tokens;
		errors = _tkGen.errors;
		return r;
	}
	/// changes regex match string for a TokeType
	void setMatch(TokenType type, string match){
		_tkGen.addTokenType(type, match);
	}
}
///
unittest{
	QScriptTokenGen tk = new QScriptTokenGen();
	uint[2][] errors;
	Token[] tokens = tk.readTokens(
`function void main(){
	return 2 + 2;
}`
		,errors);
	if (errors.length){
		foreach (error; errors)
			writeln(error);
	}else{
		foreach (token; tokens)
			writeln((cast(TokenType)token.type).to!string, " : '", token.token,"'");
	}
	.destroy(tk);
}

/// escapes a string to be used in matching with regex
private string regEscape(string s){
	char[] r;
	r = ['('];
	foreach (i, c; s){
		if (c == '\n')
			r ~= "\\n";
		else if (c == '\t')
			r ~= "\\t";
		else{
			if ("[{|*+?()^$ .\\".hasElement(c))
				r ~= '\\';
			r ~= c;
		}
	}
	r ~= ')';
	return cast(string)r;
}
/// 
unittest{
	assert(regEscape("$$\n\t\\") == `(\$\$\n\t\\)`);
}