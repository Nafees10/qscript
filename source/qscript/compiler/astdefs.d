module qscript.compiler.astdefs;

import utils.misc;
import utils.ds;

import qscript.compiler.compiler;
import qscript.compiler.tokens.tokens;
import qscript.compiler.astgen;

debug import std.stdio;
import std.conv : to;


/// Data Type
class DataType : ASTNode{
public:
	bool isRef = false;
	uint dimensions = 0;
	string type; // null if void
	DataType[] argTypes;

	/// default constructor, creates void type
	this (){
		type = null;
	}
	/// constructor
	this(string name, uint dimensions = 0){
		type = name;
		dimensions = dimensions;
	}

	/// if this is a function
	@property bool isFn(){
		return argTypes.length > 0;
	}

	/// this data as string
	override string toString() const{
		char[] r;
		if (isRef)
			r = cast(char[])"ref " ~ type;
		else
			r = type.dup;
		uint index = cast(uint)r.length;
		r.length += 2 * dimensions;
		for (; index < r.length; index += 2)
			r[index .. index + 2] = "[]";
		return cast(string)r;
	}

	/// == operator
	bool opBinary(string op : "==")(DataType rhs){
		return rhs !is null && rhs.dimensions == dimensions && type == rhs.type;
	}
}

/// Declaration Node (function decl, struct decl, enum decl...)
package abstract class DeclNode : ASTNode{
public:
	/// visibility
	bool isPub = false;

	this(bool pub = false){
		isPub = pub;
	}
}

/// Expression
package abstract class ExpressionNode : ASTNode{
public:
	/// Return type of expression, null -> void
	DataType returnType;

	this (DataType retType = null){
		returnType = retType;
	}
}

/// Operator expression
package abstract class Operator : ExpressionNode{
public:
	/// operator
	string operator;
	/// if this comes before a operandA (binary will always be false)
	bool prefix;
}

/// Binary operator expression
package abstract class OperatorBin : Operator{
public:
	/// Left side operand
	ExpressionNode operandL;

	/// Right side operand
	ExpressionNode operandR;
}

/// Unary operator expression
package abstract class OperatorUn : Operator{
public:
	/// Operand
	ExpressionNode operand;
}

/// Script Node
package class ScriptNode : ASTNode{
public:
	/// declarations
	DeclNode[] declarations;
}

/// Variable declaration
private class VarDefNode : DeclNode{
public:
	/// Data type
	DataType dataType;

	/// names of variables
	string[] varName;

	/// default value, if not null
	ExpressionNode[] varValue;
}

/// Struct declaration
package class StructDefNode : DeclNode{
public:
	/// Variables.
	DeclNode[] members;
}

/// Enum declaration
package class EnumDefNode : DeclNode{
public:
	/// Base data type
	DataType dataType;
	/// member names
	string[] memberName;
	/// member values, if not null
	ExpressionNode[] memberValue;
}

/// Function declaration (return type, name, args + arg types)
package class FuncDeclNode : DeclNode{
public:
	/// Returns type
	DataType returnType;
	/// function name
	string name;
	/// Argument types
	DataType[] argTypes;
	/// Argument names
	string[] argNames;
	/// Expression
	ExpressionNode expression;
}

/// Block
package class BlockNode : ExpressionNode{
public:
	ExpressionNode[] expressions;
}

/// Function call expression
package class FnCall : ExpressionNode{
public:
	/// function
	ExpressionNode fn;
	/// Arguments of function call
	ExpressionNode[] args;
}

/// Literal ExpressionNode template
private class LiteralExpression(T, string typename, uint dim = 0) : ExpressionNode{
public:
	/// value
	T _val;

	this(){
		this.returnType = new DataType(typename, dim);
	}
}

/// Integer Literal
package alias LiteralInt = LiteralExpression!(ptrdiff_t, TYPENAME.INT, 0);
/// Float Literal
package alias LiteralFloat = LiteralExpression!(double, TYPENAME.FLOAT, 0);
/// Character Literal
package alias LiteralChar = LiteralExpression!(char, TYPENAME.CHAR, 0);
/// Boolean Literal
package alias LiteralBool = LiteralExpression!(bool, TYPENAME.BOOL, 0);
/// String Literal
package alias LiteralString = LiteralExpression!(string, TYPENAME.CHAR, 1);

/// member select operator
package class OperatorMemberSelect : OperatorBin{
public:
}

/// index read operator
package class OperatorIndex: OperatorBin{
public:
}

/// post increment operator
package class OperatorIncPost : OperatorUn{
public:
}

/// post decrement operator
package class OperatorDecPost : OperatorUn{
public:
}

/// boolean not operator
package class OperatorBoolNot : OperatorUn{
public:
}

/// pre increment operator
package class OperatorIncPre : OperatorUn{
public:
}

/// pre decrement operator
package class OperatorDecPre : OperatorUn{
public:
}

/// multiply operator
package class OperatorMultiply : OperatorBin{
public:
}

/// divide operator
package class OperatorDivide : OperatorBin{
public:
}

/// mod operator
package class OperatorMod : OperatorBin{
public:
}

/// add operator
package class OperatorAdd : OperatorBin{
public:
}

/// subtract operator
package class OperatorSubtract : OperatorBin{
public:
}

/// bitshift left operator
package class OperatorBitshiftLeft : OperatorBin{
public:
}

/// bitshift right operator
package class OperatorBitshiftRight : OperatorBin{
public:
}

/// Equals operator
package class OperatorEquals : OperatorBin{
public:
}

/// NotEquals operator
package class OperatorNotEquals : OperatorBin{
public:
}

/// GreaterOrEquals operator
package class OperatorGreaterEquals : OperatorBin{
public:
}

/// SmallerOrEquals operator
package class OperatorSmallerEquals : OperatorBin{
public:
}

/// Greater operator
package class OperatorGreater : OperatorBin{
public:
}

/// Smaller operator
package class OperatorSmaller : OperatorBin{
public:
}

/// is operator
package class OperatorIs : OperatorBin{
public:
}

/// not is operator
package class OperatorNotIs : OperatorBin{
public:
}

/// Binary And operator
package class OperatorBinAnd : OperatorBin{
public:
}

/// Binary Or operator
package class OperatorBinOr : OperatorBin{
public:
}

/// Binary Xor operator
package class OperatorBinXor : OperatorBin{
public:
}

/// Boolean And operator
package class OperatorBoolAnd : OperatorBin{
public:
}

/// Boolean Or operator
package class OperatorBoolOr : OperatorBin{
public:
}

/// Assign operator
package class OperatorAssign : OperatorBin{
public:
}

/// Add Assign operator
package class OperatorAddAssign : OperatorBin{
public:
}

/// Subtract Assign operator
package class OperatorSubAssign : OperatorBin{
public:
}

/// Multiply Assign operator
package class OperatorMulAssign : OperatorBin{
public:
}

/// Divide Assign operator
package class OperatorDivAssign : OperatorBin{
public:
}

/// Mod Assign operator
package class OperatorModAssign : OperatorBin{
public:
}

/// Binary And Assign operator
package class OperatorBinAndAssign : OperatorBin{
public:
}

/// Binary Or Assign operator
package class OperatorBinOrAssign : OperatorBin{
public:
}

/// Binary Xor Assign operator
package class OperatorBinXorAssign : OperatorBin{
public:
}
