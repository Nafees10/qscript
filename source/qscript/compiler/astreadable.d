﻿/++
Used for debugging the astgen.  
Contains functions to generate a readable string respresentation of AST nodes
+/
module qscript.compiler.astreadable;

import qscript.compiler.ast;

import utils.misc;

import std.conv : to;
import std.json;

// below comes a long list of functions to createJSONValue for each ASTNode

/// Creates JSONValue for ScriptNode
JSONValue toJSON(ScriptNode node){
	JSONValue[] functionsJSON;
	functionsJSON.length = node.functions.length;
	foreach (i, fNode; node.functions){
		functionsJSON[i] = fNode.toJSON;
	}
	JSONValue r;
	r["node"] = JSONValue("ScriptNode");
	r["functions"] = JSONValue(functionsJSON);
	return r;
}

/// Creates JSONValue for FunctionNode
JSONValue toJSON(FunctionNode node){
	JSONValue[] argListJSON;
	argListJSON.length = node.arguments.length;
	foreach (i, arg; node.arguments){
		argListJSON[i]["name"] = JSONValue(arg.argName);
		argListJSON[i]["type"] = JSONValue(arg.argType.toString);
	}
	JSONValue bodyJSON = node.bodyBlock.toJSON;
	JSONValue r;
	r["node"] = JSONValue("FunctionNode");
	r["type"] = node.returnType.toString;
	r["name"] = node.name;
	r["arguments"] = JSONValue(argListJSON);
	r["body"] = JSONValue(bodyJSON);
	return r;
}

/// Creates JSONValue for BlockNode
JSONValue toJSON(BlockNode node){
	JSONValue[] statementListJSON;
	statementListJSON.length = node.statements.length;
	foreach (i, statement; node.statements){
		statementListJSON[i] = statement.toJSON;
	}
	JSONValue r;
	r["node"] = JSONValue("BlockNode");
	r["statements"] = JSONValue(statementListJSON);
	return r;
}

/// Creates JSONValue for StatementNode
JSONValue toJSON(StatementNode node){
	JSONValue r;
	r["node"] = JSONValue("StatementNode");
	if (node.type == StatementNode.Type.Assignment){
		r["statement"] = node.node!(StatementNode.Type.Assignment).toJSON;
	}else if (node.type == StatementNode.Type.Block){
		r["statement"] = node.node!(StatementNode.Type.Block).toJSON;
	}else if (node.type == StatementNode.Type.DoWhile){
		r["statement"] = node.node!(StatementNode.Type.DoWhile).toJSON;
	}else if (node.type == StatementNode.Type.For){
		r["statement"] = node.node!(StatementNode.Type.For).toJSON;
	}else if (node.type == StatementNode.Type.FunctionCall){
		r["statement"] = node.node!(StatementNode.Type.FunctionCall).toJSON;
	}else if (node.type == StatementNode.Type.If){
		r["statement"] = node.node!(StatementNode.Type.If).toJSON;
	}else if (node.type == StatementNode.Type.VarDeclare){
		r["statement"] = node.node!(StatementNode.Type.VarDeclare).toJSON;
	}else if (node.type == StatementNode.Type.While){
		r["statement"] = node.node!(StatementNode.Type.While).toJSON;
	}
	return r;
}

/// Creates JSONValue for AssignmentNode
JSONValue toJSON(AssignmentNode node){
	JSONValue r;
	r["node"] = JSONValue("AssignmentNode");
	r["lvalueIsRef"] = JSONValue(node.deref ? "true" : "false");
	r["var"] = node.var.toJSON;
	JSONValue[] indexes;
	indexes.length = node.indexes.length;
	foreach (i, index; node.indexes){
		indexes[i] = index.toJSON;
	}
	r["indexes"] = JSONValue(indexes);
	r["val"] = node.val.toJSON;
	return r;
}

/// Creates JSONValue for IfNode
JSONValue toJSON(IfNode node){
	JSONValue r;
	r["node"] = JSONValue("IfNode");
	r["condition"] = node.condition.toJSON;
	r["onTrue"] = node.statement.toJSON;
	if (node.hasElse)
		r["onFalse"] = node.elseStatement.toJSON;
	return r;
}

/// Creates JSONValue for WhileNode
JSONValue toJSON(WhileNode node){
	JSONValue r;
	r["node"] = JSONValue("WhileNode");
	r["condtion"] = node.condition.toJSON;
	r["statement"] = node.statement.toJSON;
	return r;
}

/// Creates JSONValue for DoWhileNode
JSONValue toJSON(DoWhileNode node){
	JSONValue r;
	r["node"] = JSONValue("DoWhileNode");
	r["condition"] = node.condition.toJSON;
	r["statement"] = node.statement.toJSON;
	return r;
}

/// Creates JSONValue for ForNode
JSONValue toJSON(ForNode node){
	JSONValue r;
	r["node"] = JSONValue("ForNode");
	r["init"] = node.initStatement.toJSON;
	r["condition"] = node.condition.toJSON;
	r["inc"] = node.incStatement.toJSON;
	r["statement"] = node.statement.toJSON;
	return r;
}

/// Creates JSONValue for FunctionCallNode
JSONValue toJSON(FunctionCallNode node){
	JSONValue r;
	r["node"] = JSONValue("FunctionCallNode");
	r["name"] = JSONValue(node.fName);
	r["type"] = JSONValue(node.returnType.toString);
	JSONValue[] argListJSON;
	argListJSON.length = node.arguments.length;
	foreach (i, arg; node.arguments){
		argListJSON[i] = arg.toJSON;
	}
	r["args"] = JSONValue(argListJSON);
	return r;
}

/// Creates JSONValue for VarDeclareNode
JSONValue toJSON(VarDeclareNode node){
	JSONValue r;
	r["node"] = JSONValue("varDeclareNode");
	r["type"] = JSONValue(node.type.toString);
	JSONValue[] varTypeValueList;
	varTypeValueList.length = node.vars.length;
	foreach (i, varName; node.vars){
		JSONValue var;
		var["name"] = JSONValue(varName);
		//var["id"] = JSONValue(node.varIDs[varName]);// TODO fixme Y U NO WORK (see ASTCheck.checkAST(ref VarDeclareNode node))
		if (node.hasValue(varName))
			var["value"] = node.getValue(varName).toJSON;
		varTypeValueList[i] = var;
	}
	r["vars"] = JSONValue(varTypeValueList);
	return r;
}

/// Creates JSONValue for CodeNode
JSONValue toJSON(CodeNode node){
	JSONValue r;
	r["node"] = JSONValue("CodeNode");
	r["type"] = JSONValue(node.returnType.toString);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	if (node.type == CodeNode.Type.Array){
		r["code"] = node.node!(CodeNode.Type.Array).toJSON;
	}else if (node.type == CodeNode.Type.FunctionCall){
		r["code"] = node.node!(CodeNode.Type.FunctionCall).toJSON;
	}else if (node.type == CodeNode.Type.Literal){
		r["code"] = node.node!(CodeNode.Type.Literal).toJSON;
	}else if (node.type == CodeNode.Type.Operator){
		r["code"] = node.node!(CodeNode.Type.Operator).toJSON;
	}else if (node.type == CodeNode.Type.ReadElement){
		r["code"] = node.node!(CodeNode.Type.ReadElement).toJSON;
	}else if (node.type == CodeNode.Type.SOperator){
		r["code"] = node.node!(CodeNode.Type.SOperator).toJSON;
	}else if (node.type == CodeNode.Type.Variable){
		r["code"] = node.node!(CodeNode.Type.Variable).toJSON;
	}
	return r;
}

/// Creates JSONValue for VariableNode
JSONValue toJSON(VariableNode node){
	JSONValue r;
	r["node"] = JSONValue("VariableNode");
	r["type"] = JSONValue(node.returnType.toString);
	r["name"] = JSONValue(node.varName);
	r["id"] = JSONValue(node.id);
	return r;
}

/// Creates JSONValue for ArrayNode
JSONValue toJSON(ArrayNode node){
	JSONValue r;
	r["node"] = JSONValue("ArrayNode");
	r["type"] = JSONValue(node.returnType.toString);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	JSONValue[] elementList;
	elementList.length = node.elements.length;
	foreach (i, element; node.elements){
		elementList[i] = element.toJSON;
	}
	r["elements"] = JSONValue(elementList);
	return r;
}

/// Creates JSONValue for LiteralNode
JSONValue toJSON(LiteralNode node){
	JSONValue r;
	r["node"] = JSONValue("LiteralNode");
	r["type"] = JSONValue(node.returnType.toString);
	r["value"] = JSONValue(node.toByteCode);
	return r;
}

/// Creates JSONValue for OperatorNode
JSONValue toJSON(OperatorNode node){
	JSONValue r;
	r["node"] = JSONValue("OperatorNode");
	r["type"] = JSONValue(node.returnType.toString);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r["operator"] = JSONValue(node.operator);
	r["operandA"] = node.operands[0].toJSON;
	r["operandB"] = node.operands[1].toJSON;
	return r;
}

/// Creates JSONValue for SOperatorNode
JSONValue toJSON(SOperatorNode node){
	JSONValue r;
	r["node"] = JSONValue("SOperatorNode");
	r["type"] = JSONValue(node.returnType.toString);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r["operator"] = JSONValue(node.operator);
	r["operand"] = node.operand.toJSON;
	return r;
}

/// Creates JSONValue for ReadElement
JSONValue toJSON(ReadElement node){
	JSONValue r;
	r["node"] = JSONValue("ReadElement");
	r["type"] = JSONValue(node.returnType.toString);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r["array"] = node.readFromNode.toJSON;
	r["index"] = node.index.toJSON;
	return r;
}