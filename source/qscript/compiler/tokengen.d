/++
For reading a script into tokens
+/
module qscript.compiler.tokengen;

import utils.misc;
import utils.lists;
import std.conv:to;
import qscript.compiler.compiler;

/// Each token is stored as a `Token` with the type and the actual token
package struct Token{
	/// Specifies type of token
	/// 
	/// used only in `compiler.tokengen`
	enum Type{
		String,/// That the token is: `"SOME STRING"`
		Char, /// That the token is: `'C'` # Some character
		Integer,/// That the token an int (or uint, or ubyte)
		Double, /// That the token is a double (floating point) value
		Bool, /// a true or false value
		Identifier,/// That the token is an identifier. i.e token is a variable name or a function name.  For a token to be marked as Identifier, it doesn't need to be defined in `new()`
		DataType, /// the  token is a data type
		MemberSelector, /// a member selector operator
		AssignmentOperator, /// and assignmentOperator
		Operator,/// That the token is an operator, like `+`, `==` etc
		Keyword,/// A `function` or `var` ...
		Comma,/// That its a comma: `,`
		StatementEnd,/// A semicolon
		ParanthesesOpen,/// `(`
		ParanthesesClose,/// `)`
		IndexBracketOpen,/// `[`
		IndexBracketClose,///`]`
		BlockStart,///`{`
		BlockEnd,///`}`
	}
	Type type;/// type of token
	string token;/// token
	this(Type tType, string tToken){
		type = tType;
		token = tToken;
	}
	/// Identifies token type itself
	/// 
	/// Throws: Exception if token invalid
	this(string tToken){
		token = tToken;
		type = getTokenType(token);
	}
}

/// To store Tokens with Types where the line number of each token is required
package struct TokenList{
	Token[] tokens; /// Stores the tokens
	uinteger[] tokenPerLine; /// Stores the number of tokens in each line
	/// Returns the line number a token is in by usin the index of the token in `tokens`
	/// 
	/// The returned value is the line-number, not index, it starts from 1, not zero
	uinteger getTokenLine(uinteger tokenIndex){
		uinteger i = 0, chars = 0;
		tokenIndex ++;
		for (; chars < tokenIndex && i < tokenPerLine.length; i ++){
			chars += tokenPerLine[i];
		}
		return i;
	}
	/// reads tokens into a string
	static string toString(Token[] t){
		char[] r;
		// set length
		uinteger length = 0;
		for (uinteger i = 0; i < t.length; i ++){
			length += t[i].token.length;
		}
		r.length = length;
		// read em all into r;
		for (uinteger i = 0, writeTo = 0; i < t.length; i ++){
			r[writeTo .. writeTo + t[i].token.length] = t[i].token;
			writeTo += t[i].token.length;
		}
		return cast(string)r;
	}
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
	}else if (token == "true" || token == "false"){
		return Token.Type.Bool;
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
	assert("null".getTokenType == Token.Type.Keyword);
	assert("true".getTokenType == Token.Type.Bool);
	assert("false".getTokenType == Token.Type.Bool);
}

/// returns Token[] with type identified based on string[] input
private Token[] stringToTokens(string[] s, bool detectType = true){
	Token[] r;
	r.length = s.length;
	foreach (i, token; s){
		if (detectType)
			r[i].type = getTokenType(s[i]);
		r[i].token = s[i].dup;
	}
	return r;
}

/// Reads script, and separates tokens
private TokenList separateTokens(string[] script, LinkedList!CompileError compileErrors){
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
			if (token[0] == '"' || token[0] == '\''){
				token = token ~ c;
				if (c == token[0] && token[$-1] != '\\'){
					lastToken = token.dup;
					return true;
				}
				return false;
			}
			// unexpected strings get read as separate tokens
			if ((c == '"' || c == '\'') && token[0] != c){
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
					token = token ~ c;
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
	r.tokens = stringToTokens(tokens.toArray, false);
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
		" a == -b;",
		"a <= b;",
		"a > b",
	];
	LinkedList!CompileError err = new LinkedList!CompileError;
	Token[] tokens = separateTokens(script, err).tokens;
	.destroy (err);
	string[] strTokens;
	strTokens.length = tokens.length;
	foreach (i, tok; tokens){
		strTokens[i] = tok.token;
	}
	/*import std.stdio : writeln;
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
			"a", "==", "-", "b", ";",
			"a", "<=", "b", ";",
			"a", ">", "b"
		]);
}

/// Returns the index of the quotation mark that ends a string
/// 
/// Returns -1 if not found
private integer strEnd(string s, uinteger i){
	const char end = s[i] == '\'' ? '\'' : '\"';
	for (i++;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			continue;
		}else if (s[i]==end){
			break;
		}
	}
	if (i==s.length){i=-1;}
	return i;
}

private alias decodeString = strReplaceSpecial;

/// decodes a string. i.e, converts \t to tab, \" to ", etc
/// The string must not be surrounded by quoation marks
/// 
/// Returns: string with special characters replaced with their actual characters (i.e, \t replaced with tab, \n with newline...)
private string strReplaceSpecial(char specialCharBegin='\\', char[char] map = ['t' : '\t', 'n' : '\n','\\':'\\'])
(string s){
	char[] r = [];
	for (uinteger i = 0; i < s.length; i ++){
		if (s[i] == specialCharBegin && i + 1 < s.length && s[i+1] in map){
			r ~= map[s[i+1]];
			i++;
			continue;
		}
		r ~= s[i];
	}
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
	LinkedList!CompileError compileErrors = new LinkedList!CompileError;
	/// Returns true if a string has chars that only identifiers can have
	TokenList tokens = separateTokens(script, compileErrors);
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


/// Checks if the brackets in a tokenlist are in correct order, and are closed
/// 
/// In case not, returns false, and appends error to `errorLog`
private bool checkBrackets(TokenList tokens, LinkedList!CompileError errors){
	enum BracketType{
		Round,
		Square,
		Block
	}
	BracketType[Token.Type] brackOpenIdent = [
		Token.Type.ParanthesesOpen: BracketType.Round,
		Token.Type.IndexBracketOpen: BracketType.Square,
		Token.Type.BlockStart: BracketType.Block
	];
	BracketType[Token.Type] brackCloseIdent = [
		Token.Type.ParanthesesClose: BracketType.Round,
		Token.Type.IndexBracketClose: BracketType.Square,
		Token.Type.BlockEnd:BracketType.Block
	];
	Stack!BracketType bracks = new Stack!BracketType;
	Stack!uinteger bracksStartIndex = new Stack!uinteger;
	BracketType curType;
	bool r = true;
	for (uinteger lastInd = tokens.tokens.length-1, i = 0; i<=lastInd; i++){
		if (tokens.tokens[i].type in brackOpenIdent){
			bracks.push(brackOpenIdent[tokens.tokens[i].type]);
			bracksStartIndex.push(i);
		}else if (tokens.tokens[i].type in brackCloseIdent){
			bracksStartIndex.pop();
			if (bracks.pop != brackCloseIdent[tokens.tokens[i].type]){
				errors.append(CompileError(tokens.getTokenLine(i),
						"brackets order is wrong; first opened must be last closed"));
				r = false;
				break;
			}
		}else if (i == lastInd && bracks.count > 0){
			// no bracket ending
			i = -2;
			errors.append(CompileError(tokens.getTokenLine(bracksStartIndex.pop), "bracket not closed"));
			r = false;
			break;
		}
	}

	.destroy(bracks);
	.destroy(bracksStartIndex);
	return r;
}

/// Returns index of closing/openinig bracket of the provided bracket  
/// 
/// `forward` if true, then the search is in forward direction, i.e, the closing bracket is searched for
/// `tokens` is the array of tokens to search in
/// `index` is the index of the opposite bracket
/// 
/// It only works correctly if the brackets are in correct order, and the closing bracket is present  
/// so, before calling this, `compiler.misc.checkBrackets` should be called
package uinteger tokenBracketPos(bool forward=true)(Token[] tokens, uinteger index){
	Token.Type[] closingBrackets = [
		Token.Type.BlockEnd,
		Token.Type.IndexBracketClose,
		Token.Type.ParanthesesClose
	];
	Token.Type[] openingBrackets = [
		Token.Type.BlockStart,
		Token.Type.IndexBracketOpen,
		Token.Type.ParanthesesOpen
	];
	uinteger count; // stores how many closing/opening brackets before we reach the desired one
	uinteger i = index;
	for (uinteger lastInd = (forward ? tokens.length : 0); i != lastInd; (forward ? i ++: i --)){
		if ((forward ? openingBrackets : closingBrackets).hasElement(tokens[i].type)){
			count ++;
		}else if ((forward ? closingBrackets : openingBrackets).hasElement(tokens[i].type)){
			count --;
		}
		if (count == 0){
			break;
		}
	}
	return i;
}
///
unittest{
	Token[] tokens;
	tokens = [
		Token(Token.Type.Comma, ","), Token(Token.Type.BlockStart,"{"), Token(Token.Type.Comma,","),
		Token(Token.Type.IndexBracketOpen,"["),Token(Token.Type.IndexBracketClose,"]"),Token(Token.Type.BlockEnd,"}")
	];
	assert(tokens.tokenBracketPos!true(1) == 5);
	assert(tokens.tokenBracketPos!false(5) == 1);
	assert(tokens.tokenBracketPos!true(3) == 4);
	assert(tokens.tokenBracketPos!false(4) == 3);
}