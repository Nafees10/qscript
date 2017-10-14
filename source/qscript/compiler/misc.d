module qscript.compiler.misc;

import utils.misc;
import utils.lists;

import qscript.qscript : QData;

import std.range;
import std.conv : to;

/// An array containing all chars that an identifier can contain
package const char[] IDENT_CHARS = iota('a', 'z'+1).array~iota('A', 'Z'+1).array~iota('0', '9'+1).array~[cast(int)'_'];
/// An array containing all keywords
package const string[] KEYWORDS = ["function", "if", "else", "while", "void", "int", "string", "double"];
/// data types
package const string[] DATA_TYPES = ["void", "int", "double", "string"];
/// An array containing another array conatining all operators
package const string[] OPERATORS = ["/", "*", "+", "-", "%", "~", "<", ">", "==", "!=", "<=", ">=", "="];
/// An array containing all bool-operators (operators that return true/false)
package const string[] BOOL_OPERATORS = ["<", ">", "==", "!=", "<=", ">="];

/// Used by compiler's functions to return error
package struct CompileError{
	string msg; /// The error stored in a string
	uinteger lineno; /// The line number on which the error is
	this(uinteger lineNumber, string errorMessage){
		lineno = lineNumber;
		msg = errorMessage;
	}
}
/// All compilation errors are stored here
package LinkedList!CompileError compileErrors;

/// used to store data types for data at compile time
package struct DataType{
	/// enum defining all data types
	public enum Type{
		Void,
		String,
		Integer,
		Double
	}
	/// the actual data type
	DataType.Type type;
	/// stores if it's an array. If type is `int`, it will be 0, if `int[]` it will be 1, if `int[][]`, then 2 ...
	uinteger arrayNestCount;
	/// returns true if it's an array
	@property bool isArray(){
		if (arrayNestCount > 0){
			return true;
		}
		return false;
	}
	/// constructor
	/// 
	/// dataType is the type to store
	/// arrayNest is the number of nested arrays
	this (DataType.Type dataType, uinteger arrayNest = 0){
		type = dataType;
		arrayNestCount = arrayNest;
	}
	/// constructor
	/// 
	/// sType is the type in string form
	this (string sType){
		fromString(sType);
	}
	/// reads DataType from a string, in case of failure or bad format in string, throws Exception
	void fromString(string s){
		string sType = null;
		uinteger indexCount = 0;
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
					throw new Exception("bad type format");
				}
				indexCount ++;
			}else{
				throw new Exception("invalid data type");
			}
		}
		// now check if the type was ok or not
		if (sType == "void"){
			type = DataType.Type.Void;
		}else if (sType == "string"){
			type = DataType.Type.String;
		}else if (sType == "int"){
			type = DataType.Type.Integer;
		}else if (sType == "double"){
			type = DataType.Type.Double;
		}else{
			throw new Exception("invalid data type");
		}
		arrayNestCount = indexCount;
	}

	/// identifies the data type from the actual data
	/// 
	/// throws Exception on failure
	void fromData(Token[] data){
		/// identifies type from data
		static DataType.Type identifyType(Token data){
			if (data.type == Token.Type.String){
				return DataType.Type.String;
			}else if (data.type == Token.Type.Integer){
				return DataType.Type.Integer;
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
			this.arrayNestCount = 0;
			this.type = DataType.Type.Void;
		}

		// make sure it's at least one token
		if (data.length == 0){
			throw new Exception("attempting to infer type of data with zero length");
		}
		// check if is an array
		if (data.length > 1 &&
			data[0].type == Token.Type.IndexBracketOpen && data[data.length-1].type == Token.Type.IndexBracketClose){
			// is an array
			this.arrayNestCount ++;
			// TODO make fromData work on arrays
			// if elements are arrays, do recursion, else, just identify types
			bool isArrayOfArray = false;
			Token[][] elements = splitArray(data);
			if (elements.length == 0){
				this.type = DataType.Type.Void;
			}else{
				// determine the type using recursion
				// stores the arrayNestCount till here
				uinteger thisNestCount = this.arrayNestCount;
				// stores the nestCount for the preious element, -1 if no previous element
				integer prevNestCount = -1;
				// stores the data type of the last element, void if no last element
				DataType.Type prevType = DataType.Type.Void;
				// now do recursion, and make sure all types come out same
				foreach (element; elements){
					fromData(element);
					// now make sure the nestCount came out same
					if (prevNestCount != -1){
						if (prevNestCount != this.arrayNestCount){
							throw new Exception("inconsistent data types in array elements");
						}
					}else{
						// set new nestCount
						prevNestCount = this.arrayNestCount;
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
					this.arrayNestCount = thisNestCount;
				}
				// now set the nestCount
				this.arrayNestCount = thisNestCount + prevNestCount;
			}
		}else{
			// then it must be only one token
			assert(data.length != 1, "non-array data must be only one token in length");
			// now check the type, and set it
			this.type = identifyType(data[0]);
		}
	}
}
/// unittests
unittest{
	assert(DataType("int") == DataType(DataType.Type.Integer, 0));
	assert(DataType("string[]") == DataType(DataType.Type.String, 1));
	assert(DataType("double[][]") == DataType(DataType.Type.Double, 2));
	assert(DataType("void") == DataType(DataType.Type.Void, 0));
	// unittests for `fromData`
	import qscript.compiler.tokengen;
	DataType dType;
	dType.fromData([Token(Token.Type.String, "\"bla bla\"")]);
	assert(dType == DataType("string"));
	dType.fromData(toTokens(["20"]).tokens);
	assert(dType == DataType("int"));
	dType.fromData(toTokens(["2.5"]).tokens);
	assert(dType == DataType("double"));
	dType.fromData(toTokens(["[\"bla\",\"bla\"]"]).tokens);
	assert(dType == DataType("string[]"));
	dType.fromData(toTokens(["[[25,2.5],[15,25]]"]).tokens);
	assert(dType == DataType("double[][]"));
}

/// splits an array in tokens format to it's elements
/// 
/// For example, splitArray("[a, b, c]") will return ["a", "b", "c"]
package Token[][] splitArray(Token[] array){
	assert(array[0].type == Token.Type.IndexBracketOpen &&
		array[array.length - 1].type == Token.Type.IndexBracketClose, "not a valid array");
	LinkedList!(Token[]) elements = new LinkedList!(Token[]);
	for (uinteger i = 1, readFrom = i; i < array.length; i ++){
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
	for (i++;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			continue;
		}else if (s[i]=='"'){
			break;
		}
	}
	if (i==s.length){i=-1;}
	return i;
}

/// converts from string to QData
/// 
/// `type` is the DataType.Type defining the type of the data
/// `s` is the string containing the data, which can be an arary or array of array of ...
/// 
/// throws Exception on failure
package QData stringToQData(DataType.Type type)(string s){
	QData result;
	// check if is an array
	if (s[0] == '['){
		// recursion...
		string[] elements = splitArray(s);
		result.arrayVal.length = elements.length;
		foreach (i, element; elements){
			result.arrayVal[i] = stringToQData!(type)(element);
		}
	}else{
		static if (type == DataType.Type.Double){
			result.doubleVal = to!double(s);
		}else static if (type == DataType.Type.Integer){
			result.intVal = to!integer(s);
		}else static if (type == DataType.Type.String){
			result.strVal = s;
		}
	}
	return result;
}

/// Each token is stored as a `Token` with the type and the actual token
package struct Token{
	/// Specifies type of token
	/// 
	/// used only in `compiler.tokengen`
	enum Type{
		String,/// That the token is: `"SOME STRING"`
		Integer,/// That the token an int
		Double, /// That the token is a double (floating point) value
		Identifier,/// That the token is an identifier. i.e token is a variable name or a function name.  For a token to be marked as Identifier, it doesn't need to be defined in `new()`
		DataType, /// the  token is a data type
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
	string toString(Token[] t){
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
package uinteger bracketPos(bool forward=true)(Token[] tokens, uinteger index){
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
	assert(tokens.bracketPos!true(1) == 5);
	assert(tokens.bracketPos!false(5) == 1);
	assert(tokens.bracketPos!true(3) == 4);
	assert(tokens.bracketPos!false(4) == 3);
}