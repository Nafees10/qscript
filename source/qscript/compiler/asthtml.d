module qscript.compiler.asthtml;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.misc;
import utils.lists;

/// generates html representation for ScriptNode
string[] toHtml(ScriptNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<scriptNode>Script");
	foreach (functionDef; node.functions){
		html.append(functionDef.toHtml);
	}
	html.append("</scriptNode>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for FunctionNode
string[] toHtml(FunctionNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<functionNode>Function Definition<br>Name: "~node.name~"<br>Return Type: "~node.returnType.toString);
	// add the arguments
	if (node.arguments.length > 0){
		html.append("<functionNodeArguments>Function Arguments");
		foreach (arg; node.arguments){
			html.append("<functionNodeArgument>Type: "~arg.argType.toString~
				"<br> Name: "~arg.argName~"</functionNodeArgument>");
		}
		html.append("</functionNodeArguments>");
	}
	// then add the body
	html.append(node.bodyBlock.toHtml("Function Body:"));
	
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for BlockNode
string[] toHtml(BlockNode node, string blockCaption = null){
	LinkedList!string html = new LinkedList!string;
	if (blockCaption != null){
		html.append("<blockNode>"~blockCaption);
	}else{
		html.append("<blockNode>Block");
	}
	// add statements
	foreach (statement; node.statements){
		html.append(statement.toHtml);
	}
	
	html.append("</blockNode>");
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
		
	}else if (node.type == StatementNode.Type.While){
		
	}else if (node.type == StatementNode.Type.VarDeclare){
		
	}else{
		throw new Exception("invalid stored type");
	}
}
/// generates html representation for AssignmentNode
string[] toHtml(AssignmentNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<assignmentNode>Variable Assignment");
	// add the variable
	html.append("<assingnmentVariable>lvalue");
	// TODO append html for the var (lvalue)
	html.append("</assingnmentVariable>");

	// then add the value
	html.append("<assignmentValue>rvalue");
	// TODO append html for the CodeNode (rvalue)
	html.append("</assignmentValue>");
	html.append("</assignmentNode>");
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html representation for FunctionCall
string[] toHtml(FunctionCallNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<functionCallNode>Function Call<br>Name: "~node.fName~"<br> Return Type: "~node.returnType.toString);
	// add the arguments
	if (node.arguments.length > 0){
		html.append("<functionCallArguments>Arguments");
		foreach (arg; node.arguments){
			// TOdO add html for the CodeNode (arguments)
		}
		html.append("</functionCallArguments>");
	}
	string[] r = html.toArray;
	.destroy(html);
	return r;
}
/// generates html repressntation for IfNode
string[] toHtml(IfNode node){
	LinkedList!string html = new LinkedList!string;
	html.append("<ifNode> If Statement");
	// add condition
	// TODO add html for CodeNode(if condition)
	// then add body
	html.append(BlockNode(node.statements).toHtml("On True"));
}