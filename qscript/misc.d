module misc;

import lists;
import std.math;
import std.stdio;
import std.conv:to;


alias scrFunction = Tqvar function(Tqvar[]);

union Tqvar{
	double d;
	string s;
	Tqvar[] array;
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