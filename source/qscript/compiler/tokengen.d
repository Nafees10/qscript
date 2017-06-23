/+ This module converts script to tokens, and does basic syntax checking
 + 
 +/
module qscript.compiler.tokengen;

import utils.misc;
import utils.lists;
import std.conv:to;
import qscript.compiler.misc;
debug{
	import std.stdio;
}

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
}

/// Reads script, and separates tokens
/// TODO mark it private
public TokenList separateTokens(string[] script){
	LinkedList!string tokens = new LinkedList!string;
	if (compileErrors is null){
		compileErrors = new LinkedList!CompileError;
	}
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
			// stop at tabs, spaces, and line-endings
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
		"main", "{",
		"new", "(", "i", ",", "i2", ")", ";",
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
		"main{",
		"\tnew (i, i2);",
		"\tif (i < 2){}",
		"\tif(i<=2){}",
		"\tif(i >= 2) { }",
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
	];
	//make sure the expected result and actual result is same
	Token[] r = separateTokens(script).tokens;
	foreach(i, rToken; r){
		writeln(rToken.token," == ",expectedResults[i]);
		assert(rToken.token == expectedResults[i]);
	}
}

/// Takes script, and separates into tokens (using `separateTokens`), identifies token types, retuns the Tokens with TokenType
/// in an array
package TokenList toTokens(string[] script){
	/// Returns true if a string has chars that only identifiers can have
	bool isIdentifier(string s){
		return (cast(char[])s).matchElements(cast(char[])IDENT_CHARS);
	}
	/// Returns tru is a string is an operator
	bool isOperator(string s){
		bool r = false;
		foreach(operators; OPERATORS){
			if (operators.hasElement(s)){
				r = true;
				break;
			}
		}
		return r;
	}
	TokenList tokens = separateTokens(script);
	if (tokens.tokens == null){
		// there's error
		return tokens;
	}else{
		// continue with identiying tokens
		// fill in tokens with tokenStrings' strings, and identify their type
		foreach(i, token; tokens.tokens){
			// identify type
			if (isIdentifier(token.token)){
				tokens.tokens[i].type = TokenType.Identifier;
			}else if (isOperator(token.token)){
				tokens.tokens[i].type = TokenType.Operator;
			}else if (token.token[0] == '"'){
				tokens.tokens[i].type = TokenType.String;
			}else if (token.token.isNum){
				tokens.tokens[i].type = TokenType.Number;
			}else if (token.token == ";"){
				tokens.tokens[i].type = TokenType.StatementEnd;
			}else if (token.token == ","){
				tokens.tokens[i].type = TokenType.Comma;
			}else if (["{", "[", "("].hasElement(token.token)){
				tokens.tokens[i].type = TokenType.BracketOpen;
			}else if ([")", "]", "}"].hasElement(token.token)){
				tokens.tokens[i].type = TokenType.BracketClose;
			}else{
				compileErrors.append(CompileError(tokens.getTokenLine(i), "unidentified token type"));
			}
		}
		return tokens;
	}
}

/*
Interpreter instructions:
psh - push element(s) to stack
clr - empty the stack
exf - execute function, don't push return to stack. take fName from stack, and argC from given args
exa - execute function, push return to stack. take fName from stack, and argC from given args
jmp - jump to another index, and start execution from there, used in loops, and if
stv - set a variable's value, val name=arg, new value = from stack
rtv - push a variable's value to stack
Rules:
An instruction can recieve one argument!
AND: right before jmp, clr must be called, to prevent a possible mem-leak
*/