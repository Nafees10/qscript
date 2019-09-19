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

/// Instruction for QVM
alias QVMInst = void delegate(QData[]); 
/// Function for QVM. Takes arguemnts in QData[], returns QData
alias QVMFunction = QData delegate(QData[]);

/// Class containing the VM (instructions, functions to load byte code into VM, and fucntions to execute the byte code in this VM)
package class QVM{
private:
	/// stores the current stack, being used by the function being curently executed
	StaticStack _stack;
	/// stack of stacks (to store stack of a function when that function calls another function)
	Stack!StaticStack _callStack;
	/// the StackBuilder for each function
	StackBuilder[] _stackMakers;
	/// to manage allocation of extra stacks
	ExtraAlloc!StaticStack[] _stackAlloc;
	/// stores the instructions for each function (index being function id)
	QVMInst*[][] _functions;
	/// stores the arguemnts for instuctions for each function (index being function id)
	QData[][][] _functionInstArgs;
	/// stores the instructions for the function being currently executed
	QVMInst*[] _instructions;
	/// stores the arguments for instructions of function being currently executed
	QData[][] _instArgs;
	/// the instruction which will be executed next, null to terminate.
	/// the pointer will be incremented by 1 before every execution
	QVMInst* _nextInst;
	/// Index of next instruction to execute
	uinteger _nextInstIndex;
	/// the return value of function
	QData* _returnVal;
	/// function for which a stack might be allocated soon by an ExtraAlloc
	uinteger _expectedFuncCall;
	/// stores external functions
	/// function used to allocate new stacks
	StaticStack _allocFuncStack(){
		return _stackMakers[_expectedFuncCall].populate;
	}
protected:
	// byte code instructions

	/// execFuncS
	void execFuncS(QData[] args){
		_expectedFuncCall = args[0].intVal;
		_stack.makeRef(_stack.peek, execute(args[0].intVal, _stack.read(args[1].intVal)));

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
	void concatString(QData[] args){
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
		_nextInstIndex = args[0].intVal;
		_nextInst = _instructions[_nextInstIndex];
		_stack.peek = args[1].intVal;
	}
	/// jumpIf
	void jumpIf(QData[] args){
		if (cast(bool)((*_stack.read()).intVal)){
			_nextInstIndex = args[0].intVal;
			_nextInst = _instructions[_nextInstIndex];
			_stack.peek = args[1].intVal;
		}
	}
	/// jumpIfNot
	void jumpIfNot(QData[] args){
		if (!cast(bool)((*_stack.read()).intVal)){
			_nextInstIndex = args[0].intVal;
			_nextInst = _instructions[_nextInstIndex];
			_stack.peek = args[1].intVal;
		}
	}
	/// doIf - obsolete, use jumpIfNot
	void doIf(QData[] args){
		// obsolete
	}
	/// return
	void returnInst(QData[] args){
		_returnVal = _stack.read();
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
	void makeArray(QData[] args){
		QData r;
		r.arrayVal.length = args[0].intVal;
		foreach (i, val; _stack.read(args[0].intVal)){
			r.arrayVal[0] = *val;
		}
		*(_stack.read!(false)) = r;
	}

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
public:
	this(){
		_callStack = new Stack!StaticStack;
	}
	~this(){
		.destroy(_callStack);
	}
	/// loads byte code, and prepares for execution
	/// 
	/// Returns: true if successfully loaded, false if not (could be instruction used doesnt exist)
	bool loadByteCode(ByteCode bCode){
		_functions.length = bCode.functions.length;
		_stackMakers.length = bCode.functions.length;
		_stackAlloc.length = bCode.functions.length;
		// prepare the StackBuilders
		foreach (i, func; bCode.functions){
			_stackMakers[i] = StackBuilder(func.stack);
		}
		// prepare the StackAlloc(ators)
		foreach(i, func; bCode.functions){
			_stackAlloc[i] = new ExtraAlloc!StaticStack(4, 8, &_allocFuncStack);
		}
		// map functions' instructions to their function pointers
		return bCode.mapInstructions([
			"execFuncS" : &execFuncS,
			"execFuncE" : &execFuncE,

			"addInt" : &addInt,
			"addDouble" : &addDouble,
			"subtractInt" : &subtractInt,
			"subtractDouble" : &subtractDouble,
			"multiplyInt" : &multiplyInt,
			"multiplyDouble" : &multiplyDouble,
			"divideInt" : &divideInt,
			"divideDouble" : &divideDouble,
			"modInt" : &modInt,
			"modDouble" : &modDouble,
			"concatArray" : &concatArray,
			"concatString" : &concatString,

			"isSameInt" : &isSameInt,
			"isSameDouble" : &isSameDouble,
			"isSameString" : &isSameString,
			"isLesserInt" : &isLesserInt,
			"isLesserDouble" : &isLesserDouble,
			"isGreaterInt" : &isGreaterInt,
			"isGreaterDouble" : &isGreaterDouble,
			"notInt" : &notInt,
			"andInt" : &andInt,
			"orInt" : &orInt,

			"write" : &write,
			"writeRef" : &writeRef,
			"makeRef" : &makeRef,
			"deref" : &deref,
			"getRef" : &getRef,
			"getRefArray" : &getRefArray,
			"getRefRefArray" : &getRefRefArray,
			"peek" : &peek,
			
			"jump" : &jump,
			"jumpIf" : &jumpIf,
			"jumpIfNot" : &jumpIfNot,
			"doIf" : &doIf,
			"return" : &returnInst,

			"setLen" : &setLen,
			"getLen" : &getLen,
			"readElement" : &readElement,
			"modifyArray" : &modifyArray,
			"makeArray" : &makeArray,

			"strLen" : &strLen,
			"readChar" : &readChar,
			
			"strToInt" : &strToInt,
			"strToDouble" : &strToDouble,
			"intToStr" : &intToStr,
			"intToDouble" : &intToDouble,
			"doubleToStr" : &doubleToStr,
			"doubleToInt" : &doubleToInt

			],
			 _functions, _functionInstArgs);
	}

	/// Executes a script defined function
	QData* execute(uinteger funcId, QData*[] args){
		// prepare a stack for it, assume recursion doesn't exists, thats taken care of by execFuncS
		_stack = _stackAlloc[funcId].get();
		// move its instructions
		_instructions = _functions[funcId];
		_instArgs = _functionInstArgs[funcId];
		// set the args
		foreach(i, arg; args){
			_stack.makeRef(i, arg);
		}
		// begin
		if (_instructions.length > 0){
			_nextInst = _instructions[0];
			_nextInstIndex = 0;			
			// now for real, begin
			while (_nextInstIndex < _instructions.length && _nextInst){
				QVMInst* curInst = _nextInst;
				QData[] curInstArgs = _instArgs[_nextInstIndex];
				_nextInstIndex++;
				_nextInst++;
				(*curInst)(curInstArgs);
			}
		}
		// get rid of the --body-- stack
		_stackAlloc[funcId].free(_stack);
		// restore last stack
		try{
			_stack = _callStack.pop();
		}catch (Exception e){
			.destroy(e);
		}
		return _returnVal;
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