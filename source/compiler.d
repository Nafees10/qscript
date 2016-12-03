module compiler;

import misc;
import lists;
import std.stdio;
import std.conv:to;
import std.algorithm:canFind;

private Tlist!string tokens;
private size_t[] origLine;

private void addEr(Tlist!string errors, size_t line, string msg){
	ptrdiff_t i;
	size_t lineno;
	for (i=0;i<origLine.length;i++){
		if (origLine[i]>line){break;}
	}
	lineno = i;

	errors.add(to!string(lineno)~':'~msg);
}

private ptrdiff_t strEnd(string s, size_t i){
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

private ptrdiff_t brackEnd(Tlist!string list, ptrdiff_t i, string s="(", string e=")"){
	size_t dcs=1;
	string token;
	for (i++;i<list.count;i++){
		if (dcs==0){
			break;
		}
		token=list.read(i);
		if (token==s){
			dcs++;
		}else if (token==e){
			dcs--;
		}
	}
	i--;
	if (dcs>0){
		i=-1;
	}
	return i;
}

private ptrdiff_t brackStart(Tlist!string list, ptrdiff_t i, string s="(", string e=")"){
	size_t dcs=1;
	string token;
	for (i--;i>=0;i--){
		if (dcs==0){
			break;
		}
		token=list.read(i);
		if (token==s){
			dcs--;
		}else if (token==e){
			dcs++;
		}
	}
	i++;
	if (dcs>0){
		i=-1;
	}
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

private string[] nextToken(size_t i){
	string token;
	string[] sp=[
		"/",
		"*",
		"+",
		"-",
		"%",
		";",
		"{",
		"}",
		")",
		",",
		"=",
		"==",
		"<",
		">",
		"<=",
		">=",
	];
	size_t frm=i;
	for (;i<tokens.count;i++){
		token = tokens.read(i);
		if (sp.hasElement(token)){
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

private string[] prevToken(ptrdiff_t i){
	string token;
	string[] sp=[
		"/",
		"*",
		"+",
		"-",
		"%",
		";",
		"{",
		"}",
		"(",
		",",
		"=",
		"==",
		"<",
		">",
		"<=",
		">=",
	];
	ptrdiff_t till=i+1;
	for (;i>=0;i--){
		token = tokens.read(i);
		if (sp.hasElement(token)){
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

private string[] restOfTheLine(ptrdiff_t i){
	string token;
	size_t frm=i;
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
	for (ptrdiff_t i=0;i<s.length;i++){
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
/*
private bool isVarName(size_t i){
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

private string[2] parseVarName(size_t i){
	string[2] r;//1 be varname 2 be index
	r[0]=tokens.read(i);
	if (tokens.read(i+1)=="["){
		r[1]=tokens.read(i+2);
	}else{
		r[1]="-1";
	}
	return r;
}
*/

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

private void addTokn(size_t count, size_t pos){
	size_t till = origLine.length;
	size_t i;
	for (i=0;i<till;i++){
		if (origLine[i]>=pos){break;}//change >= to = if not working
		//if (origLine[i]==pos){i--;break;}//Uncomment if done above
	}
	for (;i<till;i++){
		origLine[i]+=count;
	}
}

private void delTokn(size_t count, size_t pos){
	size_t till = origLine.length;
	size_t i;
	for (i=0;i<till;i++){
		if (origLine[i]>=pos){break;}//change >= to = if not working
		//if (origLine[i]==pos){i--;break;}//Uncomment if done above
	}
	for (;i<till;i++){
		origLine[i]-=count;
	}
}

private bool isNum(string s){
	bool r=false;
	size_t i;
	if (!"0123456789".canFind(s[0])){
		goto skipCheck;
	}
	if (s.length==1){
		r = true;
	}
	for (i=1;i<s.length;i++){
		if ("0123456789.".canFind(s[i])){
			r = true;
			break;
		}
	}
	skipCheck:
	return r;
}

private bool isAlphaNum(string s){
	ubyte aStart = cast(ubyte)'a';
	ubyte aEnd = cast(ubyte)'z';
	s = lowercase(s);
	bool r=true;
	ubyte cur;
	for (size_t i=0;i<s.length;i++){
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
private void removeWhitespace(Tlist!string scr){
	string line, newline;
	bool modified;
	size_t i, tmpint;
	for (size_t lineno=0;lineno<scr.count;lineno++){
		line=scr.read(lineno);
		modified=false;
		newline="";
		for (i=0;i<line.length;i++){
			if (line[i]=='"'){
				tmpint = strEnd(line,i);
				newline~=line[i..tmpint+1];
				i=tmpint+1;
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
	size_t i, lineno;
	ptrdiff_t tmpint;
	string token;
	string line;
	
	origLine.length=slst.count;
	
	Tlist!string scr = new Tlist!string;
	scr.loadArray(slst.toArray);
	removeWhitespace(scr);
	string sp="/*+-%~;{}(),=<>#$[]";
	
	size_t till = scr.count;
	
	tokens = new Tlist!string;
	for (lineno=0;lineno<till;lineno++){
		line = scr.read(lineno);
		token="";
		for (i=0;i<line.length;i++){
			if (line[i]=='"'){
				tmpint = strEnd(line,i);
				token~=line[i..tmpint+1];
				i=tmpint+1;
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

private Tlist!string compileOp(){
	size_t i;
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
			size_t bEnd;
			Tlist!string tmList = new Tlist!string;
			for (ptrdiff_t j=0;j<operand[0].length && operand[0][j]!="!?";j++){
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
			/*size_t pos = brackEnd(tokens,brackEnd(tokens,i+1)+1,"{","}");
			tokens.insert(pos, ["!again","(","foo",")",";"]);
			addTokn(1,pos);*/
		}else if (line in compareFunc){
			tokens.set(i,",");
			operand[0] = tokens.readRange(brackStart(tokens,i),i);
			operand[0] = prevToken(i-operand[0].length)~operand[0];
			operand[1] = tokens.readRange(i+1,brackEnd(tokens,i));

			if (operand[0].length==0 || operand[1].length==0){
				addEr(errors,i,"not enough operands for "~line~" operator");
			}

			//<TYPE CHECKING>
			if (operand[0].length==1 || operand[1].length==1){
				ubyte[2] opType;
				//Put operand types ptrdiff_to opType[...];
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
				for (size_t j=0;j<operand[0].length;j++){
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
				//tokens.set(i+2,'"'~tokens.read(i+2)~'"');
				size_t j = i+2, till = tokens.count;
				operand[0].length = 1;
				if (tokens.read(j-1)=="("){
					for (;j<till;j++){
						operand[0][0] = tokens.read(j);
						if (operand[0][0]==")"){
							break;
						}
						tokens.set(j,'"'~operand[0][0]~'"');
					}
				}
			}
		}else
		if (line=="(" && i>0){//delette unnecessary brackets
			tmstr[0] = tokens.read(i-1);
			tmstr[1] = tokens.read(brackEnd(tokens,i)+1);
			if ((tmstr[0]==","||tmstr[0]=="(") && (tmstr[1]==","||tmstr[1]==")")){
				size_t delPos = brackEnd(tokens,i);
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
			size_t toIns = i-operand[0].length;
			tokens.insert(toIns,["![","("]);
			addTokn(2,toIns);
		}
	}
	return errors;
}

private string[][string] compileByte(){
	size_t i, till, argC, j;
	string token, tmStr, fName;
	Tlist!string output = new Tlist!string;
	Tlist!size_t blockDepth = new Tlist!size_t;
	Tlist!(size_t[2]) addJmp = new Tlist!(size_t[2]);
	Tlist!(size_t[2]) addIfPos = new Tlist!(size_t[2]);
	size_t[2] tmpint;

	string[][string] r;

	till = tokens.count;
	for (i=0;i<till;i++){
		token = tokens.read(i);
		if (token=="{"){
			if (blockDepth.count==0){
				fName = tokens.read(i-1);
			}
			blockDepth.add(i);
		}else
		if (token=="}"){
			j = blockDepth.count-1;
			//JMP has to be added first, or it'll become an infinite loop n the interpreter, as the !if
			//will keep landing on JMP
			if (addJmp.count>0){
				tmpint = addJmp.readLast;
				if (tmpint[1]==/*blockDepth.count*/j){
					//!while's block is ending
					output.add("JMP "~to!string(tmpint[0]));
					addJmp.removeLast;
				}
			}
			if (addIfPos.count>0){
				tmpint = addIfPos.readLast;
				if (tmpint[1] == /*blockDepth.count*/j){
					//!if statement's block is ending
					output.set(tmpint[0],"PSH "~to!string(output.count-1));
					//-1 cause after execution of if, +1 will be done by interpreter.
					addIfPos.removeLast;
				}
			}
			if (/*blockDepth.count*/j==/*1*/0){
				r[fName]=output.toArray;
				output.clear;
				fName = null;
			}
			blockDepth.removeLast;
		}else
		if (token==")"){
			tmStr = tokens.read(brackStart(tokens,i)-1);
			if (tmStr=="!if"){
				tmpint = [output.count,blockDepth.count];
				output.add("PSH foo");
				addIfPos.add(tmpint);
			}
			//count the args:
			string tmStr2;
			argC=0;
			size_t end = brackStart(tokens,i);
			if (!(i-end==1) && !(tmStr=="!if")){
				for (j=i-1;j>=end;j--){
					tmStr2 = tokens.read(j);
					if (tmStr2==")"){
						j = brackStart(tokens,j);
						continue;
					}
					if (tmStr2=="(" || tmStr2==","){
						argC++;
					}
				}
			}else{
				if (i-end==1){
					argC = 0;
				}else{
					argC = 2;
				}
			}
			output.add("PSH "~to!string(argC));
			output.add("EXE \""~tmStr~'"');
		}else
		if (token=="!while"){
			tmpint = [output.count-1,blockDepth.count];//interptreter will do +1
			addJmp.add(tmpint);
			tokens.set(i,"!if");
		}else
		if (token==";"){
			output.add("CLR 1");
			//Cause some functions' return won't be used, unless CLR-ed, it'll waste memory
		}else
		if (isNum(token)){
			//is a number type argument
			output.add("PSH "~token);
		}else
		if (token[0]=='"'){
			//is a string type argument
			output.add("PSH "~token);
		}
	}
	//free the memory
	delete output;
	delete blockDepth;
	delete addJmp;
	delete addIfPos;
	return r;
}


string[][string] compileQScript(Tlist!string script, bool writeOutput = false){
	toTokens(script);
	Tlist!string err;
	err = compileOp();
	string[][string] r; 
	r["#####"] = err.toArray;
	delete err;
	if (r["#####"].length==0){
		r = null;
		r.remove("#####");
		r = compileByte();
		debug{
			if (writeOutput){
				foreach(key; r.keys){
					writeln(key,":");
					writeArray(r[key],"\n");
				}
			}
		}
	}
	delete tokens;
	return r;
}