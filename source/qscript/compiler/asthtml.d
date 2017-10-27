module qscript.compiler.asthtml;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

/// generates html representation for ScriptNode
string[] toHtml(ScriptNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=scriptNode>Script");
	foreach (functionDef; node.functions){
		html.append(functionDef.toHtml);
	}
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for FunctionNode
string[] toHtml(FunctionNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=functionNode>Function Definition<br>Name: "~node.name~"<br>Return Type: "~node.returnType.toString);
	// add the arguments
	if (node.arguments.length > 0){
		html.append("<div class=functionNodeArguments>Function Arguments");
		foreach (arg; node.arguments){
			html.append("<div class=functionNodeArgument>Type: "~arg.argType.toString~
				"<br> Name: "~arg.argName~"</div>");
		}
		html.append("</div>");
	}
	// then add the body
	html.append(node.bodyBlock.toHtml("Function Body:"));
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for BlockNode
string[] toHtml(BlockNode node, string blockCaption = null){
	LinkedList!string html = new LinkedList!string;
	if (blockCaption != null){
		html.append("<div class=blockNode>"~blockCaption);
	}else{
		html.append("<div class=blockNode>Block");
	}
	// add statements
	foreach (statement; node.statements){
		html.append(statement.toHtml);
	}
	
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for StatementNode
string[] toHtml(StatementNode node){
	if (node.type == StatementNode.Type.Assignment){
		return node.node!(StatementNode.Type.Assignment).toHtml();
	}else if (node.type == StatementNode.Type.Block){
		return node.node!(StatementNode.Type.Block).toHtml();
	}else if (node.type == StatementNode.Type.FunctionCall){
		return node.node!(StatementNode.Type.FunctionCall).toHtml();
	}else if (node.type == StatementNode.Type.If){
		return node.node!(StatementNode.Type.If).toHtml();
	}else if (node.type == StatementNode.Type.While){
		return node.node!(StatementNode.Type.While).toHtml();
	}else if (node.type == StatementNode.Type.VarDeclare){
		return node.node!(StatementNode.Type.VarDeclare).toHtml();
	}else{
		throw new Exception("invalid stored type");
	}
}
/// generates html representation for AssignmentNode
string[] toHtml(AssignmentNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=assignmentNode>Variable Assignment");
	// add the variable
	html.append("<div class=assingnmentVariable>lvalue");
	// TODO append html for the var (lvalue)
	html.append("</div>");

	// then add the value
	html.append("<div class=assignmentValue>rvalue");
	// TODO append html for the CodeNode (rvalue)
	html.append("</div></div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for FunctionCall
string[] toHtml(FunctionCallNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=functionCallNode>Function Call<br>Name: "~node.fName~"<br> Return Type: "~node.returnType.toString);
	// add the arguments
	if (node.arguments.length > 0){
		html.append("<div class=functionCallArguments>Arguments");
		foreach (arg; node.arguments){
			// TOdO add html for the CodeNode (arguments)
		}
		html.append("</div>");
	}
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html repressntation for IfNode
string[] toHtml(IfNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=ifNode>If Statement");
	// add condition
	// TODO add html for CodeNode(if condition)
	// then add body
	html.append(BlockNode(node.statements).toHtml("On True"));
	// then add elseBody if any
	if (node.hasElse){
		html.append(BlockNode(node.elseStatements).toHtml("On False"));
	}
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for WhileNode
string[] toHtml(WhileNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=whileNode>While Statement");
	// add condition
	// TODO add html for CodeNode(while condition)
	// then add body
	html.append(BlockNode(node.statements).toHtml("While True"));
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for VarDeclareNode
string[] toHtml(VarDeclareNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=varDeclareNode> Variable Declaration<br>Type: "~node.type.toString);
	// then add the variables declared
	html.append("<div class=varDeclareVariables>");
	foreach (var; node.vars){
		html.append("<div class=varDeclareVariable>"~var~"</div>");
	}
	html.append("</div></div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for CodeNode
string[] toHtml(CodeNode node){
	if (node.type == CodeNode.Type.FunctionCall){
		return node.node!(CodeNode.Type.FunctionCall).toHtml();
	}else if (node.type == CodeNode.Type.Literal){
		return node.node!(CodeNode.Type.Literal).toHtml();
	}else if (node.type == CodeNode.Type.Operator){
		return node.node!(CodeNode.Type.Operator).toHtml();
	}else if (node.type == CodeNode.Type.Variable){
		return node.node!(CodeNode.Type.Variable).toHtml();
	}else{
		throw new Exception("invalid stored type");
	}
}
/// generates html representation for LiteralNode
string[] toHtml(LiteralNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=literalNode>Literal<br>Type: "~node.type.toString);
	html.append("<div class=literalValue>"~node.toByteCode~"</div>");
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for OperatorNode
string[] toHtml(OperatorNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div class=operatorNode>Operator<br>Operator Type: "~node.operator~
		"<br>Return Type: "~node.returnType.toString);
	html.append("<div class=operatorOperands>");
	foreach (operand; node.operands){
		html.append("<div class=operatorOperand>"~operand.toHtml~"</div>");
	}
	html.append("</div></div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for VariableNode
string[] toHtml(VariableNode node){
	string[] r = [
		"<div class=variableNode>Variable<br>Name: "~node.varName~"<br>Type: "~node.varType.toString,
		"</div>"
		];
	return r;
}