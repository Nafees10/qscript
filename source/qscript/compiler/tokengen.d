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

/// Reads script, and separates tokens
private string[] separateTokens(List!string script){
	LinkedList!string tokens = new LinkedList!string;
	//First convert everything to 'tokens', TokenType will be set later
	for (uinteger lineno=0, lineCount = script.length; lineno < lineCount; lineno++){
		string line = script.read(lineno);
		bool prevIsIdent = false; /// Stores if the previous char read was present in IDENT_CHARS
		bool isIdent; /// Stores if the current char is present in IDENT_CHARS
		for (uinteger i = 0, readFrom = 0; i < line.length; i ++){
			// stop at tabs, spaces, and line-endings
			if (line[i] == ' '|| line[i] == '\t' || i == line.length-1){
				// check if there is any token to be inserted
				if (readFrom < i){
					// insert this token
					string t = line[readFrom .. i].dup;// use .dup instead of just `=` to avoid horrible memory issues
					tokens.append(t);
				}
				// skip the current char for the next token
				readFrom = i + 1;
			}else
			// stop at brackets, and commas
			if (['{', '[', '(', ')', ']', '}', ','].hasElement(line[i])){
				string t;
				// add the previous token first
				if (readFrom < i){
					t = line[readFrom .. i].dup;
					tokens.append(t);
				}
				t = cast(string)[line[i]];
				tokens.append(t);
				//move readFrom to next token's position
				readFrom = i + 1;
			}else
			// stop and add if a string is seen
			if (line[i] == '"'){
				//check if there was a previous "unterminated" token before string
				if (readFrom < i){
					// :(
					CompileError error = CompileError(i + 1, "found unexpected token before string");
					compileErrors.append(error);
					break;
				}else{
					// check if string has an ending
					integer strEndPos = strEnd(line, i);
					if (strEndPos == -1){
						// error
						CompileError error = CompileError(i + 1, "unterminated string");
						compileErrors.append(error);
						break;
					}else{
						// everything's good
						string t;
						t = line[i .. strEndPos + 1].dup;// we added the quotation marks around the string too!
						tokens.append(t);
						// skip string
						i = strEndPos;
						// move readFrom too
						readFrom = i + 1;
					}
				}
			}
			// finally, check if the previous char's isIdent is different from this one's, then it means they're different tokens
			isIdent = IDENT_CHARS.hasElement(line[i]);
			if (prevIsIdent != isIdent){
				string t;
				t = line[readFrom .. i];
				tokens.append(t);
				// move readFrom
				readFrom = i + 1;
			}
			prevIsIdent = isIdent;
		}
	}

	// return tokens if no error
	string[] r = tokens.toArray;
	tokens.destroy();
	if (compileErrors.count == 0){
		return r;
	}else{
		return null;
	}
}
///
unittest{

}

/// Takes script, and separates into tokens (using `separateTokens`), identifies token types, retuns the Tokens with TokenType
/// in an array
package Token[] toTokens(List!string script){
	/// Returns true if a string has chars that only identifiers can have
	bool isIdentifier(string s){
		bool r = true;
		foreach(c; s){
			if (!IDENT_CHARS.hasElement(c)){
				r = false;
				break;
			}
		}
		return r;
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
	string[] tokenStrings = separateTokens(script);
	if (tokenStrings == null){
		// there's error
		return null;
	}else{
		// continue with identiying tokens
		Token[] tokens;
		tokens.length = tokenStrings.length;
		// fill in tokens with tokenStrings' strings, and identify their type
		foreach(i, token; tokenStrings){
			tokens[i].token = token;
			// identify type
			if (isIdentifier(token)){
				tokens[i].type = TokenType.Identifier;
			}else if (isOperator(token)){
				tokens[i].type = TokenType.Operator;
			}else if (token[0] == '"'){
				tokens[i].type = TokenType.String;
			}else if ()
		}
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