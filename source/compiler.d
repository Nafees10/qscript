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

private enum TokenType{
	String,
	Number,
	Identifier,
	Operator,
	Comma,
	VarDef,
	StatementEnd,
	BracketOpen,
	BracketClose,
	FunctionCall,
	FunctionDef,
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

private bool isBracketOpen(char b){
	return ['{','[','('].hasElement(b);
}

private bool isBracketClose(char b){
	return ['}',']',')'].hasElement(b);
}

private Token[] IdentifiersToString(Token[] ident){
	for (uinteger i = 0;i < ident.length; i++){
		if (ident[i].type==TokenType.Identifier){
			ident[i].token = '"'~ident[i].token~'"';
			ident[i].type = TokenType.String;
		}
	}
	return ident;
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
			if ([TokenType.BracketClose,TokenType.Comma,TokenType.StatementEnd,
					TokenType.Operator].hasElement(token.type)){
				break;
			}else if (token.type == TokenType.BracketOpen){
				i = bracketPos(i);
			}
		}
		r = tokens.readRange(pos,i);
	}else{
		for (i=pos;i>=0;i--){
			Token token = tokens.read(i);
			if ([TokenType.BracketOpen,TokenType.Comma,TokenType.StatementEnd,
					TokenType.Operator].hasElement(token.type)){
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
		}else if (token.token == "new"){
			//is a data type
			token.type = TokenType.VarDef;
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
					TokenType.String,TokenType.BracketOpen,TokenType.BracketClose];
			}else if (token.token=="{"){
				blockDepth++;
				expectedTokens = [TokenType.FunctionCall,TokenType.Identifier,TokenType.VarDef];
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
				}
				expectedTokens = [TokenType.BracketClose,TokenType.VarDef,TokenType.FunctionCall,
					TokenType.FunctionDef,TokenType.Identifier];
			}else{//is obviously a square bracket
				expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
					TokenType.StatementEnd,TokenType.BracketOpen];//BrOpen cuz i`[0][0]` =...; 
			}
			
		}else if (token.type == TokenType.VarDef){//is var declaration
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
					expComma = true;
				}
			}
			if (hasError){
				break;
			}
			i=end+1;
			expectedTokens = [TokenType.VarDef,TokenType.FunctionCall,
				TokenType.Identifier];
			continue;//to skip the semicolon at end
			
		}else if (token.type == TokenType.Comma){
			expectedTokens = [TokenType.BracketOpen,TokenType.FunctionCall,TokenType.Identifier,
				TokenType.Number,TokenType.String];
			
		}else if (token.type == TokenType.FunctionCall || token.type == TokenType.FunctionDef){
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
				TokenType.StatementEnd,TokenType.BracketOpen];
			
		}else if (token.type == TokenType.Number || token.type == TokenType.String){
			expectedTokens = [TokenType.BracketClose,TokenType.Comma,TokenType.Operator,
				TokenType.StatementEnd];
			
		}else if (token.type == TokenType.Operator){
			expectedTokens = [TokenType.BracketOpen,TokenType.FunctionCall,TokenType.Identifier,
				TokenType.Number,TokenType.String];
			
		}else if (token.type == TokenType.StatementEnd){
			expectedTokens = [TokenType.VarDef,TokenType.FunctionCall,TokenType.Identifier,
				TokenType.BracketClose];
		}
	}
	delete vars;

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
	Token[][2] operand;
	uinteger j;

	string[string][] operators;//[operator priority][operator name]->compiled name
	operators.length = 3;
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
	operators[2] = [
		"=":"_="
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
				//operand[0] = operand[0].IdentifiersToString;
				//read second operand a+'b' -> 'b'
				operand[1] = readOperand(i+1);
				//operand[1] = operand[1].IdentifiersToString;
				//First, change the operator into a comma! NO MESSING WITH THIS ORDER!
				tmpToken[0].token = ",";
				tmpToken[0].type = TokenType.Comma;
				tokens.set(i,tmpToken[0]);
				//Then, insert a bracket at end! Don't mess with this order!
				tmpToken[0].token = ")";
				tmpToken[0].type = TokenType.BracketClose;
				j = (i+operand[1].length)+1;//cause i+operand[0].length... is required twice.
				tokens.insert(j,[tmpToken[0]]);
				incLineLength(j,1);
				//Insert tokens that make the operator into a function call
				tmpToken[0].token = curOperators[token.token];
				tmpToken[0].type = TokenType.FunctionCall;
				tmpToken[1].token = "(";
				tmpToken[1].type = TokenType.BracketOpen;
				j = (i-operand[0].length);//cause i-operand[0].length... is required twice.
				tokens.insert(j,tmpToken);
				incLineLength(j,2);
				//go back a few steps
				i-=operand[0].length+1;
				//update `till`
				till = tokens.length;
			}
		}
	}
	//remove unnecessary brackets, and `[]` from assignment calls
	bool isInAssignment=false;
	operators.length=0;//free mem(?)
	for (i=0;i<till;i++){
		token = tokens.read(i);
		if (token.type==TokenType.FunctionCall && ["setLength","getLength","_="].hasElement(token.token)){
			isInAssignment = true;
		}
		if (isInAssignment && token.type==TokenType.Comma){
			isInAssignment = false;
		}
		if (isInAssignment && token.type==TokenType.Identifier){
			token.type = TokenType.String;
			token.token = '"'~token.token~'"';
			tokens.set(i,token);
		}
		if (isInAssignment && token.type==TokenType.BracketOpen && token.token=="["){
			j = bracketPos(i);
			//convert these to comma
			tmpToken[0].token = ",";
			tmpToken[0].type = TokenType.Comma;
			tokens.set(i,tmpToken[0]);
			tokens.remove(j);
			till--;
			i = j-1;//so it doesnt mess up with contents inside []
			continue;
		}
		if (token.type == TokenType.BracketClose && token.token==")"){
			j = bracketPos(i,false);
			tmpToken[0] = tokens.read(j-1);
			if ([TokenType.BracketOpen,TokenType.Comma].hasElement(token.type)){
				//remove it!
				tokens.remove(j);
				tokens.remove(i);
				till-=2;
				i-=3;//cuz `for` will do +1
				continue;
			}
		}
	}
	isInAssignment = false;
	//put `_?` for vars
	for (i=0;i<till;i++){
		token = tokens.read(i);
		//skip if in `new`
		if (token.type == TokenType.VarDef){
			j = bracketPos(i+1);
			i=j;
			continue;
		}
		//now replace
		//vars
		if (token.type == TokenType.Identifier){
			//change from Identifier to String
			token.type = TokenType.String;
			token.token = '"'~token.token~'"';
			tokens.set(i,token);
			//put the bracket at end
			tmpToken[0].token = ")";
			tmpToken[0].type = TokenType.BracketClose;
			tokens.insert(i+1,[tmpToken[0]]);
			//put _?( at start:
			tmpToken[0].token = "_?";
			tmpToken[0].type = TokenType.FunctionCall;
			tmpToken[1].token = "(";
			tmpToken[1].type = TokenType.BracketOpen;
			tokens.insert(i,tmpToken);
		}
		//arrays
		if (token.type == TokenType.BracketOpen && token.token=="["){
			operand[0] = readOperand(i-1,false);
			j = bracketPos(i);
			//operand[1] = tokens.readRange(i+1,bracketPos(i+1));
			//change `[` to `,`
			tmpToken[0].token = ",";
			tmpToken[0].type = TokenType.Comma;
			tokens.set(i,tmpToken[0]);
			//change `]` to `)`
			tmpToken[0].token = ")";
			tmpToken[0].type = TokenType.BracketClose;
			tokens.set(j,tmpToken[0]);
			//insert `_readArray`
			j = i-operand[0].length;
			tmpToken[0].type = TokenType.FunctionCall;
			tmpToken[0].token = "_readArray";
			tmpToken[1].type = TokenType.BracketOpen;
			tmpToken[1].token = "(";
			tokens.insert(j,tmpToken);
			till+=2;
			i-=3;
			continue;
		}
	}
}

private string[][string] toByteCode(){
	List!(uinteger[2]) addIfJump = new List!(uinteger[2]);//1:blockDepth; 2:whereTheJMPis
	List!(uinteger[2]) addJump = new List!(uinteger[2]);//First element for onBlockToAdd, second: whatToAdd
	List!uinteger argC = new List!uinteger;
	List!string calls = new List!string;
	uinteger blockDepth = 0;
	uinteger brackDepth = 0;
	Token token, tmpToken;
	string fname = null;
	string[][string] r;
	uinteger[2] tmint;

	uinteger i, till;
	till = tokens.length;
	for (i=0;i<till;i++){
		token = tokens.read(i);
		if (token.type==TokenType.FunctionDef){
			fname = token.token;
		}
		if (token.type==TokenType.BracketOpen && token.token=="{"){
			blockDepth++;
			if (addIfJump.length>0){
				calls.add("jmp foo");//will be later replaced
				addIfJump.set(addIfJump.length-1,[addIfJump.readLast[0],calls.length-1]);
			}
		}else if (token.type==TokenType.BracketOpen && token.token=="("){
			brackDepth++;
			argC.add(0);
		}
		if (token.type == TokenType.BracketClose && token.token=="}"){
			if (addJump.length>0){
				//just add a jmp statement
				tmint = addJump.readLast;
				if (tmint[0]==blockDepth){
					calls.add("jmp "~to!string(tmint[1]));
					addJump.removeLast;
				}
			}
			if (addIfJump.length>0){
				tmint = addIfJump.readLast;
				if (tmint[0]==blockDepth){
					calls.set(tmint[1],"jmp "~to!string(calls.length));
					addIfJump.removeLast;
				}
			}
			if (blockDepth==1){
				//is an ending function
				r[fname] = calls.toArray;
				calls.clear;
				fname=null;
			}
			blockDepth--;
		}else if (token.type == TokenType.BracketClose && token.token==")"){
			//could be an if statement end
			tmint[0] = bracketPos(i,false);
			tmpToken = tokens.read(tmint[0]-1);
			if (i-tmint[0]!=1){
				//meaning it was NOT a `()` so increment in argC
				argC.set(argC.length-1,argC.readLast+1);
				//push the last argument, if any
				//calls.add("psh "~tokens.read(i-1).token);
			}
			calls.add("psh \""~tmpToken.token~'"');
			if (brackDepth>1){
				//is a function-as-arg
				calls.add("exa "~to!string(argC.readLast));
			}else{
				calls.add("exf "~to!string(argC.readLast));
			}
			argC.removeLast;
			brackDepth--;
		}
		if (token.type == TokenType.FunctionCall){
			if (token.token=="if" || token.token=="while"){
				addIfJump.add([blockDepth+1,0]);//0 will be later replaced
				if (token.token=="while"){
					addJump.add([blockDepth,calls.length-1]);
					//change while to if
					tmpToken.token = "if";
					tmpToken.type = TokenType.FunctionCall;
					tokens.set(i,tmpToken);
				}
			}
			//Deal with normal functions
		}
		if (token.type == TokenType.String){
			calls.add("psh "~token.token);
		}else if (token.type == TokenType.Number){
			calls.add("psh "~token.token);
		}else if (token.type == TokenType.Identifier){
			calls.add("psh \""~token.token~'"');
		}
		if (token.type == TokenType.Comma && brackDepth!=0){
			//increment in argC
			argC.set(argC.length-1,argC.readLast+1);
		}
	}

	delete calls;
	delete addJump;
	delete argC;
	return r;
}

public string[][string] compileQScript(List!string script, bool showOutput=false){
	string[][string] r;
	errors = new List!string;
	 if (!toTokens(script)){
		//was an error
		r["#errors"] = errors.toArray;
		goto skipIt;
	}
	if (!checkSyntax){
		r["#errors"] = errors.toArray;
		goto skipIt;
	}
	operatorsToFunctionCalls;
	r = toByteCode;
	debug{
		import std.stdio;
		if (showOutput){
			foreach(func; r.keys){
				writeln("ByteCode for ",func);
				foreach(inst; r[func]){
					writeln(inst);
				}
				write("Press Enter to continue...");
				readln;
			}
		}
	}

skipIt:
	delete errors;
	return r;
}

/*
Sample QScript:
main{
	newString someStringVar;//It's a string!
	double 
}
Interpreter instructions:
psh - push element(s) to stack
exf - execute function(s), don't push return to stack. take fName from stack, and argC from given args
exa - execute function(s), push retur to stack. take fName from stack, and argC from given args
jmp - jump to another index, and start execution from there, used in loops, and if
Rules:
An instruction can recieve dynamic amount of arguments! No limit
*/