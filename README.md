<p>
This is the dev branch, you should clone from the master branch.<br>
dev branch is for development, and nothing is stable in dev.
</p>
QScript is a fast, and simple scripting language.<br>
QScript has been designed and tested on only Linux, and I have no plans to add support for Windows.
<br>
<h3>How to build</h3><br>
<ol>
	<li>Download/clone this repo</li>
	<li><code>cd</code> into %CLONE DIR%/qscript</li>
	<li>Build using:<code>dmd -m32 -shared -fPIC "lists.d" "main.d" "misc.d" "qcompiler.d" "qscript.d" -oflibqscript.so</code></li>
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
	<li>Fast execution - a loop of 10000 times, calling 8 functions each time, finished within 0.3 - 0.4 seconds.<br>
	Meaning that in 0.4 seconds, 8*10000=80000 functions are finished!</li>
	<li>More features on the way, qscript is still in beta</li>
</ol>
<br>
<h3>Where to get help?</h3>
<p>Use the issues tab at the top, or if you can't, here is my email address: nafees[dot]hassan[at]outlook[dot]com</p>
<br>
<h3>How to contribute?</h3>
<p>Clone this repo, make changes, commit and push to dev or any other branch branch.</p>
<br>
<br>
<h3>Where to learn QScript from?</h3>
<p>I've written a whole wiki on this topic, here is the link to the wiki: <a hred="https://github.com/Nafees10/qscript/wiki">https://github.com/Nafees10/qscript/wiki</a></p>
