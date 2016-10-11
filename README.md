QScript is a fast, and simple scripting language.<br>
QScript has been designed and tested on only Linux, and I have no plans to add support for Windows.
<br>
<h3>How to build</h3><br>
<ol>
	<li>Download/clone this repo</li>
	<li><code>cd</code> into %CLONE DIR%/qscript</li>
	<li>Build using:<code>dmd -m32 -shared -fPIC "lists.d" "main.d" "misc.d" "qcompiler.d" "qscript.d"</code></li>
</ol><br>
<h3>Usage</h3>
The file <code>qloader.d</code> and <code>main.d</code> in <code>/test</code> demonstrate how to use QScript.<br>
<br>
<h3>Features:</h3>
<ol>
	<li>Declare functions inside scripts</li>
	<li>Easy and unique (a bit like C) syntax</li>
	<li>Dynamic arrays</li>
	<li>Open source - Can't find a feature, implement it yourself</li>
	<li>More features on the way, qscript is still in beta</li>
</ol>
<br>
<h3>Where to get help?</h3>
<p>Use the issues tab at the top, or if you can't, here is my email address: nafees[dot]hassan[at]outlook[dot]com</p>
<br>
<h3>How to contribute?</h3>
<p>Clone this repo, make changes, commit and push to dev branch.</p>
<br>
<br>
