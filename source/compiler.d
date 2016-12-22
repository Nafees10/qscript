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
	DoubleArray,
	Char,
	Double
}

private enum TokenType{
	String,
	Number,
	Identifier,
	Operator,
	Comma,
	DataType,
	StatementEnd,
	BracketOpen,
	BracketClose,
	FunctionCall,
	FunctionDef
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
	return ["/","*","+","-","%","~","=","<",">","<=","==",">="].hasElement(s);
}

private bool isCompareOperator(string s){
	return ["<",">","<=","==",">="].hasElement(s);
}

private bool isDataType(string s){
	return ["double","doubleArray","char","string"].hasElement(s);
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

/*private Token[] readTokens(uinteger pos, bool forward = true){
	integer i;
	uinteger till = tokens.length;
	Token token = tokens.read(pos);
	if (forward){
		for (i=pos;i<till;i++){

		}
	}
}*/

//Functions below is where the 'magic' happens
private bool toTokens(List!string script){
	if (tokens){
		delete tokens;
	}
	tokens = new List!Token;
	uinteger i, lineno, till = script.length, addFrom;
	//addFrom stores position in line from where token starts
	uinteger tmInt;//To store temp function returns
	string line;
	Token token;
	uinteger tokenCount;//count of tokens added from current line, needed for error reporting
	bool hasError = false;
	lineLength.length = till;
	//First convert everything to 'tokens', TokenType will be set later
	for (lineno=0; lineno<till; lineno++){
		line = script.read(lineno);
		addFrom = 0;
		tokenCount = 0;
		for (i=0;i<line.length;i++){
			//ignore whitespace
			if (line[i] == ' ' || line[i] == '\t'){
				//Add token if any
				if (addFrom!=i){
					token.token = line[addFrom..i];
					tokens.add(token);
					tokenCount++;
				}
				addFrom = i+1;
			}
			//comments
			if (i<line.length-1 && line[i..i+2]=="//"){
				if (addFrom!=i){
					token.token = line[addFrom..i];
					tokens.add(token);
					tokenCount++;
				}
				break;
			}
			//ignore and add strings
			if (line[i]=='"'){
				tmInt = line.strEnd(i);
				if (tmInt==-1){
					addError(i,"Unterminated string");
					hasError = true;
					break;
				}else if (addFrom!=i){
					addError(i,"Unexpected token");
					hasError = true;
					break;
				}else{
					token.token = line[addFrom..tmInt+1];
					tokens.add(token);
					tokenCount++;
					addFrom = tmInt+1;
				}
			}
			//at bracket end/open & comma & semicolon
			if (isBracketOpen(line[i]) || isBracketClose(line[i]) || [',',';'].hasElement(line[i])){
				if (addFrom!=i){
					//has to add a token from before the bracket
					token.token = line[addFrom..i];
					tokens.add(token);
					tokenCount++;
				}
				//add the current token too
				token.token = [line[i]];
				tokens.add(token);
				tokenCount++;
				addFrom = i+1;
			}
			//and operators
			if (isOperator([line[i]])){// it works cuz 2char operator's for char is an operator
				//check if is a 2char op:
				if (i<line.length-1 && isOperator(line[i..i+2])){
					//is 2 char operator
					if (addFrom!=i){
						//has to add a token from before the operator
						token.token = line[addFrom..i];
						tokens.add(token);
						tokenCount++;
					}
					//add the operator too
					token.token = line[i..i+2];//it's a 2char operator
					tokens.add(token);
					tokenCount++;
					addFrom = i+2;//it's a 2char operator!
				}else{
					//is 1 char operator
					if (addFrom!=i){
						//has to add a token from before the operator
						token.token = line[addFrom..i];
						tokens.add(token);
						tokenCount++;
					}
					//add the operator too
					token.token = [line[i]];
					tokens.add(token);
					tokenCount++;
					addFrom = i+1;
				}
			}
		}
		lineLength[lineno] = tokenCount;
		if (hasError){
			break;
		}
	}
	if (hasError){
		goto skipConversion;
	}
	//Now put in Token Types
	Token tmpToken;
	till = tokens.length;
	for (i=0; i<till; i++){
		token = tokens.read(i);
		if (token.token.isNum){
			//Numbers:
			token.type = TokenType.Number;
			tokens.set(i,token);
		}else if (token.token.isAlphaNum){
			//Identifiers & FunctionCall & FunctionCall
			if (i<till-1){
				tmpToken = tokens.read(i+1).token;
				if (tmpToken.token=="("){
					token.type = TokenType.FunctionCall;
				}else if (tmpToken.token="{"){
					token.type = TokenType.FunctionDef;
				}
			}else{
				token.type = TokenType.Identifier;
			}
			tokens.set(i,token);
		}else if (token.token.isOperator){
			//Operator
			token.type = TokenType.Operator;
			tokens.set(i,token);
		}else if (token.token.length == 1){
			//comma, semicolon, brackets
			switch (token.token[0]){
				case ',':
					token.type = TokenType.Comma;
					break;
				case ';':
					token.type = TokenType.StatementEnd;
					break;
				default:
					if (isBracketOpen(token.token[0])){
						token.type = TokenType.BracketOpen;
					}else if (isBracketOpen(token.token[0])){
						token.type = TokenType.BracketClose;
					}
					break;
			}
			tokens.set(i,token);
		}else if (token.token[0]=='"'){
			//string
			token.type = TokenType.String;
			tokens.set(i,token);
		}else if (isDataType(token.token)){
			//is a data type
			token.type = TokenType.DataType;
			tokens.set(i,token);
		}
	}

skipConversion:
	return hasError;
}

private void toFunctionCalls(){
	struct var{
		DataTypes type;
		string name;
	}

	List!var vars = new List!var;
	List!var globalVars = new List!var;
	uinteger i, till=tokens.length;
	Token token;
	TokenType[] expectedTokens = [TokenType.Identifier, TokenType.DataType];
	bool hasError = false;
	//^either it has to be a function name, or globalvar

	for (i=0;i<till;i++){
		token = tokens.read(i);
		//die at unexpected tokens
		if (!expectedTokens.hasElement(token.type)){
			addError(i,"Unexpected token");
			hasError = true;
			break;//That's it! No more compiling!
		}
		//make sure all brackets are closed
		if (token.type == TokenType.BracketOpen){
			if (bracketPos(i)==-1){
				addError(i,"Unclosed bracket");
				hasError = true;
				break;
			}
			//set next set of expectedTokens
			if (["(","{"].hasElement(token.token)){
				expectedTokens = [TokenType.FunctionCall,TokenType.Identifier];//common expectation
				if (token.token=="("){
					expectedTokens += [TokenType.Number,TokenType.String];
				}else{
					expectedTokens += [TokenType.DataType];
				}
			}else{//is obviously a square bracket
				expectedTokens = [TokenType.FunctionCall,TokenType.Identifier,TokenType.Number];
			}

		}else if (token.type == TokenType.BracketClose){
			if (bracketPos(i,false)==-1){
				addError(i,"Unopened bracket");
				hasError = true;
				break;
			}
			//set next set of expectedTokens
			if ([")","}"].hasElement(token.token)){
				expectedTokens = [TokenType.BracketClose];//common expectation
				if (token.token==")"){
					expectedTokens += [TokenType.Comma,TokenType.Operator,TokenType.StatementEnd];
				}else{
					expectedTokens += [TokenType.DataType,TokenType.FunctionCall,TokenType.FunctionDef,
						TokenType.Identifier];
				}
			}else{//is obviously a square bracket
				expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,TokenType.StatementEnd];
			}
		}
	}

	
	delete vars;
	delete globalVars;
}


/*
Sample QScript:
main{
	newString someStringVar;//It's a string!
	double 
}

*/