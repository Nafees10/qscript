/+
classes and stuff for the VM:
converting bytecode to function_pointers and running it
+/
module qscript.vm;

import qscript.compiler.compiler;
import qscript.compiler.bytecode;
import qscript.qscript : QData;
import qscript.compiler.misc : stringToQData;
import std.conv : to;
import utils.lists;
import utils.misc;

// TODO write this
/// Class containing the VM (instructions, functions to load byte code into VM, and fucntions to execute the byte code in this VM)
package class QVM{
private:

}

/// stores instructions to build a StaticStack. Using this to populate a stack is faster (or atleast that's the aim)
struct StackBuilder{
	/// stores the elements that are references to other elements. Index is the element that is reference, val is element to reference
	private uinteger[uinteger] _refs;
	/// stores the elements that are literals.
	private QData[uinteger] _literals;
	/// stores the indexes of elements that are to be created, but no value assigned
	private uinteger[] _empty;
	/// stores the length of the stack;
	private uinteger _length;
	/// populates a StaticStack
	/// 
	/// Returns: the populated StaticStack
	StaticStack populate(){
		StaticStack r = new StaticStack(_length);
		// first comes the empty ones
		foreach (i; _empty){
			r.makeEmpty(i);
		}
		// now the literals
		foreach (i, value; _literals){
			r.makeLiteral(i, value);
		}
		// finally the refs
		foreach (i, refTo; _refs){
			r.makeRef(i, refTo);
		}
		return r;
	}
	/// prepares this StackBuilder to build stack for a specific Function, using it's `ByteCode.Data[]`
	this(ByteCode.Data[] stack){
		_length = stack.length;
		/// stores list of empty elements
		List!uinteger emptyElements = new List!uinteger;
		foreach (i, element; stack){
			if (element.type == ByteCode.Data.Type.Empty){
				emptyElements.append(i);
			}else if (element.type == ByteCode.Data.Type.Literal){
				_literals[i] = stringToQData(element.literal);
			}else if (element.type == ByteCode.Data.Type.Reference){
				_refs[i] = element.refIndex;
			}
		}
		_empty = emptyElements.toArray;
		.destroy(emptyElements);
	}
}

/// To store the new "static stack" where the elements are populated before execution begins
private class StaticStack{
private:
	/// the array of pointers which is the actual stack
	QData*[] _stack;
	/// the index where the next element will be written to/read from
	uinteger _peek;
public:
	/// constructor
	this(uinteger length){
		_stack.length = length;
		_peek = 0;
	}
	/// destructor
	~this(){
		foreach (ptr; _stack){
			.destroy(*ptr);
		}
	}
	/// creates a reference at `index` to element at `to`
	void makeRef(uinteger index, uinteger to){
		_stack[index] = _stack[to];
	}
	/// creates an empty element at `index`
	void makeEmpty(uinteger index){
		_stack[index] = new QData;
	}
	/// creates an empty element at `index` and assigns it a value
	void makeLiteral(uinteger index, QData value){
		_stack[index] = new QData;
		*(_stack[index]) = value;
	}
	// functions to read/write to stack

	/// reads n number of elements
	QData*[] read(bool incPeek=true)(uinteger n){
		QData*[] r = _stack[_peek .. _peek + n];
		static if (incPeek)
			_peek = _peek + n;
		return r;
	}
	/// reads 1 element
	QData* read(bool incPeek=true)(){
		QData* r = _stack[_peek];
		static if (incPeek)
			_peek ++;
		return r;
	}
}