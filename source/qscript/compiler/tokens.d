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
		_tkGen.addTokenType(TokenType.Whitespace, function (string str){
			foreach (index, ch; str){
				if (ch != ' ' && ch != '\t' && ch != '\n')
					return cast(uint)index;
			}
			return cast(uint)(str.length);
		});
		_tkGen.addTokenType(TokenType.Comment, function (string str){
			if (!str.length || str[0] != '#')
				return cast(uint)0;
			foreach (index, ch; str[1 .. $]){
				if (ch == '\n')
					return cast(uint)index + 1;
			}
			return cast(uint)(str.length);
		});
		_tkGen.addTokenType(TokenType.CommentMultiline, function (string str){
			if (str.length < 2 || str[0 .. 2] != "/*")
				return 0;
			for (uint i = 4; i <= str.length; i ++){
				if (str[i - 2 .. i] == "*/")
					return i;
			}
			return 0;
		});
		_tkGen.addTokenType(TokenType.LiteralInt, function (string str){
			foreach (index, ch; str){
				if (ch < '0' || ch > '9')
					return cast(uint)index;
			}
			return cast(uint)str.length;
		});
		_tkGen.addTokenType(TokenType.LiteralFloat, function (string str){
			int charsAfterDot = -1;
			foreach (index, ch; str){
				if (ch == '.' && charsAfterDot == -1){
					charsAfterDot = 0;
					continue;
				}
				if (ch < '0' || ch > '9')
					return (charsAfterDot > 0) * cast(uint)index;
				charsAfterDot += charsAfterDot != -1;
			}
			return (charsAfterDot > 0) * cast(uint)str.length;
		});
		_tkGen.addTokenType(TokenType.LiteralString, function (string str){
			if (str.length < 2 || str[0] != '"')
				return 0;
			for (uint i = 1; i < str.length; i ++){
				if (str[i] == '\\'){
					i ++;
					continue;
				}
				if (str[i] == '"')
					return i + 1;
			}
			return 0;
		});
		_tkGen.addTokenType(TokenType.LiteralChar, function (string str){
			if (str.length < 3 || str[0] != '\'')
				return 0;
			if (str[1] == '\\' && str.length > 3 && str[3] == '\'')
				return 4;
			if (str[1] != '\'' && str[2] == '\'')
				return 3;
			return 0;
		});
		_tkGen.addTokenType(TokenType.LiteralHexadecimal, function (string str){
			if (str.length < 3 || str[0] != '0' || (str[1] != 'x' && str[1] != 'X'))
				return 0;
			foreach (index, ch; str[2 .. $]){
				if ((ch < '0' || ch > '9')
					&& (ch < 'A' || ch > 'F')
					&& (ch < 'a' || ch > 'f'))
					return cast(uint)index + 2;
			}
			return cast(uint)str.length;
		});
		_tkGen.addTokenType(TokenType.LiteralBinary, function (string str){
			if (str.length < 3 || str[0] != '0' || (str[1] != 'b' && str[1] != 'B'))
				return 0;
			foreach (index, ch; str[2 .. $]){
				if (ch != '0' && ch != '1')
					return cast(uint)index + 2;
			}
			return cast(uint)str.length;
		});
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
		_tkGen.addTokenType(TokenType.Identifier, function (string str){
			uint len;
			while (len < str.length && str[len] == '_')
				len ++;
			if (len == 0 && 
				(str[len] < 'a' || str[len] > 'z') &&
				(str[len] < 'A' || str[len] > 'Z'))
				return 0;
			for (; len < str.length; len ++){
				const char ch = str[len];
				if ((ch < '0' || ch > '9') &&
					(ch < 'a' || ch > 'z') &&
					(ch < 'A' || ch > 'Z') && ch != '_')
					return len;
			}
			return cast(uint)str.length;
		});
		_tkGen.addTokenType(TokenType.Semicolon, `;`);
		_tkGen.addTokenType(TokenType.Comma, `,`);
		_tkGen.addTokenType(TokenType.OpMemberSelect, `.`);
		_tkGen.addTokenType(TokenType.OpRef, `@`);
		_tkGen.addTokenType(TokenType.OpNot, `!`);
		_tkGen.addTokenType(TokenType.OpMultiply, `*`);
		_tkGen.addTokenType(TokenType.OpDivide, `/`);
		_tkGen.addTokenType(TokenType.OpAdd, `+`);
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
		_tkGen.addTokenType(TokenType.OpBoolOr, `||`);
		_tkGen.addTokenType(TokenType.OpAssign, `=`);
		_tkGen.addTokenType(TokenType.BracketOpen, `(`);
		_tkGen.addTokenType(TokenType.BracketClose, `)`);
		_tkGen.addTokenType(TokenType.IndexOpen, `[`);
		_tkGen.addTokenType(TokenType.IndexClose, `]`);
		_tkGen.addTokenType(TokenType.CurlyOpen, `{`);
		_tkGen.addTokenType(TokenType.CurlyClose, `}`);
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
	/// Adds a token type with a match.
	/// 
	/// Returns: token type, or uint.max in case of error
	uint addToken(string match){
		static uint type = TokenType.max + 1;
		if (type == uint.max)
			return uint.max;
		_tkGen.addTokenType(type, match);
		return type ++;
	}
	/// Generates tokens from a source.
	/// Will write errors locations [line, column] to `errors`
	/// 
	/// Returns: tokens
	Token[] readTokens(string source, ref uint[2][] errors){
		Token[] r;
		errors = [];
		_tkGen.source = source;
		_tkGen.readTokens();
		r = _tkGen.tokens;
		errors = _tkGen.errors;
		return r;
	}
}
///
unittest{
	QScriptTokenGen tk = new QScriptTokenGen();
	uint[2][] errors;
	Token[] tokens = tk.readTokens(
`function void main(){ # comment
	return 2 + 0B10; #another comment
}`
		,errors);
	if (errors.length){
		foreach (error; errors)
			writeln(error);
	}else{
		foreach (token; tokens)
			writeln((cast(TokenType)token.type).to!string, " : '", token.token,"'");
	}
	assert(errors.length == 0);
	.destroy(tk);
}
