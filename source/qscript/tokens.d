module qscript.tokens;

import qscript.base.tokens;

import utils.ds;

debug import std.stdio;

/// A Token
public alias Token = qscript.base.tokens.Token!TokenType;
/// Tokenizer
public alias Tokenizer = qscript.base.tokens.Tokenizer!TokenType;

/// removes whitespace tokens
void whitespaceRemove(ref Token[] tokens){
	uint i = 0, shift = 0;
	while (i + shift < tokens.length){
		auto tok = tokens[i + shift];
		if (tok.type.get!(TokenType.Whitespace) ||
				tok.type.get!(TokenType.Comment) ||
				tok.type.get!(TokenType.CommentMultiline)){
			++ shift;
			continue;
		}

		if (shift)
			tokens[i] = tok;
		++ i;
	}
	tokens.length -= shift;
}

/// possible token types
enum TokenType{
	@Match(&identifyWhitespace)							Whitespace,
	@Match(&identifyComment)								Comment,
	@Match(&identifyCommentMultiline)				CommentMultiline,
	@Match(&identifyLiteralInt)							LiteralInt,
	@Match(&identifyLiteralFloat)						LiteralFloat,
	@Match(&identifyLiteralString)					LiteralString,
	@Match(&identifyLiteralChar)						LiteralChar,
	@Match(&identifyLiteralHexadecimal)			LiteralHexadecimal,
	@Match(&identifyLiteralBinary)					LiteralBinary,
	@Match(`template`)											Template,
	@Match(`load`)													Load,
	@Match(`alias`)													Alias,
	@Match(`fn`)														Fn,
	@Match(`var`)														Var,
	@Match(`ref`)														Ref,
	@Match(`enum`)													Enum,
	@Match(`struct`)												Struct,
	@Match(`pub`)														Pub,
	@Match(`return`)												Return,
	@Match(`this`)													This,
	@Match(`auto`)													Auto,
	@Match(`int`)														Int,
	@Match(`float`)													Float,
	@Match(`char`)													Char,
	@Match(`string`)												String,
	@Match(`bool`)													Bool,
	@Match(`true`)													True,
	@Match(`false`)													False,
	@Match(`if`)														If,
	@Match(`else`)													Else,
	@Match(`while`)													While,
	@Match(`do`)														Do,
	@Match(`for`)														For,
	@Match(`break`)													Break,
	@Match(`continue`)											Continue,
	@Match(`is`)														Is,
	@Match(`!is`)														NotIs,
	@Match(`null`)													Null,
	@Match(&identifyIdentifier)							Identifier,
	@Match(`;`)															Semicolon,
	@Match(`->`)														Arrow,
	@Match(`,`)															Comma,
	@Match(`.`)															OpDot,
	@Match(`[`)															OpIndex,
	@Match(`(`)															OpFnCall,
	@Match(`++`)														OpInc,
	@Match(`--`)														OpDec,
	@Match(`!`)															OpNot,
	@Match(`*`)															OpMul,
	@Match(`/`)															OpDiv,
	@Match(`%`)															OpMod,
	@Match(`+`)															OpAdd,
	@Match(`-`)															OpSub,
	@Match(`<<`)														OpLShift,
	@Match(`>>`)														OpRShift,
	@Match(`==`)														OpEquals,
	@Match(`!=`)														OpNotEquals,
	@Match(`>=`)														OpGreaterEquals,
	@Match(`<=`)														OpLesserEquals,
	@Match(`>`)															OpGreater,
	@Match(`<`)															OpLesser,
	@Match(`is`)														OpIs,
	@Match(`!is`)														OpNotIs,
	@Match(`&`)															OpBinAnd,
	@Match(`|`)															OpBinOr,
	@Match(`^`)															OpBinXor,
	@Match(`&&`)														OpBoolAnd,
	@Match(`||`)														OpBoolOr,
	@Match(`=`)															OpAssign,
	@Match(`+=`)														OpAddAssign,
	@Match(`-=`)														OpSubAssign,
	@Match(`*=`)														OpMulAssign,
	@Match(`/=`)														OpDivAssign,
	@Match(`%=`)														OpModAssign,
	@Match(`&=`)														OpBinAndAssign,
	@Match(`|=`)														OpBinOrAssign,
	@Match(`^=`)														OpBinXorAssign,
	@Match(`(`)															BracketOpen,
	@Match(`)`)															BracketClose,
	@Match(`[`)															IndexOpen,
	@Match(`]`)															IndexClose,
	@Match(`{`)															CurlyOpen,
	@Match(`}`)															CurlyClose,
	@Match(&identifyTrait)									Trait,
	@Match(`$if`)														StaticIf,
	@Match(`$for`)													StaticFor,
	@Match(`$fn`)														TemplateFn,
	@Match(`$struct`)												TemplateStruct,
	@Match(`$enum`)													TemplateEnum,
	@Match(`$var`)													TemplateVar,
	@Match(`$alias`)												TemplateAlias
}

private uint identifyWhitespace(string str){
	foreach (index, ch; str){
		if (ch != ' ' && ch != '\t' && ch != '\n')
			return cast(uint)index;
	}
	return cast(uint)(str.length);
}

private uint identifyComment(string str){
	if ((!str.length || str[0] != '#') &&
			(str.length < 2 || str[0 .. 2] != "//"))
		return cast(uint)0;
	foreach (index, ch; str[1 .. $]){
		if (ch == '\n')
			return cast(uint)index + 1;
	}
	return cast(uint)(str.length);
}

private uint identifyCommentMultiline(string str){
	if (str.length < 2 || str[0 .. 2] != "/*")
		return 0;
	for (uint i = 4; i <= str.length; i ++){
		if (str[i - 2 .. i] == "*/")
			return i;
	}
	return 0;
}

private uint identifyLiteralInt(string str){
		foreach (index, ch; str){
		if (ch < '0' || ch > '9')
		return cast(uint)index;
		}
		return cast(uint)str.length;
		}

private uint identifyLiteralFloat(string str){
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
}

private uint identifyLiteralString(string str){
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
}

private uint identifyLiteralChar(string str){
	if (str.length < 3 || str[0] != '\'')
		return 0;
	if (str[1] == '\\' && str.length > 3 && str[3] == '\'')
		return 4;
	if (str[1] != '\'' && str[2] == '\'')
		return 3;
	return 0;
}

private uint identifyLiteralHexadecimal(string str){
	if (str.length < 3 || str[0] != '0' || (str[1] != 'x' && str[1] != 'X'))
		return 0;
	foreach (index, ch; str[2 .. $]){
		if ((ch < '0' || ch > '9')
				&& (ch < 'A' || ch > 'F')
				&& (ch < 'a' || ch > 'f'))
			return cast(uint)index + 2;
	}
	return cast(uint)str.length;
}

private uint identifyLiteralBinary(string str){
	if (str.length < 3 || str[0] != '0' || (str[1] != 'b' && str[1] != 'B'))
		return 0;
	foreach (index, ch; str[2 .. $]){
		if (ch != '0' && ch != '1')
			return cast(uint)index + 2;
	}
	return cast(uint)str.length;
}

private uint identifyIdentifier(string str){
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
}

private uint identifyTrait(string str){
	if (str.length < 2 || str[0] != '$')
		return 0;
	const  uint len = identifyIdentifier(str[1 .. $]);
	if (!len)
		return 0;
	return 1 + len;
}

unittest{
	import std.conv : to;

	string source =
`fn main(){ # comment
return 2 + 0B10; #another comment
voidNot
}`;
	Token[] tokens;
	auto tokenizer = Tokenizer(source, Flags!TokenType());

	foreach (token; tokenizer)
		tokens ~= token;

	const string[] expectedStr = [
		"fn", " ", "main", "(", ")", "{", " ", "# comment",
		"\n", "return", " ", "2", " ",  "+", " ", "0B10", ";", " ",
		"#another comment", "\n", "voidNot", "\n", "}"
	];
	const TokenType[] expectedType = [
		TokenType.Fn, TokenType.Whitespace,
		TokenType.Identifier, TokenType.BracketOpen,
		TokenType.BracketClose, TokenType.CurlyOpen, TokenType.Whitespace,
		TokenType.Comment, TokenType.Whitespace, TokenType.Return,
		TokenType.Whitespace, TokenType.LiteralInt, TokenType.Whitespace,
		TokenType.OpAdd, TokenType.Whitespace, TokenType.LiteralBinary,
		TokenType.Semicolon, TokenType.Whitespace, TokenType.Comment,
		TokenType.Whitespace, TokenType.Identifier, TokenType.Whitespace,
		TokenType.CurlyClose
	];
	foreach (i, token; tokens){
		assert (token.token == expectedStr[i] && token.type[expectedType[i]],
				"failed to match at index " ~ i.to!string);
	}
}
