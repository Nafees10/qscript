module lists;

import misc;
import std.file;
import std.stdio;
import std.conv:to;

class Tlist(T){
private:
	T[] list;
	uint taken=0;
public:
	void add(T dat){
		if (taken==list.length){
			list.length+=10;
		}
		taken++;
		list[taken-1] = dat;
	}
	void set(uint index, T dat){
		list[index]=dat;
	}
	void del(uint index, uint count=1){
		int i;
		int till=taken-count;
		for (i=index;i<till;i++){
			list[i] = list[i+count];
		}
		list.length-=count;
		taken-=count;
	}
	void shrink(uint newSize){
		list.length=newSize;
		taken = list.length;
	}
	void insert(uint index, T[] dat){
		int i;
		T[] ar,ar2;
		ar=list[0..index];
		ar2=list[index..taken];
		list.length=0;
		list=ar~dat~ar2;
		taken+=dat.length;
	}
	void saveFile(string s, T sp){
		File f = File(s,"w");
		uint i;
		for (i=0;i<taken;i++){
			f.write(list[i],sp);
		}
		f.close;
	}
	T read(uint index){
		return list[index];
	}
	T[] readRange(uint index,uint i2){
		return list[index..i2];
	}
	T readLast(){
		return list[taken-1];
	}
	int count(){
		return taken;
	}
	T[] toArray(){
		uint i;
		T[] r;
		if (taken!=-1){
			r.length=taken;
			for (i=0;i<taken;i++){
				r[i]=list[i];
			}
		}
		return r;
	}
	void loadArray(T[] dats){
		uint i;
		list.length=dats.length;
		taken=list.length;
		for (i=0;i<dats.length;i++){
			list[i]=dats[i];
		}
	}
	void clear(){
		list.length=0;
		taken=0;
	}
	int indexOf(T dat, int i=0, bool forward=true){
		if (forward){
			for (;i<taken;i++){
				if (list[i]==dat){break;}
			}
		}else{
			for (;i<taken;i--){
				if (list[i]==dat){break;}
			}
		}
		if (i==taken){i=-1;}
		return i;
	}
}

class TbinReader{
private:
	char[] stream;
	string[] functions;
	uint pos=0;
	uint total;
public:
	this(string[] dat=null, string fname = null, char[] strm=null){
		if (fname){
			stream = cast(char[])(std.file.read(fname,to!uint(getSize(fname))));
			total = stream.length;
		}else if (dat){
			uint i, lnth=0;
			for (i=0;i<dat.length;i++){
				lnth+=dat[i].length;
			}
			stream.length=lnth;
			uint wPos=0;
			for (i=0;i<dat.length;i++){
				stream[wPos..wPos+dat[i].length]=cast(char[])dat[i];
				wPos+=dat[i].length;
			}
			total = stream.length;
		}else if (strm){
			stream=strm;
			total = stream.length;
		}
	}
	char[] read(bool forward = true){
		uint i;
		char[] r;
		if (forward){
			for (i=pos+1;i<total;i++){
				if (stream[i]=='\000'){
					break;
				}
			}
			r= stream[pos..i];
			pos=i+1;
		}else{
			for (i=pos-1;i>=0;i--){
				if (stream[i]=='\000'){
					break;
				}
			}
			r= stream[i+1..pos+1];
			pos=i-1;
		}
		return r;
	}
	char[] toArray(){
		return stream;
	}
	void position(uint newPos){
		pos=newPos;
	}
	uint position(){
		return pos;
	}
	uint size(){
		return total;
	}
	char[][string] extractFunctions(){
		uint sPos;
		uint ePos;
		bool soe = true;

		string line, name;

		Tlist!string fNames = new Tlist!string;

		string[string] codes=[
			"fEnd":to!string(cast(char)8),
			"fStart":to!string(cast(char)1),
			"numArg":to!string(cast(char)4),
			"callEnd":to!string(cast(char)6),
		];

		char[][string] r;
		pos = 0;
		while (pos<total){
			if (soe){
				sPos=pos;
			}else{
				ePos=pos;
			}
			line = cast(string)read;
			if (line==codes["numArg"]){
				read;
			}else
			if (line==codes["fEnd"]){
				r[name]=stream[sPos..ePos+1];
				sPos=pos;
			}else
			if (line==codes["fStart"]){
				name = cast(string)read;
				fNames.add(name);
				soe=false;
			}
		}

		functions = fNames.toArray;
		delete fNames;
		return r;
	}
	string[] getFunctionNames(){
		return functions;
	}
}