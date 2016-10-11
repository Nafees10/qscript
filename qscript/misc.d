module misc;

import lists;
import std.stdio;
import std.conv:to;

union Tqvar{
	double d;
	string s;
	Tqvar[] array;
}

uint decodeNum(string s){
	uint r=0;
	ubyte bt;
	for (uint i=0;i<s.length;i++){
		bt = cast(char)s[i];
		if (bt==255){
			r+=(cast(ubyte)s[i+1])*255;
			i++;
		}else{
			r+=(cast(ubyte)s[i]);
		}
	}
	return r;
}

string encodeNum(uint n){
	string r;

	uint count;
	ubyte extra;

	char c255=cast(char)255;

	if (n>=255){
		extra = n%255;
		count=n/255;
		while (count>255){
			n-=255*255;
			count-=255;
			r~=c255;
			r~=c255;
		}
		r~=c255;
		r~=cast(char)count;
		r~=cast(char)extra;
	}else{
		r~=cast(char)n;
		n=0;
	}
	return r;
}

string parseStr(string s){
	string r;
	for (uint i=0;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			switch (s[i]){
				case '\\':
					r~='\\';
					break;
				case 'n':
					r~='\n';
					break;
				case 'q':
					r~='"';
					break;
				default:
					break;
			}
		}else{
			r~=s[i];
		}
	}
	return r;
}

void writeArray(T)(T[] a,T sp){
	foreach(cur; a){
		write(cur,sp);
	}
}

T[] convArrayType(T,T2)(T2[] dat){
	T[] r;
	r= new T[dat.length];
	for (uint i=0;i<dat.length;i++){
		r[i]=to!T(dat[i]);
	}
	return r;
}

string[] fileToArray(string fname){
	File f = File(fname,"r");
	string[] r;
	string line;
	int i=0;
	r.length=0;
	while (!f.eof()){
		if (i+1>=r.length){
			r.length+=5;
		}
		line=f.readln;
		if (line.length>0 && line[line.length-1]=='\n'){
			line.length--;
		}
		r[i]=line;
		i++;
	}
	f.close;
	r.length = i;
	return r;
}

int brackEnd(Tlist!string list, int i, string s="(", string e=")"){
	uint dcs=1;
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

int brackStart(Tlist!string list, int i, string s="(", string e=")"){
	uint dcs=1;
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

T[] del(T)(T[] dat, uint pos, uint count=1){
	T[] ar1, ar2;
	ar1 = dat[0..pos];
	ar2 = dat[pos+count..dat.length];
	return ar1~ar2;
}

T[] insert(T)(T[] dat, T[] ins, uint pos){
	T[] ar1, ar2;
	ar1 = dat[0..pos];
	ar2 = dat[pos..dat.length];
	return ar1~ins~ar2;
}