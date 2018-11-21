/++
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
	r.object["node"] = JSONValue("ScriptNode");
	r.object["functions"] = JSONValue(functionsJSON);
	return r;
}

/// Creates JSONValue for FunctionNode
JSONValue toJSON(FunctionNode node){
	JSONValue[] argListJSON;
	argListJSON.length = node.arguments.length;
	foreach (i, arg; node.arguments){
		argListJSON[i].object["name"] = arg.argName;
		argListJSON[i].object["type"] = arg.argType.toString;
	}
	JSONValue bodyJSON = node.bodyBlock.toJSON;
	JSONValue r;
	r.object["node"] = JSONValue("FunctionNode");
	r.object["type"] = node.returnType.toString;
	r.object["name"] = node.name;
	r.object["arguments"] = JSONValue(argListJSON);
	r.object["body"] = JSONValue(bodyJSON);
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
	r.object["node"] = JSONValue("BlockNode");
	r.object["statements"] = JSONValue(statementListJSON);
	return r;
}

/// Creates JSONValue for StatementNode
JSONValue toJSON(StatementNode node){
	JSONValue r;
	r.object["node"] = JSONValue("StatementNode");
	if (node.type == StatementNode.Type.Assignment){
		r.object["statement"] = node.node!(StatementNode.Type.Assignment).toJSON;
	}else if (node.type == StatementNode.Type.Block){
		r.object["statement"] = node.node!(StatementNode.Type.Block).toJSON;
	}else if (node.type == StatementNode.Type.DoWhile){
		r.object["statement"] = node.node!(StatementNode.Type.DoWhile).toJSON;
	}else if (node.type == StatementNode.Type.For){
		r.object["statement"] = node.node!(StatementNode.Type.For).toJSON;
	}else if (node.type == StatementNode.Type.FunctionCall){
		r.object["statement"] = node.node!(StatementNode.Type.FunctionCall).toJSON;
	}else if (node.type == StatementNode.Type.If){
		r.object["statement"] = node.node!(StatementNode.Type.If).toJSON;
	}else if (node.type == StatementNode.Type.VarDeclare){
		r.object["statement"] = node.node!(StatementNode.Type.VarDeclare).toJSON;
	}else if (node.type == StatementNode.Type.While){
		r.object["statement"] = node.node!(StatementNode.Type.While).toJSON;
	}
	return r;
}

/// Creates JSONValue for AssignmentNode
JSONValue toJSON(AssignmentNode node){
	JSONValue r;
	r.object["node"] = JSONValue("AssignmentNode");
	r.object["lvalueIsRef"] = JSONValue(node.deref ? "true" : "false");
	r.object["var"] = node.var.toJSON;
	JSONValue[] indexes;
	indexes.length = node.indexes.length;
	foreach (i, index; node.indexes){
		indexes[i] = index.toJSON;
	}
	r.object["indexes"] = JSONValue(indexes);
	r.object["val"] = node.val.toJSON;
	return r;
}

/// Creates JSONValue for IfNode
JSONValue toJSON(IfNode node){
	JSONValue r;
	r.object["node"] = JSONValue("IfNode");
	r.object["condition"] = node.condition.toJSON;
	r.object["onTrue"] = node.statement.toJSON;
	if (node.hasElse)
		r.object["onFalse"] = node.elseStatement.toJSON;
	return r;
}

/// Creates JSONValue for WhileNode
JSONValue toJSON(WhileNode node){
	JSONValue r;
	r.object["node"] = JSONValue("WhileNode");
	r.object["condtion"] = node.condition.toJSON;
	r.object["statement"] = node.statement.toJSON;
	return r;
}

/// Creates JSONValue for DoWhileNode
JSONValue toJSON(DoWhileNode node){
	JSONValue r;
	r.object["node"] = JSONValue("DoWhileNode");
	r.object["condition"] = node.condition.toJSON;
	r.object["statement"] = node.statement.toJSON;
	return r;
}

/// Creates JSONValue for ForNode
JSONValue toJSON(ForNode node){
	JSONValue r;
	r.object["node"] = JSONValue("ForNode");
	r.object["init"] = node.initStatement.toJSON;
	r.object["condition"] = node.condition.toJSON;
	r.object["inc"] = node.incStatement.toJSON;
	r.object["statement"] = node.statement.toJSON;
	return r;
}

/// Creates JSONValue for FunctionCallNode
JSONValue toJSON(FunctionCallNode node){
	JSONValue r;
	r.object["node"] = JSONValue("FunctionCallNode");
	r.object["name"] = JSONValue(node.fName);
	r.object["type"] = JSONValue(node.returnType.toString);
	JSONValue[] argListJSON;
	argListJSON.length = node.arguments.length;
	foreach (i, arg; node.arguments){
		argListJSON[i] = arg.toJSON;
	}
	r.object["args"] = JSONValue(argListJSON);
	return r;
}

/// Creates JSONValue for VarDeclareNode
JSONValue toJSON(VarDeclareNode node){
	JSONValue r;
	r.object["node"] = JSONValue("varDeclareNode");
	r.object["type"] = JSONValue(node.type.toString);
	JSONValue[] varTypeValueList;
	varTypeValueList.length = node.vars.length;
	foreach (i, varName; node.vars){
		JSONValue var;
		var.object["name"] = JSONValue(varName);
		var.object["id"] = JSONValue(node.varIDs[varName]);
		if (node.hasValue(varName))
			var.object["value"] = node.getValue(varName).toJSON;
		varTypeValueList[i] = var;
	}
	r.object["vars"] = JSONValue(varTypeValueList);
	return r;
}

/// Creates JSONValue for CodeNode
JSONValue toJSON(CodeNode node){
	JSONValue r;
	r.object["node"] = JSONValue("CodeNode");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	if (node.type == CodeNode.Type.Array){
		r.object["code"] = node.node!(CodeNode.Type.Array).toJSON;
	}else if (node.type == CodeNode.Type.FunctionCall){
		r.object["code"] = node.node!(CodeNode.Type.FunctionCall).toJSON;
	}else if (node.type == CodeNode.Type.Literal){
		r.object["code"] = node.node!(CodeNode.Type.Literal).toJSON;
	}else if (node.type == CodeNode.Type.Operator){
		r.object["code"] = node.node!(CodeNode.Type.Operator).toJSON;
	}else if (node.type == CodeNode.Type.ReadElement){
		r.object["code"] = node.node!(CodeNode.Type.ReadElement).toJSON;
	}else if (node.type == CodeNode.Type.SOperator){
		r.object["code"] = node.node!(CodeNode.Type.SOperator).toJSON;
	}else if (node.type == CodeNode.Type.Variable){
		r.object["code"] = node.node!(CodeNode.Type.Variable).toJSON;
	}
	return r;
}

/// Creates JSONValue for VariableNode
JSONValue toJSON(VariableNode node){
	JSONValue r;
	r.object["node"] = JSONValue("VariableNode");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["name"] = JSONValue(node.varName);
	return r;
}

/// Creates JSONValue for ArrayNode
JSONValue toJSON(ArrayNode node){
	JSONValue r;
	r.object["node"] = JSONValue("ArrayNode");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	JSONValue[] elementList;
	elementList.length = node.elements.length;
	foreach (i, element; node.elements){
		elementList[i] = element.toJSON;
	}
	r.object["elements"] = JSONValue(elementList);
	return r;
}

/// Creates JSONValue for LiteralNode
JSONValue toJSON(LiteralNode node){
	JSONValue r;
	r.object["node"] = JSONValue("LiteralNode");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["value"] = JSONValue(node.toByteCode);
	return r;
}

/// Creates JSONValue for OperatorNode
JSONValue toJSON(OperatorNode node){
	JSONValue r;
	r.object["node"] = JSONValue("OperatorNode");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r.object["operator"] = JSONValue(node.operator);
	r.object["operandA"] = node.operands[0].toJSON;
	r.object["operandB"] = node.operands[1].toJSON;
	return r;
}

/// Creates JSONValue for SOperatorNode
JSONValue toJSON(SOperatorNode node){
	JSONValue r;
	r.object["node"] = JSONValue("SOperatorNode");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r.object["operator"] = JSONValue(node.operator);
	r.object["operand"] = node.operand.toJSON;
	return r;
}

/// Creates JSONValue for ReadElement
JSONValue toJSON(ReadElement node){
	JSONValue r;
	r.object["node"] = JSONValue("ReadElement");
	r.object["type"] = JSONValue(node.returnType.toString);
	r.object["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r.object["array"] = node.readFromNode.toJSON;
	r.object["index"] = node.index.toJSON;
	return r;
}