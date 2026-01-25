


--[[


This is the language specification for the markup language I want to make.


The top level assumption is text, or a quoted language environment.  There should be something you can dequote into.
Maybe the spec doesn't need to define what that is, but maybe it does.  
Backslasshing escapes.

[?(*|)*] is the definition for an or block.  Legal blocks include [|], [something|other thing].  You can nest them as well.

(|)?  I would be willing to change the bracket style, the fact we have exactly three kinds of bracket is probably correct?

I see no reason to mess with hyperlinks [](), wiki links [[\]\], just don't use |'s in your titles/urls?  They aren't valid URL characters anyway, so that shouldn't be hard.
Any |'s in your titles should be used as formatting in this context.  I mean, besides, ascii art, does anyone use them?


Yeah, I actually like markdown for the most part and want to keep it, so a markdown extension kind of makes sense, but I'm not willing to deal with how that might
just break.

Right.  Markdown tables.  But as long as you don't place them inside brackets it's fine.
I would define it as ]| table |[, and the final opening bracket doesn't count as part of other things.
I do want this to be markdown compatible, but I also really want to make my own parser to escape into apl.


I also want link annotations.
Or more generally, text annotations.
Inlining?
Not hover text, but something similar, like the footnote text box that pops up.




]]



















