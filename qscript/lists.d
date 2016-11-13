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
	void addArray(T[] dat){
		list.length = taken;
		list ~= dat;
		taken += dat.length;
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
	void removeLast(uint count = 1){
		taken -= count;
		if (list.length-taken>10){
			list.length=taken;
		}
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
	T[] readLast(uint count){
		return list[taken-count..taken];
	}
	int count(){
		return taken;
	}
	T[] toArray(){
		uint i;
		T[] r;
		if (taken!=-1){
			r.length=taken;
			for (i=0;i<taken;i++){//using a loop cuz simple '=' will just copy the pionter
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