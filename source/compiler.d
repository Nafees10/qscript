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
	pos++;
	for (; chars<pos;i++){
		chars+=lineLength[i];
	}
	errors.add("Line: "~to!string(i)~": "~msg);
}

private void incLineLength(uinteger pos, uinteger n=1){
	uinteger i = 0, chars = 0;
	pos++;
	for (; chars<pos;i++){
		chars+=lineLength[i];
	}
	lineLength[i] += n;
}
/*
private void decLineLength(uinteger pos, uinteger n=1){
	uinteger i = 0, chars = 0;
	for (; i<=pos;i++){
		if (chars>i || chars==i){
			break;
		}else{
			chars+=lineLength[i];
		}
	}
	//Decrement could be from several lines:
	while (n>0){
		if (lineLength[i]<n){
			n -= lineLength[i];
			lineLength[i] = 0;
		}else{
			lineLength[i] -= n;
			n = 0;
		}
		i++;
	}
}
*/
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

private bool isIdentifier(string s){
	ubyte aStart = cast(ubyte)'a';
	ubyte aEnd = cast(ubyte)'z';
	s = lowercase(s);
	bool r=true;
	ubyte cur;
	for (uinteger i=0;i<s.length;i++){
		cur = cast(ubyte) s[i];
		if (cur<aStart || cur>aEnd){
			if ("0123456789_".canFind(s[i])==false){
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
	return ['}',']',')'].hasElement(b);
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
debug{
	private string DataTypeToStr(DataType dat){
		string r;
		if (dat==DataType.Double){
			r = "double";
		}else if (dat==DataType.String){
			r = "string";
		}
		return r;
	}
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

private Token[] readOperand(uinteger pos, bool forward = true){
	integer i;
	Token[] r;
	if (forward){
		uinteger till = tokens.length;
		for (i=pos;i<till;i++){
			Token token = tokens.read(i);
			if ([TokenType.BracketClose,TokenType.Comma,TokenType.StatementEnd].hasElement(token.type)){
				break;
			}else if (token.type == TokenType.BracketOpen){
				i = bracketPos(i);
			}
		}
		r = tokens.readRange(pos,i);
	}else{
		for (i=pos;i>=0;i--){
			Token token = tokens.read(i);
			if ([TokenType.BracketOpen,TokenType.Comma,TokenType.StatementEnd].hasElement(token.type)){
				break;
			}else if (token.type == TokenType.BracketClose){
				i = bracketPos(i,false);
			}
		}
		r = tokens.readRange(i+1,pos+1);
	}
	return r;
}

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
					i = tmInt;
					continue;
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
		}else if (isKeyword(token.token)){//this has to come before isIdentifier! Don't mess with it!
			//Keyword
			token.type = TokenType.Keyword;
		}else if (token.token.isIdentifier){
			//Identifiers & FunctionCall & FunctionCall
			token.type = TokenType.Identifier;
			if (i<till-1){
				tmpToken = tokens.read(i+1);
				if (tmpToken.token=="("){
					token.type = TokenType.FunctionCall;
				}else if (tmpToken.token=="{"){
					token.type = TokenType.FunctionDef;
				}
			}
		}else if (token.token.isOperator){
			//Operator
			token.type = TokenType.Operator;
		}else if (token.token[0]=='"'){
			//string
			token.type = TokenType.String;
		}else if (isDataType(token.token)){
			//is a data type
			token.type = TokenType.DataType;
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
					}else if (isBracketClose(token.token[0])){
						token.type = TokenType.BracketClose;
					}
					break;
			}
		}
		tokens.set(i,token);
	}

skipConversion:
	if (hasError){
		hasError = false;
	}else{
		hasError = true;
	}
	return hasError;
}

private bool checkSyntax(){
	List!string vars = new List!string;
	List!DataType varTypes = new List!DataType;
	uinteger i, till = tokens.length;
	bool hasError = false;
	uinteger blockDepth;
	Token token, tmpToken;
	TokenType[] expectedTokens = [TokenType.FunctionDef];

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
				addError(i+1,"variable definitions must be enclosed in paranthesis");
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
				tmpToken = tokens.read(j);
				if (tmpToken.type!=TokenType.Identifier){
					if (!expComma){
						//it should've been an identifier, but it wasn't
						addError(i+1,"identifier expected in variable definition");
						hasError = true;
						break;
					}else if (tmpToken.type!=TokenType.Comma){
						//comma was expected, but it wasn't there :(
						addError(i+1,"comma must be used to separate variable names in definition");
						hasError = true;
						break;
					}else{
						//comma was expected, and it was there :)
						expComma = false;
					}
				}else if (tmpToken.type==TokenType.Identifier){
					vars.add(tmpToken.token);
					varTypes.add(tmpToken.token.strToDataType);
					expComma = true;
				}
			}
			if (hasError){
				break;
			}
			i=end+1;
			expectedTokens = [TokenType.DataType,TokenType.FunctionCall,TokenType.Keyword,
				TokenType.Identifier];
			continue;//to skip the semicolon at end
			
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
				addError(i, "variable was not defined");
				hasError = true;
				//isn't a 'critical' error, just add it to list-of-errors, and don't generate bytecode
			}
			//set next set of tokens
			expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
				TokenType.StatementEnd];
			
		}else if (token.type == TokenType.Number || token.type == TokenType.String){
			expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
				TokenType.StatementEnd];
			
		}else if (token.type == TokenType.Operator){
			expectedTokens = [TokenType.BracketOpen,TokenType.FunctionCall,TokenType.Identifier,
				TokenType.Number,TokenType.String];
			
		}else if (token.type == TokenType.StatementEnd){
			expectedTokens = [TokenType.DataType,TokenType.FunctionCall,TokenType.Keyword,
				TokenType.Identifier,TokenType.BracketClose];
		}
	}
	delete vars;
	delete varTypes;

	if (hasError){
		hasError = false;
	}else{
		hasError = true;
	}
	return hasError;
}

private void operatorsToFunctionCalls(){
	uinteger i, till=tokens.length;
	Token token;
	Token[2] tmpToken;
	uinteger blockDepth = 0;
	Token[][2] operand;
	uinteger j;

	string[string][] operators;//[operator priority][operator name]->compiled name
	operators.length = 2;
	operators[0] = [//top priority
		"/":"_/",
		"*":"_*",
		"-":"_-",
		"+":"_+",
		"%":"_%",
		"~":"_~",
	];
	operators[1] = [//second
		"==":"_==",
		">=":"_>=",
		"<=":"_<=",
		">":"_>",
		"<":"_<"
	];
	/*Note to future self: `=` operator is not compiled here,
	 *there is the `setv` instruction for it, so it is compiled
	 *by the `toByteCode` function!*/
	foreach(curOperators; operators){//compile all priority functions, one by one
		for (i=0;i<till;i++){
			token = tokens.read(i);
			if (token.type == TokenType.Operator && token.token in curOperators){
				//read first operand 'a'+b -> 'a'
				operand[0] = readOperand(i-1,false);
				//read second operand a+'b' -> 'b'
				operand[1] = readOperand(i+1);
				//Insert tokens that make the operator into a function call
				tmpToken[0].token = curOperators[token.token];
				tmpToken[0].type = TokenType.FunctionCall;
				tmpToken[1].token = "(";
				tmpToken[1].type = TokenType.BracketOpen;
				j = i-operand[0].length;//cause i-operand[0].length is required twice.
				tokens.insert(j,tmpToken);
				incLineLength(j,2);
				//change the operator to comma
				tmpToken[0].token = ",";
				tmpToken[0].type = TokenType.Comma;
				tokens.set(i,tmpToken[0]);
				//Insert a bracket end
				tmpToken[0].token = ")";
				tmpToken[0].type = TokenType.BracketClose;
				j = i+operand[0].length;//cause i+operand[0].length is required twice.
				tokens.insert(j,[tmpToken[0]]);
				incLineLength(j,1);
				
			}
		}
	}


}

debug{
	void debugCompiler(string fname){
		import std.stdio;
		List!string scr = new List!string;
		errors = new List!string;
		scr.loadArray(fileToArray(fname));

		string[TokenType] toks = [
			TokenType.BracketClose:"Bracket Close",
			TokenType.BracketOpen:"Bracket Open",
			TokenType.Comma:"Comma",
			TokenType.DataType:"Data Type",
			TokenType.FunctionCall:"Function Call",
			TokenType.FunctionDef:"Function Definition",
			TokenType.Identifier:"Identifier",
			TokenType.Keyword:"Keyword",
			TokenType.Number:"Number",
			TokenType.Operator:"Operator",
			TokenType.StatementEnd:"Semicolon",
			TokenType.String:"String"
		];

		writeln("Converting to tokens, press enter to begin...");readln;
		if (!toTokens(scr)){
			writeln("There were errors:");
			foreach(error; errors.toArray){
				writeln(error);
			}
			writeln("press enter to exit...");readln;
			goto skip;
		}
		delete scr;
		writeln("Conversion complete, press enter to display tokens...");readln;
		foreach(token; tokens.toArray){
			writeln(token.token,"\t\t",toks[token.type]);
		}
		writeln("Press enter to start syntax check");readln;
		if (!checkSyntax){
			writeln("There were errors:");
			foreach(error; errors.toArray){
				writeln(error);
			}
			writeln("press enter to exit...");readln;
			goto skip;
		}
		writeln("Syntax check complete, no errors found,\n",
			" press enter to start conversion from operators to functions...");readln;
		operatorsToFunctionCalls;
		writeln("Conversion complete, press enter to display tokens...");readln;
		foreach(token; tokens.toArray){
			writeln(token.token,"\t\t",toks[token.type]);
		}
		writeln("test ended!");

	skip:
		delete errors;
	}
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