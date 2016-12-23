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

private enum DataType{
	String,
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
	FunctionDef,
	Keyword
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

private bool isKeyword(string s){
	return ["if","while","setLength","getLength","array"].hasElement(s);
}

private bool isBracketOpen(char b){
	return ['{','[','('].hasElement(b);
}

private bool isBracketClose(char b){
	return ['{','[','('].hasElement(b);
}

private DataType strToDataType(string s){
	DataType r;
	if (s=="double"){
		r = DataType.Double;
	}else if (s=="string"){
		r = DataType.String;
	}
	return r;
}
/*//Not used
private string DataTypeToStr(DataType dat){
	string r;
	if (dat==DataType.Double){
		r = "double";
	}else if (dat==DataType.String){
		r = "string";
	}
	return r;
}
*/
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
					addError(i,"brackets order is wrong, first opened must be last closed");
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
					addError(i,"brackets order is wrong, first opened must be last closed");
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
					addError(i,"string must be terminated with a \"");
					hasError = true;
					break;
				}else if (addFrom!=i){
					addError(i,"string at enexpected position");
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
	Token tmpToken;
	if (hasError){
		goto skipConversion;
	}
	//Now put in Token Types
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
				tmpToken = tokens.read(i+1);
				if (tmpToken.token=="("){
					token.type = TokenType.FunctionCall;
				}else if (tmpToken.token=="{"){
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
		}else if (isKeyword(token.token)){
			//Keyword
			token.type = TokenType.Keyword;
		}
	}

skipConversion:
	return hasError;
}

private void toFunctionCalls(){

	List!string vars = new List!string;
	List!DataType varTypes = new List!DataType;
	uinteger i, till=tokens.length;
	Token token;
	Token[1] tmpToken;
	TokenType[] expectedTokens = [TokenType.FunctionDef];//expect a functionDef
	bool hasError = false;
	uinteger blockDepth = 0;
	//^either it has to be a function name, or globalvar

	for (i=0;i<till;i++){
		token = tokens.read(i);
		//die at unexpected tokens
		if (!expectedTokens.hasElement(token.type)){
			addError(i,"unexpected token found");
			hasError = true;
			break;//That's it! No more compiling, first fix this, then I'll compile!
		}
		//make sure all brackets are closed
		if (token.type == TokenType.BracketOpen){
			if (bracketPos(i)==-1){
				addError(i,"bracket left unclosed");
				hasError = true;
				break;
			}
			//set next set of expectedTokens
			if (token.token=="("){
				expectedTokens = [TokenType.FunctionCall,TokenType.Identifier,TokenType.Number,
					TokenType.String,TokenType.BracketOpen];
			}else if (token.token=="{"){
				blockDepth++;
				expectedTokens = [TokenType.FunctionCall,TokenType.Identifier,TokenType.DataType];
			}else{//if it ain't a round or a square, then it is obviously a square bracket
				expectedTokens = [TokenType.FunctionCall,TokenType.Identifier,TokenType.Number];
			}

		}else if (token.type == TokenType.BracketClose){
			if (bracketPos(i,false)==-1){
				addError(i,"closing an unopened bracket");
				hasError = true;
				break;
			}
			//set next set of expectedTokens
			if (token.token==")"){
				expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
					TokenType.StatementEnd,TokenType.BracketOpen];//BracketOpen cuz `if(...){...}`
			}else if (token.token=="}"){
				blockDepth--;
				if (blockDepth==0){
					vars.clear;
					varTypes.clear;
				}
				expectedTokens = [TokenType.BracketClose,TokenType.DataType,TokenType.FunctionCall,
					TokenType.FunctionDef,TokenType.Identifier,TokenType.Keyword];
			}else{//is obviously a square bracket
				expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
					TokenType.StatementEnd];
			}

		}else if (token.type == TokenType.DataType){//is var declaration
			uinteger j, end;
			bool expComma = false;
			if (tokens.read(i+1).token!="("){
				addError(i+1,"variable declarations must be enclosed in paranthesis");
				hasError = true;
				break;
			}
			end = bracketPos(i+1);
			if (end==-1){
				addError(i+1,"bracket left unclosed");
				hasError = true;
				break;
			}
			if (end+1>=till || tokens.read(end+1).type!=TokenType.StatementEnd){
				addError(end+1,"semicolon expected at end of statement");
				hasError = true;
				break;
			}
			for (j=i+2;j<end;j++){
				tmpToken[0] = tokens.read(j);
				if (tmpToken[0].type!=TokenType.Identifier){
					if (!expComma){
						//it should've been an identifier, but it wasn't
						addError(i+1,"identifier expected in variable declaration");
						hasError = true;
						break;
					}else if (tmpToken[0].type!=TokenType.Comma){
						//comma was expected, but it wasn't there :(
						addError(i+1,"comma must be used to separate variable names in declaration");
						hasError = true;
						break;
					}else{
						//comma was expected, and it was there :)
						expComma = false;
					}
				}else if (tmpToken[0].type==TokenType.Identifier){
					vars.add(tmpToken[0].token);
					varTypes.add(tmpToken[0].token.strToDataType);
					expComma = true;
				}
			}
			if (hasError){
				break;
			}
			i=end+2;
			expectedTokens = [TokenType.DataType,TokenType.FunctionCall,TokenType.Keyword,
				TokenType.Identifier];

		}else if (token.type == TokenType.Comma){
			expectedTokens = [TokenType.BracketOpen,TokenType.FunctionCall,TokenType.Identifier,
				TokenType.Number,TokenType.String];

		}else if (token.type == TokenType.FunctionCall || token.type == TokenType.FunctionDef ||
				token.type == TokenType.Keyword){
			expectedTokens = [TokenType.BracketOpen];

		}else if (token.type == TokenType.Identifier){
			//Check if is a var
			if (vars.indexOf(token.token)==-1){
				//is not a declared var
				addError(i, "Variable was not declared.");
				hasError = true;
				//isn't a 'critical' error, just add it to list-of-errors, and don't generate bytecode
			}//No else needed to handle variable, byteCode converter will do
			//set next set of tokens
			expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
				TokenType.StatementEnd];

		}else if (token.type == TokenType.Number || token.type == TokenType.String){
			expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
				TokenType.StatementEnd];

		}else if (token.type == TokenType.Operator){
			//TODO: Implement Operators in compiler!

		}else if (token.type == TokenType.StatementEnd){
			expectedTokens = [TokenType.DataType,TokenType.FunctionCall,TokenType.Keyword,
				TokenType.Identifier];
		}
	}

	
	delete vars;
	delete varTypes;
}


/*
Sample QScript:
main{
	newString someStringVar;//It's a string!
	double 
}
Interpreter instructions:
psh  - push element(s) to stack
pop  - pop `n` elements from stack
clr  - empty the stack, remove all elements
pshv - push a variable's value to stack
setv - set variable value to last element on stack
exe  - execute function(s), don't push return to stack
exa  - execute function(s), push retur to stack
jmp  - jump to another index, and start execution from there, used in loops, and if
Rules:
An instruction can recieve dynamic amount of arguments! No limit
*/