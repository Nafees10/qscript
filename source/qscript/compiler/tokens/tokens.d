module qscript.compiler.tokens.tokens;

import qscript.compiler.tokens.tokengen;

debug import std.stdio;

/// A Token
public alias Token = qscript.compiler.tokens.tokengen.Token!TokenType;

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
	@Match(`template`)											KeywordTemplate,
	@Match(`load`)													KeywordLoad,
	@Match(`alias`)													KeywordAlias,
	@Match(`fn`)														KeywordFn,
	@Match(`var`)														KeywordVar,
	@Match(`ref`)														KeywordRef,
	@Match(`enum`)													KeywordEnum,
	@Match(`struct`)												KeywordStruct,
	@Match(`pub`)														KeywordPub,
	@Match(`return`)												KeywordReturn,
	@Match(`this`)													KeywordThis,
	@Match(`auto`)													KeywordAuto,
	@Match(`int`)														KeywordInt,
	@Match(`float`)													KeywordFloat,
	@Match(`char`)													KeywordChar,
	@Match(`string`)												KeywordString,
	@Match(`bool`)													KeywordBool,
	@Match(`true`)													KeywordTrue,
	@Match(`false`)													KeywordFalse,
	@Match(`if`)														KeywordIf,
	@Match(`else`)													KeywordElse,
	@Match(`while`)													KeywordWhile,
	@Match(`do`)														KeywordDo,
	@Match(`for`)														KeywordForeach,
	@Match(`break`)													KeywordBreak,
	@Match(`continue`)											KeywordContinue,
	@Match(`is`)														KeywordIs,
	@Match(`!is`)														KeywordNotIs,
	@Match(&identifyIdentifier)							Identifier,
	@Match(`;`)															Semicolon,
	@Match(`->`)														Arrow,
	@Match(`,`)															Comma,
	@Match(`.`)															OperatorDot,
	@Match(`[`)															OperatorIndex,
	@Match(`(`)															OperatorFnCall,
	@Match(`++`)														OperatorInc,
	@Match(`--`)														OperatorDec,
	@Match(`!`)															OperatorNot,
	@Match(`*`)															OperatorMul,
	@Match(`/`)															OperatorDiv,
	@Match(`%`)															OperatorMod,
	@Match(`+`)															OperatorAdd,
	@Match(`-`)															OperatorSub,
	@Match(`~`)															OperatorCat,
	@Match(`<<`)														OperatorLShift,
	@Match(`>>`)														OperatorRShift,
	@Match(`==`)														OperatorEquals,
	@Match(`!=`)														OperatorNotEquals,
	@Match(`>=`)														OperatorGreaterEquals,
	@Match(`<=`)														OperatorSmallerEquals,
	@Match(`>`)															OperatorGreater,
	@Match(`<`)															OperatorSmaller,
	@Match(`is`)														OperatorIs,
	@Match(`!is`)														OperatorNotIs,
	@Match(`&`)															OperatorBinAnd,
	@Match(`|`)															OperatorBinOr,
	@Match(`^`)															OperatorBinXor,
	@Match(`&&`)														OperatorBoolAnd,
	@Match(`||`)														OperatorBoolOr,
	@Match(`=`)															OperatorAssign,
	@Match(`+=`)														OperatorAddAssign,
	@Match(`-=`)														OperatorSubAssign,
	@Match(`*`)															OperatorMulAssign,
	@Match(`/=`)														OperatorDivAssign,
	@Match(`%=`)														OperatorModAssign,
	@Match(`~=`)														OperatorCatAssign,
	@Match(`&=`)														OperatorBinAndAssign,
	@Match(`|=`)														OperatorBinOrAssign,
	@Match(`^=`)														OperatorBinXorAssign,
	@Match(`(`)															BracketOpen,
	@Match(`)`)															BracketClose,
	@Match(`[`)															IndexOpen,
	@Match(`]`)															IndexClose,
	@Match(`{`)															CurlyOpen,
	@Match(`}`)															CurlyClose,
	@Match(&identifyTrait)									Trait,
	@Match(`$if`)														StaticIf,
	@Match(`$for`)													StaticForeach,
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
	auto tokenizer = new Tokenizer!TokenType(source);

	while (!tokenizer.end)
		tokens ~= tokenizer.next;

	const string[] expectedStr = [
		"fn", " ", "main", "(", ")", "{", " ", "# comment",
		"\n", "return", " ", "2", " ",  "+", " ", "0B10", ";", " ",
		"#another comment", "\n", "voidNot", "\n", "}"
	];
	const TokenType[] expectedType = [
		TokenType.KeywordFn, TokenType.Whitespace,
		TokenType.Identifier, TokenType.BracketOpen,
		TokenType.BracketClose, TokenType.CurlyOpen, TokenType.Whitespace,
		TokenType.Comment, TokenType.Whitespace, TokenType.KeywordReturn,
		TokenType.Whitespace, TokenType.LiteralInt, TokenType.Whitespace,
		TokenType.OperatorAdd, TokenType.Whitespace, TokenType.LiteralBinary,
		TokenType.Semicolon, TokenType.Whitespace, TokenType.Comment,
		TokenType.Whitespace, TokenType.Identifier, TokenType.Whitespace,
		TokenType.CurlyClose
	];
	foreach (i, token; tokens){
		assert (token.token == expectedStr[i] && token.type[expectedType[i]],
				"failed to match at index " ~ i.to!string);
	}
}
