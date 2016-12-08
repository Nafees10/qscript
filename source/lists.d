module lists;

import misc;
import std.file;
import std.stdio;
//import std.conv:to;

class Tlist(T){
private:
	T[] list;
	size_t taken=0;
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
	void set(size_t index, T dat){
		list[index]=dat;
	}
	void del(size_t index, size_t count=1){
		ptrdiff_t i;
		ptrdiff_t till=taken-count;
		for (i=index;i<till;i++){
			list[i] = list[i+count];
		}
		list.length-=count;
		taken-=count;
	}
	void removeLast(size_t count = 1){
		taken -= count;
		if (list.length-taken>10){
			list.length=taken;
		}
	}
	void shrink(size_t newSize){
		list.length=newSize;
		taken = list.length;
	}
	void insert(size_t index, T[] dat){
		ptrdiff_t i;
		T[] ar,ar2;
		ar=list[0..index];
		ar2=list[index..taken];
		list.length=0;
		list=ar~dat~ar2;
		taken+=dat.length;
	}
	void saveFile(string s, T sp){
		File f = File(s,"w");
		size_t i;
		for (i=0;i<taken;i++){
			f.write(list[i],sp);
		}
		f.close;
	}
	T read(size_t index){
		return list[index];
	}
	T[] readRange(size_t index,size_t i2){
		return list[index..i2];
	}
	T readLast(){
		return list[taken-1];
	}
	T[] readLast(size_t count){
		return list[taken-count..taken];
	}
	ptrdiff_t count(){
		return taken;
	}
	T[] toArray(){
		size_t i;
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
		size_t i;
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
	ptrdiff_t indexOf(T dat, ptrdiff_t i=0, bool forward=true){
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

class Tqstack(T){
private:
	T[] list;
	size_t pos = 0;
public:
	this(size_t size=512){
		list = new T[size];
	}
	void push(T dat){
		pos ++;
		list[pos] = dat;
	}
	void push(T[] dat){//This one is untested
		pos++;
		list[pos..pos+dat.length] = dat;
		pos += dat.length-1;
	}
	T pop(){
		T r;
		r = list[pos];
		pos--;
		return r;
	}
	T[] pop(size_t count){
		T[] r;
		size_t tmp = pos - count;
		r = list[tmp+1..pos+1];
		pos -= count;
		return r;
	}
	void clear(){
		pos = 0;
	}
	@property size_t position(){
		return pos;
	}
	@property size_t position(size_t newPos){
		return pos=newPos;
	}
}
