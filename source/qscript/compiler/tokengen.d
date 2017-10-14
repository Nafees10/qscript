module qscript.compiler.tokengen;

import utils.misc;
import utils.lists;
import std.conv:to;
import qscript.compiler.misc;
debug{
	import std.stdio;
}

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

	if (isInt(token)){
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
}

/// Reads script, and separates tokens
private TokenList separateTokens(string[] script){
	if (compileErrors is null){
		compileErrors = new LinkedList!CompileError;
	}
	LinkedList!string tokens = new LinkedList!string;
	uinteger[] tokenPerLine;
	tokenPerLine.length = script.length;
	// make space in lineTokenCount to store number of tokens in each line, which will be used in error-reporting
	for (uinteger lineno=0, lineCount = script.length; lineno < lineCount; lineno++){
		string line = script[lineno];
		bool prevIsIdent; /// Stores if the previous char read was present in IDENT_CHARS
		bool isIdent; /// Stores if the current char is present in IDENT_CHARS
		if (line.length > 0){
			prevIsIdent = IDENT_CHARS.hasElement(line[0]);
			isIdent = prevIsIdent;
		}
		uinteger tokenCount = tokens.count;

		for (uinteger i = 0, readFrom = 0; i < line.length; i ++){
			// end at comments
			if (line[i] == '#'){
				if (readFrom < i){
					tokens.append(line[readFrom .. i].dup);
				}
				break;
			}
			// stop at tabs, spaces, and line-endings, and comments
			if (line[i] == ' '|| line[i] == '\t' || i == line.length-1){
				// check if there is any token to be inserted
				if (readFrom < i){
					// insert this token
					tokens.append(line[readFrom .. i].dup);
					readFrom = i;
				}
				if (readFrom == i && i == line.length - 1 && ![' ', '\t'].hasElement(line[i])){
					//add this token which is at end (this condition is for one-char token at end of line)
					tokens.append(cast(string)[line[i]]);
				}
				// skip the current char for the next token
				readFrom = i + 1;
			}else
			// stop at brackets, and commas
			if (['{', '[', '(', ')', ']', '}', ','].hasElement(line[i])){
				// add the previous token first
				if (readFrom < i){
					tokens.append(line[readFrom .. i].dup);
				}
				tokens.append(cast(string)[line[i]]);
				//move readFrom to next token's position
				readFrom = i + 1;
			}else
			// stop and add if a string is seen
			if (line[i] == '"'){
				//check if there was a previous "unterminated" token before string
				if (readFrom < i){
					// :(
					tokens.append(line[readFrom .. i].dup);
				}
				// check if string has an ending
				integer strEndPos = strEnd(line, i);
				if (strEndPos == -1){
					// error
					compileErrors.append(CompileError(i + 1, "unterminated string"));
					break;
				}else{
					// everything's good-
					tokens.append(line[i .. strEndPos + 1].dup);
					// skip string
					i = strEndPos;
					// move readFrom too
					readFrom = i + 1;
				}

			}
			// finally, check if the previous char's isIdent is different from this one's, then it means they're different tokens
			isIdent = IDENT_CHARS.hasElement(line[i]);
			if (readFrom < i && prevIsIdent != isIdent){
				tokens.append(line[readFrom .. i].dup);
				// move readFrom
				readFrom = i;
			}
			prevIsIdent = isIdent;
		}
		tokenCount = tokens.count - tokenCount;
		tokenPerLine[lineno] = tokenCount;
	}

	// check if error-free
	if (compileErrors.count == 0){
		// put all tokens in a Token[] from string[]
		TokenList list;
		list.tokens.length = tokens.count;
		uinteger i = 0;
		tokens.resetRead;
		string* ptr = tokens.read;
		while (ptr !is null && i < list.tokens.length){
			list.tokens[i].token = *ptr;
			i ++;
			ptr = tokens.read;
		}
		tokens.destroy;
		// put in tokenPerLine
		list.tokenPerLine = tokenPerLine;
		return list;
	}else{
		TokenList list;
		list.tokens = null;
		return list;
	}

}
///
unittest{
	string[] expectedResults;
	expectedResults = [
		"function", "main", "{",
		"int", "(", "i", ",", "i2", ")", ";",
		"if", "(", "i", "<", "2", ")", "{", "}",
		"if", "(", "i", "<=", "2", ")", "{", "}",
		"if", "(", "i", ">=", "2", ")", "{", "}",
		"if", "(", "i", ">", "2", ")", "{", "}",
		"if", "(", "i", "==", "2", ")", "{", "}",
		"i", "=", "6", ";",
		"i2", "[", "i", "]", "=", "2", ";",
		"if", "(", "i", "[", "2", "]", "<", "2", ")", "{", "}",
		"if", "(", "i", "[", "2", "]", "<=", "2", ")", "{", "}",
		"if", "(", "i", "[", "2", "]", ">=", "2", ")", "{", "}",
		"if", "(", "i", "[", "2", "]", ">", "2", ")", "{", "}",
		"if", "(", "i", "[", "2", "]", "==", "2", ")", "{", "}",
		"}"
	];
	string[] script = [
		"function main{",
		"\tint (i, i2);",
		"\tif (i < 2){}",
		"\tif(i<=2){}",
		"\tif(i >= 2) {#comment }",
		"}",
		"if \t(i > 2)",
		"{",
		"}",
		"if ( i == 2 ) { } ",
		"i=6;",
		"i2[i]=2;",
		"if (i [ 2 ] < 2)",
		"\t{}",
		"if ( i[2]<=2){}",
		"if ( i[2]>=2){}",
		"if ( i[2]>2){}",
		"if ( i[2]==2){}",
		"}"
	];
	//make sure the expected result and actual result is same
	Token[] r = separateTokens(script).tokens;
	assert(r.length == expectedResults.length);
	foreach(i, rToken; r){
		assert(rToken.token == expectedResults[i], "toTokens result does not match expected result");
	}
}

/// Takes script, and separates into tokens (using `separateTokens`), identifies token types, retuns the Tokens with Token.Type
/// in an array
/// 
/// As a plus, it also checks if the brackets are in correct order (and properly closed)
package TokenList toTokens(string[] script){
	/// Returns true if a string has chars that only identifiers can have
	TokenList tokens = separateTokens(script);
	if (tokens.tokens == null || tokens.tokens.length == 0){
		// there's error
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
		return tokens;
	}
}