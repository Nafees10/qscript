/++
Used for debugging the astgen.  
Contains functions to generate a html representation of AST.
+/
module qscript.compiler.asthtml;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

private const string HTML_STYLE = "<style>
div{
\tpadding: 5px;
\tfont-size: 24;
\twidth: auto
\tdisplay: inline-block;
\tborder-style: solid;
\tborder-color: #000000;
\tborder-width: 3px;
}
</style>";

/// generates html representation for ScriptNode
string[] toHtml(ScriptNode node){
	LinkedList!string html = new LinkedList!string;
	html.append(HTML_STYLE);
	html.append("<div>Script");
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
	html.append("<div>Function Definition<br>Name: "~node.name~"<br>Return Type: "~node.returnType.toString);
	// add the arguments
	if (node.arguments.length > 0){
		html.append("<div>Function Arguments");
		foreach (arg; node.arguments){
			html.append("<div>Type: "~arg.argType.toString~
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
		html.append("<div>"~blockCaption);
	}else{
		html.append("<div>Block");
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
string[] toHtml(StatementNode node, string caption = null){
	string[] r;
	if (node.type == StatementNode.Type.Assignment){
		r = node.node!(StatementNode.Type.Assignment).toHtml();
	}else if (node.type == StatementNode.Type.Block){
		r = node.node!(StatementNode.Type.Block).toHtml();
	}else if (node.type == StatementNode.Type.FunctionCall){
		r = node.node!(StatementNode.Type.FunctionCall).toHtml();
	}else if (node.type == StatementNode.Type.If){
		r = node.node!(StatementNode.Type.If).toHtml();
	}else if (node.type == StatementNode.Type.While){
		r = node.node!(StatementNode.Type.While).toHtml();
	}else if (node.type == StatementNode.Type.VarDeclare){
		r = node.node!(StatementNode.Type.VarDeclare).toHtml();
	}else{
		throw new Exception("invalid stored type");
	}
	if (caption != null){
		return ["<div>"~caption]~r~["</div>"];
	}
	return r;
}
/// generates html representation for AssignmentNode
string[] toHtml(AssignmentNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div>Variable Assignment");
	// add the variable
	html.append("<div>lvalue");
	html.append(node.var.toHtml);
	html.append("</div>");

	// then add the value
	html.append("<div>rvalue");
	html.append(node.val.toHtml("Value"));
	html.append("</div></div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for FunctionCall
string[] toHtml(FunctionCallNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div>Function Call<br>Name: "~node.fName~"<br> Return Type: "~node.returnType.toString);
	// add the arguments
	if (node.arguments.length > 0){
		html.append("<div>Arguments");
		foreach (arg; node.arguments){
			html.append(arg.toHtml);
		}
		html.append("</div>");
	}
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html repressntation for IfNode
string[] toHtml(IfNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div>If Statement");
	// add condition
	html.append(node.condition.toHtml("Condition"));
	// then add body
	html.append(node.statement.toHtml("On True"));
	// then add elseBody if any
	if (node.hasElse){
		html.append(node.elseStatement.toHtml("On False"));
	}
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for WhileNode
string[] toHtml(WhileNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div>While Statement");
	// add condition
	html.append(node.condition.toHtml("Condition"));
	// then add body
	html.append(node.statement.toHtml("While True"));
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for VarDeclareNode
string[] toHtml(VarDeclareNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div> Variable Declaration<br>Type: "~node.type.toString);
	// then add the variables declared
	html.append("<div>Variables");
	foreach (var; node.vars){
		html.append("<div>"~var~"</div>");
	}
	html.append("</div></div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for CodeNode
string[] toHtml(CodeNode node, string caption = null){
	string[] r;
	if (node.type == CodeNode.Type.FunctionCall){
		r = node.node!(CodeNode.Type.FunctionCall).toHtml();
	}else if (node.type == CodeNode.Type.Literal){
		r = node.node!(CodeNode.Type.Literal).toHtml();
	}else if (node.type == CodeNode.Type.Operator){
		r = node.node!(CodeNode.Type.Operator).toHtml();
	}else if (node.type == CodeNode.Type.Variable){
		r = node.node!(CodeNode.Type.Variable).toHtml();
	}else{
		throw new Exception("invalid stored type");
	}
	if (caption != null){
		r = ["<div>"~caption]~r~"</div>";
	}
	return r;
}
/// generates html representation for LiteralNode
string[] toHtml(LiteralNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div>Literal<br>Type: "~node.type.toString);
	html.append("<div>"~node.toByteCode~"</div>");
	html.append("</div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for OperatorNode
string[] toHtml(OperatorNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<div>Operator<br>Operator Type: "~node.operator~
		"<br>Return Type: "~node.returnType.toString);
	html.append("<div>");
	foreach (operand; node.operands){
		html.append("<div>"~operand.toHtml~"</div>");
	}
	html.append("</div></div>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for VariableNode
string[] toHtml(VariableNode node){
	string[] r = [
		"<div>Variable<br>Name: "~node.varName~"<br>Type: "~node.varType.toString,
		"</div>"
		];
	return r;
}