/*
 * uinteger will be used instead of uint. If uint was used, 
 * then array.length would have to be casted to uint, plus,
 * less elements could be used. uintger is uint on 32 bit, 
 * and ulong on 64 bit. integer is int on 32 bit, and long 
 * on 64 bit.
*/

module compiler;

import misc;
import lists;
import std.stdio;
import std.conv:to;
import std.algorithm:canFind;

private List!Token tokens;
private List!string errors;
private uinteger[] lineLength;

private enum BracketType{
	Square,
	Round,
	Block
}

private enum DataTypes{
	String,
	Array,
	Char,
	Double
}

private enum TokenType{
	String,
	Number,
	Identifier,
	Operator,
	Comma,
	BracketOpen,
	BracketClose
}

private struct Token{
	TokenType type;
	string token;
}
//These functions below are used by compiler
private void addError(uinteger pos, string msg){
	uinteger i = 0, chars = 0;
	for (; i<=pos;i++){
		if (chars>i || chars==i){
			break;
		}else{
			chars+=lineLength[i];
		}
	}
	errors.add("Line: "~to!string(i+1)~": "~msg);
}

private integer strEnd(string s, uinteger i){
	for (i++;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			continue;
		}else if (s[i]=='"'){
			break;
		}
	}
	if (i==s.length){i=-1;}
	return i;
}

private bool hasElement(T)(T[] array, T element){
	bool r = false;
	foreach(cur; array){
		if (cur == element){
			r = true;
			break;
		}
	}
	return r;
}

private string lowercase(string s){
	string tmstr;
	ubyte tmbt;
	for (integer i=0;i<s.length;i++){
		tmbt = cast(ubyte) s[i];
		if (tmbt>=65 && tmbt<=90){//is in range of capital letters
			tmbt+=32;//small letters are +32 of their capitals
			tmstr ~= cast(char) tmbt;
		}else{
			tmstr ~= s[i];
		}
	}
	
	return tmstr;
}

private bool isNum(string s){
	bool r=false;
	uinteger i;
	for (i=0;i<s.length;i++){
		if ("0123456789.".canFind(s[i])){
			r = true;
			break;
		}
	}
	return r;
}

private bool isAlphaNum(string s){
	ubyte aStart = cast(ubyte)'a';
	ubyte aEnd = cast(ubyte)'z';
	s = lowercase(s);
	bool r=true;
	ubyte cur;
	for (uinteger i=0;i<s.length;i++){
		cur = cast(ubyte) s[i];
		if (cur<aStart || cur>aEnd){
			if ("0123456789".canFind(s[i])==false){
				r=false;
				break;
			}
		}
	}
	return r;
}

private bool isOperator(string s){
	return ["/","*","+","-","%","<",">","=","<=","==",">="].hasElement(s);
}

private bool isBracketOpen(char b){
	return ['{','[','('].hasElement(b);
}

private bool isBracketClose(char b){
	return ['{','[','('].hasElement(b);
}

private integer bracketPos(uinteger start, bool forward = true){
	List!BracketType bracks = new List!BracketType;
	integer i;
	string curToken;
	BracketType[string] brackOpenIdent = [
		"(":BracketType.Round,
		"[":BracketType.Square,
		"{":BracketType.Block
	];
	BracketType[string] brackCloseIdent = [
		")":BracketType.Round,
		"]":BracketType.Square,
		"}":BracketType.Block
	];
	if (forward){
		for (i=start; i<tokens.length; i++){
			curToken = tokens.read(i).token;
			if (curToken in brackOpenIdent){
				bracks.add(brackOpenIdent[curToken]);
			}else if (curToken in brackCloseIdent){
				if (bracks.readLast == brackCloseIdent[curToken]){
					bracks.removeLast;
				}else{
					addError(i," Wrong bracket closed.");
					i = -1;
					break;
				}
			}
			if (bracks.length == 0){
				break;
			}
		}
	}else{
		for (i=start; i>=0; i--){
			curToken = tokens.read(i).token;
			if (curToken in brackCloseIdent){
				bracks.add(brackCloseIdent[curToken]);
			}else if (curToken in brackOpenIdent){
				if (bracks.readLast == brackOpenIdent[curToken]){
					bracks.removeLast;
				}else{
					addError(i," Wrong bracket closed.");
					i = -1;
					break;
				}
			}
			if (bracks.length == 0){
				break;
			}
		}
	}

	delete bracks;
	return i;
}

//Functions below is where the 'magic' happens
private void toTokens(List!string script){
	if (tokens){
		delete tokens;
	}
	tokens = new List!Token;
	uinteger i, lineno, till = script.length, addFrom;
	uinteger[2] tmInt;
	string line;
	Token tmpToken;
	bool hasError = false;
	//First convert everything to 'tokens', TokenType will be set later
	for (lineno=0; lineno<till; lineno++){
		line = script.read(lineno);
		addFrom = 0;
		for (i=0;i<line.length;i++){
			//ignore whitespace
			if (line[i] == ' ' || line[i] == '\t'){
				//Add token if any
				if (addFrom!=i){
					tmpToken.token = line[addFrom..i];
					tokens.add(tmpToken);
				}
				addFrom = i+1;
			}
			if (i<line.length-1 && line[i..i+2]=="//"){
				if (addFrom!=i){
					break;
				}else{
					tmpToken.token = line[addFrom..i];
					tokens.add(tmpToken);
				}
			}
			//ignore and add strings
			if (line[i]=='"'){
				tmInt[0] = line.strEnd(i);
				if (tmInt[0]==-1){
					addError(i,"Unterminated string");
				}else if (addFrom!=i){
					addError(i,"Unexpected string");
				}else{
					tmpToken.token = line[addFrom..tmInt[0]+1];
					tokens.add(tmpToken);
				}
			}
			//at bracket end/open & dot & comma
			if (isBracketOpen(line[i]) || isBracketClose(line[i]) || [',','.'].hasElement(line[i])){
				if (addFrom!=i){
					//has to add a token from before the bracket
					tmpToken.token = line[addFrom..i];
					tokens.add(tmpToken);
				}
				//add the bracket too
				tmpToken.token = [line[i]];
				tokens.add(tmpToken);
			}
			//and operators
			if (isOperator([line[i]])){// it works cuz 2char operator's for char is an operator
				//check if is a 2char op:
				if (i<line.length-1 && isOperator(line[i..i+2])){
					//is 2 char operator
					if (addFrom!=i){
						//has to add a token from before the operator
						tmpToken.token = line[addFrom..i];
						tokens.add(tmpToken);
					}
					//add the operator too
					tmpToken.token = line[i..i+2];//it's a 2 char operator
					tokens.add(tmpToken);
				}else{
					//is 1 char operator
					if (addFrom!=i){
						//has to add a token from before the operator
						tmpToken.token = line[addFrom..i];
						tokens.add(tmpToken);
					}
					//add the operator too
					tmpToken.token = [line[i]];
					tokens.add(tmpToken);
				}
			}
		}
	}
}

private void toFunctionCalls(){
	struct var{
		DataTypes type;
		string name;
	}

	List!var vars = new List!var;
	List!var globalVars = new List!var;
	uinteger i, till;

	till = tokens.length;
	for (i=0;i<till;i++){
		//Compile stuff here
	}
	
	delete vars;
	delete globalVars;
}