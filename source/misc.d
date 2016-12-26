module misc;

import lists;
import std.math;
import std.stdio;
import std.conv:to;

alias integer = ptrdiff_t;
alias uinteger = size_t;

string parseStr(string s){
	string r;
	for (uinteger i=0;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			switch (s[i]){
				case '\\':
					r~='\\';
					break;
				case 'n':
					r~='\n';
					break;
				case '"':
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

T max (T)(T[] dat){
	T highest = dat[0];
	foreach(key; dat){
		if (highest<key){
			highest = key;
		}
	}
	return highest;
}

T[] convArrayType(T,T2)(T2[] dat){
	T[] r;
	r= new T[dat.length];
	for (uinteger i=0;i<dat.length;i++){
		r[i]=to!T(dat[i]);
	}
	return r;
}

string[] fileToArray(string fname){
	File f = File(fname,"r");
	string[] r;
	string line;
	integer i=0;
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

T[] del(T)(T[] dat, uinteger pos, uinteger count=1){
	T[] ar1, ar2;
	ar1 = dat[0..pos];
	ar2 = dat[pos+count..dat.length];
	return ar1~ar2;
}

T[] insert(T)(T[] dat, T[] ins, uinteger pos){
	T[] ar1, ar2;
	ar1 = dat[0..pos];
	ar2 = dat[pos..dat.length];
	return ar1~ins~ar2;
}
