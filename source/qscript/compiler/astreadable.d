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
	JSONValue[] arrayJSON;
	arrayJSON.length = node.functions.length;
	foreach (i, fNode; node.functions){
		arrayJSON[i] = fNode.toJSON;
	}
	JSONValue r;
	r["node"] = JSONValue("ScriptNode");
	r["functions"] = JSONValue(arrayJSON.dup);
	arrayJSON.length = node.enums.length;
	foreach (i, enumNode; node.enums){
		arrayJSON[i] = enumNode.toJSON;
	}
	r["enums"] = JSONValue(arrayJSON.dup);
	arrayJSON.length = node.structs.length;
	foreach (i, structNode; node.structs){
		arrayJSON[i] = structNode.toJSON;
	}
	r["structs"] = JSONValue(arrayJSON.dup);
	arrayJSON.length = node.variables.length;
	foreach (i, var; node.variables){
		arrayJSON[i] = var.toJSON;
	}
	r["variables"] = JSONValue(arrayJSON.dup);
	arrayJSON.length = node.imports.length;
	foreach (i, importName; node.imports){
		arrayJSON[i] = JSONValue(importName);
	}
	r["imports"] = JSONValue(arrayJSON.dup);
	return r;
}

/// Creates JSONValue for FunctionNode
JSONValue toJSON(FunctionNode node){
	JSONValue[] argListJSON;
	argListJSON.length = node.arguments.length;
	foreach (i, arg; node.arguments){
		argListJSON[i]["name"] = JSONValue(arg.argName);
		argListJSON[i]["type"] = JSONValue(arg.argType.name);
	}
	JSONValue bodyJSON = node.bodyBlock.toJSON;
	JSONValue r;
	r["node"] = JSONValue("FunctionNode");
	r["type"] = node.returnType.name;
	r["name"] = node.name;
	r["arguments"] = JSONValue(argListJSON);
	r["body"] = JSONValue(bodyJSON);
	r["id"] = JSONValue(node.id);
	r["lineno"] = JSONValue(node.lineno);
	r["visibility"] = JSONValue(node.visibility.to!string);
	return r;
}

/// Creates JSONValue for StructNode
JSONValue toJSON(StructNode node){
	JSONValue r;
	r["node"] = JSONValue("ScriptNode");
	r["lineno"] = JSONValue(node.lineno);
	r["visibility"] = JSONValue(node.visibility.to!string);
	r["name"] = JSONValue(node.name);
	JSONValue[] members;
	members.length = node.membersName.length;
	foreach (i; 0 .. node.membersName.length){
		members[i]["name"] = JSONValue(node.membersName[i]);
		members[i]["type"] = JSONValue(node.membersDataType[i].name);
	}
	r["members"] = JSONValue(members);
	r["containsRef"] = JSONValue(node.containsRef.to!string);
	return r;
}

/// Creates JSONValue for EnumNode
JSONValue toJSON(EnumNode node){
	JSONValue r;
	r["node"] = JSONValue("EnumNode");
	r["lineno"] = JSONValue(node.lineno);
	r["visibility"] = JSONValue(node.visibility.to!string);
	r["name"] = JSONValue(node.name);
	r["baseDataType"] = JSONValue(node.baseDataType.name);
	JSONValue[] members;
	members.length = node.membersName.length;
	if (node.membersValue.length){
		foreach (i; 0 .. node.membersName.length){
			members[i]["name"] = JSONValue(node.membersName[i]);
			members[i]["value"] = node.membersValue[i].toJSON;
		}
	}else{
		foreach (i, name; node.membersName){
			members[i] = JSONValue(name);
		}
	}
	r["members"] = JSONValue(members);
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
	r["lineno"] = JSONValue(node.lineno);
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
	}else if (node.type == StatementNode.Type.Return){
		r["statement"] = node.node!(StatementNode.Type.Return).toJSON;
	}
	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for AssignmentNode
JSONValue toJSON(AssignmentNode node){
	JSONValue r;
	r["node"] = JSONValue("AssignmentNode");
	r["lineno"] = JSONValue(node.lineno);
	r["deref"] = JSONValue(node.deref.to!string);
	r["lvalue"] = node.lvalue.toJSON;
	r["rvalue"] = node.rvalue.toJSON;
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
	
	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for WhileNode
JSONValue toJSON(WhileNode node){
	JSONValue r;
	r["node"] = JSONValue("WhileNode");
	r["condtion"] = node.condition.toJSON;
	r["statement"] = node.statement.toJSON;

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for DoWhileNode
JSONValue toJSON(DoWhileNode node){
	JSONValue r;
	r["node"] = JSONValue("DoWhileNode");
	r["condition"] = node.condition.toJSON;
	r["statement"] = node.statement.toJSON;

	r["lineno"] = JSONValue(node.lineno);
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

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for FunctionCallNode
JSONValue toJSON(FunctionCallNode node){
	JSONValue r;
	r["node"] = JSONValue("FunctionCallNode");
	r["name"] = JSONValue(node.fName);
	r["type"] = JSONValue(node.returnType.name);
	r["libraryId"] = JSONValue(node.libraryId);
	r["id"] = node.id;
	JSONValue[] argListJSON;
	argListJSON.length = node.arguments.length;
	foreach (i, arg; node.arguments){
		argListJSON[i] = arg.toJSON;
	}
	r["args"] = JSONValue(argListJSON);

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for VarDeclareNode
JSONValue toJSON(VarDeclareNode node){
	JSONValue r;
	r["node"] = JSONValue("varDeclareNode");
	r["visibility"] = JSONValue(node.visibility.to!string);
	r["type"] = JSONValue(node.type.name);
	JSONValue[] varTypeValueList;
	varTypeValueList.length = node.vars.length;
	foreach (i, varName; node.vars){
		JSONValue var;
		var["name"] = JSONValue(varName);
		if (varName in node.varIDs)
			var["id"] = JSONValue(node.varIDs[varName]);
		if (node.hasValue(varName))
			var["value"] = node.getValue(varName).toJSON;
		varTypeValueList[i] = var;
	}
	r["vars"] = JSONValue(varTypeValueList);

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for ReturnNode
JSONValue toJSON(ReturnNode node){
	JSONValue r;
	r["node"] = JSONValue("ReturnNode");
	r["value"] = node.value.toJSON;
	return r;
}

/// Creates JSONValue for CodeNode
JSONValue toJSON(CodeNode node){
	JSONValue r;
	r["node"] = JSONValue("CodeNode");
	r["type"] = JSONValue(node.returnType.name);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	if (node.type == CodeNode.Type.Array){
		r["code"] = node.node!(CodeNode.Type.Array).toJSON;
	}else if (node.type == CodeNode.Type.FunctionCall){
		r["code"] = node.node!(CodeNode.Type.FunctionCall).toJSON;
	}else if (node.type == CodeNode.Type.Literal){
		r["code"] = node.node!(CodeNode.Type.Literal).toJSON;
	}else if (node.type == CodeNode.Type.Negative){
		r["code"] = node.node!(CodeNode.Type.Negative).toJSON;
	}else if (node.type == CodeNode.Type.Operator){
		r["code"] = node.node!(CodeNode.Type.Operator).toJSON;
	}else if (node.type == CodeNode.Type.ReadElement){
		r["code"] = node.node!(CodeNode.Type.ReadElement).toJSON;
	}else if (node.type == CodeNode.Type.SOperator){
		r["code"] = node.node!(CodeNode.Type.SOperator).toJSON;
	}else if (node.type == CodeNode.Type.Variable){
		r["code"] = node.node!(CodeNode.Type.Variable).toJSON;
	}else if (node.type == CodeNode.Type.MemberSelector){
		r["code"] = node.node!(CodeNode.Type.MemberSelector).toJSON;
	}
	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for VariableNode
JSONValue toJSON(VariableNode node){
	JSONValue r;
	r["node"] = JSONValue("VariableNode");
	r["type"] = JSONValue(node.returnType.name);
	r["name"] = JSONValue(node.varName);
	r["id"] = JSONValue(node.id);
	r["libraryId"] = JSONValue(node.libraryId);
	r["isGlobal"] = JSONValue(node.isGlobal);
	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for ArrayNode
JSONValue toJSON(ArrayNode node){
	JSONValue r;
	r["node"] = JSONValue("ArrayNode");
	r["type"] = JSONValue(node.returnType.name);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	JSONValue[] elementList;
	elementList.length = node.elements.length;
	foreach (i, element; node.elements){
		elementList[i] = element.toJSON;
	}
	r["elements"] = JSONValue(elementList);

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for LiteralNode
JSONValue toJSON(LiteralNode node){
	JSONValue r;
	r["node"] = JSONValue("LiteralNode");
	r["type"] = JSONValue(node.returnType.name);
	r["value"] = JSONValue(node.literal);

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for NegativeValue
JSONValue toJSON(NegativeValueNode node){
	JSONValue r;
	r["node"] = JSONValue("NegativeValueNode");
	r["type"] = JSONValue(node.returnType.name);
	r["value"] = node.value.toJSON;
	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for MemberSelectorNode
JSONValue toJSON(MemberSelectorNode node){
	JSONValue r;
	r["node"] = JSONValue("MemberSelectorNode");
	r["type"] = JSONValue(node.returnType.name);
	r["lineno"] = JSONValue(node.lineno);
	r["parent"] = node.parent.toJSON;
	r["member"] = JSONValue(node.memberName);
	return r;
}

/// Creates JSONValue for OperatorNode
JSONValue toJSON(OperatorNode node){
	JSONValue r;
	r["node"] = JSONValue("OperatorNode");
	r["type"] = JSONValue(node.returnType.name);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r["operator"] = JSONValue(node.operator);
	r["operandA"] = node.operands[0].toJSON;
	r["operandB"] = node.operands[1].toJSON;

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for SOperatorNode
JSONValue toJSON(SOperatorNode node){
	JSONValue r;
	r["node"] = JSONValue("SOperatorNode");
	r["type"] = JSONValue(node.returnType.name);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r["operator"] = JSONValue(node.operator);
	r["operand"] = node.operand.toJSON;

	r["lineno"] = JSONValue(node.lineno);
	return r;
}

/// Creates JSONValue for ReadElement
JSONValue toJSON(ReadElement node){
	JSONValue r;
	r["node"] = JSONValue("ReadElement");
	r["type"] = JSONValue(node.returnType.name);
	r["isLiteral"] = JSONValue(node.isLiteral ? "true" : "false");
	r["array"] = node.readFromNode.toJSON;
	r["index"] = node.index.toJSON;

	r["lineno"] = JSONValue(node.lineno);
	return r;
}
