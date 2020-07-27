/++
Some misc stuff used by the compiler
+/
module qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.range;
import std.traits;
import std.conv : to;

/// An array containing all chars that an identifier can contain
package const char[] IDENT_CHARS = iota('a', 'z'+1).array~iota('A', 'Z'+1).array~iota('0', '9'+1).array~[cast(int)'_'];
/// An array containing all keywords
package const string[] KEYWORDS = [
	"import",
	"function",
	"struct",
	"enum",
	"var",
	"return",
	"if",
	"else",
	"while",
	"for",
	"do",
] ~ DATA_TYPES ~ VISIBILITY_SPECIFIERS;
/// Visibility Specifier keywords
package const string[] VISIBILITY_SPECIFIERS = ["public", "private"];
/// data types
package const string[] DATA_TYPES = ["void", "int", "uint", "double", "char", "bool", "byte", "ubyte"];
/// An array containing double-operand operators
package const string[] OPERATORS = [".", "/", "*", "+", "-", "%", "~", "<", ">", ">=", "<=", "==", "=", "&&", "||"];
/// single-operand operators
package const string[] SOPERATORS = ["!", "@"];
/// An array containing all bool-operators (operators that return true/false)
package const string[] BOOL_OPERATORS = ["<", ">", ">=", "<=", "==", "&&", "||"];
/// Inbuilt QScript functions (like `length(void[])`)
package Function[] INBUILT_FUNCTIONS = [
	/// length(@void[], int)
	Function("length", DataType(DataType.Type.Void), [DataType(DataType.Type.Void,	1, true), DataType(DataType.Type.Int)]),
	/// length(void[])
	Function("length", DataType(DataType.Type.Int), [DataType(DataType.Type.Void, 1, false)]),
	/// length (string)
	Function("length", DataType(DataType.Type.Int), [DataType(DataType.Type.Char, 1, false)]),

	/// toInt(string)
	Function("toInt", DataType(DataType.Type.Int), [DataType(DataType.Type.Char, 1)]),
	/// toInt(double)
	Function("toInt", DataType(DataType.Type.Int), [DataType(DataType.Type.Double)]),
	/// toDouble(string)
	Function("toDouble", DataType(DataType.Type.Double), [DataType(DataType.Type.Char, 1)]),
	/// toDouble(int)
	Function("toDouble", DataType(DataType.Type.Double), [DataType(DataType.Type.Int)]),
	/// toString(int)
	Function("toStr", DataType(DataType.Type.Char, 1), [DataType(DataType.Type.Int)]),
	/// toString(double)
	Function("toStr", DataType(DataType.Type.Char, 1), [DataType(DataType.Type.Double)]),

	/// copy(void[], @void[])
	Function("copy", DataType(DataType.Type.Void), [DataType(DataType.Type.Void, 1), DataType(DataType.Type.Void, 1, true)]),
];

/// Used by compiler's functions to return error
public struct CompileError{
	string msg; /// The error stored in a string
	uinteger lineno; /// The line number on which the error is
	/// constructor
	this(uinteger lineNumber, string errorMessage){
		lineno = lineNumber;
		msg = errorMessage;
	}
}

/// Visibility Specifiers
package enum Visibility{
	Public,
	Private
}

/// Returns: Visibilty from a string
/// 
/// Throws: Exception if invalid input provided
package Visibility strToVisibility(string s){
	foreach (curVisibility; EnumMembers!Visibility){
		if (curVisibility.to!string.lowercase == s)
			return curVisibility;
	}
	throw new Exception(s~" is not a visibility option");
}

/// To store information about a function
public struct Function{
	/// the name of the function
	string name;
	/// the data type of the value returned by this function
	DataType returnType;
	/// stores the data type of the arguments received by this function
	private DataType[] _argTypes;
	/// the data type of the arguments received by this function
	/// 
	/// if an argType is defined as void, with array dimensions=0, it means accept any type.
	/// if an argType is defined as void with array dimensions>0, it means array of any type of that dimensions
	@property ref DataType[] argTypes() return{
		return _argTypes;
	}
	/// the data type of the arguments received by this function
	@property ref DataType[] argTypes(DataType[] newArray) return{
		return _argTypes = newArray.dup;
	}
	/// constructor
	this (string functionName, DataType functionReturnType, DataType[] functionArgTypes){
		name = functionName;
		returnType = functionReturnType;
		_argTypes = functionArgTypes.dup;
	}
}

/// used to store data types for data at compile time
public struct DataType{
	/// enum defining all data types. These are all lowercase of what they're written here
	public enum Type{
		Void, /// .
		Char, /// .
		Int, /// .
		Double, /// .
		Custom, /// some other type
	}
	/// the actual data type
	Type type = DataType.Type.Void;
	/// stores if it's an array. If type is `int`, it will be 0, if `int[]` it will be 1, if `int[][]`, then 2 ...
	uinteger arrayDimensionCount = 0;
	/// stores if it's a reference to a type
	bool isRef = false;
	/// stores the type name in case of Type.Custom
	private string _name;
	/// Returns: this data type in human readable string.
	@property string name(){
		char[] r = cast(char[])(this.type == Type.Custom ? _name.dup : this.type.to!string.lowercase);
		uinteger i = r.length;
		if (this.isArray){
			r.length += this.arrayDimensionCount * 2;
			for (; i < r.length; i += 2){
				r[i .. i + 2] = "[]";
			}
		}
		return cast(string)r;
	}
	/// Just calls fromString()
	@property string name(string newName){
		this.fromString(newName);
		return newName;
	}
	/// returns: true if it's an array. Strings are arrays too (char[])
	@property bool isArray(){
		if (arrayDimensionCount > 0){
			return true;
		}
		return false;
	}
	/// constructor.
	/// 
	/// dataType is the type to store
	/// arrayDimension is the number of nested arrays
	/// isRef is whether the type is a reference to the actual type
	this (DataType.Type dataType, uinteger arrayDimension = 0, bool isReference = false){
		type = dataType;
		arrayDimensionCount = arrayDimension;
		isRef = isReference;
	}
	/// constructor.
	/// 
	/// dataType is the name of type to store
	/// arrayDimension is the number of nested arrays
	/// isRef is whether the type is a reference to the actual type
	this (string dataType, uinteger arrayDimension = 0, bool isReference = false){
		this.name = dataType;
		arrayDimensionCount = arrayDimension;
		isRef = isReference;
	}
	
	/// constructor.
	/// 
	/// `sType` is the type in string form
	this (string sType){
		fromString(sType);
	}
	/// constructor.
	/// 
	/// `data` is the data to infer type from
	this (Token[] data){
		fromData(data);
	}
	/// reads DataType from a string, works for base types and custom types
	/// 
	/// Throws: Exception in case of failure or bad format in string
	void fromString(string s){
		isRef = false;
		string sType = null;
		uinteger indexCount = 0;
		// check if it's a ref
		if (s.length > 0 && s[0] == '@'){
			isRef = true;
			s = s[1 .. s.length].dup;
		}
		// read the type
		for (uinteger i = 0, lastInd = s.length-1; i < s.length; i ++){
			if (s[i] == '['){
				sType = s[0 .. i];
				break;
			}else if (i == lastInd){
				sType = s;
				break;
			}
		}
		// now read the index
		for (uinteger i = sType.length; i < s.length; i ++){
			if (s[i] == '['){
				// make sure next char is a ']'
				i ++;
				if (s[i] != ']'){
					throw new Exception("invalid data type format");
				}
				indexCount ++;
			}else{
				throw new Exception("invalid data type");
			}
		}
		bool isCustom = true;
		foreach (curType; EnumMembers!Type){
			if (curType != Type.Custom && curType.to!string.lowercase == sType){
				this.type = curType;
				isCustom = false;
			}
		}
		if (isCustom){
			this.type = Type.Custom;
			this._name = sType;
		}
		arrayDimensionCount = indexCount;
	}

	/// identifies the data type from the actual data. Only works for base types
	/// keep in mind, this won't be able to identify if the data type is a reference or not
	/// 
	/// throws Exception on failure
	void fromData(Token[] data){
		/// identifies type from data
		static DataType.Type identifyType(Token data, ref uinteger arrayDimension){
			if (data.type == Token.Type.String){
				arrayDimension ++;
				return DataType.Type.Char;
			}else if (data.type == Token.Type.Char){
				return DataType.Type.Char;
			}else if (data.type == Token.Type.Integer){
				return DataType.Type.Int;
			}else if (data.type == Token.Type.Double){
				return DataType.Type.Double;
			}else{
				throw new Exception("failed to read data type");
			}
		}
		// keeps count of number of "instances" of this function currently being executed
		static uinteger callCount = 0;
		callCount ++;

		if (callCount == 1){
			this.arrayDimensionCount = 0;
			this.type = DataType.Type.Void;
		}
		// check if is an array
		if (data.length > 1 &&
			data[0].type == Token.Type.IndexBracketOpen && data[data.length-1].type == Token.Type.IndexBracketClose){
			// is an array
			this.arrayDimensionCount ++;
			// if elements are arrays, do recursion, else, just identify types
			Token[][] elements = splitArray(data);
			if (elements.length == 0){
				this.type = DataType.Type.Void;
			}else{
				// determine the type using recursion
				// stores the arrayDimensionCount till here
				uinteger thisNestCount = this.arrayDimensionCount;
				// stores the nestCount for the preious element, -1 if no previous element
				integer prevNestCount = -1;
				// stores the data type of the last element, void if no last element
				DataType.Type prevType = DataType.Type.Void;
				// now do recursion, and make sure all types come out same
				foreach (element; elements){
					fromData(element);
					// now make sure the nestCount came out same
					if (prevNestCount != -1){
						if (prevNestCount != this.arrayDimensionCount){
							throw new Exception("inconsistent data types in array elements");
						}
					}else{
						// set new nestCount
						prevNestCount = this.arrayDimensionCount;
					}
					// now to make sure type came out same
					if (prevType != DataType.Type.Void){
						if (this.type != prevType){
							throw new Exception("inconsistent data types in array elements");
						}
					}else{
						prevType = this.type;
					}
					// re-set the nestCount for the next element
					this.arrayDimensionCount = thisNestCount;
				}
				// now set the nestCount
				this.arrayDimensionCount = prevNestCount;
			}
		}else if (data.length == 0){
			this.type = DataType.Type.Void;
		}else{
			// then it must be only one token, if is zero, then it's void
			assert(data.length == 1, "non-array data must be only one token in length");
			// now check the type, and set it
			this.type = identifyType(data[0], arrayDimensionCount);
		}
		callCount --;
	}
}
/// 
unittest{
	assert(DataType("int") == DataType(DataType.Type.Int, 0));
	assert(DataType("char[][]") == DataType(DataType.Type.Char, 2));
	assert(DataType("double[][]") == DataType(DataType.Type.Double, 2));
	assert(DataType("void") == DataType(DataType.Type.Void, 0));
	// unittests for `fromData`
	import qscript.compiler.tokengen : stringToTokens;
	DataType dType;
	dType.fromData(["\"bla bla\""].stringToTokens);
	assert(dType == DataType("char[]"));
	dType.fromData(["20"].stringToTokens);
	assert(dType == DataType("int"));
	dType.fromData(["2.5"].stringToTokens);
	assert(dType == DataType("double"));
	dType.fromData(["[", "\"bla\"", ",", "\"bla\"", "]"].stringToTokens);
	assert(dType == DataType("char[][]"));
	dType.fromData(["[", "[", "25.0", ",", "2.5", "]", ",", "[", "15.0", ",", "25.0", "]", "]"].stringToTokens);
	assert(dType == DataType("double[][]"));
	// unittests for `.name()`
	assert(DataType("potatoType[][]").name == "potatoType[][]");
	assert(DataType("double[]").name == "double[]");
}

/// splits an array in tokens format to it's elements
/// 
/// For example, splitArray("[a, b, c]") will return ["a", "b", "c"]
package Token[][] splitArray(Token[] array){
	assert(array[0].type == Token.Type.IndexBracketOpen &&
		array[array.length - 1].type == Token.Type.IndexBracketClose, "not a valid array");
	LinkedList!(Token[]) elements = new LinkedList!(Token[]);
	for (uinteger i = 1, readFrom = i; i < array.length; i ++){
		// skip any other brackets
		if (array[i].type == Token.Type.BlockStart || array[i].type == Token.Type.IndexBracketOpen ||
			array[i].type == Token.Type.ParanthesesOpen){
			i = tokenBracketPos!(true)(array, i);
			continue;
		}
		// check if comma is here
		if (array[i].type == Token.Type.Comma || array[i].type == Token.Type.IndexBracketClose){
			if ((readFrom > i || readFrom == i) && array[i].type == Token.Type.Comma){
				throw new Exception("syntax error");
			}
			elements.append(array[readFrom .. i]);
			readFrom = i + 1;
		}
	}
	Token[][] r = elements.toArray;
	.destroy(elements);
	return r;
}

/// Returns the index of the quotation mark that ends a string
/// 
/// Returns -1 if not found
package integer strEnd(string s, uinteger i){
	const char end = s[i] == '\'' ? '\'' : '\"';
	for (i++;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			continue;
		}else if (s[i]==end){
			break;
		}
	}
	if (i==s.length){i=-1;}
	return i;
}

/// decodes a string. i.e, converts \t to tab, \" to ", etc
/// The string must not be surrounded by quoation marks
/// 
/// throws Exception on error
string decodeString(string s){
	string r;
	for (uinteger i = 0; i < s.length; i ++){
		if (s[i] == '\\'){
			// read the next char
			if (i == s.length-1){
				throw new Exception("unexpected end of string");
			}
			char nextChar = s[i+1];
			if (nextChar == '"'){
				r ~= '"';
			}else if (nextChar == 'n'){
				r ~= '\n';
			}else if (nextChar == 't'){
				r ~= '\t';
			}else if (nextChar == '\\'){
				r ~= '\\';
			}else if (nextChar == '\''){
				r ~= '\'';
			}else{
				throw new Exception("\\"~nextChar~" is not an available character");
			}
			i ++;
			continue;
		}
		r ~= s[i];
	}
	return r;
}

/// Generates a string containing Function Name, along with it's argument types.
/// Makes it easier to differentiate b/w function overloads
/// 
/// Arguments:
/// `name` is the function name  
/// `argTypes` is the array of it's arguments' Data Types
/// 
/// Returns: the byte code style function name
string encodeFunctionName (string name, DataType[] argTypes){
	string r = name ~ '/';
	foreach (argType; argTypes)
		r = r ~ argType.name~ '/';
	return r;
}
/// 
unittest{
	assert ("abcd".encodeFunctionName ([DataType(DataType.Type.Double,3),DataType(DataType.Type.Void)]) == 
			"abcd/double[][][]/void/"
		);
}

/// matches argument types with defined argument types. Used by ASTGen
/// 
/// * `void` will match true against all types (arrays, and even references)
/// * `@void` will match true against only references of any type
/// * `@void[]` will match true against only references of any type of array
/// * `void[]` will match true against any type of array
/// 
/// returns: true if match successful, else, false
bool matchArguments(DataType[] definedTypes, DataType[] argTypes){
	if (argTypes.length != definedTypes.length)
		return false;
	for (uinteger i = 0; i < argTypes.length; i ++){
		if (definedTypes[i].isRef != argTypes[i].isRef)
			return false;
		if (definedTypes[i].type == DataType.Type.Void || argTypes[i].type == DataType.Type.Void){
			if (definedTypes[i].arrayDimensionCount != argTypes[i].arrayDimensionCount)
				return false;
			continue;
		}
		// check the array dimension
		if (definedTypes[i].arrayDimensionCount != argTypes[i].arrayDimensionCount)
			return false;
		if (argTypes[i].type != definedTypes[i].type)
			return false;
	}
	return true;
}

/// Each token is stored as a `Token` with the type and the actual token
package struct Token{
	/// Specifies type of token
	/// 
	/// used only in `compiler.tokengen`
	enum Type{
		String,/// That the token is: `"SOME STRING"`
		Char, /// That the token is: `'C'` # Some character
		Integer,/// That the token an int
		Double, /// That the token is a double (floating point) value
		Identifier,/// That the token is an identifier. i.e token is a variable name or a function name.  For a token to be marked as Identifier, it doesn't need to be defined in `new()`
		DataType, /// the  token is a data type
		MemberSelector, /// a member selector operator
		AssignmentOperator, /// and assignmentOperator
		Operator,/// That the token is an operator, like `+`, `==` etc
		Keyword,/// A `function` or `var` ...
		Comma,/// That its a comma: `,`
		StatementEnd,/// A semicolon
		ParanthesesOpen,/// `(`
		ParanthesesClose,/// `)`
		IndexBracketOpen,/// `[`
		IndexBracketClose,///`]`
		BlockStart,///`{`
		BlockEnd,///`}`
	}
	Type type;/// type of token
	string token;/// token
	this(Type tType, string tToken){
		type = tType;
		token = tToken;
	}
}
/// To store Tokens with Types where the line number of each token is required
package struct TokenList{
	Token[] tokens; /// Stores the tokens
	uinteger[] tokenPerLine; /// Stores the number of tokens in each line
	/// Returns the line number a token is in by usin the index of the token in `tokens`
	/// 
	/// The returned value is the line-number, not index, it starts from 1, not zero
	uinteger getTokenLine(uinteger tokenIndex){
		uinteger i = 0, chars = 0;
		tokenIndex ++;
		for (; chars < tokenIndex && i < tokenPerLine.length; i ++){
			chars += tokenPerLine[i];
		}
		return i;
	}
	/// reads tokens into a string
	static string toString(Token[] t){
		char[] r;
		// set length
		uinteger length = 0;
		for (uinteger i = 0; i < t.length; i ++){
			length += t[i].token.length;
		}
		r.length = length;
		// read em all into r;
		for (uinteger i = 0, writeTo = 0; i < t.length; i ++){
			r[writeTo .. writeTo + t[i].token.length] = t[i].token;
			writeTo += t[i].token.length;
		}
		return cast(string)r;
	}
}

/// Checks if the brackets in a tokenlist are in correct order, and are closed
/// 
/// In case not, returns false, and appends error to `errorLog`
package bool checkBrackets(TokenList tokens, LinkedList!CompileError errors){
	enum BracketType{
		Round,
		Square,
		Block
	}
	BracketType[Token.Type] brackOpenIdent = [
		Token.Type.ParanthesesOpen: BracketType.Round,
		Token.Type.IndexBracketOpen: BracketType.Square,
		Token.Type.BlockStart: BracketType.Block
	];
	BracketType[Token.Type] brackCloseIdent = [
		Token.Type.ParanthesesClose: BracketType.Round,
		Token.Type.IndexBracketClose: BracketType.Square,
		Token.Type.BlockEnd:BracketType.Block
	];
	Stack!BracketType bracks = new Stack!BracketType;
	Stack!uinteger bracksStartIndex = new Stack!uinteger;
	BracketType curType;
	bool r = true;
	for (uinteger lastInd = tokens.tokens.length-1, i = 0; i<=lastInd; i++){
		if (tokens.tokens[i].type in brackOpenIdent){
			bracks.push(brackOpenIdent[tokens.tokens[i].type]);
			bracksStartIndex.push(i);
		}else if (tokens.tokens[i].type in brackCloseIdent){
			bracksStartIndex.pop();
			if (bracks.pop != brackCloseIdent[tokens.tokens[i].type]){
				errors.append(CompileError(tokens.getTokenLine(i),
						"brackets order is wrong; first opened must be last closed"));
				r = false;
				break;
			}
		}else if (i == lastInd && bracks.count > 0){
			// no bracket ending
			i = -2;
			errors.append(CompileError(tokens.getTokenLine(bracksStartIndex.pop), "bracket not closed"));
			r = false;
			break;
		}
	}

	.destroy(bracks);
	.destroy(bracksStartIndex);
	return r;
}

/// Returns index of closing/openinig bracket of the provided bracket  
/// 
/// `forward` if true, then the search is in forward direction, i.e, the closing bracket is searched for
/// `tokens` is the array of tokens to search in
/// `index` is the index of the opposite bracket
/// 
/// It only works correctly if the brackets are in correct order, and the closing bracket is present  
/// so, before calling this, `compiler.misc.checkBrackets` should be called
package uinteger tokenBracketPos(bool forward=true)(Token[] tokens, uinteger index){
	Token.Type[] closingBrackets = [
		Token.Type.BlockEnd,
		Token.Type.IndexBracketClose,
		Token.Type.ParanthesesClose
	];
	Token.Type[] openingBrackets = [
		Token.Type.BlockStart,
		Token.Type.IndexBracketOpen,
		Token.Type.ParanthesesOpen
	];
	uinteger count; // stores how many closing/opening brackets before we reach the desired one
	uinteger i = index;
	for (uinteger lastInd = (forward ? tokens.length : 0); i != lastInd; (forward ? i ++: i --)){
		if ((forward ? openingBrackets : closingBrackets).hasElement(tokens[i].type)){
			count ++;
		}else if ((forward ? closingBrackets : openingBrackets).hasElement(tokens[i].type)){
			count --;
		}
		if (count == 0){
			break;
		}
	}
	return i;
}
///
unittest{
	Token[] tokens;
	tokens = [
		Token(Token.Type.Comma, ","), Token(Token.Type.BlockStart,"{"), Token(Token.Type.Comma,","),
		Token(Token.Type.IndexBracketOpen,"["),Token(Token.Type.IndexBracketClose,"]"),Token(Token.Type.BlockEnd,"}")
	];
	assert(tokens.tokenBracketPos!true(1) == 5);
	assert(tokens.tokenBracketPos!false(5) == 1);
	assert(tokens.tokenBracketPos!true(3) == 4);
	assert(tokens.tokenBracketPos!false(4) == 3);
}

/// removes "extra" whitespace from a string. i.e, if there are more than 1 consecutive spaces/tabs, one is removed
/// 
/// `line` is the string to remove whitespace from
/// `commentStart` is the character that marks the start of a comment, if ==0, then comments are not not considered
package string removeWhitespace(string line, char commentStart=0){
	bool prevWasWhitespace = true;
	string r;
	foreach (c; line){
		if (prevWasWhitespace && (c == ' ' || c == '\t')){
			// do not add this one then
			continue;
		}else if (c != 0 && c == commentStart){
			break;
		}else{
			prevWasWhitespace = false;
			r ~= c;
		}
	}
	return r;
}
