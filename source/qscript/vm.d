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
	/// stores the stacks for each script defined function
	StaticStack[] _stacks;
	/// stores the current stack, being used by the function being curently executed
	StaticStack _stack;
	/// stack of stacks (to store stack of a function when that function calls another function)
	Stack!StaticStack _callStack;
	/// the StackBuilder which populates new stacks
	StackBuilder _stackMake;
	/// to manage allocation of extra stacks (recursion is a thing, need >1 stack for each function at a time for speed improvement)
	ExtraAlloc!StaticStack _stackMan;
protected:
	// byte code instructions

	/// execFuncS
	void execFuncS(QData[] args){
		// TODO

	}
	/// execFuncE
	void execFuncE(QData[] args){
		// TODO
	}

	// operators

	/// addInt
	void addInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = (*a).intVal + (*b).intVal;
	}
	/// addDouble
	void addDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).doubleVal = (*a).doubleVal + (*b).doubleVal;
	}
	/// subtractInt
	void subtractInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = (*a).intVal - (*b).intVal;
	}
	/// subtractDouble
	void subtractDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).doubleVal = (*a).doubleVal - (*b).doubleVal;
	}
	/// multiplyInt
	void multiplyInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = (*a).intVal * (*b).intVal;
	}
	/// multiplyDouble
	void multiplyDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).doubleVal = (*a).doubleVal * (*b).doubleVal;
	}
	/// divideInt
	void divideInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = (*a).intVal / (*b).intVal;
	}
	/// divideDouble
	void divideDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).doubleVal = (*a).doubleVal / (*b).doubleVal;
	}
	/// modInt
	void modInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = (*a).intVal % (*b).intVal;
	}
	/// modDouble
	void modDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).doubleVal = (*a).doubleVal % (*b).doubleVal;
	}
	/// concatArray
	void concatArray(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).arrayVal = (*a).arrayVal ~ (*b).arrayVal;
	}
	/// concatString
	void concatArray(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).strVal = (*a).strVal ~ (*b).strVal;
	}

	// comparison operators

	/// isSameInt
	void isSameInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).intVal == (*b).intVal);
	}
	/// isSameDouble
	void isSameDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).doubleVal == (*b).doubleVal);
	}
	/// isSameString
	void isSameString(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).strVal == (*b).strVal);
	}
	/// isLesserInt
	void isLesserInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).intVal < (*b).intVal);
	}
	/// isLesserDouble
	void isLesserDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).doubleVal < (*b).doubleVal);
	}
	/// isGreaterInt
	void isGreaterInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).intVal > (*b).intVal);
	}
	/// isGreaterDouble
	void isGreaterDouble(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)((*a).doubleVal > (*b).doubleVal);
	}
	/// notInt
	void notInt(QData[] args){
		QData* a = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)(!cast(bool)((*a).intVal));
	}
	/// andInt
	void andInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)(cast(bool)((*a).intVal) && cast(bool)((*b).intVal));
	}
	/// orInt
	void orInt(QData[] args){
		QData* a = _stack.read(), b = _stack.read();
		(*_stack.read!(false)()).intVal = cast(integer)(cast(bool)((*a).intVal) || cast(bool)((*b).intVal));
	}

 	// modifying stack

	/// write
	void write(QData[] args){
		*(_stack.readAt(args[0].intVal)) = *(_stack.read());
	}
	/// writeRef
	void writeRef(QData[] args){
		*(_stack.read()) = *(_stack.read());
	}
	/// makeRef
	void makeRef(QData[] args){
		_stack.makeRef(args[0].intVal, args[1].intVal);
		_stack.peek = args[1].intVal+1;
	}
	/// deref
	void deref(QData[] args){
		_stack.makeLiteral(_stack.peek, *(_stack.read()));
	}
	/// getRef
	void getRef(QData[] args){
		_stack.makeRef(_stack.peek, args[0].intVal);
	}
	/// getRefArray
	void getRefArray(QData[] args){
		const uinteger indexCount = args[1].intVal;
		QData* array = _stack.readAt(args[0].intVal);
		for (uinteger i = 0; i < indexCount; i ++){
			array = &(array.arrayVal[(*(_stack.read())).intVal]);
		}
		_stack.makeRef(_stack.peek, array);
	}
	/// getRefRefArray
	void getRefRefArray(QData[] args){
		const uinteger indexCount = args[1].intVal;
		QData* array = _stack.read();
		for (uinteger i = 0; i < indexCount; i ++){
			array = &(array.arrayVal[(*(_stack.read())).intVal]);
		}
		_stack.makeRef(_stack.peek, array);
	}
	/// peek
	void peek(QData[] args){
		_stack.peek = args[0].intVal;
	}

	// misc

	/// jump
	void jump(QData[] args){
		// TODO
		_stack.peek = args[1].intVal;
	}
	/// jumpIf
	void jumpIf(QData[] args){
		if (cast(bool)((*_stack.read()).intVal)){
			// TODO
			_stack.peek = args[1].intVal;
		}
	}
	/// jumpIfNot
	void jumpIfNot(QData[] args){
		if (!cast(bool)((*_stack.read()).intVal)){
			// TODO
			_stack.peek = args[1].intVal;
		}
	}
	/// doIf - obsolete, use jumpIfNot
	void doIf(QData[] args){
		// obsolete
	}
	/// return
	void returnInst(QData[] args){
		// TODO
	}

	// arrays

	/// setLen
	void setLen(QData[] args){
		(*_stack.read()).arrayVal.length = (*_stack.read()).intVal;
	}
	/// getLen
	void getLen(QData[] args){
		uinteger l = (*_stack.read()).arrayVal.length;
		*(_stack.read!(false)) = QData(cast(integer)l);
	}
	/// readElement
	void readElement(QData[] args){
		// obsolete
	}
	/// modifyArray
	void modifyArray(QData[] args){
		// obsolete
	}
	/// makeArray

	// strings

	/// strLen
	void strLen(QData[] args){
		uinteger l = (*_stack.read()).strVal.length;
		*(_stack.read!(false)) = QData(cast(integer)l);
	}
	/// readChar
	void readChar(QData[] args){
		QData r;
		r.strVal = cast(string)[(*_stack.read()).strVal[(*_stack.read()).intVal]];
		*(_stack.read!(false)) = r;
	}

	// type conversion

	/// strToInt
	void strToInt(QData[] args){
		QData r;
		r.intVal = to!integer((*_stack.read()).strVal);
		*(_stack.read!(false)) = r;
	}
	/// strToDouble
	void strToDouble(QData[] args){
		QData r;
		r.doubleVal = to!double((*_stack.read()).strVal);
		*(_stack.read!(false)) = r;
	}
	/// intToStr
	void intToStr(QData[] args){
		QData r;
		r.strVal = to!string((*_stack.read()).intVal);
		*(_stack.read!(false)) = r;
	}
	/// intToDouble
	void intToDouble(QData[] args){
		QData r;
		r.doubleVal = to!double((*_stack.read()).intVal);
		*(_stack.read!(false)) = r;
	}
	/// doubleToStr
	void doubleToStr(QData[] args){
		QData r;
		r.strVal = to!string((*_stack.read()).doubleVal);
		*(_stack.read!(false)) = r;
	}
	/// doubleToInt
	void doubleToInt(QData[] args){
		QData r;
		r.intVal = to!integer((*_stack.read()).doubleVal);
		*(_stack.read!(false)) = r;
	}
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
	/// creates a referenec at `index` to an external QData
	void makeRef(uinteger index, QData* to){
		_stack[index] = to;
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

	/// Returns: n number of elements from stack
	QData*[] read(bool incPeek=true)(uinteger n){
		QData*[] r = _stack[_peek .. _peek + n];
		static if (incPeek)
			_peek = _peek + n;
		return r;
	}
	/// Returns: 1 element from stack
	QData* read(bool incPeek=true)(){
		QData* r = _stack[_peek];
		static if (incPeek)
			_peek ++;
		return r;
	}

	/// Returns: element at index
	QData* readAt(uinteger index){
		return _stack[index];
	}

	/// increases peek by n
	void peekInc(uinteger n){
		_peek += n;
	}

	/// to set value of _peek
	@property uinteger peek(uinteger newVal){
		return _peek = newVal;
	}
	/// Returns: peek index
	@property uinteger peek(){
		return _peek;
	}
}