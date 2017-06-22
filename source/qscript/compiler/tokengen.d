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

/// First step in compilation
/// Converts the script into tokens, identifies the TokenType, returns the tokens in a `Token[]`
/// adds error to `misc.compilerErrors` in case of error, and returns empty array or null
package Token[] toTokens(List!string script){
	LinkedList!Token tokens = new LinkedList!Token;
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
					Token t;
					t.token = line[readFrom .. i].dup;// use .dup instead of just `=` to avoid horrible memory issues
					tokens.append(t);
				}
				// skip the current char for the next token
				readFrom = i + 1;
			}
			// stop at brackets, and commas
			if (['{', '[', '(', ')', ']', '}', ','].hasElement(line[i])){
				Token t;
				// add the previous token first
				if (readFrom < i){
					t.token = line[readFrom .. i].dup;
					tokens.append(t);
				}
				t.token = cast(string)[line[i]];
				tokens.append(t);
				//move readFrom to next token's position
				readFrom = i + 1;
			}
			// stop and add if a string is seen
			if (line[i] == '"'){
				// check if string has an ending
				integer strEndPos = strEnd(line, i);
				if (strEndPos == -1){
					// error
					CompileError error = CompileError(i + 1, "unterminated string");
					compileErrors.append(error);
					break;
				}else{
					// everything's good
					Token t;
					//t.token = line[]
					//TODO continue from here
				}
			}
			prevIsIdent = isIdent;
		}
	}

	// now identify token types, only if there were no errors
	if (compileErrors.count == 0){
		// identify token types
	}

	// return tokens if no error
	Token[] r = tokens.toArray;
	tokens.destroy();
	if (compileErrors.count == 0){
		return r;
	}else{
		return null;
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