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
	string[] stream;
	uint pos=0;
	uint total;
public:
	this(string[] dat=null, string fname = null){
		if (fname){
			char[] fContents = cast(char[])(std.file.read(fname,to!uint(getSize(fname))));
			uint i, till = fContents.length, readFrom;
			Tlist!string rStream = new Tlist!string;
			for (i=0;i<till;i++){
				if (fContents[i]=='\000' && i>readFrom){
					rStream.add(cast(string)fContents[readFrom..i]);//not i+1, as we don't want \000
					readFrom = i+1;//again, i+1 to skip the \000
					i++;//In case the next char is \000 as a number, not as sp
				}
			}
			delete fContents;
			stream = rStream.toArray;
			delete rStream;
			total = stream.length;
		}else if (dat){
			Tlist!string rStream = new Tlist!string;
			rStream.loadArray(dat);
			uint i, till = rStream.count;
			for (i=0;i<till;i++){
				if (rStream.read(i)=="\004"){
					i++;
					continue;
				}
				if (rStream.read(i)=="\000"){
					rStream.del(i);
					till--;
				}
			}
			stream = rStream.toArray;
			delete rStream;
			total = stream.length;
		}
	}
	string read(){
		uint i;
		string r;
		r = stream[pos];
		pos++;
		return r;
	}
	string[] toArray(){
		return stream;
	}
	@property uint position(uint newPos){
		return pos=newPos;
	}
	@property uint position(){
		return pos;
	}
	uint size(){
		return total;
	}
	string[][string] extractFunctions(){//This has to be called before reading functions[]
		uint startPos;//index from where a function is starting
		uint i;
		string name = null;//Name of current function
		string[string] codes=[
			"fEnd":cast(string)[8],
			"fStart":cast(string)[1],
			"numArg":cast(string)[4],
			"endAt":cast(string)[7],
			"startAt":to!string(cast(char)9)
		];
		string[][string] r;

		for (i=0;i<total;i++){
			if (stream[i]==codes["numArg"] || stream[i]==codes["startAt"] ||
				stream[i]==codes["endAt"]){
				i+=2;//+=1 = the number, which can be \000
			}

			if (stream[i]==codes["fStart"]){
				name = stream[i+1];
				startPos = i+2;//+1 = functionName;+2 = start of function Body

			}
			if (stream[i]==codes["fEnd"]){
				r[name]=stream[startPos..i];
				name = null;
			}
		}
		return r;

	}
}