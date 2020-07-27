/++
For reading a script into tokens
+/
module qscript.compiler.tokengen;

import utils.misc;
import utils.lists;
import std.conv:to;
import qscript.compiler.misc;

/// stores errors for tokengen
private LinkedList!CompileError compileErrors;

/// Attempts to identify a token type by the token (string).
/// returns token type, if fails, throws exception
private Token.Type getTokenType(string token){
	/// Returns true if a string is a keyword
	bool isKeyword(string s){
		return KEYWORDS.hasElement(s);
	}
	/// Returns true if a string is an identifier
	bool isIdentifier(string s){
		// token that qualifies as a number can qualify as an identifier, but not vice versa, so this if statement
		if (!token.isNum && !isKeyword(token)){
			return (cast(char[])s).matchElements(cast(char[])IDENT_CHARS);
		}else{
			return false;
		}
	}
	/// Returns true is a string is an operator
	bool isOperator(string s){
		return OPERATORS.hasElement(s) || SOPERATORS.hasElement(s);
	}
	/// Returns true if string contains an integer
	bool isInt(string s){
		return isNum(s, false);
	}
	/// Returns true if a string contains a double
	/// 
	/// to be identified as a double, the number must have a decimal point in it
	bool isDouble(string s){
		return isNum(s, true);
	}
	if (token == "."){
		return Token.Type.MemberSelector;
	}else if (token == "="){
		return Token.Type.AssignmentOperator;
	}else if (isInt(token)){
		return Token.Type.Integer;
	}else if (isDouble(token)){
		return Token.Type.Double;
	}else if (DATA_TYPES.hasElement(token)){
		return Token.Type.DataType;
	}else if (isKeyword(token)){
		return Token.Type.Keyword;
	}else if (isIdentifier(token)){
		return Token.Type.Identifier;
	}else if (isOperator(token)){
		return Token.Type.Operator;
	}else if (token[0] == '"'){
		return Token.Type.String;
	}else if (token[0] == '\''){
		if (token.length < 3)
			throw new Exception("no character provided inside ''");
		if (decodeString(token[1 .. $-1]).length > 1)
			throw new Exception("'' can only hold 1 character");
		return Token.Type.Char;
	}else if (token == ";"){
		return Token.Type.StatementEnd;
	}else if (token == ","){
		return Token.Type.Comma;
	}else if (token == "("){
		return Token.Type.ParanthesesOpen;
	}else if (token == ")"){
		return Token.Type.ParanthesesClose;
	}else if (token == "["){
		return Token.Type.IndexBracketOpen;
	}else if (token == "]"){
		return Token.Type.IndexBracketClose;
	}else if (token == "{"){
		return Token.Type.BlockStart;
	}else if (token == "}"){
		return Token.Type.BlockEnd;
	}else{
		throw new Exception("unidentified token type '"~token~'\'');
	}
}
///
unittest{
	assert("thisIsAVar_1234".getTokenType == Token.Type.Identifier);
	assert("24.5".getTokenType == Token.Type.Double);
	assert("245".getTokenType == Token.Type.Integer);
	assert("\"This is a string\"".getTokenType == Token.Type.String);
	assert("==".getTokenType == Token.Type.Operator);
	assert(";".getTokenType == Token.Type.StatementEnd);
	assert(",".getTokenType == Token.Type.Comma);
	assert("int".getTokenType == Token.Type.DataType);
	assert("double".getTokenType == Token.Type.DataType);
	assert("char".getTokenType == Token.Type.DataType);
	assert("function".getTokenType == Token.Type.Keyword);
	assert("if".getTokenType == Token.Type.Keyword);
	assert("while".getTokenType == Token.Type.Keyword);
	assert("else".getTokenType == Token.Type.Keyword);
	assert(".".getTokenType == Token.Type.MemberSelector);
	assert("\'p\'".getTokenType == Token.Type.Char);
}

/// returns Token[] with type identified based on string[] input
package Token[] stringToTokens(string[] s){
	Token[] r;
	r.length = s.length;
	foreach (i, token; s){
		r[i].type = getTokenType(s[i]);
		r[i].token = s[i].dup;
	}
	return r;
}

/// Reads script, and separates tokens
private TokenList separateTokens(string[] script){
	static bool isDifferent(char c, ref char[] token){
		static const SEPERATORS = ['(','[','{','}',']',')', ';', ','];
		static const WHITESPACE = [' ', '\t'];
		static char[] lastToken = []; /// stores last complete token, used to check if `-` or `.` is to be considered operator or part of number
		static char pendingTokenChar = 0; /// as the name says...
		if (pendingTokenChar != 0){
			token = [pendingTokenChar];
			pendingTokenChar = 0;
			if (SEPERATORS.hasElement(token[0])){
				if (!WHITESPACE.hasElement(c))
					pendingTokenChar = c;
				lastToken = token.dup;
				return true;
			}
		}
		if (WHITESPACE.hasElement(c)){
			if (token.length > 0){
				lastToken = token.dup;
				return true;
			}
			return false;
		}
		if (SEPERATORS.hasElement(c)){
			if (token.length == 0){
				token = [c];
				lastToken = token.dup;
				return true;
			}
			pendingTokenChar = c;
			lastToken = token.dup;
			return true;
		}
		if (token.length > 0){
			// strings
			if (token[0] == '\"' || token[0] == '\''){
				token = token ~ c;
				if (c == token[0] && token[$-1] != '\\'){
					lastToken = token.dup;
					return true;
				}
			}
			// unexpected strings get read as separate tokens
			if ((c == '\"' || c == '\'') && token[0] != c){
				pendingTokenChar = c;
				lastToken = token.dup;
				return true;
			}
			// space
			if (c == ' ' || c == '\t'){
				lastToken = token.dup;
				return true;
			}
			// - is operator or part of number
			if (token[0] == '-' && isNum([c],false) && !(lastToken.matchElements(cast(char[])IDENT_CHARS))){
				token = token ~ c;
				// go on
				return false;
			}
			// . is memberSelector or decimal place
			if (c == '.' && !isNum(cast(string)token, false)){
				lastToken = token;
				pendingTokenChar = c;
				return true;
			}
			// token is operator
			if (OPERATORS.hasElement(cast(string)token) || SOPERATORS.hasElement(cast(string)token)){
				// see if it's still operator after adding c
				if (OPERATORS.hasElement(cast(string)(token ~ c)) || SOPERATORS.hasElement(cast(string)(token ~ c))){
					// go on
					return false;
				}else{
					pendingTokenChar = c;
					lastToken = token.dup;
					return true;
				}
			}else if ((OPERATORS.hasElement(cast(string)[c]) || SOPERATORS.hasElement(cast(string)[c])) && !isNum(cast(string)(token~c))){
				// token not operator, c is operator
				pendingTokenChar = c;
				lastToken = token.dup;
				return true;
			}
		}
		// nothing else matches, just add it to end
		token = token ~ c;
		return false;
	}
	LinkedList!string tokens = new LinkedList!string;
	uinteger[] tokenPerLine;
	tokenPerLine.length = script.length;
	uinteger tokenCount = 0;
	foreach (lineno, line; script){
		integer stringEndIndex = -1;
		char[] token = [];
		for (uinteger i = 0; i < line.length; i ++){
			// skip strings
			if ((line[i] == '"' || line[i] == '\'') && i > stringEndIndex){
				stringEndIndex = line.strEnd(i);
				if (stringEndIndex == -1){
					compileErrors.append(CompileError(lineno, "string not closed"));
					break;
				}
			}
			// break at comments
			if (line[i] == '#' && cast(integer)i > stringEndIndex){
				isDifferent(' ', token);
				// add pending token
				if (token.length){
					tokens.append(cast(string)token.dup);
					token = [];
				}
				break;
			}
			// hand this line[i] to isDifferent
			if (isDifferent(line[i], token)){
				tokens.append(cast(string)token.dup);
				token = [];
			}
		}
		isDifferent(' ', token);
		if (token.length)
			tokens.append(cast(string)token.dup);
		tokenPerLine[lineno] = tokens.count - tokenCount;
		tokenCount += tokenPerLine[lineno];
	}
	// put them all in TokenList
	TokenList r;
	r.tokenPerLine = tokenPerLine; // no need to dup it
	r.tokens = stringToTokens(tokens.toArray);
	.destroy (tokens);
	return r;
}
///
unittest{
	string[] script = [
		"function void main{",
		"\tint i = 5;",
		"\t.5sdfdf = (!5 - 5);",
		"\ta.b.c = @a;",
		"\ta = 5.5;",
		" a = -20+5;",
		" a=-20+5;",
	];
	Token[] tokens = separateTokens(script).tokens;
	string[] strTokens;
	strTokens.length = tokens.length;
	foreach (i, tok; tokens){
		strTokens[i] = tok.token;
	}
	/*import std.stdio;
	foreach(token; strTokens)
		writeln(token);*/
	assert (strTokens == [
			"function", "void", "main", "{",
			"int", "i", "=", "5", ";",
			".", "5sdfdf", "=", "(", "!", "5", "-", "5", ")", ";",
			"a", ".", "b", ".", "c", "=", "@", "a", ";",
			"a", "=", "5.5", ";",
			"a", "=", "-20", "+", "5", ";",
			"a", "=", "-20", "+", "5", ";",
		]);
}
/// Takes script, and separates into tokens (using `separateTokens`), identifies token types, retuns the Tokens with Token.Type
/// in an array
/// 
/// `script` is the script to convert to tokens, each line is a separate string, without ending \n
/// `errors` is the array to which erors will be put
/// 
/// As a plus, it also checks if the brackets are in correct order (and properly closed)
package TokenList toTokens(string[] script, ref CompileError[] errors){
	compileErrors = new LinkedList!CompileError;
	/// Returns true if a string has chars that only identifiers can have
	TokenList tokens = separateTokens(script);
	if (tokens.tokens == null || tokens.tokens.length == 0){
		// there's error
		errors = compileErrors.toArray;
		.destroy(compileErrors);
		return tokens;
	}else{
		// continue with identiying tokens
		// fill in tokens with tokenStrings' strings, and identify their type
		foreach(i, token; tokens.tokens){
			try{
				tokens.tokens[i].type = getTokenType(token.token);
			}catch(Exception e){
				compileErrors.append(CompileError(tokens.getTokenLine(i), e.msg));
			}
		}
		// now check brackets
		tokens.checkBrackets(compileErrors);
		if (compileErrors.count > 0){
			errors = compileErrors.toArray;
		}
		.destroy(compileErrors);
		return tokens;
	}
}
