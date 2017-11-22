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
		return OPERATORS.hasElement(s);
	}
	/// Returns true if string contains an integer
	bool isInt(string s){
		// make sure it's at least a number
		if (isNum(s)){
			foreach (digit; s){
				if (digit == '.'){
					return false;
				}
			}
			return true;
		}
		return false;
	}
	/// Returns true if a string contains a double
	/// 
	/// to be identified as a double, the number must have a decimal point in it
	bool isDouble(string s){
		if (isNum(s)){
			foreach (digit; s){
				if (digit == '.'){
					return true;
				}
			}
			return false;
		}
		return false;
	}

	if (token == "="){
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
		throw new Exception("unidentified token type");
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
	assert("string".getTokenType == Token.Type.DataType);
	assert("function".getTokenType == Token.Type.Keyword);
	assert("if".getTokenType == Token.Type.Keyword);
	assert("while".getTokenType == Token.Type.Keyword);
	assert("else".getTokenType == Token.Type.Keyword);
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
	enum CharType{
		Bracket, /// any bracket
		Operator, /// any char that can be a part of a operator
		Semicolon, /// semicolon
		Comma, /// a comma
		Ident /// including the ones for keywords
	}
	static CharType getCharType(char c){
		if (c == ';'){
			return CharType.Semicolon;
		}
		if (c == ','){
			return CharType.Comma;
		}
		if (['(','[','{','}',']',')'].hasElement(c)){
			return CharType.Bracket;
		}
		if (isAlphabet(cast(string)[c]) || isNum(cast(string)[c])){
			return CharType.Ident;
		}
		foreach (operator; OPERATORS){
			foreach (opChar; operator){
				if (c == opChar){
					return CharType.Operator;
				}
			}
		}
		throw new Exception ("unexpected char, '"~c~'\'');
	}
	LinkedList!string tokens = new LinkedList!string;
	uinteger[] tokenPerLine;
	tokenPerLine.length = script.length;
	uinteger tokenCount = 0;
	foreach (lineno, line; script){
		CharType prevType = CharType.Ident, currentType = CharType.Ident;
		for (uinteger i = 0, readFrom = 0, lastInd = line.length-1; i < line.length; i ++){
			// skip strings
			if (line[i] == '"'){
				if (readFrom != i){
					compileErrors.append (CompileError(lineno, "unexpected string"));
				}
				integer end = line.strEnd(i);
				if (end == -1){
					compileErrors.append(CompileError(lineno, "string not closed"));
					break;
				}
				i = end;
				continue;
			}
			// break at comments
			if (line[i] == '#' || line[i] == ' ' || line[i] == '\t'){
				// add a token if remaining
				if (readFrom < i){
					tokens.append (line[readFrom .. i]);
				}
				readFrom = i+1;
				if (line[i] == '#'){
					break;
				}
				continue;
			}
			// add other types of tokens
			try{
				currentType = getCharType(line[i]);
			}catch (Exception e){
				compileErrors.append (CompileError(lineno, e.msg));
				.destroy (e);
				break;
			}
			if (currentType != prevType || currentType == CharType.Bracket || currentType == CharType.Semicolon ||
				currentType == CharType.Comma){
				if (readFrom < i){
					tokens.append (line[readFrom .. i]);
					readFrom = i;
				}
				if (currentType == CharType.Bracket || currentType == CharType.Semicolon || currentType == CharType.Comma){
					tokens.append (cast(string)[line[i]]);
					readFrom = i+1;
				}
			}
			prevType = currentType;
			// add if is at end of line
			if (i == lastInd && readFrom <= i){
				tokens.append (line[readFrom .. i+1]);
			}
		}
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