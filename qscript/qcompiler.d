module qcompiler;

import misc;
import lists;
import std.stdio;
import std.conv:to;
import std.algorithm:canFind;

private Tlist!string tokens;
private uint[] origLine;

private void addEr(Tlist!string errors, uint line, string msg){
	uint till = origLine.length;
	int i;
	uint lineno;
	for (i=0;i<till;i++){
		if (origLine[i]>=line){break;}
	}
	lineno = i+1;
	//Get position of error
	/*uint pos;
	if (i>0){
		i = origLine[i-1];
	}
	for (;i<line;i++){
		pos+=tokens.read(i).length;
	}*/


	errors.add(to!string(lineno)/*~','~to!string(pos)*/~':'~msg);
}

private int strEnd(string s, uint i){
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

private string[] nextToken(uint i){
	string token;
	bool[string] sp=[
		"/":true,
		"*":true,
		"+":true,
		"-":true,
		"%":true,
		";":true,
		"{":true,
		"}":true,
		")":true,
		",":true,
		"=":true,
		"==":true,
		"<":true,
		">":true,
		"<=":true,
		">=":true,
	];
	uint frm=i;
	for (;i<tokens.count;i++){
		token = tokens.read(i);
		if (token in sp){
			//i--;
			break;
		}
		if (token=="("||token=="["){
			if (token=="("){
				i=brackEnd(tokens,i);
				break;
			}else{
				i=brackEnd(tokens,i,"[","]");
			}
			i++;
		}
	}
	return tokens.toArray[frm..i];
}

private string[] prevToken(int i){
	string token;
	bool[string] sp=[
		"/":true,
		"*":true,
		"+":true,
		"-":true,
		"%":true,
		";":true,
		"{":true,
		"}":true,
		"(":true,
		",":true,
		"=":true,
		"==":true,
		"<":true,
		">":true,
		"<=":true,
		">=":true,
	];
	int till=i+1;
	for (;i>=0;i--){
		token = tokens.read(i);
		if (token in sp){
			//i--;
			break;
		}
		if (token==")"){
			i=brackStart(tokens,i);
		}else if (token=="]"){
			i=brackStart(tokens,i,"[","]");
		}
	}
	return tokens.toArray[i+1..till];
}

private string[] restOfTheLine(int i){
	string token;
	uint frm=i;
	for (;i<tokens.count;i++){
		token = tokens.read(i);
		if (token==";"){
			break;
		}
		if (token=="(" || token=="{"){
			if (token=="("){
				i=brackEnd(tokens,i);
			}else{
				i=brackEnd(tokens,i,"{","}");
			}
		}
	}
	return tokens.toArray[frm..i+1];
}

private string lowercase(string s){
	string tmstr;
	ubyte tmbt;
	for (int i=0;i<s.length;i++){
		tmbt = cast(ubyte) s[i];
		if (tmbt>=65 && tmbt<=90){
			tmbt+=32;
			tmstr ~= cast(char) tmbt;
		}else{
			tmstr ~= s[i];
		}
	}
	
	return tmstr;
}

private bool isVarName(uint i){
	bool r=true;
	if (!isAlphaNum(tokens.read(i))){
		r=false;
	}
	if (tokens.read(i+1)=="["){
		if (tokens.read(brackEnd(tokens,i+1,"[","]")+1)=="="){
			r=false;
		}
	}
	return r;
}

string[2] parseVarName(uint i){
	string[2] r;//1 be varname 2 be index
	r[0]=tokens.read(i);
	if (tokens.read(i+1)=="["){
		r[1]=tokens.read(i+2);
	}else{
		r[1]="-1";
	}
	return r;
}

private void removeWhitespace(Tlist!string scr){
	string line, newline;
	bool modified;
	uint i, tmint;
	for (uint lineno=0;lineno<scr.count;lineno++){
		line=scr.read(lineno);
		modified=false;
		newline="";
		for (i=0;i<line.length;i++){
			if (line[i]=='"'){
				tmint = strEnd(line,i);
				newline~=line[i..tmint+1];
				i=tmint+1;
			}
			if (line[i]=='\t'){
				continue;
			}else if(i<line.length-1 && line[i..i+2]=="//"){
				break;
			}else if (i<line.length-1 && line[i..i+2]=="  "){
				continue;
			}else{
				newline~=line[i];
			}
		}
		scr.set(lineno,newline);
	}
}

private void toTokens(Tlist!string slst){
	uint i, lineno;
	int tmint;
	string token;
	string line;

	origLine.length=slst.count;

	Tlist!string scr = new Tlist!string;
	scr.loadArray(slst.toArray);
	removeWhitespace(scr);
	string sp="/*+-%~;{}(),=<>#$[]";

	uint till = scr.count;

	tokens = new Tlist!string;
	for (lineno=0;lineno<till;lineno++){
		line = scr.read(lineno);
		token="";
		for (i=0;i<line.length;i++){
			if (line[i]=='"'){
				tmint = strEnd(line,i);
				token~=line[i..tmint+1];
				i=tmint+1;
			}
			if (line[i]==' '){
				if (token!=""){
					tokens.add(token);
					token="";
				}
				continue;
			}
			if (sp.canFind(line[i])){
				if (token!=""){
					tokens.add(token);
				}
				token="";
				if (i<line.length-1&&"=<>".canFind(line[i+1])&&"=<>".canFind(line[i])){
					tokens.add(line[i..i+2]);
					i++;
				}else{
					tokens.add(to!string(line[i]));
				}
				continue;
			}
			token~=line[i];
			if (i==line.length-1 && token!=""){
				tokens.add(token);
			}
		}
		origLine[lineno]=tokens.count-1;
	}
}

private ubyte getOpType(string[] operand){
	ubyte r=2;
	if (operand.length>1){
		r=2;
	}else if (operand.length>0){
		if (operand[0][0]=='"'){
			r=1;
		}else if (isNum(operand[0])){
			r=0;
		}else{
			r=2;
		}
	}
	return r;
}

private string[] parseNum(string num){
	uint i;
	string[] r=[num];
	string newNum;
	for (i=0;i<num.length;i++){
		if (num[i]=='.'){
			break;
		}
		newNum~=num[i];
	}
	if (i<num.length){
		uint divBy=1;
		for (i++;i<num.length;i++){
			divBy*=10;
			newNum~=num[i];
		}
		r=["!/","(",newNum,",",to!string(divBy),")"];
	}
	return r;
}

private void addTokn(uint count, uint pos){
	uint till = origLine.length;
	uint i;
	for (i=0;i<till;i++){
		if (origLine[i]>pos){break;}
		if (origLine[i]==pos){i--;break;}
	}
	for (;i<till;i++){
		origLine[i]+=count;
	}
}

private void delTokn(uint count, uint pos){
	uint till = origLine.length;
	uint i;
	for (i=0;i<till;i++){
		if (origLine[i]>pos){break;}
		if (origLine[i]==pos){i--;break;}
	}
	for (;i<till;i++){
		origLine[i]-=count;
	}
}

private Tlist!string compileOp(){
	uint i;
	string line;
	string[2] tmstr;
	string[][2] operand;
	Tlist!string errors = new Tlist!string;

	string[string] mthFunc=[
		"/":"!/",
		"*":"!*",
		"+":"!+",
		"-":"!-",
		"%":"!%",
		"~":"!~"
	];
	string[string] compareFunc=[
		"<":"!<",
		">":"!>",
		"<=":"!<=",
		">=":"!>=",
		"==":"!==",

	];
	string[string] toReplace=[
		"if":"!if",
		"again":"!again",
		"string":"!string",
		"double":"!double",
		"getLength":"!getLength"
	];

	for (i=0;i<tokens.count;i++){
		line = tokens.read(i);
		//Error catching:
		//unclosed/unopened brackets/blocks
		if (line=="(" && brackEnd(tokens,i)==-1){
			addEr(errors,i,"unclosed bracket");
		}else if (line==")" && brackStart(tokens,i)==-1){
			addEr(errors,i,"unopened bracket");
		}else if(line=="{" && brackEnd(tokens,i,"{","}")==-1){
			addEr(errors,i,"unclosed block");
		}else if(line=="}" && brackStart(tokens,i,"{","}")==-1){
			addEr(errors,i,"unopened block");
		}
		//Skip compilation if has errors:
		if (errors.count>0){
			continue;
		}
		//compiling:
		if (line in mthFunc){
			tokens.set(i,",");
			operand[0]=prevToken(i-1);
			operand[1]=nextToken(i+1);

			if (operand[0].length==0 && line=="-"){
				operand[0]=["0"];
				tokens.insert(i,["0"]);
				i++;
			}
			if (operand[0].length==0 || operand[1].length==0){
				addEr(errors,i,"not enough operands for "~line~" operator");
			}

			//<TYPE CHECKING>
			if (operand[0].length==1 || operand[1].length==1){
				ubyte[2] opType;
				//Put operand types into opType[...];
				opType[0]=getOpType(operand[0]);
				opType[1]=getOpType(operand[1]);
				//Do actual type checking-
				if (line=="~"){
					if (opType[0]!=2 && opType[1]!=2 && opType[0]+opType[1]==2){
						addEr(errors,i,"incompatible types for "~line~" operator");
					}
				}else{
					//Make sure no strings get through maths!
					if (opType[0]==1 || opType[1]==1){
						addEr(errors,i,"incompatible types for "~line~" operator");
					}
				}
			}
			//<</TYPE CHECKING>

			tokens.insert(i-operand[0].length,[mthFunc[line],"("]);
			tokens.insert(i+operand[1].length+3,[")"]);
			addTokn(3,i);
			i-=operand[0].length+1;
		}else if(line=="="){
			operand[1] = restOfTheLine(i+1);
			operand[1].length--;
			operand[0] = prevToken(i-1);
			tokens.set(i,",");
			tokens.del((i-operand[0].length),operand[0].length);
			i -= operand[0].length-1;
			delTokn(operand[0].length,i-operand[0].length+1);
			uint bEnd;
			Tlist!string tmList = new Tlist!string;
			for (int j=0;j<operand[0].length && operand[0][j]!="!?";j++){
				if (operand[0][j]=="!["){
					tmList.loadArray(operand[0]);
					bEnd = brackEnd(tmList,j+1);
					operand[0]=del(operand[0],bEnd);
					operand[0]=del(operand[0],j,2);
					j=-1;
				}
			}
			delete tmList;
			operand[0]=del(operand[0],0,2);
			operand[0]=del(operand[0],1);

			tokens.insert(i+operand[1].length,[")"]);
			addTokn(1,i+operand[1].length);
			tokens.insert(i-1,["!=","("]~operand[0]);
			addTokn(2+operand[0].length,i-1);

			i-=operand[0].length-2;
		}else if(line in toReplace){
			tokens.set(i,toReplace[line]);
		}else if (line=="while"){
			tokens.set(i,"!while");
			tokens.insert(brackEnd(tokens,brackEnd(tokens,i+1)+1,"{","}"),
				["again","(",")",";"]);
		}else if (line in compareFunc){
			tokens.set(i,",");
			operand[0]=tokens.readRange(brackStart(tokens,i),i);
			operand[0] = prevToken(i-operand[0].length)~operand[0];
			operand[1]=tokens.readRange(i+1,brackEnd(tokens,i));

			if (operand[0].length==0 || operand[1].length==0){
				addEr(errors,i,"not enough operands for "~line~" operator");
			}

			//<TYPE CHECKING>
			if (operand[0].length==1 || operand[1].length==1){
				ubyte[2] opType;
				//Put operand types into opType[...];
				opType[0]=getOpType(operand[0]);
				opType[1]=getOpType(operand[1]);
				//Do actual type checking
				if (line=="=="){
					if (opType[0]!=2 && opType[1]!=2 && opType[0] != opType[1]){
						addEr(errors,i,"incompatible types for "~line~" operator");
					}
				}else{
					//Make sure no strings get through!
					if (opType[0]==1 || opType[1]==1){
						addEr(errors,i,"incompatible types for "~line~" operator");
					}
				}
			}
			//<</TYPE CHECKING>

			tokens.insert(i-operand[0].length+1,[compareFunc[line],"("]);
			tokens.insert(i+operand[1].length+3,[")"]);
			addTokn(3,i);
		}else if (line=="new" || line=="setLength"){
			tokens.set(i,"!"~line);
			if (line=="setLength"){
				operand[0] = nextToken(i+2);
				tokens.del(i+2,operand[0].length);
				delTokn(operand[0].length,i+2);
				Tlist!string tmp = new Tlist!string;
				for (uint j=0;j<operand[0].length;j++){
					if (operand[0][j]=="["){
						operand[0][j] = ",";
						tmp.loadArray(operand[0]);
						j = brackEnd(tmp,j,"[","]");
						tmp.del(j);
						operand[0] = tmp.toArray;
						j--;
					}
				}
				delete tmp;
				operand[0][0] = '"'~operand[0][0]~'"';
				tokens.insert(i+2,operand[0]);
				addTokn(operand[0].length,i+2);
			}else{
				tokens.set(i+2,'"'~tokens.read(i+2)~'"');
			}
		}else
		if (line=="(" && i>0){
			tmstr[0] = tokens.read(i-1);
			tmstr[1] = tokens.read(brackEnd(tokens,i)+1);
			if ((tmstr[0]==","||tmstr[0]=="(") && (tmstr[1]==","||tmstr[1]==")")){
				uint delPos = brackEnd(tokens,i);
				tokens.del(delPos);
				delTokn(1,delPos);
				tokens.del(i);
				delTokn(1,i);
			}
		}else if (isAlphaNum(line) && !"0123456789".canFind(line[0]) && i<tokens.count-1){
			tmstr[0]=tokens.read(i+1);
			if (tmstr[0]!="(" && tmstr[0]!="{"){
				tokens.del(i);
				tokens.insert(i,["!?","(",'"'~line~'"',")"]);

				addTokn(3,i);
			}
		}else if (line=="["){
			operand[0]=prevToken(i-1);
			tokens.set(brackEnd(tokens,i,"[","]"),")");
			tokens.set(i,",");
			uint toIns = i-operand[0].length;
			tokens.insert(toIns,["![","("]);
			addTokn(2,toIns);
		}
	}
	return errors;
}

private bool isNum(string s){
	bool r=false;
	if ("0123456789.".canFind(s[0])){
		r=true;
	}
	return r;
}

private bool isAlphaNum(string s){
	ubyte aStart = cast(ubyte)'a';
	ubyte aEnd = cast(ubyte)'z';
	s = lowercase(s);
	bool r=true;
	ubyte cur;
	for (uint i=0;i<s.length;i++){
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

private void compileByte(){
	Tlist!int curlPos= new Tlist!int;
	Tlist!string r=new Tlist!string;
	uint i;
	string line;
	
	string[string] codes=[
		"sp":to!string(cast(char)0),
		"function":to!string(cast(char)1),
		"call":to!string(cast(char)2),
		"numArg":to!string(cast(char)4),
		"strArg":to!string(cast(char)5),
		"end":to!string(cast(char)6),
		"endAt":to!string(cast(char)7),
		"endF":to!string(cast(char)8),
		"startAt":to!string(cast(char)9)
	];
	
	uint till = tokens.count;
	for (i=0;i<till;i++){
		line = tokens.read(i);
		if (line=="("){
			r.add(codes["call"]);
			r.add(codes["sp"]);
			r.add(tokens.read(i-1));
			r.add(codes["sp"]);
		}else
		if(line==")"){
			r.add(codes["end"]);
			r.add(codes["sp"]);
		}else
		if (line=="{"){
			if (curlPos.count==0){
				r.add(codes["function"]);
				r.add(codes["sp"]);
				r.add(tokens.read(i-1));
				r.add(codes["sp"]);
				//notice that the line below is curlPos.add, not r.add! It caused me a huge confusion!
				curlPos.add(r.count-2);
			}else{
				r.add(codes["endAt"]);
				r.add(codes["sp"]);
				r.add("{");//It's just a placeholder, will be replaced when '}' is reached
				r.add(codes["sp"]);
				curlPos.add(r.count-2);
			}
		}else
		if (line=="}"){
			if (curlPos.count==1){
				r.add(codes["endF"]);
				r.add(codes["sp"]);
			}else{
				uint sPos = curlPos.readLast;

				uint j, lnth, end;
				lnth = 0;
				end=r.count;
				string ln;
				for (j=sPos+1;j<end;j++){
					lnth+=r.read(j).length;
				}
				lnth+=2;
				r.set(sPos,to!string(encodeNum(lnth)));

				r.add(codes["startAt"]);
				r.add(codes["sp"]);
				r.add(to!string(encodeNum(lnth)));
				r.add(codes["sp"]);
			}
			curlPos.del(curlPos.count-1);
		}else
		if (line[0]=='"'){
			r.add(codes["strArg"]);
			r.add(codes["sp"]);
			r.add(parseStr(line[1..line.length-1]));
			r.add(codes["sp"]);
		}else
		if (isNum(line)){
			if (line.canFind('.')){
				tokens.del(i);
				tokens.insert(i,parseNum(line));
				till = tokens.count;
				i-=1;
			}else{
				r.add(codes["numArg"]);
				r.add(codes["sp"]);
				r.add(encodeNum(to!uint(line)));
				r.add(codes["sp"]);
			}
		}
	}
	delete tokens;
	delete curlPos;
	tokens = r;
}

string[] compile(Tlist!string script){
	toTokens(script);
	Tlist!string err;
	err = compileOp();
	string[] r = err.toArray;
	delete err;
	if (r.length==0){
		debug{
			tokens.saveFile("/home/nafees/Desktop/q.tokens","\n");
		}
		compileByte();
		debug{
			tokens.saveFile("/home/nafees/Desktop/q.compiled","");
		}
		script.loadArray(tokens.toArray);
	}
	delete tokens;
	return r;
}